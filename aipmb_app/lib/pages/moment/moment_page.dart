import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/providers/recommendation_provider.dart';
import 'package:aipmb_app/providers/auth_provider.dart';

import 'package:aipmb_app/widgets/cards/todo_card.dart';
import 'package:aipmb_app/widgets/cards/promo_card.dart';
import 'package:aipmb_app/widgets/cards/product_card.dart';

import 'package:aipmb_app/models/skill_card.dart';
import 'package:aipmb_app/models/user_profile.dart';
import 'package:aipmb_app/models/recommendation.dart';
import 'package:aipmb_app/models/thinking_step.dart';
import 'package:aipmb_app/widgets/chat/thinking_panel.dart';
import 'package:aipmb_app/widgets/cards/history_today_card.dart';
import 'package:aipmb_app/services/calendar_api.dart';
import 'package:aipmb_app/services/api_client.dart';

class MomentPage extends ConsumerStatefulWidget {
  const MomentPage({super.key});

  @override
  ConsumerState<MomentPage> createState() => _MomentPageState();
}

class _MomentPageState extends ConsumerState<MomentPage> {
  bool _dismissedHistoryToday = false;
  bool _isGeneratingCalendar = false;

  // AI 产品匹配（为你推荐）
  List<AiMatchedProduct> _aiProducts = [];
  bool _isRefreshingProducts = false;
  List<ThinkingStep> _matchThinkingSteps = [];
  Timer? _pollTimer;

  /// 已被 Agent 收编的 Skill，不在前端单独展示入口
  static const _agentManagedSkills = {'consumption_analysis', 'income_forecast'};

  /// 静态兜底快捷问题（当后端无法获取 Skill 列表时使用）
  static const _fallbackQuestions = [
    _QuickQ(icon: Icons.account_balance_wallet, label: '我的财务状况', msg: '帮我分析一下我的财务状况'),
    _QuickQ(icon: Icons.trending_up, label: '制定理财方案', msg: '帮我制定一份理财方案'),
    _QuickQ(icon: Icons.recommend, label: '推荐产品', msg: '根据我的情况推荐一些理财产品'),
    _QuickQ(icon: Icons.analytics_outlined, label: '收支分析', msg: '@收支分析师 帮我分析收支'),
    _QuickQ(icon: Icons.psychology_outlined, label: '我的消费画像', msg: '给我画一个消费画像'),
  ];

