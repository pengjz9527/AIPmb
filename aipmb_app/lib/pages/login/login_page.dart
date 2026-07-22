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

  // 预设环境
  static const _localUrl = 'http://10.0.2.2:8001';
  static const _cloudUrl = 'http://39.107.68.177:8000';

  String get _currentEnvLabel {
    final url = ApiConfig.baseUrl;
    if (url.startsWith(_localUrl)) return '🏠 本地';
    if (url.startsWith(_cloudUrl)) return '☁️ 公网';
    return '🔧 自定义';
  }

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
            // 服务器地址配置入口（右上角）
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _showServerConfigDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        _currentEnvLabel,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
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

  /// 显示服务器地址配置弹窗（含快捷切换）
  void _showServerConfigDialog() {
    _serverUrlController.text = ApiConfig.baseUrl;
    final isLocal = ApiConfig.baseUrl.startsWith(_localUrl);
    final isCloud = ApiConfig.baseUrl.startsWith(_cloudUrl);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
              // 快捷切换按钮
              const Text('快速切换', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildPresetButton(
                      ctx,
                      setDialogState,
                      label: '🏠 本地开发',
                      subtitle: '10.0.2.2:8001',
                      url: _localUrl,
                      active: isLocal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPresetButton(
                      ctx,
                      setDialogState,
                      label: '☁️ 公网环境',
                      subtitle: '39.107.68.177',
                      url: _cloudUrl,
                      active: isCloud,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              // 自定义地址
              const Text('自定义地址', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              TextField(
                controller: _serverUrlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'http://...',
                  prefixIcon: const Icon(Icons.link, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  helperText: '模拟器用 10.0.2.2 访问宿主机',
                  helperMaxLines: 2,
                  helperStyle: const TextStyle(fontSize: 10),
                ),
                style: const TextStyle(fontSize: 13),
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
      ),
    );
  }

  /// 预设环境按钮
  Widget _buildPresetButton(
    BuildContext dialogContext,
    StateSetter setDialogState, {
    required String label,
    required String subtitle,
    required String url,
    required bool active,
  }) {
    return InkWell(
      onTap: () {
        _serverUrlController.text = url;
        setDialogState(() {});
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: active ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
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
