import 'package:aipmb_app/models/thinking_step.dart';

/// AI 产品匹配进度步骤
class MatchProgressStep {
  final String id; // e.g. "checking_tags"
  final String label; // e.g. "检查用户标签"
  final String icon; // e.g. "label"
  final String status; // "pending" | "running" | "completed" | "error"
  final String? detail;

  const MatchProgressStep({
    required this.id,
    required this.label,
    this.icon = '',
    this.status = 'pending',
    this.detail,
  });

  factory MatchProgressStep.fromJson(Map<String, dynamic> json) =>
      MatchProgressStep(
        id: json['id'] ?? '',
        label: json['label'] ?? '',
        icon: json['icon'] ?? '',
        status: json['status'] ?? 'pending',
        detail: json['detail'],
      );

  bool get isCompleted => status == 'completed';
  bool get isRunning => status == 'running';
  bool get isPending => status == 'pending' || status == '';
}

/// AI 产品匹配的完整进度
class MatchProgress {
  final String status; // "running" | "done" | "error" | "idle"
  final List<MatchProgressStep> steps;
  final String message;
  final List<Map<String, dynamic>>? result; // only when done
  final List<String>? tagsUsed;

  const MatchProgress({
    this.status = 'idle',
    this.steps = const [],
    this.message = '',
    this.result,
    this.tagsUsed,
  });

  factory MatchProgress.fromJson(Map<String, dynamic> json) {
    final stepsList = (json['steps'] as List?)
        ?.map((e) => MatchProgressStep.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    final resultList = (json['result'] as List?)
        ?.map((e) => e as Map<String, dynamic>)
        .toList();
    final tagsList = (json['tags_used'] as List?)
        ?.cast<String>();

    return MatchProgress(
      status: json['status'] ?? 'idle',
      steps: stepsList,
      message: json['message'] ?? '',
      result: resultList,
      tagsUsed: tagsList,
    );
  }

  bool get isDone => status == 'done';
  bool get isRunning => status == 'running';
  bool get isIdle => status == 'idle';

  /// 将匹配步骤转为 ThinkingStep 列表，复用聊天中的 ThinkingPanel 组件
  List<ThinkingStep> toThinkingSteps() {
    return steps.map((s) {
      ThinkingStepStatus st;
      switch (s.status) {
        case 'completed':
          st = ThinkingStepStatus.completed;
          break;
        case 'running':
          st = ThinkingStepStatus.invoking;
          break;
        default:
          st = ThinkingStepStatus.invoking; // will show as pending in UI
      }

      // 阶段映射: 前两步为数据收集，后三步为分析匹配
      ThinkingPhase phase;
      int phaseOrder;
      if (s.id == 'checking_tags' || s.id == 'checking_risk' || s.id == 'loading_products') {
        phase = ThinkingPhase.collect;
        phaseOrder = 0;
      } else if (s.id == 'generating_tags' || s.id == 'matching' || s.id == 'ranking') {
        phase = ThinkingPhase.analyze;
        phaseOrder = 1;
      } else {
        phase = ThinkingPhase.unknown;
        phaseOrder = 2;
      }

      return ThinkingStep(
        stepId: s.id,
        skillName: 'ai_product_matching',
        displayName: s.label,
        message: s.detail ?? '',
        status: st,
        phase: phase,
        phaseOrder: phaseOrder,
      );
    }).toList();
  }
}
