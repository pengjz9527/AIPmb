import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aipmb_app/config/api_config.dart';
import 'package:aipmb_app/services/api_client.dart';
import 'package:aipmb_app/providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phoneController = TextEditingController();
  final _serverUrlController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _serverUrlController.text = ApiConfig.baseUrl;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Icon(
                      Icons.account_balance,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AI 手机银行',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '手机号登录，即刻体验智能银行服务',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 48),
                    // 手机号输入
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: '手机号',
                        hintText: '请输入手机银行预留手机号',
                        prefixIcon: const Icon(Icons.phone_android),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 登录按钮
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _doLogin,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('登录', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 服务器地址配置入口（右上角齿轮）
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(
                  Icons.settings,
                  color: Colors.grey.shade500,
                  size: 22,
                ),
                tooltip: '服务器地址设置',
                onPressed: _showServerConfigDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doLogin() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入手机号')),
      );
      return;
    }
    if (phone.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的11位手机号')),
      );
      return;
    }
    setState(() => _loading = true);
    await ref.read(authProvider.notifier).login(phone);
    setState(() => _loading = false);

    final authState = ref.read(authProvider);
    if (authState.asData?.value != null) {
      if (context.mounted) context.go('/moment');
    } else {
      if (context.mounted) {
        final errMsg = authState.hasError
            ? authState.error.toString()
            : '用户不存在';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败：$errMsg')),
        );
      }
    }
  }

  /// 显示服务器地址配置弹窗
  void _showServerConfigDialog() {
    _serverUrlController.text = ApiConfig.baseUrl;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.dns_outlined, size: 20),
            SizedBox(width: 8),
            Text('服务器地址', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _serverUrlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'API 地址',
                hintText: '例如 http://192.168.1.100:8000',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                helperText: '手机与电脑需在同一局域网',
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _saveServerUrl(ctx),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 保存服务器地址到 SharedPreferences 并更新 ApiClient
  Future<void> _saveServerUrl(BuildContext dialogContext) async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入服务器地址')),
      );
      return;
    }
    // 简易校验：必须是 http:// 或 https:// 开头
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('地址必须以 http:// 或 https:// 开头')),
      );
      return;
    }

    // 保存到 SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);

    // 更新 ApiConfig 和 ApiClient
    ApiClient().updateBaseUrl(url);

    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('服务器地址已更新：$url')),
      );
    }
  }
}
