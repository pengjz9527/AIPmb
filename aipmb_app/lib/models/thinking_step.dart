/// 技能调用步骤状态
enum ThinkingStepStatus { invoking, completed, error }

/// 编排阶段
enum ThinkingPhase { intent, orchestrate, collect, analyze, unknown }

/// 单个技能调用步骤
class ThinkingStep {
  final String stepId;
  final String skillName;
  final String displayName;
  final String message;
  final ThinkingStepStatus status;
  final ThinkingPhase phase;
  final int phaseOrder;

  const ThinkingStep({
    required this.stepId,
    required this.skillName,
    required this.displayName,
    required this.message,
    required this.status,
    this.phase = ThinkingPhase.unknown,
    this.phaseOrder = 0,
  });

  factory ThinkingStep.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'invoking';
    ThinkingStepStatus status;
    switch (statusStr) {
      case 'completed':
        status = ThinkingStepStatus.completed;
        break;
      case 'error':
        status = ThinkingStepStatus.error;
        break;
      default:
        status = ThinkingStepStatus.invoking;
    }

    final phaseStr = json['phase'] as String? ?? '';
    ThinkingPhase phase;
    switch (phaseStr) {
      case 'intent':
        phase = ThinkingPhase.intent;
        break;
      case 'orchestrate':
        phase = ThinkingPhase.orchestrate;
        break;
      case 'collect':
        phase = ThinkingPhase.collect;
        break;
      case 'analyze':
        phase = ThinkingPhase.analyze;
        break;
      default:
        phase = ThinkingPhase.unknown;
    }

    return ThinkingStep(
      stepId: json['step_id'] as String? ?? '',
      skillName: json['skill_name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: status,
      phase: phase,
      phaseOrder: json['phase_order'] as int? ?? 0,
    );
  }

  /// 是否为编排阶段节点（意图识别/编排/分析生成）
  bool get isPhaseNode => phase != ThinkingPhase.unknown && phase != ThinkingPhase.collect;

  /// 阶段中文名
  String get phaseName {
    switch (phase) {
      case ThinkingPhase.intent:
        return '意图识别';
      case ThinkingPhase.orchestrate:
        return 'Skill编排';
      case ThinkingPhase.collect:
        return '数据收集';
      case ThinkingPhase.analyze:
        return '分析生成';
      case ThinkingPhase.unknown:
        return '处理中';
    }
  }
}