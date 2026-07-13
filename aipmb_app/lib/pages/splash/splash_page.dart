import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/providers/auth_provider.dart';

/// 启动页：检查登录态后自动跳转
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  Widget build(BuildContext context) {
    // watch authProvider 确保状态变化时自动跳转
    final authState = ref.watch(authProvider);

    // 状态一旦确定（非 loading），立即跳转
    if (authState is AsyncData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (authState.value != null) {
            context.go('/moment');
          } else {
            context.go('/login');
          }
        }
      });
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'AI 手机银行',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
