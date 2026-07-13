import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aipmb_app/models/app_user.dart';
import 'package:aipmb_app/services/api_client.dart';
import 'package:aipmb_app/config/api_config.dart';
import 'package:aipmb_app/providers/account_provider.dart';
import 'package:aipmb_app/providers/recommendation_provider.dart';
import 'package:aipmb_app/providers/chat_provider.dart';
import 'package:aipmb_app/providers/held_product_provider.dart';
import 'package:aipmb_app/providers/risk_assessment_provider.dart';

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AppUser?>>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AsyncValue.loading()) {
    _restoreFromStorage();
  }

  static const _keyPhone = 'login_phone';
  static const _keyName = 'login_name';

  /// App 启动时从 SharedPreferences 恢复登录态
  Future<void> _restoreFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString(_keyPhone) ?? '';
      final name = prefs.getString(_keyName) ?? '';
      if (phone.isNotEmpty && name.isNotEmpty) {
        state = AsyncValue.data(
            AppUser(phone: phone, name: name, createdAt: ''));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      state = const AsyncValue.data(null);
    }
  }

  /// 登录：调用后端 API 验证手机号
  Future<void> login(String phone) async {
    state = const AsyncValue.loading();
    try {
      final api = ApiClient();
      final resp = await api.post(ApiConfig.authLogin, data: {'phone': phone});
      final data = resp['data'] as Map<String, dynamic>?;
      if (data == null) {
        state = AsyncValue.error('登录失败：用户不存在', StackTrace.current);
        return;
      }
      final user = AppUser.fromJson(data);
      // 持久化
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPhone, user.phone);
      await prefs.setString(_keyName, user.name);
      state = AsyncValue.data(user);
      // 登录成功后清除旧数据缓存，确保新用户数据重新加载
      refreshDataAfterLogin();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 退出登录
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyName);
    state = const AsyncValue.data(null);
    _invalidateAllDataProviders();
  }

  /// 清除所有数据相关的 Provider 缓存
  void _invalidateAllDataProviders() {
    // 账户与财富数据
    _ref.invalidate(accountsProvider);
    _ref.invalidate(wealthOverviewProvider);
    _ref.invalidate(accountSummaryProvider);
    // 推荐与画像数据
    _ref.invalidate(todosProvider);
    _ref.invalidate(promosProvider);
    _ref.invalidate(productRecommendationsProvider);
    _ref.invalidate(profileTagsProvider);
    _ref.invalidate(domainSkillsProvider);
    // 持有产品数据
    _ref.invalidate(heldProductsSummaryProvider);
    _ref.invalidate(heldWealthProductsProvider);
    _ref.invalidate(heldLoansProvider);
    _ref.invalidate(heldPensionsProvider);
    // 聊天数据
    _ref.invalidate(chatMessagesProvider);
    _ref.invalidate(chatSessionsProvider);
    _ref.invalidate(historyTodayProvider);
    _ref.invalidate(riskAssessmentProvider);
  }

  /// 登录成功后刷新数据
  void refreshDataAfterLogin() {
    _invalidateAllDataProviders();
  }

  /// 当前登录用户名
  String get currentUserName {
    return state.asData?.value?.name ?? '';
  }
}
