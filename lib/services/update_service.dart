import 'dart:async';
import 'dart:convert';
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
}

class UpdateService {
  static const String _updateJsonUrl =
      'https://memimo-updates.netlify.app/version.json';

  /// 最近一次检查失败的原因（null 表示成功）
  static String? lastError;

  /// 最近一次检查的诊断信息（版本号、HTTP 状态、原始响应片段）
  static String diagnostic = '尚未检查';

  /// 检查更新。
  /// 返回 null 表示"已是最新"或"检查失败"，用 [lastError] 区分两者。
  static Future<UpdateInfo?> checkUpdate({bool silent = false}) async {
    lastError = null;
    final sb = StringBuffer();
    try {
      final pkg = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(pkg.buildNumber) ?? 1;
      sb.writeln('当前版本: ${pkg.version} (code $currentVersionCode)');

      final resp = await http
          .get(
            Uri.parse(_updateJsonUrl),
            headers: {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 12));

      sb.writeln('HTTP 状态: ${resp.statusCode}');
      if (resp.statusCode != 200) {
        lastError = '服务器返回 ${resp.statusCode}';
        diagnostic = sb.toString();
        return null;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final update = UpdateInfo.fromJson(data);
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
    } on TimeoutException {
      lastError = '连接超时，请检查网络';
      sb.writeln('结果: 超时');
      diagnostic = sb.toString();
      return null;
    } catch (e) {
      lastError = '网络错误：${e.toString().split('\n').first}';
      sb.writeln('结果: 异常 $e');
      diagnostic = sb.toString();
      return null;
    }
  }

  // 简单版本号比较：1.2.3 > 1.2.2
  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map(int.parse).toList();
    final c = current.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
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
              Text(info.releaseNotes),
              const SizedBox(height: 12),
            ],
            Text(
              info.forceUpdate
                  ? '此版本为强制更新，必须更新后才能继续使用。'
                  : '建议更新以获得更好体验。',
              style: TextStyle(
                  fontSize: 13, color: info.forceUpdate ? Colors.red : Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          if (!info.forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后'),
            ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse(info.downloadUrl);
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

  /// 在 Settings 页手动点击「检查更新」时调用
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
      messenger.showSnackBar(
        SnackBar(content: Text('检查失败：$lastError')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('已是最新版本')),
      );
    }
  }

  /// App 启动时静默检查（不弹框，只在有强制更新 / 有普通更新时弹）
  static Future<void> autoCheck(BuildContext context) async {
    final info = await checkUpdate(silent: true);
    if (context.mounted && info != null) {
      _showUpdateDialog(context, info);
    }
  }
}