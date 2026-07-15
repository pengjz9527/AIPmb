import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aipmb_app/config/design_tokens.dart';
import 'package:aipmb_app/models/history_today.dart';

class HistoryTodayCard extends StatelessWidget {
  final HistoryTodayResult result;
  final VoidCallback? onDismiss;
  final int? index;

  const HistoryTodayCard({
    super.key,
    required this.result,
    this.onDismiss,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    final memory = result.memory;
    final benefit = result.benefit;
    if (memory == null || benefit == null) return const SizedBox.shrink();

    final card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLG)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade50,
              Colors.orange.shade50,
              Colors.pink.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            _buildHeader(context),
            // 纪念内容
            _buildMemory(context, memory),
            const Divider(indent: 16, endIndent: 16, height: 1),
            // 权益
            _buildBenefit(context, benefit),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    final delay = index != null ? DesignTokens.staggerDelay(index!) : DesignTokens.staggerBase;
    return card
        .animate(delay: delay, autoPlay: true)
        .fadeIn(
          duration: DesignTokens.durationEntrance,
          curve: DesignTokens.curveEntrance,
        )
        .slideY(
          begin: 0.06,
          end: 0,
          duration: DesignTokens.durationEntrance,
          curve: DesignTokens.curveEntrance,
        );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.history_toggle_off,
                size: 18, color: Colors.orange.shade700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('历史上的今天',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(result.todayFormatted,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildMemory(BuildContext context, HistoryTodayMemory memory) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 年份标记
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${memory.year}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800)),
                Text('年',
                    style: TextStyle(
                        fontSize: 10, color: Colors.orange.shade600)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(memory.eventTypeLabel,
                      style: TextStyle(
                          fontSize: 10, color: Colors.orange.shade700)),
                ),
                const SizedBox(height: 4),
                Text(memory.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(memory.description,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(BuildContext context, HistoryTodayBenefit benefit) {
    final hasProduct = benefit.linkedProduct != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          // 权益图标
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: benefit.forFamily
                  ? Colors.pink.shade50
                  : Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              benefit.forFamily ? Icons.favorite : Icons.card_giftcard,
              size: 20,
              color: benefit.forFamily
                  ? Colors.pink.shade400
                  : Colors.teal.shade400,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(benefit.label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  benefit.forFamily
                      ? '为家人送上: ${benefit.benefitDesc}'
                      : benefit.benefitDesc,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // CTA 按钮
          SizedBox(
            height: 30,
            child: ElevatedButton(
              onPressed: () {
                if (hasProduct) {
                  context.push(benefit.linkedProduct!.detailLink);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Text(hasProduct ? '去看看' : '领取'),
            ),
          ),
        ],
      ),
    );
  }
}
