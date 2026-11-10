import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// 下载进度快照
class DownloadProgress {
  final int received;
  final int total;
  final double bytesPerSecond;
  final bool merging;

  const DownloadProgress(this.received, this.total, this.bytesPerSecond,
      {this.merging = false});

  static const idle = DownloadProgress(0, 0, 0);

  bool get connecting => total <= 0;

  double get fraction => total <= 0 ? 0 : (received / total).clamp(0.0, 1.0);

  int get percent => (fraction * 100).floor();

  static String humanBytes(int b) {
    if (b >= 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }

  String get sizeText => '${humanBytes(received)} / ${humanBytes(total)}';

  String get speedText {
    if (bytesPerSecond <= 0) return '—';
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / 1024 / 1024).toStringAsFixed(2)} MB/s';
    }
    return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
  }

  String? get etaText {
    if (bytesPerSecond <= 0 || total <= 0) return null;
    final left = total - received;
    if (left <= 0) return null;
    final s = (left / bytesPerSecond).round();
    if (s < 1) return '即将完成';
    if (s < 60) return '剩 $s 秒';
    return '剩 ${(s / 60).ceil()} 分钟';
  }
}

/// 用户主动取消下载
class DownloadCancelled implements Exception {
  const DownloadCancelled();
  @override
  String toString() => '下载已取消';
}

/// 下载失败
class DownloadException implements Exception {
  final String message;
  const DownloadException(this.message);
  @override
  String toString() => message;
}

class _Probe {
  final String url;
  final int total;
  final Duration elapsed;
  const _Probe(this.url, this.total, this.elapsed);
}

/// 多源 + 多连接分片下载器
///
/// 为什么需要它：GitHub 及其免费镜像普遍对**单条连接**限速（实测
/// ghproxy.net 单连接只有 20KB/s）。但把文件切成多段、每条连接各下一段，
/// 带宽是可以叠加的（实测 16 连接比单连接快 7 倍以上）。
///
/// 注意实现细节：Dart 的 FileMode 没有「不截断的随机写」模式
/// （writeOnly 也会 truncate），所以每个分片先写自己的临时文件，
/// 全部下完再顺序合并，避免多连接互相清空对方的数据。
class MultiSourceDownloader {
  static Future<File> download({
    required List<String> urls,
    required String savePath,
    required void Function(DownloadProgress) onProgress,
    bool Function()? isCancelled,
    int maxConnections = 16,
  }) async {
    final cancelled = isCancelled ?? () => false;
    final file = File(savePath);
    final partFiles = <File>[];

    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..idleTimeout = const Duration(seconds: 60)
      ..maxConnectionsPerHost = 24
      ..userAgent = 'Mozilla/5.0 (Linux; Android) memimo-updater';

    onProgress(DownloadProgress.idle);

    try {
      // ---- 1. 并发探测所有源，挑最快的 ----
      final probes = await Future.wait(urls.map((u) => _probe(client, u)));
      final usable = probes.whereType<_Probe>().where((p) => p.total > 0).toList()
        ..sort((a, b) => a.elapsed.compareTo(b.elapsed));

      if (usable.isEmpty) {
        throw const DownloadException('所有下载源都连不上，请检查网络后重试');
      }
      if (cancelled()) throw const DownloadCancelled();

      final best = usable.first;
      final total = best.total;

      // ---- 2. 切片 ----
      final mb8 = 8 * 1024 * 1024;
      final wanted =
          total > mb8 ? maxConnections : (total > 2 * 1024 * 1024 ? 8 : 4);
      final parts = wanted.clamp(1, 16);
      final chunk = (total / parts).ceil();

      var received = 0;
      var lastReceived = 0;
      var lastTick = DateTime.now();
      var speed = 0.0;

      final ticker = Timer.periodic(const Duration(milliseconds: 350), (_) {
        final now = DateTime.now();
        final dt = now.difference(lastTick).inMilliseconds / 1000.0;
        if (dt > 0) {
          speed = (received - lastReceived) / dt;
          lastReceived = received;
          lastTick = now;
        }
        onProgress(DownloadProgress(received, total, speed));
      });

      final futures = <Future<void>>[];
      for (var i = 0; i < parts; i++) {
        final start = i * chunk;
        if (start >= total) break;
        final end = (start + chunk - 1) >= total ? total - 1 : start + chunk - 1;
        final pf = File('$savePath.$i.part');
        partFiles.add(pf);
        futures.add(_fetchPart(
          client: client,
          url: best.url,
          partFile: pf,
          start: start,
          end: end,
          onBytes: (n) => received += n,
          cancelled: cancelled,
        ));
      }

      try {
        await Future.wait(futures);
      } finally {
        ticker.cancel();
      }

      if (cancelled()) throw const DownloadCancelled();

      // ---- 3. 合并 ----
      onProgress(DownloadProgress(total, total, speed, merging: true));

      var written = 0;
      final sink = file.openWrite();
      try {
        for (final pf in partFiles) {
          if (await pf.exists()) {
            written += await pf.length();
            await sink.addStream(pf.openRead());
          }
        }
      } finally {
        await sink.close();
      }

      if (written != total) {
        throw DownloadException('文件不完整（$written / $total 字节），请重试');
      }

      onProgress(DownloadProgress(total, total, speed));
      return file;
    } finally {
      client.close(force: true);
      for (final pf in partFiles) {
        try {
          if (await pf.exists()) await pf.delete();
        } catch (_) {}
      }
    }
  }

