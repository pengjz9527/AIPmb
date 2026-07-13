# 用户登录功能

## Context

当前 App 启动直接进入 `/moment` 页面，无登录机制。用户信息（"彭楫洲"）硬编码在 `ChatMessagesNotifier._userName`。需要增加登录功能、支持多用户、在"此刻"页面展示当前用户信息。

## 设计概要

- 后端新增 `POST /api/v1/auth/login` 接口，用户数据存 `pmb/output/users.json`
- Flutter 用 Riverpod `AuthNotifier` + `SharedPreferences` 管理登录状态
- GoRouter 路由守卫：未登录 → `/login`，已登录 → `/moment`
- `ChatMessagesNotifier._userName` 改为动态从 `authProvider` 读取

---

## Task 1: 新建 `pmb/api/routers/auth_router.py` — 后端登录接口

- `POST /api/v1/auth/login`：接收 `{"phone": "..."}` → 查 users.json → 返回用户信息 或 404
- `GET /api/v1/auth/users`：列出所有用户（调试用）
- `users.json` 首次不存在时自动创建，默认用户：`{"phone":"18600035919","name":"彭楫洲","created_at":"2026-06-07T00:00:00"}`

## Task 2: 修改 `pmb/api/app.py` — 注册 auth_router

```python
from pmb.api.routers import auth_router
app.include_router(auth_router.router, prefix="/api/v1", tags=["认证"])
```

## Task 3: 新建 `aipmb_app/lib/models/app_user.dart`

```dart
class AppUser {
  final String phone;
  final String name;
  final String createdAt;
  bool get isLoggedIn => phone.isNotEmpty;
  factory AppUser.fromJson(Map<String, dynamic> json);
}
```

## Task 4: 新建 `aipmb_app/lib/providers/auth_provider.dart` — AuthNotifier

- `AuthNotifier` 继承 `StateNotifier<AsyncValue<AppUser?>>`
- `login(phone)` → 调后端 → 成功则存 `SharedPreferences` + 更新 state
- `logout()` → 清除 SharedPreferences + state 置 null
- 构造函数中 `_restoreFromStorage()` 恢复登录态
- `currentUserName` getter 供 `ChatMessagesNotifier` 使用

## Task 5: 新建 `aipmb_app/lib/pages/login/login_page.dart` — 登录页

- 手机号输入框 + 登录按钮
- 成功 → `context.go('/moment')`，失败 → SnackBar 提示

## Task 6: 新建 `aipmb_app/lib/pages/splash/splash_page.dart` — 启动过渡页

纯展示：银行图标 + `CircularProgressIndicator`

## Task 7: 改造 `aipmb_app/lib/config/routes.dart` — 动态路由 + 守卫

- `router` 改为 `routerProvider = Provider<GoRouter>(...)`，从 `ref` 读取 `authProvider` 判断登录态
- 新增 `/splash`、`/login` 路由
- `redirect` 逻辑：加载中 → splash；未登录 → login；已登录且在 splash/login → moment

## Task 8: 修改 `aipmb_app/lib/main.dart` — ConsumerWidget

```dart
class AipmbApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(routerConfig: router, ...);
  }
}
```

## Task 9: 修改 `aipmb_app/lib/config/api_config.dart` — 增加 authLogin 常量

```dart
static const String authLogin = '/api/v1/auth/login';
```

## Task 10: 修改 `aipmb_app/lib/pages/moment/moment_page.dart` — 用户信息展示

在 `ListView` children 最前面增加 `_buildUserGreeting()`：
- 圆形头像（取用户名首字）+ "Hi, {姓名}" + 手机号

## Task 11: 修改 `aipmb_app/lib/pages/mine/mine_page.dart` — 用户卡片 + 退出

在页面顶部增加用户信息 Card，含"退出登录"按钮

## Task 12: 修改 `aipmb_app/lib/providers/chat_provider.dart` — _userName 动态化

- `ChatMessagesNotifier` 增加 `Ref _ref` 字段
- `_userName` 从 `final String` 改为 `String get` → `_ref.read(authProvider).asData?.value?.name ?? ''`
- `ensureConnected()` 中传入动态 userName
- `chatMessagesProvider` 改为 `(ref) => ChatMessagesNotifier(ref.read(webSocketProvider), ref)`

## Task 13: 修改 `aipmb_app/pubspec.yaml` — 增加 shared_preferences 依赖

```yaml
shared_preferences: ^2.2.2
```

---

## 变更文件汇总

| 操作 | 文件 | 说明 |
|------|------|------|
| 新建 | `pmb/api/routers/auth_router.py` | 登录接口 + users.json 自动初始化 |
| 修改 | `pmb/api/app.py` | 注册 auth_router |
| 新建 | `aipmb_app/lib/models/app_user.dart` | AppUser 模型 |
| 新建 | `aipmb_app/lib/providers/auth_provider.dart` | AuthNotifier |
| 新建 | `aipmb_app/lib/pages/login/login_page.dart` | 登录页 |
| 新建 | `aipmb_app/lib/pages/splash/splash_page.dart` | 启动页 |
| 修改 | `aipmb_app/lib/config/routes.dart` | 动态路由 + 守卫 |
| 修改 | `aipmb_app/lib/config/api_config.dart` | authLogin 常量 |
| 修改 | `aipmb_app/lib/main.dart` | ConsumerWidget |
| 修改 | `aipmb_app/lib/providers/chat_provider.dart` | _userName 动态化 |
| 修改 | `aipmb_app/lib/pages/moment/moment_page.dart` | 用户问候区域 |
| 修改 | `aipmb_app/lib/pages/mine/mine_page.dart` | 用户卡片 + 退出 |
| 修改 | `aipmb_app/pubspec.yaml` | shared_preferences |

共 13 个文件（6 新建 + 7 修改）。

---

## 验证方案

1. **后端**：`POST /api/v1/auth/login` `{"phone":"18600035919"}` → 返回 `{"phone":"...","name":"彭楫洲","created_at":"..."}` → 200
2. **404**：`POST /api/v1/auth/login` `{"phone":"13800000000"}` → 404 `"用户不存在"`
3. **Flutter 登录流**：启动 App → splash → 未登录跳 login → 输入 18600035919 → 登录成功 → 跳转 /moment
4. **用户信息展示**：此刻页面顶部显示 "Hi, 彭楫洲" + 手机号
5. **退出登录**：我的页面 → 退出登录 → 跳转 login 页
6. **重启恢复**：关闭 App 重新打开 → 自动恢复登录态 → 直接进入 /moment
7. **Chat 记忆**：登录后对话 → WebSocket 连接带有 `user_name=彭楫洲` 参数 → 长期记忆正常工作
