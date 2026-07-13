import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/models/manage_user.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';

final usersProvider = FutureProvider.family<List<ManageUser>, String>((ref, keyword) async {
  final res = await ApiClient().get(ApiConfig.users, params: {'keyword': keyword});
  final data = res.data['data'] as List<dynamic>;
  return data.map((e) => ManageUser.fromJson(e)).toList();
});

final userDetailProvider = FutureProvider.family<UserDetail, String>((ref, name) async {
  final res = await ApiClient().get(ApiConfig.userDetail(name));
  return UserDetail.fromJson(res.data['data']);
});