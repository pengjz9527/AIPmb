import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/config/theme.dart';
import 'package:aipmb_manage/config/routes.dart';

void main() {
  runApp(const ProviderScope(child: AipmbManageApp()));
}

class AipmbManageApp extends StatelessWidget {
  const AipmbManageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AI-Manage 运营管理',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}