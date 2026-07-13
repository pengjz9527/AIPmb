import 'package:go_router/go_router.dart';
import 'package:aipmb_manage/pages/dashboard/dashboard_page.dart';
import 'package:aipmb_manage/pages/model_config/model_config_list_page.dart';
import 'package:aipmb_manage/pages/model_config/model_config_form_page.dart';
import 'package:aipmb_manage/pages/users/user_list_page.dart';
import 'package:aipmb_manage/pages/users/user_detail_page.dart';
import 'package:aipmb_manage/pages/tagging/tagging_page.dart';
import 'package:aipmb_manage/pages/matching/matching_page.dart';
import 'package:aipmb_manage/pages/calendar/calendar_page.dart';
import 'package:aipmb_manage/pages/conversations/conversation_list_page.dart';
import 'package:aipmb_manage/pages/conversations/conversation_detail_page.dart';
import 'package:aipmb_manage/pages/skill_monitor/skill_monitor_page.dart';

final router = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    GoRoute(
      path: '/dashboard',
      builder: (_, __) => const DashboardPage(),
    ),
    GoRoute(
      path: '/model-configs',
      builder: (_, __) => const ModelConfigListPage(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (_, __) => const ModelConfigFormPage(),
        ),
        GoRoute(
          path: ':id/edit',
          builder: (_, state) => ModelConfigFormPage(
            configId: state.pathParameters['id'],
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/users',
      builder: (_, __) => const UserListPage(),
      routes: [
        GoRoute(
          path: ':name',
          builder: (_, state) => UserDetailPage(
            userName: state.pathParameters['name']!,
          ),
          routes: [
            GoRoute(
              path: 'tagging',
              builder: (_, state) => TaggingPage(
                userName: state.pathParameters['name']!,
              ),
            ),
            GoRoute(
              path: 'matching',
              builder: (_, state) => MatchingPage(
                userName: state.pathParameters['name']!,
              ),
            ),
            GoRoute(
              path: 'calendar',
              builder: (_, state) => CalendarPage(
                userName: state.pathParameters['name']!,
              ),
            ),
            GoRoute(
              path: 'conversations',
              builder: (_, state) => ConversationListPage(
                userName: state.pathParameters['name']!,
              ),
              routes: [
                GoRoute(
                  path: ':sessionId',
                  builder: (_, state) => ConversationDetailPage(
                    userName: state.pathParameters['name']!,
                    sessionId: state.pathParameters['sessionId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/skill-monitor',
      builder: (_, __) => const SkillMonitorPage(),
    ),
  ],
);