  /// 下 128KB 测速，同时拿到文件总大小
  static Future<_Probe?> _probe(HttpClient client, String url) async {
    final sw = Stopwatch()..start();
    try {
      final req = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-131071');
      final resp = await req.close().timeout(const Duration(seconds: 6));
      if (resp.statusCode != 206 && resp.statusCode != 200) return null;

      int total = 0;
      final cr = resp.headers.value('content-range');
      if (cr != null) {
        final i = cr.lastIndexOf('/');
        if (i >= 0) total = int.tryParse(cr.substring(i + 1)) ?? 0;
      }
      if (total <= 0 && resp.contentLength > 0) total = resp.contentLength;

      var got = 0;
      try {
        await for (final chunk in resp.timeout(const Duration(seconds: 8))) {
          got += chunk.length;
          if (got >= 131072) break;
        }
      } catch (_) {}

      sw.stop();
      if (total <= 0 || got < 4096) return null;
      return _Probe(url, total, sw.elapsed);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _fetchPart({
    required HttpClient client,
    required String url,
    required File partFile,
    required int start,
    required int end,
    required void Function(int) onBytes,
    required bool Function() cancelled,
  }) async {
    final need = end - start + 1;
    var attempt = 0;

    while (true) {
      var sent = 0;
      try {
        final req = await client
            .getUrl(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
        final resp = await req.close().timeout(const Duration(seconds: 15));

        if (resp.statusCode != 206) {
          throw DownloadException('分片请求被拒绝（HTTP ${resp.statusCode}）');
        }

        final sink = partFile.openWrite();
        try {
          var remaining = need;
          await for (final chunk in resp) {
            if (cancelled()) throw const DownloadCancelled();
            if (chunk.isEmpty) continue;
            final take = chunk.length > remaining ? remaining : chunk.length;
            sink.add(take == chunk.length ? chunk : chunk.sublist(0, take));
            remaining -= take;
            sent += take;
            onBytes(take);
            if (remaining <= 0) break;
          }
          if (remaining > 0) {
            throw DownloadException('分片数据不完整（缺 $remaining 字节）');
          }
        } finally {
          await sink.close();
        }
        return;
      } catch (e) {
        if (e is DownloadCancelled) rethrow;
        if (sent > 0) onBytes(-sent);
        attempt++;
        if (attempt >= 4) {
          if (e is DownloadException) rethrow;
          throw DownloadException('分片下载失败：$e');
        }
        await Future.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
  }
}
