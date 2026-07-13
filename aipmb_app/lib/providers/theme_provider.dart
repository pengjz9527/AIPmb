import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 三套主题模式
enum AppThemeMode {
  /// 科幻系：紫/靛蓝/粉紫
  sciFi('科幻系', '🪐'),

  /// 二次元系：樱花粉/软紫/暖橙
  anime('二次元系', '🌸'),

  /// 浓艳系：正红/琥珀金/紫罗兰
  vibrant('浓艳系', '🔥');

  final String label;
  final String emoji;
  const AppThemeMode(this.label, this.emoji);
}

/// 当前主题模式 Provider
final themeModeProvider = StateProvider<AppThemeMode>((ref) => AppThemeMode.sciFi);
