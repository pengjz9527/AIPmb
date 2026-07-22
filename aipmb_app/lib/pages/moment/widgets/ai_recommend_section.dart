import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/providers/recommendation_provider.dart';
import 'package:aipmb_app/services/api_client.dart';
import 'package:aipmb_app/models/recommendation.dart';
import 'package:aipmb_app/models/thinking_step.dart';
import 'package:aipmb_app/widgets/chat/thinking_panel.dart';
import 'package:aipmb_app/widgets/cards/product_card.dart';
import 'package:aipmb_app/pages/moment/widgets/section_header.dart';

class AiRecommendSection extends ConsumerStatefulWidget {
  const AiRecommendSection({super.key});

  @override
  ConsumerState<AiRecommendSection> createState() => _AiRecommendSectionState();
}

class _AiRecommendSectionState extends ConsumerState<AiRecommendSection> {
  List<AiMatchedProduct> _aiProducts = [];
  bool _isRefreshing = false;
  List<ThinkingStep> _matchThinkingSteps = [];
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiProductsAsync = ref.watch(aiMatchedProductsProvider);

    // 首次加载同步本地状态
    aiProductsAsync.whenData((products) {
      if (!_isRefreshing) {
        _aiProducts = products;
      }
    });

    final displayProducts = _aiProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header + 换一批
        Row(
          children: [
            const SectionHeader(title: '为你推荐'),
            const Spacer(),
            if (displayProducts.isNotEmpty)
              TextButton.icon(
                onPressed: _isRefreshing ? null : _onRefresh,
                icon: _isRefreshing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.autorenew, size: 16),
                label: Text(_isRefreshing ? '匹配中...' : '换一批', style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),

        // 思考过程
        if (_isRefreshing && _matchThinkingSteps.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ThinkingPanel(
              steps: _matchThinkingSteps,
              reasoningContent: 'AI 正在分析你的消费画像和风险偏好...',
            ),
          ),

        if (_isRefreshing && _matchThinkingSteps.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('正在启动 AI 智能匹配...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),

        // 产品卡片
        if (displayProducts.isEmpty && !_isRefreshing)
          aiProductsAsync.when(
            data: (_) => const Padding(padding: EdgeInsets.all(16), child: Text('暂无推荐', style: TextStyle(color: Colors.grey))),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('加载失败: $e', style: TextStyle(color: Colors.red))),
          )
        else if (displayProducts.isNotEmpty)
          Column(
            children: displayProducts.asMap().entries.map((e) {
              final p = e.value;
              return ProductRecommendationCard(
                item: p.toProductRecommendation(),
                index: e.key,
                onTap: () => context.push('/product/detail?product_name=${Uri.encodeComponent(p.productName)}'),
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _matchThinkingSteps = [];
    });

    try {
      final api = ref.read(apiProvider);
      final refreshResp = await refreshAiProducts(api);
      final data = refreshResp['data'];
      final status = data is Map ? data['status'] as String? : null;

      if (status == 'ok') {
        final products = (data?['products'] as List?) ?? [];
        if (mounted) {
          setState(() {
            _aiProducts = products.map((e) => AiMatchedProduct.fromJson(e as Map<String, dynamic>)).toList();
            _isRefreshing = false;
          });
        }
        return;
      }

      _startPolling(api);
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _startPolling(ApiClient api) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final progress = await fetchMatchProgress(api);
        if (!mounted) { timer.cancel(); return; }

        final thinkingSteps = progress.toThinkingSteps();
        setState(() => _matchThinkingSteps = thinkingSteps);

        if (progress.isDone) {
          timer.cancel();
          final resultProducts = progress.result ?? [];
          setState(() {
            _aiProducts = resultProducts.map((e) => AiMatchedProduct.fromJson(e)).toList();
            _isRefreshing = false;
          });
          ref.invalidate(aiMatchedProductsProvider);
        }
      } catch (_) {}
    });
  }
}
