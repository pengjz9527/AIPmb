import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/pages/main_shell.dart';
import 'package:aipmb_app/pages/moment/moment_page.dart';
import 'package:aipmb_app/pages/mine/mine_page.dart';
import 'package:aipmb_app/pages/ai_service/ai_service_page.dart';
import 'package:aipmb_app/pages/agent/agent_chat_page.dart';
import 'package:aipmb_app/pages/agent/agent_report_page.dart';
import 'package:aipmb_app/pages/chat/full_chat_page.dart';
import 'package:aipmb_app/pages/recommendation/recommendation_page.dart';
import 'package:aipmb_app/pages/product/product_detail_page.dart';
import 'package:aipmb_app/pages/held_products/product_detail_page.dart' as held_detail;
import 'package:aipmb_app/pages/purchase/purchase_page.dart';
import 'package:aipmb_app/pages/login/login_page.dart';
import 'package:aipmb_app/pages/splash/splash_page.dart';
import 'package:aipmb_app/pages/held_products/held_products_page.dart';
import 'package:aipmb_app/pages/held_products/repayment_plan_page.dart';
import 'package:aipmb_app/pages/calendar/calendar_result_page.dart';
import 'package:aipmb_app/pages/risk_assessment/risk_assessment_page.dart';
import 'package:aipmb_app/pages/channel/payment_page.dart';
import 'package:aipmb_app/providers/auth_provider.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.watch(authProvider);
      final isLoggedIn = authState.asData?.value != null;
      final isAuthLoading = authState is AsyncLoading;
      final loc = state.uri.path;

      // 启动页：等待 authProvider 初始化完成
      if (loc == '/splash') {
        if (isAuthLoading) return null; // 继续等待
        return isLoggedIn ? '/moment' : '/login';
      }

      // 登录页：已登录则跳转到此刻频道
      if (loc == '/login') {
        return isLoggedIn ? '/moment' : null;
      }

      // 其他页面：未登录则跳转到登录页
      if (!isLoggedIn) {
        return '/login';
      }

      return null; // 允许访问
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/moment',
                builder: (context, state) => const MomentPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai-service',
                builder: (context, state) => const AiServicePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mine',
                builder: (context, state) => const MinePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/agent/:agentId',
        builder: (context, state) {
          final agentId = state.pathParameters['agentId']!;
          final agentName = state.uri.queryParameters['name'] ?? 'AI助手';
          return AgentChatPage(agentId: agentId, agentName: agentName);
        },
      ),
      GoRoute(
        path: '/agent/:agentId/report',
        builder: (context, state) {
          final agentId = state.pathParameters['agentId']!;
          final agentName = state.uri.queryParameters['name'] ?? 'AI助手';
          return AgentReportPage(agentId: agentId, agentName: agentName);
        },
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final msg = state.uri.queryParameters['msg'];
          return FullChatPage(initialMessage: msg);
        },
      ),
      GoRoute(
        path: '/recommendations',
        builder: (context, state) {
          final productName = state.uri.queryParameters['product'];
          return RecommendationPage(initialProductName: productName);
        },
      ),
      GoRoute(
        path: '/held-products',
        builder: (context, state) => const HeldProductsPage(),
      ),
      GoRoute(
        path: '/held-products/detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return held_detail.ProductDetailPage(
            type: extra['type'] as String,
            data: extra['data'],
          );
        },
      ),
      GoRoute(
        path: '/held-products/repayment-plan',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return RepaymentPlanPage(loanId: extra['loanId'] as String);
        },
      ),
      GoRoute(
        path: '/risk-assessment',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final userName = extra?['user'] as String? ?? '';
          return RiskAssessmentPage(userName: userName);
        },
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) {
          final userName = state.uri.queryParameters['user'] ?? '';
          return CalendarResultPage(userName: userName);
        },
      ),
      GoRoute(
        path: '/channel/payment',
        builder: (context, state) {
          final paymentNo = state.uri.queryParameters['payment_no'] ?? '';
          final paymentType = state.uri.queryParameters['payment_type'] ?? '';
          return PaymentPage(
            paymentNo: paymentNo,
            paymentType: paymentType,
          );
        },
      ),
      GoRoute(
        path: '/product/detail',
        builder: (context, state) {
          final productName = state.uri.queryParameters['product_name'] ?? '';
          return ProductInfoPage(productName: productName);
        },
      ),
      GoRoute(
        path: '/purchase',
        builder: (context, state) {
          final productName = state.uri.queryParameters['product_name'] ?? '';
          return PurchasePage(productName: productName);
        },
      ),
    ],
  );
}
