import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/models/agent.dart';
import 'package:aipmb_app/services/api_client.dart';
import 'package:aipmb_app/config/api_config.dart';

final agentsProvider = FutureProvider<List<AgentInfo>>((ref) async {
  final api = ApiClient();
  final list = await api.getList(ApiConfig.agents);
  return list.map((e) => AgentInfo.fromJson(e as Map<String, dynamic>)).toList();
});

/// 调用智能体深度分析 API
final agentAnalyzeProvider = FutureProvider.family<AgentResult, String>((ref, agentId) async {
  final api = ApiClient();
  final result = await api.post('/api/v1/agents/$agentId/analyze');
  final data = result['data'];
  if (data is Map<String, dynamic>) {
    return AgentResult.fromJson(data);
  }
  return AgentResult(agentId: agentId, content: '分析结果解析失败');
});
