import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/models/model_config.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';

final modelConfigsProvider = FutureProvider<List<ModelConfig>>((ref) async {
  final res = await ApiClient().get(ApiConfig.modelConfigs);
  final data = res.data['data'] as List<dynamic>;
  return data.map((e) => ModelConfig.fromJson(e)).toList();
});

final activeModelConfigProvider = FutureProvider<ModelConfig?>((ref) async {
  try {
    final res = await ApiClient().get(ApiConfig.activeModelConfig);
    return ModelConfig.fromJson(res.data['data']);
  } catch (_) {
    return null;
  }
});