import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/providers/ai_service_provider.dart';
import 'package:aipmb_app/providers/account_provider.dart';
import 'package:aipmb_app/pages/ai_service/widgets/asset_overview_section.dart';
import 'package:aipmb_app/pages/ai_service/widgets/ai_insight_card.dart';
import 'package:aipmb_app/pages/ai_service/widgets/quick_data_cards.dart';
import 'package:aipmb_app/pages/ai_service/widgets/recent_bills_section.dart';
import 'package:aipmb_app/pages/ai_service/widgets/ai_service_input_bar.dart';

class AiServicePage extends ConsumerStatefulWidget {
  const AiServicePage({super.key});

  @override
  ConsumerState<AiServicePage> createState() => _AiServicePageState();
}

class _AiServicePageState extends ConsumerState<AiServicePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 服务', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // 可滚动内容区
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(wealthOverviewProvider);
                ref.invalidate(aiInsightProvider);
                ref.invalidate(lastMonthSummaryProvider);
                ref.invalidate(recentTransactionsProvider);
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: const [
                  // 模块2: 资产总览
                  AssetOverviewSection(),
                  SizedBox(height: 8),

                  // 模块3: 小易说洞察卡片
                  AiInsightCard(),
                  SizedBox(height: 12),

                  // 模块4: 快捷数据卡片
                  QuickDataCards(),
                  SizedBox(height: 20),

                  // 模块5: 最近账单
                  RecentBillsSection(),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // 模块6: 底部输入栏（固定底部）
          const AiServiceInputBar(),
        ],
      ),
    );
  }
}
