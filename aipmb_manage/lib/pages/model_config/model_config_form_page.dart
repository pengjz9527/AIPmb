import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';
import 'package:aipmb_manage/providers/model_config_provider.dart';

class ModelConfigFormPage extends ConsumerStatefulWidget {
  final String? configId;
  const ModelConfigFormPage({super.key, this.configId});

  @override
  ConsumerState<ModelConfigFormPage> createState() => _ModelConfigFormPageState();
}

class _ModelConfigFormPageState extends ConsumerState<ModelConfigFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _providerCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _modelNameCtrl = TextEditingController();
  bool _loading = true;

  bool get isEdit => widget.configId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _loadConfig();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadConfig() async {
    try {
      final res = await ApiClient().get(ApiConfig.configDetail(widget.configId!));
      final data = res.data['data'];
      if (data != null && mounted) {
        _nameCtrl.text = data['name'] ?? '';
        _providerCtrl.text = data['provider'] ?? '';
        _apiKeyCtrl.text = data['api_key'] ?? '';
        _baseUrlCtrl.text = data['base_url'] ?? '';
        _modelNameCtrl.text = data['model_name'] ?? '';
      }
    } catch (_) {
      // 加载失败，保持空表单
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _providerCtrl.dispose();
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(isEdit ? '编辑配置' : '新建配置')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '编辑配置' : '新建配置')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '配置名称', hintText: '如: Kimi K2.5'),
                validator: (v) => (v == null || v.isEmpty) ? '必填' : null,
              ),
              TextFormField(
                controller: _providerCtrl,
                decoration: const InputDecoration(labelText: '提供商', hintText: '如: moonshot'),
                validator: (v) => (v == null || v.isEmpty) ? '必填' : null,
              ),
              TextFormField(
                controller: _apiKeyCtrl,
                decoration: const InputDecoration(labelText: 'API Key'),
                validator: (v) => (v == null || v.isEmpty) ? '必填' : null,
              ),
              TextFormField(
                controller: _baseUrlCtrl,
                decoration: const InputDecoration(labelText: 'Base URL', hintText: '如: https://api.moonshot.cn/v1'),
                validator: (v) => (v == null || v.isEmpty) ? '必填' : null,
              ),
              TextFormField(
                controller: _modelNameCtrl,
                decoration: const InputDecoration(labelText: '模型名称', hintText: '如: kimi-k2.5'),
                validator: (v) => (v == null || v.isEmpty) ? '必填' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                child: Text(isEdit ? '保存' : '创建'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final data = {
      'name': _nameCtrl.text,
      'provider': _providerCtrl.text,
      'api_key': _apiKeyCtrl.text,
      'base_url': _baseUrlCtrl.text,
      'model_name': _modelNameCtrl.text,
    };
    try {
      if (isEdit) {
        await ApiClient().put(ApiConfig.configDetail(widget.configId!), data: data);
      } else {
        await ApiClient().post(ApiConfig.modelConfigs, data: data);
      }
      // 强制刷新列表页（GoRouter 子路由回到父路由时不会重建）
      ref.invalidate(modelConfigsProvider);
      if (mounted) context.go('/model-configs');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失败: $e')));
    }
  }
}