  /// Skill 名称到图标映射
  static IconData _iconForSkill(String skillName) {
    switch (skillName) {
      case 'financial_planning':
        return Icons.trending_up;
      case 'consumption_analysis':
        return Icons.shopping_bag_outlined;
      case 'life_recommendation':
        return Icons.recommend;
      case 'user_profiling':
        return Icons.psychology_outlined;
      case 'income_forecast':
        return Icons.savings_outlined;
      case 'neighborhood_profiler':
        return Icons.location_on_outlined;
      case 'loan_cost_optimizer':
        return Icons.calculate_outlined;
      case 'loan_product_recommendation':
        return Icons.request_quote_outlined;
      case 'history_today':
        return Icons.history;
      default:
        return Icons.auto_awesome_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(profileTagsProvider);
    final todosAsync = ref.watch(todosProvider);
    final promosAsync = ref.watch(promosProvider);
    final aiProductsAsync = ref.watch(aiMatchedProductsProvider);
    final skillsAsync = ref.watch(domainSkillsProvider);
    final historyTodayAsync = ref.watch(historyTodayProvider);
    final calendarCache = ref.watch(calendarCacheProvider);

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
          ref.invalidate(profileTagsProvider);
          ref.invalidate(todosProvider);
          ref.invalidate(promosProvider);
          ref.invalidate(productRecommendationsProvider);
          ref.invalidate(aiMatchedProductsProvider);
          ref.invalidate(domainSkillsProvider);
          ref.invalidate(historyTodayProvider);
          setState(() => _dismissedHistoryToday = false);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // 用户问候
            _buildGreeting(),
            const SizedBox(height: 12),
            // 用户画像标签
            tagsAsync.when(
              data: (tags) => _buildProfileTags(tags),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // 历史上的今天
            if (!_dismissedHistoryToday)
              historyTodayAsync.when(
                data: (ht) {
                  if (ht.hasMemory) {
                    return HistoryTodayCard(
                      result: ht,
                      index: 0,
                      onDismiss: () =>
                          setState(() => _dismissedHistoryToday = true),
                    );
                  }
                  // 无今日记忆：展示温馨引导 + 纪念日历入口
                  return _buildNoHistoryToday();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            // 已有缓存日历的快捷入口
            if (calendarCache != null)
              _buildCalendarQuickEntry(calendarCache!),

            // AI 助手入口 — 动态 Skill 快捷卡片
            skillsAsync.when(
              data: (skills) => _buildAiAssistantSection(skills: skills),
              loading: () => _buildAiAssistantSection(skills: const []),
              error: (_, _) => _buildAiAssistantSection(skills: const []),
            ),
            const SizedBox(height: 20),

            // 待办推荐
            _buildSectionHeader('待办提醒'),
            todosAsync.when(
              data: (todos) => todos.isEmpty
                  ? const Padding(padding: EdgeInsets.all(16), child: Text('暂无待办'))
                  : Column(children: todos.asMap().entries.map((e) {
                    final t = e.value;
                    return TodoCard(
                      item: t,
                      index: e.key,
                      onTap: () {
                        if (t.type == 'payment_due') {
                          context.push(
                            '/channel/payment'
                            '?payment_no=${Uri.encodeComponent(t.paymentNo ?? '')}'
                            '&payment_type=${Uri.encodeComponent(t.paymentTypeLabel ?? '')}',
                          );
                        } else if (t.type == 'credit_repayment') {
                          context.push('/held-products');
                        } else if (t.type == 'spending_alert') {
                          context.push('/chat?msg=${Uri.encodeComponent('帮我分析最近的消费明细')}');
                        }
                      },
                    );
                  }).toList()),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('加载失败: $e')),
            ),
            const SizedBox(height: 16),

            // 优惠推荐
            _buildSectionHeader('专属优惠'),
            promosAsync.when(
              data: (promos) => promos.isEmpty
                  ? const Padding(padding: EdgeInsets.all(16), child: Text('暂无优惠'))
                  : GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.8,
                      children: promos.map((p) => PromoCard(item: p)).toList(),
                    ),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // AI产品推荐（为你推荐）
            _buildAiRecommendSection(aiProductsAsync),
            const SizedBox(height: 16),

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

  Widget _buildProfileTags(UserProfileTags tags) {
    final labels = tags.displayLabels;
    if (labels.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // 计算两行能容纳的标签数
        int visibleCount = labels.length;
        double rowWidth = 0;
        int rowCount = 1;
        for (int i = 0; i < labels.length; i++) {
          final chipWidth = _estimateChipWidth(labels[i]);
          if (rowWidth + chipWidth > availableWidth && rowWidth > 0) {
            rowCount++;
            rowWidth = chipWidth;
          } else {
            rowWidth += chipWidth;
          }
          if (rowCount > 2) {
            visibleCount = i;
            break;
          }
        }
        // "更多>>" 宽度约 60px，如果第二行放不下就回退一个标签
        const moreWidth = 60.0;
        if (visibleCount < labels.length && rowCount == 2) {
          if (rowWidth + moreWidth > availableWidth && visibleCount > 0) {
            visibleCount--;
          }
        }

        final showMore = visibleCount < labels.length;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < (showMore ? visibleCount : labels.length); i++)
              _buildTagChip(labels[i], tags, i),
            if (showMore)
              ActionChip(
                label: Text('更多>>',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onPressed: () => _showAllTags(tags),
              ),
          ],
        );
      },
    );
  }

  /// 估算单个标签 Chip 的渲染宽度（含间距）
  double _estimateChipWidth(String label) {
    final textPainter = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    // ActionChip: 左右内边距各~12, 间距8, 加6px安全边距
    return textPainter.width + 12 + 12 + 8 + 6;
  }

  Widget _buildTagChip(String label, UserProfileTags tags, int index) {
    final hasDetail = tags.hasAiTags && index < tags.aiTags.length;
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onPressed: hasDetail
          ? () => _showTagDetail(context, tags.aiTags[index])
          : null,
    );
  }

