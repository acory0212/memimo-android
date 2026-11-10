import 'package:flutter/material.dart';

/// 一个可选主题（名称 + 种子色）
class ThemePreset {
  final String name;
  final Color seed;

  const ThemePreset(this.name, this.seed);
}

/// 全局调色板：所有界面颜色都从这里取，切换主题时统一切换。
///
/// 用法：启动时 `AppPalette.apply(index)`，切换时同样调用并把
/// `revision.value++` 通知 MaterialApp 重建。
class AppPalette {
  AppPalette._();

  /// 可选的预设主题色
  static const List<ThemePreset> presets = [
    ThemePreset('松绿', Color(0xFF4A7C59)),
    ThemePreset('海蓝', Color(0xFF1565C0)),
    ThemePreset('墨紫', Color(0xFF6A3FB5)),
    ThemePreset('暖橙', Color(0xFFE65100)),
    ThemePreset('玫红', Color(0xFFC2185B)),
    ThemePreset('石墨', Color(0xFF37474F)),
  ];

  /// 当前选中的索引
  static int index = 0;

  /// 主题变更通知（MaterialApp 监听它重建）
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static ColorScheme _scheme = ColorScheme.fromSeed(seedColor: presets[0].seed);

  /// 应用第 i 个主题
  static void apply(int i) {
    index = i.clamp(0, presets.length - 1);
    _scheme = ColorScheme.fromSeed(seedColor: presets[index].seed);
  }

  static ColorScheme get scheme => _scheme;
  static Color get seed => presets[index].seed;

  /// 主色
  static Color get primary => _scheme.primary;

  /// 浅一档的主色（渐变、进度条用）
  static Color get primaryLight => Color.lerp(primary, Colors.white, 0.38)!;

  /// 深一档的主色（强调文字用）
  static Color get primaryDark => Color.lerp(primary, Colors.black, 0.42)!;

  /// 很浅的主色背景（卡片底色）
  static Color get soft => Color.lerp(primary, Colors.white, 0.92)!;

  /// 页面背景
  static Color get background => Color.lerp(primary, Colors.white, 0.965)!;

  /// 首页大卡片的渐变
  static List<Color> get gradient => [primary, primaryLight];
}
