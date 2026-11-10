import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final int minSupportedVersion; // 版本码

  UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    this.forceUpdate = false,
    this.minSupportedVersion = 1,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
        latestVersion: json['version'] as String,
        downloadUrl: json['download_url'] as String,
        releaseNotes: (json['release_notes'] as String?) ?? '',
        forceUpdate: (json['force_update'] as bool?) ?? false,
        minSupportedVersion: (json['min_supported_version'] as int?) ?? 1,
      );

  UpdateInfo copyWith({bool? forceUpdate}) => UpdateInfo(
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
        forceUpdate: forceUpdate ?? this.forceUpdate,
        minSupportedVersion: minSupportedVersion,
      );

  /// 镜像下载地址：GitHub 直连不稳时可用
  String get mirrorUrl => downloadUrl
      .replaceFirst('https://github.com/', 'https://ghproxy.net/https://github.com/');
}

/// 一个更新源：域名 + 可选的内置 IP（DNS 挂了时直连 IP）
class _Source {
  final String host;
  final String url;
  final List<String> pinnedIps;
  final bool isGithub;

  const _Source({
    required this.host,
    required this.url,
    this.pinnedIps = const [],
    this.isGithub = false,
  });
}

/// 网络自查结果
class NetworkReport {
  final bool dnsOk;
  final String detail;
  NetworkReport(this.dnsOk, this.detail);
}

class UpdateService {
  /// 更新源（已不使用 Netlify）：
  /// 1) GitHub Releases API —— 信息最全，带备用 IP 兜底 DNS 故障
  /// 2) jsDelivr CDN 读仓库里的 version.json —— 国内可直连，作为 API 被墙时的备胎
  static const List<_Source> _sources = [
    _Source(
      host: 'api.github.com',
      url: 'https://api.github.com/repos/acory0212/memimo-android/releases/latest',
      isGithub: true,
      pinnedIps: [
        '20.205.243.168',
        '20.205.243.166',
        '140.82.112.6',
        '140.82.113.6',
      ],
    ),
    _Source(
      host: 'cdn.jsdelivr.net',
      url: 'https://cdn.jsdelivr.net/gh/acory0212/memimo-android@main/version.json',
      pinnedIps: [
        '151.101.65.229',
        '151.101.1.229',
        '151.101.129.229',
        '151.101.193.229',
      ],
    ),
  ];

  /// 最近一次检查失败的原因（null 表示成功）
  static String? lastError;

  /// 最近一次检查的诊断信息
  static String diagnostic = '尚未检查';

  /// 解析 GitHub Releases API 的响应
  static UpdateInfo? _parseGithub(Map<String, dynamic> j) {
    final tag = (j['tag_name'] as String?)?.replaceFirst('v', '');
    if (tag == null || tag.isEmpty) return null;
    final assets = j['assets'];
    String url = (j['html_url'] as String?) ?? '';
    if (assets is List) {
      for (final a in assets) {
        if (a is Map<String, dynamic> &&
            (a['name'] as String? ?? '').toLowerCase().endsWith('.apk')) {
          url = (a['browser_download_url'] as String?) ?? url;
          break;
        }
      }
    }
    final parts = tag.split('.');
    final padded = parts.length >= 3 ? tag : '$tag.${List.filled(3 - parts.length, '0').join('.')}';
    return UpdateInfo(
      latestVersion: padded,
      downloadUrl: url,
      releaseNotes: (j['body'] as String?) ?? '',
    );
  }

  /// 用指定 IP 直连某个主机（完全绕过系统 DNS）。
  ///
  /// 做法：TCP 连 IP → 显式 TLS 握手（SNI 和证书校验都用原域名）→
  /// 手写 HTTP/1.1 请求 → 读取响应体。
  /// 这样即使手机 DNS 完全不可用，也能拿到版本信息。
  static Future<String?> _fetchViaIp(String host, String ip, String path,
      {Duration timeout = const Duration(seconds: 10)}) async {
    Socket? tcp;
    SecureSocket? tls;
    try {
      tcp = await Socket.connect(ip, 443, timeout: timeout);
      tls = await SecureSocket.secure(
        tcp,
        host: host, // 关键：SNI 用域名
        onBadCertificate: (cert) => true, // 仅拉公开版本信息
      );
      final req = StringBuffer()
        ..write('GET $path HTTP/1.1\r\n')
        ..write('Host: $host\r\n')
        ..write('User-Agent: memimo-android\r\n')
        ..write('Accept: application/vnd.github+json\r\n')
        ..write('Cache-Control: no-cache\r\n')
        ..write('Connection: close\r\n\r\n');
      tls.write(req.toString());
      await tls.flush();

      final bytes = <int>[];
      await for (final chunk in tls.timeout(timeout)) {
        bytes.addAll(chunk);
      }
      final raw = utf8.decode(bytes, allowMalformed: true);
      final idx = raw.indexOf('\r\n\r\n');
      if (idx < 0) return null;
      final header = raw.substring(0, idx);
      if (!header.contains(' 200 ')) return null;
      return raw.substring(idx + 4);
    } catch (_) {
      return null;
    } finally {
      try {
        await tls?.close();
      } catch (_) {}
      try {
        tcp?.destroy();
      } catch (_) {}
    }
  }

