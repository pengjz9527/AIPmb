/// 日历生成进度状态
class CalendarGenProgress {
  final String status;
  final int step;
  final int totalSteps;
  final String message;
  final List<CalendarGenStep> steps;

  const CalendarGenProgress({
    required this.status,
    required this.step,
    required this.totalSteps,
    required this.message,
    required this.steps,
  });

  factory CalendarGenProgress.fromJson(Map<String, dynamic> json) {
    return CalendarGenProgress(
      status: json['status'] ?? '',
      step: json['step'] ?? 0,
      totalSteps: json['total_steps'] ?? 6,
      message: json['message'] ?? '',
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => CalendarGenStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isDone => status == 'done';
  bool get isError => status == 'error';
  bool get isRunning => !isDone && !isError;
}

class CalendarGenStep {
  final String id;
  final String label;
  final String icon;
  final String? detail;

  const CalendarGenStep({
    required this.id,
    required this.label,
    required this.icon,
    this.detail,
  });

  factory CalendarGenStep.fromJson(Map<String, dynamic> json) {
    return CalendarGenStep(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      icon: json['icon'] ?? '',
      detail: json['detail'],
    );
  }
}
