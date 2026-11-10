// 验证分片并发下载器：真实下载一次 APK 并校验完整性
// 运行：dart run tool/check_downloader.dart
import 'dart:io';

import '../lib/services/downloader.dart';

const _expected = 79679809; // v1.6.0 APK 的字节数
const _url = 'https://github.com/acory0212/memimo-android/releases/download/v1.6.0/memimo-v1.6.0.apk';

void main() async {
  final out = 'D:/Minecraft/dev-tools/temp/dl-selftest.apk';
  var lastShown = -1;

  print('目标: $_url');
  print('期望大小: $_expected bytes');
  print('');

  final sw = Stopwatch()..start();
  File? result;

  try {
    result = await MultiSourceDownloader.download(
      urls: [
        'https://gh-proxy.com/$_url',
        'https://ghfast.top/$_url',
        'https://ghproxy.net/$_url',
        _url,
      ],
      savePath: out,
      onProgress: (p) {
        if (p.connecting) return;
        if (p.percent >= lastShown + 10 || p.percent == 100) {
          lastShown = p.percent;
          print('${p.percent.toString().padLeft(3)}%  ${p.sizeText.padRight(18)}  '
              '${p.speedText.padRight(10)}  ${p.etaText ?? ''}');
        }
      },
    );
  } on DownloadException catch (e) {
    print('FAILED: $e');
    exit(1);
  }

  sw.stop();
  final len = await result.length();
  final mbps = len / sw.elapsed.inMilliseconds * 1000 / 1024 / 1024;

  print('');
  print('实际大小: $len bytes');
  print('耗时:     ${sw.elapsed.inSeconds} 秒');
  print('平均速度: ${mbps.toStringAsFixed(2)} MB/s');

  var ok = true;
  if (len != _expected) {
    print('FAIL 大小不符（期望 $_expected）');
    ok = false;
  } else {
    print('ok   大小正确');
  }

  // 检查文件头：APK 是 zip，应以 PK 开头
  final raf = await result.open();
  final head = await raf.read(4);
  await raf.close();
  if (head.length >= 2 && head[0] == 0x50 && head[1] == 0x4B) {
    print('ok   文件头是合法 ZIP/APK (PK)');
  } else {
    print('FAIL 文件头异常: ${head.map((b) => b.toRadixString(16)).join(' ')}');
    ok = false;
  }

  // 检查文件尾：zip 中央目录结束标记附近应有 PK\x05\x06
  final raf2 = await result.open();
  await raf2.setPosition(len - 64);
  final tail = await raf2.read(64);
  await raf2.close();
  var found = false;
  for (var i = 0; i + 4 <= tail.length; i++) {
    if (tail[i] == 0x50 && tail[i + 1] == 0x4B && tail[i + 2] == 0x05 && tail[i + 3] == 0x06) {
      found = true;
      break;
    }
  }
  if (found) {
    print('ok   文件尾有 ZIP 中央目录结束标记');
  } else {
    print('FAIL 文件尾缺少 ZIP 结束标记（可能最后一段没下完）');
    ok = false;
  }

  print('');
  print(ok ? '结论: 分片下载器工作正常' : '结论: 有问题');
  if (!ok) exit(1);
}
