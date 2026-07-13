import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_manage/providers/conversation_provider.dart';
import 'package:aipmb_manage/models/conversation.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';

class ConversationListPage extends ConsumerStatefulWidget {
  final String userName;
  const ConversationListPage({super.key, required this.userName});

  @override
  ConsumerState<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends ConsumerState<ConversationListPage> {
  String _keyword = '';
  String _businessType = '';
  String _timeRange = '';
  int _offset = 0;
  static const int _limit = 20;
  bool _isAnalyzingLeads = false;

  final List<Map<String, String>> _businessFilters = const [
    {'value': '', 'label': '全部业务'},
    {'value': '理财', 'label': '理财'},
    {'value': '贷款', 'label': '贷款'},
    {'value': '保险', 'label': '保险'},
    {'value': '基金', 'label': '基金'},
    {'value': '外汇', 'label': '外汇'},
    {'value': '存款', 'label': '存款'},
    {'value': '黄金', 'label': '黄金'},
    {'value': '信用卡', 'label': '信用卡'},
  ];

  final List<Map<String, String>> _timeFilters = const [
    {'value': '', 'label': '全部时间'},
    {'value': 'today', 'label': '今天'},
    {'value': 'week', 'label': '本周'},
    {'value': 'month', 'label': '本月'},
    {'value': 'older', 'label': '更早'},
  ];

  late ConversationQuery _query;

  @override
  void initState() {
    super.initState();
    _query = ConversationQuery(
      userName: widget.userName,
      keyword: _keyword,
      businessType: _businessType,
      timeRange: _timeRange,
      limit: _limit,
      offset: _offset,
    );
  }

  void _updateQuery() {
    _query = ConversationQuery(
      userName: widget.userName,
      keyword: _keyword,
      businessType: _businessType,
      timeRange: _timeRange,
      limit: _limit,
      offset: _offset,
    );
  }

  Future<void> _analyzeLeads() async {
    setState(() => _isAnalyzingLeads = true);
    try {
      final res = await ApiClient().post(
        ApiConfig.marketingLeads(widget.userName),
      );
      final data = res.data['data'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() => _isAnalyzingLeads = false);
      if (data != null) {
        _showLeadsDialog(data);
      } else {
        _showErrorDialog(res.data['message'] ?? '分析失败');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzingLeads = false);
      _showErrorDialog('请求失败: $e');
    }
  }

  void _showLeadsDialog(Map<String, dynamic> data) {
    final leads = (data['leads'] as List<dynamic>?) ?? [];
    final insight = data['user_insight'] as String? ?? '';
    final count = data['conversation_count'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            const Text('营销线索分析', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 用户洞察
                if (insight.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('用户洞察',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700)),
                        const SizedBox(height: 4),
                        Text(insight,
                            style: const TextStyle(fontSize: 14, height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('基于近 $count 次对话分析',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 12),
                ],
                // 线索列表
                if (leads.isNotEmpty) ...[
                  Text('营销线索 (${leads.length}条)',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...leads.asMap().entries.map((entry) {
                    final i = entry.key;
                    final lead = entry.value as Map<String, dynamic>;
                    return _buildLeadCard(lead, i);
                  }),
                ] else
                  const Text('暂无营销线索',
                      style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> lead, int index) {
    final type = lead['lead_type'] as String? ?? '';
    final name = lead['lead_name'] as String? ?? '';
    final category = lead['category'] as String? ?? '';
    final reason = lead['reason'] as String? ?? '';
    final priority = lead['priority'] as String? ?? '中';
    final action = lead['suggested_action'] as String? ?? '';

    final priorityColor = priority == '高'
        ? Colors.red
        : priority == '中'
            ? Colors.orange
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _leadTypeColor(type).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(type,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _leadTypeColor(type))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(priority,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: priorityColor)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 类别标签
            if (category.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(category,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ),
            const SizedBox(height: 6),
            // 推荐理由
            Text(reason,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3)),
            if (action.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.campaign_outlined,
                      size: 14, color: Colors.teal.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(action,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.teal.shade700,
                            fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _leadTypeColor(String type) {
    switch (type) {
      case '产品推荐':
        return Colors.blue;
      case '权益推荐':
        return Colors.purple;
      case '服务建议':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('分析失败'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.watch(conversationsProvider(_query));
    final summaryAsync = ref.watch(conversationSummaryProvider(widget.userName));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName} 的对话记录'),
        actions: [
          _isAnalyzingLeads
              ? const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: _analyzeLeads,
                  icon: const Icon(Icons.lightbulb_outline,
                      color: Color(0xFF0D47A1), size: 18),
                  label: const Text('线索分析',
                      style: TextStyle(
                          color: Color(0xFF0D47A1),
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D47A1),
                    side: const BorderSide(
                        color: Color(0xFF0D47A1), width: 1.5),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: summaryAsync.when(
            data: (summary) {
              final total = summary['total_sessions'] ?? 0;
              final history = summary['history_sessions'] ?? 0;
              final realtime = summary['realtime_sessions'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '共 $total 次对话 · 历史 $history · 实时 $realtime',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: asyncValue.when(
              data: (result) => _buildList(result),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        decoration: const InputDecoration(
          hintText: '搜索对话内容...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (v) => setState(() {
          _keyword = v;
          _offset = 0;
          _updateQuery();
        }),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: _businessFilters.map((f) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f['label']!),
                  selected: _businessType == f['value'],
                  onSelected: (_) => setState(() {
                    _businessType = f['value']!;
                    _offset = 0;
                    _updateQuery();
                  }),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: _timeFilters.map((f) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f['label']!),
                  selected: _timeRange == f['value'],
                  onSelected: (_) => setState(() {
                    _timeRange = f['value']!;
                    _offset = 0;
                    _updateQuery();
                  }),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildList(ConversationListResult result) {
    if (result.items.isEmpty) {
      return const Center(child: Text('暂无对话记录'));
    }

    // 按 timeRange 分组
    final groups = <String, List<ConversationItem>>{};
    for (var item in result.items) {
      groups.putIfAbsent(item.timeRange, () => []).add(item);
    }

    const groupOrder = ['today', 'week', 'month', 'older'];
    final orderedGroups = groupOrder.where((g) => groups.containsKey(g)).toList();

    final List<Widget> listItems = [];
    for (var group in orderedGroups) {
      listItems.add(_GroupHeader(label: _groupLabel(group)));
      for (var item in groups[group]!) {
        listItems.add(_ConversationCard(
          item: item,
          onTap: () => context.push(
            '/users/${widget.userName}/conversations/${item.sessionId}',
          ),
        ));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: listItems.length,
      itemBuilder: (_, index) => listItems[index],
    );
  }

  String _groupLabel(String timeRange) {
    switch (timeRange) {
      case 'today':
        return '今天';
      case 'week':
        return '本周';
      case 'month':
        return '本月';
      default:
        return '更早';
    }
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final ConversationItem item;
  final VoidCallback onTap;

  const _ConversationCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: item.businessTypes.map((bt) {
                        return Chip(
                          label: Text(bt, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: _businessColor(bt).withOpacity(0.12),
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ),
                  if (item.source == 'realtime')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        '实时',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.preview.isNotEmpty ? item.preview : '（无预览内容）',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.messageCount} 条消息',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    _formatTime(item.startedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _businessColor(String bt) {
    final map = {
      '理财': Colors.orange,
      '贷款': Colors.blue,
      '保险': Colors.purple,
      '基金': Colors.indigo,
      '外汇': Colors.teal,
      '存款': Colors.green,
      '黄金': Colors.amber,
      '信用卡': Colors.red,
    };
    return map[bt] ?? Colors.grey;
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