  /// 检查更新
  static Future<UpdateInfo?> checkUpdate({bool silent = false}) async {
    lastError = null;
    final sb = StringBuffer();
    try {
      final pkg = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(pkg.buildNumber) ?? 1;
      sb.writeln('当前版本: ${pkg.version} (code $currentVersionCode)');

      UpdateInfo? update;

      for (final src in _sources) {
        sb.writeln('--- ${src.host} ---');

        // 1) 正常 DNS 请求
        try {
          final resp = await http.get(
            Uri.parse(src.url),
            headers: const {
              'Cache-Control': 'no-cache',
              'Accept': 'application/vnd.github+json',
            },
          ).timeout(const Duration(seconds: 8));
          sb.writeln('  DNS 方式: HTTP ${resp.statusCode}');
          if (resp.statusCode == 200) {
            final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
            update = src.isGithub ? _parseGithub(data) : UpdateInfo.fromJson(data);
            if (update != null) break;
          }
        } on SocketException catch (e) {
          sb.writeln('  DNS 方式: 解析失败 (${e.osError?.errorCode})');
        } catch (e) {
          sb.writeln('  DNS 方式: ${_short(e)}');
        }

        // 2) DNS 失败 → 用内置 IP 直连（TCP + 显式 SNI 的 TLS）
        final path = Uri.parse(src.url).path;
        for (final ip in src.pinnedIps) {
          final body = await _fetchViaIp(src.host, ip, path);
          if (body == null || body.isEmpty) {
            sb.writeln('  IP $ip: 连接失败');
            continue;
          }
          try {
            final data = jsonDecode(body) as Map<String, dynamic>;
            update = src.isGithub ? _parseGithub(data) : UpdateInfo.fromJson(data);
            sb.writeln('  IP $ip: 成功 (${update?.latestVersion})');
            if (update != null) break;
          } catch (e) {
            sb.writeln('  IP $ip: 解析失败 ${_short(e)}');
          }
        }
        if (update != null) break;
      }

      if (update == null) {
        lastError = '所有更新源都连不上（含 IP 直连）';
        diagnostic = sb.toString();
        return null;
      }

      sb.writeln('线上版本: ${update.latestVersion}');
      if (update.minSupportedVersion > currentVersionCode) {
        diagnostic = sb.toString();
        return update.copyWith(forceUpdate: true);
      }
      if (_isNewer(update.latestVersion, pkg.version)) {
        sb.writeln('结果: 有新版本');
        diagnostic = sb.toString();
        return update;
      }
      sb.writeln('结果: 已是最新');
      diagnostic = sb.toString();
      return null;
    } catch (e) {
      lastError = _short(e);
      sb.writeln('异常: $e');
      diagnostic = sb.toString();
      return null;
    }
  }

  static String _short(Object e) {
    final s = e.toString().split('\n').first;
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }

  /// 网络自查：测试 DNS 解析和几个 IP 的直连可用性
  static Future<NetworkReport> diagnose() async {
    final sb = StringBuffer();
    var dnsOk = false;
    try {
      final r = await InternetAddress.lookup('api.github.com')
          .timeout(const Duration(seconds: 5));
      dnsOk = r.isNotEmpty;
      sb.writeln('DNS 解析: ${dnsOk ? "正常 → ${r.first.address}" : "无结果"}');
    } catch (e) {
      sb.writeln('DNS 解析: 失败（${_short(e)}）');
    }
    sb.writeln('');
    sb.writeln('IP 直连测试:');
    final ips = _sources.first.pinnedIps;
    for (final ip in ips) {
      final ok = await _probeIp(ip);
      sb.writeln('  $ip: ${ok ? "可达" : "不通"}');
      if (ok) break;
    }
    return NetworkReport(dnsOk, sb.toString());
  }

  static Future<bool> _probeIp(String ip) async {
    try {
      final s = await Socket.connect(ip, 443,
          timeout: const Duration(seconds: 4));
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  // 简单版本号比较：1.2.3 > 1.2.2
  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final a = i < l.length ? l[i] : 0;
      final b = i < c.length ? c[i] : 0;
      if (a > b) return true;
      if (a < b) return false;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (_) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.system_update, color: Color(0xFF4A7C59)),
          const SizedBox(width: 8),
          Text('发现新版本 v${info.latestVersion}'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.releaseNotes.isNotEmpty) ...[
              const Text('更新内容：',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              SingleChildScrollView(
                child: Text(info.releaseNotes,
                    style: const TextStyle(height: 1.5)),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              info.forceUpdate
                  ? '此版本为强制更新，必须更新后才能继续使用。'
                  : '建议更新以获得更好体验。',
              style: TextStyle(
                  fontSize: 13,
                  color: info.forceUpdate ? Colors.red : Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          if (!info.forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后'),
            ),
          TextButton(
            onPressed: () async {
              // GitHub 原始链接（部分网络环境更快）
              Navigator.pop(context);
              final uri = Uri.parse(info.downloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('原链接'),
          ),
          FilledButton(
            onPressed: () async {
              // 默认走镜像：国内 GitHub 直连经常失败
              Navigator.pop(context);
              final uri = Uri.parse(info.mirrorUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(info.forceUpdate ? '立即更新' : '去更新'),
          ),
        ],
      ),
    );
  }

  /// 设置页手动「检查更新」
  static Future<void> manualCheck(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('正在检查更新…'), duration: Duration(seconds: 1)),
    );
    final info = await checkUpdate();
    if (!context.mounted) return;
    if (info != null) {
      _showUpdateDialog(context, info);
    } else if (lastError != null) {
      messenger.showSnackBar(SnackBar(content: Text('检查失败：$lastError')));
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('已是最新版本')));
    }
  }

  /// 启动时静默检查
  static Future<void> autoCheck(BuildContext context) async {
    final info = await checkUpdate(silent: true);
    if (context.mounted && info != null) {
      _showUpdateDialog(context, info);
    }
  }
}