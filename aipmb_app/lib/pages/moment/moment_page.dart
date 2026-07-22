import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/providers/recommendation_provider.dart';
import 'package:aipmb_app/providers/agent_provider.dart';
import 'package:aipmb_app/pages/moment/widgets/greeting_header.dart';
import 'package:aipmb_app/pages/moment/widgets/asset_summary_card.dart';
import 'package:aipmb_app/pages/moment/widgets/recent_bills_section.dart';
import 'package:aipmb_app/pages/moment/widgets/ai_entry_section.dart';
import 'package:aipmb_app/pages/moment/widgets/todo_section.dart';
import 'package:aipmb_app/pages/moment/widgets/promo_section.dart';
import 'package:aipmb_app/pages/moment/widgets/ai_recommend_section.dart';

class MomentPage extends ConsumerStatefulWidget {
  const MomentPage({super.key});

  @override
  ConsumerState<MomentPage> createState() => _MomentPageState();
}

class _MomentPageState extends ConsumerState<MomentPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('此刻', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todosProvider);
          ref.invalidate(promosProvider);
          ref.invalidate(productRecommendationsProvider);
          ref.invalidate(aiMatchedProductsProvider);
          ref.invalidate(agentsProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            const SizedBox(height: 4),
            const GreetingHeader(),
            const SizedBox(height: 16),
            const AssetSummaryCard(),
            const SizedBox(height: 20),
            const RecentBillsSection(),
            const SizedBox(height: 20),
            const AiEntrySection(),
            const SizedBox(height: 20),
            const TodoSection(),
            const SizedBox(height: 20),
            const PromoSection(),
            const SizedBox(height: 20),
            const AiRecommendSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chat'),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('问小易'),
      ),
    );
  }
}
