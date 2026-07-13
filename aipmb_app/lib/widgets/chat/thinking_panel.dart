import 'package:flutter/material.dart';
import 'package:aipmb_app/config/design_tokens.dart';
import 'package:aipmb_app/models/thinking_step.dart';

/// 可折叠的思考过程面板 — 流程图样式展示 Skill 编排
class ThinkingPanel extends StatefulWidget {
  final List<ThinkingStep> steps;
  final String? reasoningContent;

  const ThinkingPanel({
    super.key,
    required this.steps,
    this.reasoningContent,
  });

  @override
  State<ThinkingPanel> createState() => _ThinkingPanelState();
}

class _ThinkingPanelState extends State<ThinkingPanel> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.steps.any((s) => s.status == ThinkingStepStatus.invoking);
  }

  @override
  void didUpdateWidget(covariant ThinkingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.steps.any((s) => s.status == ThinkingStepStatus.invoking)) {
      _isExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final completedCount = widget.steps.where((s) => s.status == ThinkingStepStatus.completed).length;
    final inProgressCount = widget.steps.where((s) => s.status == ThinkingStepStatus.invoking).length;

    // 按阶段分组
    final phaseGroups = _groupByPhase(widget.steps);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 折叠/展开标题行
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  if (inProgressCount > 0)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  else
                    Icon(Icons.check_circle_outline, size: 14, color: Colors.green.shade600),
                  const SizedBox(width: 6),
                  Text(
                    inProgressCount > 0
                        ? '思考中... ($completedCount/${widget.steps.length} 步骤完成)'
                        : '已完成 ${widget.steps.length} 个步骤',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 展开的流程图
          AnimatedSize(
            duration: DesignTokens.durationNormal,
            curve: DesignTokens.curveStandard,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1, indent: 12, endIndent: 12),
                      AnimatedOpacity(
                        duration: DesignTokens.durationNormal,
                        opacity: _isExpanded ? 1.0 : 0.0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 流程图标题
                              Text(
                                'Skill 编排流程',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              // 阶段流程图
                              ..._buildPhaseFlow(phaseGroups),
                              const SizedBox(height: 8),
                              // 推理内容
                              if (widget.reasoningContent != null &&
                                  widget.reasoningContent!.isNotEmpty) ...[
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Text(
                                  '推理过程：',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.reasoningContent!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// 按阶段分组步骤
  Map<ThinkingPhase, List<ThinkingStep>> _groupByPhase(List<ThinkingStep> steps) {
    final groups = <ThinkingPhase, List<ThinkingStep>>{};
    for (final step in steps) {
      groups.putIfAbsent(step.phase, () => []).add(step);
    }
    return groups;
  }

  /// 构建阶段流程图
  List<Widget> _buildPhaseFlow(Map<ThinkingPhase, List<ThinkingStep>> phaseGroups) {
    final phases = [
      ThinkingPhase.intent,
      ThinkingPhase.orchestrate,
      ThinkingPhase.collect,
      ThinkingPhase.analyze,
    ];

    final List<Widget> widgets = [];
    bool hasAddedUnknown = false;

    for (int i = 0; i < phases.length; i++) {
      final phase = phases[i];
      final steps = phaseGroups[phase] ?? [];

      // 在 Skill编排 阶段前插入 unknown 阶段的步骤（兼容旧数据）
      if (phase == ThinkingPhase.orchestrate && !hasAddedUnknown) {
        final unknownSteps = phaseGroups[ThinkingPhase.unknown] ?? [];
        if (unknownSteps.isNotEmpty) {
          widgets.add(_buildPhaseNode(ThinkingPhase.unknown, unknownSteps));
          widgets.add(_buildConnector(unknownSteps.every((s) => s.status == ThinkingStepStatus.completed)));
          hasAddedUnknown = true;
        }
      }

      if (steps.isEmpty) continue;

      // 阶段节点
      widgets.add(_buildPhaseNode(phase, steps));

      // 连接箭头（除最后一个有内容的阶段）
      final remainingPhases = phases.sublist(i + 1);
      final hasMoreContent = remainingPhases.any((p) => (phaseGroups[p] ?? []).isNotEmpty) ||
          (!hasAddedUnknown && (phaseGroups[ThinkingPhase.unknown] ?? []).isNotEmpty);
      if (hasMoreContent) {
        widgets.add(_buildConnector(steps.every((s) => s.status == ThinkingStepStatus.completed)));
      }
    }

    // 如果前面没有插入 unknown，且存在 unknown 步骤，在最后显示
    if (!hasAddedUnknown) {
      final unknownSteps = phaseGroups[ThinkingPhase.unknown] ?? [];
      if (unknownSteps.isNotEmpty) {
        if (widgets.isNotEmpty) {
          widgets.add(_buildConnector(false));
        }
        widgets.add(_buildPhaseNode(ThinkingPhase.unknown, unknownSteps));
      }
    }

    return widgets;
  }

  /// 构建阶段节点
  Widget _buildPhaseNode(ThinkingPhase phase, List<ThinkingStep> steps) {
    final isCompleted = steps.every((s) => s.status == ThinkingStepStatus.completed);
    final isInvoking = steps.any((s) => s.status == ThinkingStepStatus.invoking);
    final hasError = steps.any((s) => s.status == ThinkingStepStatus.error);

    Color nodeColor;
    IconData nodeIcon;
    if (hasError) {
      nodeColor = Colors.red.shade400;
      nodeIcon = Icons.error_outline;
    } else if (isInvoking) {
      nodeColor = Theme.of(context).colorScheme.primary;
      nodeIcon = Icons.hourglass_top;
    } else if (isCompleted) {
      nodeColor = Colors.green.shade500;
      nodeIcon = Icons.check_circle;
    } else {
      nodeColor = Colors.grey.shade400;
      nodeIcon = Icons.circle_outlined;
    }

    final phaseTitle = steps.first.phaseName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isInvoking ? nodeColor.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isInvoking ? nodeColor.withValues(alpha: 0.3) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 阶段标题行
          Row(
            children: [
              Icon(nodeIcon, size: 16, color: nodeColor),
              const SizedBox(width: 6),
              Text(
                phaseTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: nodeColor,
                ),
              ),
              const Spacer(),
              if (isInvoking)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: nodeColor),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // 阶段内的步骤详情
          ...steps.map((step) => _buildStepDetail(step)),
        ],
      ),
    );
  }

  /// 构建步骤详情
  Widget _buildStepDetail(ThinkingStep step) {
    IconData icon;
    Color color;
    switch (step.status) {
      case ThinkingStepStatus.completed:
        icon = Icons.check;
        color = Colors.green.shade600;
        break;
      case ThinkingStepStatus.error:
        icon = Icons.close;
        color = Colors.red.shade500;
        break;
      case ThinkingStepStatus.invoking:
        icon = Icons.arrow_right;
        color = Theme.of(context).colorScheme.primary;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 22, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              step.message.isNotEmpty ? step.message : step.displayName,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建阶段间连接箭头
  Widget _buildConnector(bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Container(
            width: 2,
            height: 16,
            color: isActive
                ? Colors.green.shade300
                : Colors.grey.shade300,
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            size: 14,
            color: isActive ? Colors.green.shade400 : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }
}
