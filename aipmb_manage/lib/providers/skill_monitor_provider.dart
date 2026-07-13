import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';

/// 日志查询参数
class SkillLogQuery {
  final String skillName; // 逗号分隔多个
  final String status; // success/failure/""
  final String userName;
  final String startTime;
  final String endTime;
  final int limit;
  final int offset;

  const SkillLogQuery({
    this.skillName = '',
    this.status = '',
    this.userName = '',
    this.startTime = '',
    this.endTime = '',
    this.limit = 50,
    this.offset = 0,
  });

  SkillLogQuery copyWith({
    String? skillName,
    String? status,
    String? userName,
    String? startTime,
    String? endTime,
    int? limit,
    int? offset,
  }) {
    return SkillLogQuery(
      skillName: skillName ?? this.skillName,
      status: status ?? this.status,
      userName: userName ?? this.userName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}

/// 日志查询参数 Provider
final skillLogQueryProvider = StateProvider<SkillLogQuery>(
  (ref) => const SkillLogQuery(),
);

/// 日志列表 Provider — 依赖 queryProvider 自动刷新
final skillLogsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final query = ref.watch(skillLogQueryProvider);
  final params = <String, dynamic>{
    'limit': query.limit,
    'offset': query.offset,
  };
  if (query.skillName.isNotEmpty) params['skill_name'] = query.skillName;
  if (query.status.isNotEmpty) params['status'] = query.status;
  if (query.userName.isNotEmpty) params['user_name'] = query.userName;
  if (query.startTime.isNotEmpty) params['start_time'] = query.startTime;
  if (query.endTime.isNotEmpty) params['end_time'] = query.endTime;

  final res = await ApiClient().get(ApiConfig.skillLogs, params: params);
  return {
    'items': res.data['data'] as List<dynamic>,
    'total': res.data['total'] as int? ?? 0,
  };
});

/// 单条日志详情 Provider
final skillLogDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, logId) async {
  final res = await ApiClient().get(ApiConfig.skillLogDetail(logId));
  return res.data['data'] as Map<String, dynamic>;
});

/// 周报 Provider
final skillWeeklyReportProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ApiClient().get(ApiConfig.skillWeeklyReport);
  return res.data['data'] as Map<String, dynamic>;
});

/// Skill 名称+标签列表 Provider — 返回 [{name, label}]
final skillNamesProvider = FutureProvider<List<Map<String, String>>>((ref) async {
  final res = await ApiClient().get(ApiConfig.skillNames);
  return (res.data['data'] as List<dynamic>)
      .map((e) => Map<String, String>.from(e as Map))
      .toList();
});
