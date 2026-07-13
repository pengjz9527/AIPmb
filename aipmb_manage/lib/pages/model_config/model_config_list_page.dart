import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_manage/models/model_config.dart';
import 'package:aipmb_manage/providers/model_config_provider.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';

class ModelConfigListPage extends ConsumerStatefulWidget {
  const ModelConfigListPage({super.key});

  @override
  ConsumerState<ModelConfigListPage> createState() => _ModelConfigListPageState();
}

class _ModelConfigListPageState extends ConsumerState<ModelConfigListPage> {
  @override
  Widget build(BuildContext context) {
    final configsAsync = ref.watch(modelConfigsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('模型配置')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/model-configs/new'),
        child: const Icon(Icons.add),
      ),
      body: configsAsync.when(
        data: (configs) => configs.isEmpty
            ? const Center(child: Text('暂无配置'))
            : ListView.builder(
                itemCount: configs.length,
                itemBuilder: (_, i) => _ConfigListTile(
                  config: configs[i],
                  onRefresh: () => ref.invalidate(modelConfigsProvider),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }
}

class _ConfigListTile extends ConsumerWidget {
  final ModelConfig config;
  final VoidCallback onRefresh;

  const _ConfigListTile({required this.config, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        title: Text(config.name),
        subtitle: Text('${config.provider} · ${config.modelName}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (config.isActive)
              const Chip(
                label: Text('活跃', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.green,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
            else
              FilledButton.tonal(
                onPressed: () async {
                  await ApiClient().post(ApiConfig.configActivate(config.id));
                  onRefresh();
                },
                child: const Text('激活'),
              ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/model-configs/${config.id}/edit'),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: config.isActive
                  ? null
                  : () async {
                      await ApiClient().delete(ApiConfig.configDetail(config.id));
                      onRefresh();
                    },
            ),
          ],
        ),
      ),
    );
  }
}