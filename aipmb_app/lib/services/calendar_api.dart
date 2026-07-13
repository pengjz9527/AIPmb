import 'dart:async';
import 'package:aipmb_app/services/api_client.dart';
import 'package:aipmb_app/config/api_config.dart';

/// 日历生成进度状态
class CalendarGenProgress {
  final String status;
  final int step;
  final int totalSteps;
  final String message;
  final List<Map<String, dynamic>> steps;
  final Map<String, dynamic>? result;

  const CalendarGenProgress({
    required this.status,
    required this.step,
    required this.totalSteps,
    required this.message,
    required this.steps,
    this.result,
  });

  factory CalendarGenProgress.fromJson(Map<String, dynamic> json) {
    return CalendarGenProgress(
      status: json['status'] ?? '',
      step: json['step'] ?? 0,
      totalSteps: json['total_steps'] ?? 6,
      message: json['message'] ?? '',
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      result: json['result'] as Map<String, dynamic>?,
    );
  }

  bool get isDone => status == 'done';
  bool get isError => status == 'error';
  bool get isRunning => !isDone && !isError;
}

/// 纪念日历 API 服务
class CalendarApi {
  final ApiClient _client;

  CalendarApi(this._client);

  /// 启动异步日历生成
  Future<void> startGeneration(String userName) async {
    await _client.post('${ApiConfig.calendarGenerate}/$userName/generate-async');
  }

  /// 查询生成进度
  Future<CalendarGenProgress> checkStatus(String userName) async {
    final resp = await _client.get('${ApiConfig.calendarStatus}/$userName/status');
    final data = resp['data'];
    if (data == null) {
      throw Exception('无效的进度数据');
    }
    return CalendarGenProgress.fromJson(data as Map<String, dynamic>);
  }

  /// 获取已生成的日历
  Future<Map<String, dynamic>> getCalendar(String userName) async {
    final resp = await _client.get('${ApiConfig.calendarGet}/$userName');
    final data = resp['data'];
    if (data == null) {
      throw Exception('日历数据为空');
    }
    return data as Map<String, dynamic>;
  }

  /// 轮询等待生成完成，返回最终结果
  /// [onProgress] 每次轮询时的回调
  Future<Map<String, dynamic>?> pollUntilDone(
    String userName, {
    void Function(CalendarGenProgress)? onProgress,
    Duration interval = const Duration(seconds: 2),
  }) async {
    while (true) {
      final progress = await checkStatus(userName);
      onProgress?.call(progress);

      if (progress.isDone) {
        return progress.result;
      }
      if (progress.isError) {
        return null;
      }
      await Future.delayed(interval);
    }
  }
}
