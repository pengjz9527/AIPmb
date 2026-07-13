import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/models/user_tag.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';

final userTagsProvider = FutureProvider.family<UserTag?, String>((ref, name) async {
  try {
    final res = await ApiClient().get(ApiConfig.userTags(name));
    return UserTag.fromJson(res.data['data']);
  } catch (_) {
    return null;
  }
});

final taggedUsersProvider = FutureProvider<List<String>>((ref) async {
  final res = await ApiClient().get(ApiConfig.tags);
  final data = res.data['data'] as List<dynamic>;
  return data.map((e) => e.toString()).toList();
});