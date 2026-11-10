import 'dart:io';

import 'package:flutter/services.dart';

/// 调用系统安装器安装 APK
///
/// Android 7 以上不允许直接暴露 file:// 路径，必须经 FileProvider 转成
/// content:// URI 才有读权限，所以这里走 MethodChannel 交给原生处理。
class ApkInstaller {
  static const MethodChannel _channel = MethodChannel('memimo/install');

  static Future<void> install(String apkPath) async {
    final file = File(apkPath);
    if (!await file.exists()) {
      throw Exception('安装包不存在：$apkPath');
    }
    try {
      await _channel.invokeMethod<bool>('installApk', {'path': apkPath});
    } on PlatformException catch (e) {
      throw Exception(e.message ?? '无法启动安装器');
    } on MissingPluginException {
      throw Exception('当前系统不支持应用内安装，请手动打开安装包');
    }
  }

  /// 打开系统的「安装未知应用」授权页，方便用户放行
  static Future<void> openInstallPermissionSettings() async {
    try {
      await _channel.invokeMethod<bool>('openInstallSettings');
    } catch (_) {}
  }
}
