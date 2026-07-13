import 'package:flutter/material.dart';
import 'package:aipmb_app/models/suggestion.dart';

/// 底部悬浮跟随条 — 展示 AI 下一步建议
///
/// 收起态：横向滚动标签行 + `>>` 展开按钮
/// 展开态：2 列卡片网格（含描述）+ `<<` 收起按钮
/// 点击标签/卡片直接发送 prompt，无需手动输入
class FloatingSuggestionBar extends StatefulWidget {
  final List<NextSuggestion> suggestions;
  final void Function(NextSuggestion suggestion) onTap;

  const FloatingSuggestionBar({
    super.key,
    required this.suggestions,
    required this.onTap,
  });

  @override
  State<FloatingSuggestionBar> createState() => _FloatingSuggestionBarState();
}

class _FloatingSuggestionBarState extends State<FloatingSuggestionBar> {
  bool _isExpanded = false;

  @override
  void didUpdateWidget(covariant FloatingSuggestionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 建议列表变为空时自动收起
    if (widget.suggestions.isEmpty) {
      _isExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.suggestions.isEmpty) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: _isExpanded ? _buildExpanded(context) : _buildCollapsed(context),
      ),
    );
  }

  /// 收起态：标题 + 横向标签 + >> 按钮
  Widget _buildCollapsed(BuildContext context) {
    return Row(
      children: [
        Text(
          '💡 下一步建议',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in widget.suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildTag(context, s),
                  ),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: () => setState(() => _isExpanded = true),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '>>',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  /// 展开态：标题 + << 按钮 + 卡片网格
  Widget _buildExpanded(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              '💡 下一步建议',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () => setState(() => _isExpanded = false),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '<<',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildCardGrid(context),
      ],
    );
  }

  Widget _buildCardGrid(BuildContext context) {
    final items = widget.suggestions;
    if (items.length == 1) {
      return _buildCard(context, items.first);
    }
    // 2 列网格
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((s) => SizedBox(
            width: cardWidth,
            child: _buildCard(context, s),
          )).toList(),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, NextSuggestion suggestion) {
    final color = switch (suggestion.priority) {
      'high' => Colors.orange,
      'low' => Colors.grey,
      _ => Theme.of(context).colorScheme.primary,
    };

    return InkWell(
      onTap: () => widget.onTap(suggestion),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    suggestion.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (suggestion.reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                suggestion.reason,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, NextSuggestion suggestion) {
    final color = switch (suggestion.priority) {
      'high' => Colors.orange,
      'low' => Colors.grey,
      _ => Theme.of(context).colorScheme.primary,
    };

    return ActionChip(
      avatar: Icon(Icons.auto_awesome, size: 14, color: color),
      label: Text(
        suggestion.label,
        style: TextStyle(fontSize: 13, color: color),
      ),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.05),
      onPressed: () => widget.onTap(suggestion),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
