import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/providers/matching_provider.dart';
import 'package:aipmb_manage/providers/tagging_provider.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';
import 'package:aipmb_manage/widgets/match_product_card.dart';

class MatchingPage extends ConsumerWidget {
  final String userName;
  const MatchingPage({super.key, required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider(userName));
    final tagsAsync = ref.watch(userTagsProvider(userName));

    return Scaffold(
      appBar: AppBar(title: Text('$userName 产品匹配')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          try {
            await ApiClient().post(ApiConfig.matches, data: {'user_name': userName});
            ref.invalidate(matchesProvider(userName));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('匹配生成成功')));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成失败: $e')));
            }
          }
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('AI 生成匹配'),
      ),
      body: matchesAsync.when(
        data: (record) {
          if (record == null || record.matches.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tagsAsync.valueOrNull == null ? '请先生成标签' : '暂无匹配结果，点击右下角按钮生成'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: record.matches.length,
            itemBuilder: (_, i) => MatchProductCard(match: record.matches[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }
}