  void _showAllTags(UserProfileTags tags) {
    final labels = tags.displayLabels;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('全部标签',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(labels.length,
                  (i) => _buildTagChip(labels[i], tags, i)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showTagDetail(BuildContext context, AITagItem tag) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(tag.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(tag.description,
                style: TextStyle(
                    fontSize: 15, color: Colors.grey[700], height: 1.5)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final auth = ref.watch(authProvider);
    final userName = auth.asData?.value?.name ?? '';
    // 根据时段生成问候语
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? '早上好' : hour < 18 ? '下午好' : '晚上好';
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            userName.isNotEmpty ? userName[0] : '?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting，${userName.isNotEmpty ? userName : '用户'}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              'AI 手机银行，懂你所需',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiAssistantSection({required List<SkillCard> skills}) {
    // 过滤：排除已由 Agent 管理的 Skill
    final filteredSkills = skills
        .where((s) => !_agentManagedSkills.contains(s.name))
        .toList();
    // 有动态 Skill 数据时使用，否则使用兜底数据
    final displayItems = filteredSkills.isNotEmpty
        ? filteredSkills.map((s) => _QuickQ(
            icon: _iconForSkill(s.name),
            label: s.label,
            msg: s.description,
          )).toList()
        : _fallbackQuestions;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
            Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI 助手小易', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('随时为你服务', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.push('/chat'),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('对话'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 动态 Skill 快捷卡片 — 2列等大矩形网格
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: displayItems.map((q) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)),
                ),
                color: Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/chat?msg=${Uri.encodeComponent(q.msg)}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(q.icon, size: 18, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            q.label,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (onTap != null)
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('查看更多', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
            )
          else
            Text('查看更多', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }

  /// 今日无历史上的今天记忆时，温馨引导用户查看纪念日历
  Widget _buildNoHistoryToday() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.shade50,
                const Color(0xFFEDE7FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.calendar_month,
                          size: 18, color: const Color(0xFF6C4DFF)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('历史上的今天',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18,
                          color: Colors.grey.shade400),
                      onPressed: () =>
                          setState(() => _dismissedHistoryToday = true),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '今天还没有特别的记忆，但每一天都值得被珍藏 ✨',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700, height: 1.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI 已经为你梳理好了一份纪念日历，看看那些与银行相伴的珍贵时刻吧~',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500, height: 1.4),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: _isGeneratingCalendar ? null : _startCalendarGenerate,
                    icon: _isGeneratingCalendar
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome, size: 16),
                    label: Text(
                        _isGeneratingCalendar ? '正在生成...' : '看看我的纪念日历'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C4DFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 已有缓存日历时的快捷查看入口
  Widget _buildCalendarQuickEntry(Map<String, dynamic> calendarData) {
    final events =
        (calendarData['events'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFEDE7FF), Colors.purple.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: () => _showCalendarBottomSheet(calendarData),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.auto_awesome,
                        size: 20, color: const Color(0xFF6C4DFF)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('我的纪念日历',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('已发现 ${events.length} 个珍贵时刻，点击查看 →',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 启动纪念日历生成 + 弹出展示
  Future<void> _startCalendarGenerate() async {
    final auth = ref.read(authProvider);
    final userName = auth.asData?.value?.name ?? '';
    if (userName.isEmpty) return;

    setState(() => _isGeneratingCalendar = true);

    try {
      final calendarApi = CalendarApi(ApiClient());

      // 尝试先获取已有日历
      Map<String, dynamic>? calendarData;
      try {
        calendarData = await calendarApi.getCalendar(userName);
      } catch (_) {
        // 无已生成日历，启动异步生成
      }

      if (calendarData == null ||
          (calendarData['events'] as List?)?.isEmpty == true) {
        // 启动生成
        await calendarApi.startGeneration(userName);
        // 轮询等待完成
        final result = await calendarApi.pollUntilDone(
          userName,
          interval: const Duration(seconds: 2),
        );
        if (result != null && result['calendar'] != null) {
          calendarData = result['calendar'] as Map<String, dynamic>;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('日历生成失败，请稍后重试')),
            );
          }
          return;
        }
      }

      if (calendarData != null) {
        // 存入会话缓存
        ref.read(calendarCacheProvider.notifier).state = calendarData;
        // 弹出日历详情
        _showCalendarBottomSheet(calendarData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingCalendar = false);
    }
  }

  // ========== AI 产品推荐（为你推荐）==========

  Widget _buildAiRecommendSection(AsyncValue<List<AiMatchedProduct>> async) {
    // 首次加载时同步本地状态
    async.whenData((products) {
      if (!_isRefreshingProducts) {
        _aiProducts = products;
      }
    });

    final displayProducts = _aiProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header + 换一批按钮
        Row(
          children: [
            const Text('为你推荐',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (displayProducts.isNotEmpty)
              TextButton.icon(
                onPressed: _isRefreshingProducts ? null : _onRefreshProducts,
                icon: _isRefreshingProducts
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.autorenew, size: 16),
                label: Text(_isRefreshingProducts ? '匹配中...' : '换一批',
                    style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // 思考过程面板（换一批匹配中时展示）
        if (_isRefreshingProducts && _matchThinkingSteps.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ThinkingPanel(
              steps: _matchThinkingSteps,
              reasoningContent: 'AI 正在分析你的消费画像和风险偏好，从银行产品库中智能匹配最适合你的产品...',
            ),
          ),

        // 匹配中但尚未有步骤时的 loading
        if (_isRefreshingProducts && _matchThinkingSteps.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('正在启动 AI 智能匹配...',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),

        // 产品卡片
        if (displayProducts.isEmpty && !_isRefreshingProducts)
          async.when(
            data: (_) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text('暂无推荐', style: TextStyle(color: Colors.grey)),
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('加载失败: $e', style: const TextStyle(color: Colors.red)),
            ),
          )
        else if (displayProducts.isNotEmpty)
          Column(
            children: displayProducts.asMap().entries.map((e) {
              final p = e.value;
              final pr = p.toProductRecommendation();
              return ProductRecommendationCard(
                item: pr,
                index: e.key,
                onTap: () => context.push(
                  '/product/detail?product_name=${Uri.encodeComponent(p.productName)}',
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _onRefreshProducts() async {
    if (_isRefreshingProducts) return;

    setState(() {
      _isRefreshingProducts = true;
      _matchThinkingSteps = [];
    });

    try {
      final api = ref.read(apiProvider);

      // 1. 触发刷新
      final refreshResp = await refreshAiProducts(api);
      final data = refreshResp['data'];
      final status = data is Map ? data['status'] as String? : null;

      if (status == 'ok') {
        final products = (data?['products'] as List?) ?? [];
        if (mounted) {
          setState(() {
            _aiProducts = products
                .map((e) => AiMatchedProduct.fromJson(e as Map<String, dynamic>))
                .toList();
            _isRefreshingProducts = false;
          });
        }
        return;
      }

      // 2. 开始轮询进度
      _startPolling(api);
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshingProducts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刷新失败: $e')),
        );
      }
    }
  }

  void _startPolling(ApiClient api) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final progress = await fetchMatchProgress(api);
        if (!mounted) {
          timer.cancel();
          return;
        }

        final thinkingSteps = progress.toThinkingSteps();
        setState(() => _matchThinkingSteps = thinkingSteps);

        if (progress.isDone) {
          timer.cancel();
          final resultProducts = progress.result ?? [];
          setState(() {
            _aiProducts = resultProducts
                .map((e) => AiMatchedProduct.fromJson(e))
                .toList();
            _isRefreshingProducts = false;
          });
          ref.invalidate(aiMatchedProductsProvider);
        }
      } catch (_) {
        // 轮询失败忽略
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// 弹窗展示纪念日历事件列表
  void _showCalendarBottomSheet(Map<String, dynamic> calendarData) {
    final events =
        (calendarData['events'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.auto_awesome,
                      size: 22, color: const Color(0xFF6C4DFF)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('我的纪念日历',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE7FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${events.length} 个时刻',
                        style: TextStyle(
                            fontSize: 12, color: const Color(0xFF6C4DFF))),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('AI 从你的交易记录中识别出的珍贵人生片段',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 12),
              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: Text('暂无纪念事件',
                          style: TextStyle(color: Colors.grey))),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: events.length,
                    itemBuilder: (_, i) {
                      final ev = events[i];
                      final eventType = ev['event_type'] as String? ?? '';
                      final title = ev['title'] as String? ?? '';
                      final desc = ev['description'] as String? ?? '';
                      final date = ev['date'] as String? ?? '';
                      final importance = ev['importance'] as int? ?? 5;

                      IconData eventIcon;
                      Color eventColor;
                      switch (eventType) {
                        case 'first_income':
                          eventIcon = Icons.trending_up;
                          eventColor = Colors.green;
                          break;
                        case 'major_purchase':
                          eventIcon = Icons.shopping_cart;
                          eventColor = Colors.orange;
                          break;
                        case 'travel_memory':
                          eventIcon = Icons.flight;
                          eventColor = const Color(0xFF3B82F6);
                          break;
                        case 'family_care':
                          eventIcon = Icons.favorite;
                          eventColor = Colors.pink;
                          break;
                        case 'growth_milestone':
                          eventIcon = Icons.emoji_events;
                          eventColor = Colors.amber;
                          break;
                        default:
                          eventIcon = Icons.star;
                          eventColor = Colors.purple;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: eventColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(eventIcon,
                                    size: 22, color: eventColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    if (desc.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(desc,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              height: 1.4),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                children: [
                                  Text(date,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500)),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: List.generate(importance, (_) =>
                                        Icon(Icons.star,
                                            size: 8,
                                            color: Colors.amber.shade300)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickQ {
  final IconData icon;
  final String label;
  final String msg;
  const _QuickQ({required this.icon, required this.label, required this.msg});
}
