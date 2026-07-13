import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aipmb_app/config/theme.dart';
import 'package:aipmb_app/config/routes.dart';
import 'package:aipmb_app/config/api_config.dart';
import 'package:aipmb_app/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 加载用户保存的服务器地址
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('server_url');
  if (savedUrl != null && savedUrl.isNotEmpty) {
    ApiConfig.setBaseUrl(savedUrl);
  }

  runApp(const ProviderScope(child: AipmbApp()));
}

/// 全局禁用滚动惯性回弹效果
/// iPhone 默认为 BouncingScrollPhysics（橡皮筋效果），Android 为 ClampingScrollPhysics（硬截断）
/// 此处统一为 ClampingScrollPhysics 去除弹性滚动。
/// 如需某个页面恢复惯性效果，可在该页面局部使用 ScrollConfiguration 覆盖。
class NoOverscrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

class AipmbApp extends ConsumerWidget {
  const AipmbApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = buildRouter(ref);
    return ScrollConfiguration(
      behavior: NoOverscrollBehavior(),
      child: MaterialApp.router(
        title: 'AI手机银行',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.buildTheme(themeMode),
        routerConfig: router,
      ),
    );
  }
}
