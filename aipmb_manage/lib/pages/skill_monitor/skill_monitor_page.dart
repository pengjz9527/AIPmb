import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/providers/skill_monitor_provider.dart';

class SkillMonitorPage extends ConsumerStatefulWidget {
  const SkillMonitorPage({super.key});

  @override
  ConsumerState<SkillMonitorPage> createState() => _SkillMonitorPageState();
}

class _SkillMonitorPageState extends ConsumerState<SkillMonitorPage> {
  final Set<String> _selectedSkills = {};
  String _statusFilter = '';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _initialized = false;
  List<Map<String, String>> _allSkills = [];

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(skillLogsProvider);
    final skillNamesAsync = ref.watch(skillNamesProvider);

    // 首次加载时，默认全选所有 skill
    ref.listen(skillNamesProvider, (prev, next) {
      if (!_initialized && next is AsyncData) {
        final skills = next.value;
        if (skills != null && skills.isNotEmpty) {
          _initialized = true;
          _allSkills = skills;
          _selectedSkills.addAll(skills.map((s) => s['name']!));
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('技能调用日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: '周报',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _ReportRedirect()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              ref.invalidate(skillLogsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(skillNamesAsync),
          const Divider(height: 1),
          Expanded(child: _buildLogList(logsAsync)),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AsyncValue<List<Map<String, String>>> skillNamesAsync) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 筛选条件行 — 统一高度 40
          Row(
            children: [
              // Skill 多选下拉
              Expanded(
                flex: 3,
                child: skillNamesAsync.when(
                  data: (skills) => _buildSkillMultiSelect(skills),
                  loading: () => const SizedBox(
                    height: 40,
                    child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 10),
              // 状态下拉
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 40,
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _statusFilter.isEmpty ? null : _statusFilter,
                    decoration: _filterInputDecoration('状态'),
                    isExpanded: true,
                    style: const TextStyle(fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('全部')),
                      DropdownMenuItem(value: 'success', child: Text('✅ 成功')),
                      DropdownMenuItem(value: 'failure', child: Text('❌ 失败')),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v ?? ''),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 时间范围
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 40,
                  child: InkWell(
                    onTap: () => _pickDateRange(),
                    child: InputDecorator(
                      decoration: _filterInputDecoration('时间范围'),
                      child: Text(
                        _startDate != null
                            ? '${_fmt(_startDate!)} ~ ${_fmt(_endDate!)}'
                            : '全部',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 查询按钮行
          Row(
            children: [
              SizedBox(
                height: 34,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('查询', style: TextStyle(fontSize: 13)),
                  onPressed: _applyFilter,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!_isAllSelected() || _statusFilter.isNotEmpty || _startDate != null)
                SizedBox(
                  height: 34,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('清除', style: TextStyle(fontSize: 13)),
                    onPressed: () {
                      setState(() {
                        _selectedSkills.clear();
                        _selectedSkills.addAll(_allSkills.map((s) => s['name']!));
                        _statusFilter = '';
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _filterInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
      ),
    );
  }

  bool _isAllSelected() {
    if (_allSkills.isEmpty) return true;
    return _selectedSkills.length == _allSkills.length;
  }

  Widget _buildSkillMultiSelect(List<Map<String, String>> skills) {
    final allNames = skills.map((s) => s['name']!).toSet();

    return PopupMenuButton<String>(
      tooltip: '选择 Skill',
      offset: const Offset(0, 42),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFD0D0D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_list, size: 18, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _isAllSelected()
                    ? '全部 Skill (${skills.length})'
                    : '已选 ${_selectedSkills.length}/${skills.length}',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey),
          ],
        ),
      ),
      itemBuilder: (ctx) {
        final items = <PopupMenuEntry<String>>[
          // 顶部的 全选/取消全选
          PopupMenuItem<String>(
            enabled: false,
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    Navigator.pop(ctx); // 关闭菜单
                    setState(() {
                      if (_isAllSelected()) {
                        _selectedSkills.clear();
                      } else {
                        _selectedSkills.clear();
                        _selectedSkills.addAll(allNames);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      _isAllSelected() ? '取消全选' : '全选',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ];

        // 每个 skill 选项
        for (final skill in skills) {
          final name = skill['name']!;
          final label = skill['label']!;
          final selected = _selectedSkills.contains(name);
          items.add(PopupMenuItem<String>(
            value: name,
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      children: [
                        TextSpan(text: label),
                        TextSpan(
                          text: ' ($name)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ));
        }
        return items;
      },
      onSelected: (name) {
        setState(() {
          if (_selectedSkills.contains(name)) {
            _selectedSkills.remove(name);
          } else {
            _selectedSkills.add(name);
          }
        });
      },
    );
  }

  Widget _buildLogList(AsyncValue<Map<String, dynamic>> logsAsync) {
    // 构建 skill 英文名 → 中文标签的映射
    final Map<String, String> skillLabelMap = {};
    for (final s in _allSkills) {
      skillLabelMap[s['name']!] = s['label']!;
    }

    return logsAsync.when(
      data: (data) {
        final items = data['items'] as List<dynamic>;
        if (items.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('暂无日志记录', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final log = items[i] as Map<String, dynamic>;
            return _LogCard(log: log, skillLabelMap: skillLabelMap);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text('加载失败: $e', style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final query = ref.watch(skillLogQueryProvider);
    final logsData = ref.watch(skillLogsProvider).valueOrNull;
    final total = logsData?['total'] as int? ?? 0;

    if (total <= query.limit) return const SizedBox.shrink();

    final currentEnd =
        query.offset + query.limit > total ? total : query.offset + query.limit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: query.offset > 0
                ? () {
                    ref.read(skillLogQueryProvider.notifier).state =
                        query.copyWith(offset: query.offset - query.limit);
                  }
                : null,
          ),
          Text(
            '${query.offset + 1}-$currentEnd / $total',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentEnd < total
                ? () {
                    ref.read(skillLogQueryProvider.notifier).state =
                        query.copyWith(offset: query.offset + query.limit);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  void _applyFilter() {
    final query = ref.read(skillLogQueryProvider);
    // 全选时不传 skill_name 参数，后端即不过滤
    ref.read(skillLogQueryProvider.notifier).state = query.copyWith(
      skillName: _isAllSelected() ? '' : _selectedSkills.join(','),
      status: _statusFilter,
      startTime: _startDate?.toIso8601String() ?? '',
      endTime: _endDate != null
          ? '${_endDate!.toIso8601String().split('T')[0]}T23:59:59'
          : '',
      offset: 0,
    );
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      helpText: '选择时间范围',
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  String _fmt(DateTime dt) =>
      '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

/// 单条日志卡片
class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final Map<String, String> skillLabelMap;
  const _LogCard({required this.log, required this.skillLabelMap});

  static const int _maxLabelChars = 14; // 中文名称最大展示字符数

  @override
  Widget build(BuildContext context) {
    final success = log['success'] == true;
    final duration = log['duration_ms'] ?? 0;
    final invokedAt = log['invoked_at'] ?? '';
    final skillName = log['skill_name'] ?? '';
    final userName = log['user_name'] ?? '';
    final errorMsg = log['error_message'] ?? '';
    final sessionId = log['session_id'] ?? '';
    final arguments = log['arguments'] ?? {};
    final summary = log['result_summary'] ?? '';
    final apiTraces = (log['api_traces'] as List<dynamic>?) ?? [];

    // 获取技能中文名称
    final skillLabel = skillLabelMap[skillName] ?? '';
    final displayLabel = skillLabel.isNotEmpty
        ? (skillLabel.length > _maxLabelChars
            ? '${skillLabel.substring(0, _maxLabelChars)}…'
            : skillLabel)
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          success ? Icons.check_circle : Icons.error,
          color: success ? Colors.green : Colors.red,
          size: 22,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (displayLabel.isNotEmpty)
              Text(
                displayLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              skillName,
              style: TextStyle(
                fontWeight: displayLabel.isEmpty ? FontWeight.w600 : FontWeight.w400,
                fontSize: displayLabel.isEmpty ? 14 : 11,
                color: displayLabel.isEmpty ? null : Colors.grey,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        subtitle: Text(
          '$userName  |  ${duration}ms  |  ${_formatTime(invokedAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('会话 ID', sessionId),
                _detailRow('参数', _fmtArgs(arguments)),
                if (summary.isNotEmpty) _detailRow('返回摘要', summary),
                if (!success) _detailRow('错误信息', errorMsg, isError: true),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 4),
                Text('API 调用链路',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                if (apiTraces.isNotEmpty)
                  ...apiTraces.map((t) {
                    final trace = t as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 3),
                      child: Text(
                        '→ ${trace['service_name']}.${trace['function_name']} '
                        '(${trace['duration_ms']}ms, ${trace['row_count']}行)',
                        style: const TextStyle(
                            fontSize: 12, fontFamily: 'monospace'),
                      ),
                    );
                  })
                else
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text('暂无链路记录',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text('$label:',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12,
                    color: isError ? Colors.red : null,
                    fontFamily: isError || label == '会话 ID' ? 'monospace' : null)),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.length > 16 ? iso.substring(5, 16) : iso;
    }
  }

  String _fmtArgs(dynamic args) {
    if (args is Map && args.isNotEmpty) {
      return args.entries.map((e) => '${e.key}=${e.value}').join(', ');
    }
    return '无';
  }
}

/// 周报页面跳转桥接
class _ReportRedirect extends ConsumerWidget {
  const _ReportRedirect();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 延迟加载周报组件
    return const _SkillReportPageInner();
  }
}

// 周报内容（内联以简化文件结构）
class _SkillReportPageInner extends ConsumerWidget {
  const _SkillReportPageInner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(skillWeeklyReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('技能调用分析周报'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(skillWeeklyReportProvider),
          ),
        ],
      ),
      body: reportAsync.when(
        data: (report) => _buildReport(context, report),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _buildReport(BuildContext context, Map<String, dynamic> report) {
    final totalCalls = report['total_calls'] ?? 0;
    final successRate = ((report['success_rate'] ?? 0) as num) * 100;
    final avgDuration = report['avg_duration_ms'] ?? 0.0;
    final successCount = report['success_count'] ?? 0;
    final failureCount = report['failure_count'] ?? 0;
    final skillStats = (report['skill_stats'] as List<dynamic>?) ?? [];
    final hotRanking = (report['hot_ranking'] as List<dynamic>?) ?? [];
    final failureReasons = (report['failure_reasons'] as List<dynamic>?) ?? [];
    final periodStart = report['period']?['start'] ?? '';
    final periodEnd = report['period']?['end'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '统计周期: ${_formatPeriod(periodStart)} ~ ${_formatPeriod(periodEnd)}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 16),

        // 总览卡片
        Row(
          children: [
            Expanded(
              child: _OverviewCard(
                title: '总调用次数',
                value: '$totalCalls',
                icon: Icons.api,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: '成功率',
                value: '${successRate.toStringAsFixed(1)}%',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _OverviewCard(
                title: '平均响应时间',
                value: '${(avgDuration as num).toStringAsFixed(0)}ms',
                icon: Icons.speed,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OverviewCard(
                title: '成功/失败',
                value: '$successCount / $failureCount',
                icon: Icons.compare_arrows,
                color: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 热度排名
        Text('🔥 热度排名', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (hotRanking.isEmpty)
          _emptyHint('暂无数据')
        else
          ...hotRanking.map((item) =>
              _HotRankTile(item as Map<String, dynamic>)),

        const SizedBox(height: 24),

        // 详细统计
        Text('📊 Skill 详细统计',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (skillStats.isEmpty)
          _emptyHint('暂无数据')
        else
          ...skillStats.map(
              (s) => _SkillStatsTile(s as Map<String, dynamic>)),

        const SizedBox(height: 24),

        // 失败原因
        Text('⚠️ 失败原因分布',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (failureReasons.isEmpty)
          _emptyHint('暂无失败记录')
        else
          ...failureReasons.map(
              (f) => _FailureReasonTile(f as Map<String, dynamic>)),
      ],
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(text,
          style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
    );
  }

  String _formatPeriod(String iso) {
    if (iso.isEmpty) return '';
    return iso.substring(0, 10);
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _OverviewCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _HotRankTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _HotRankTile(this.item);

  @override
  Widget build(BuildContext context) {
    final rank = item['rank'] ?? 0;
    final name = item['skill_name'] ?? '';
    final count = item['call_count'] ?? 0;
    final medalColor = rank == 1
        ? Colors.amber
        : rank == 2
            ? Colors.blueGrey
            : rank == 3
                ? Colors.brown
                : Colors.grey;
    return ListTile(
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: medalColor.withValues(alpha: 0.15),
        child: Text('$rank',
            style: TextStyle(fontSize: 12, color: medalColor, fontWeight: FontWeight.bold)),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: Text('调用 $count 次',
          style: const TextStyle(fontSize: 13, color: Colors.grey)),
      dense: true,
    );
  }
}

class _SkillStatsTile extends StatelessWidget {
  final Map<String, dynamic> stat;
  const _SkillStatsTile(this.stat);

  @override
  Widget build(BuildContext context) {
    final name = stat['skill_name'] ?? '';
    final count = stat['call_count'] ?? 0;
    final successRate = ((stat['success_rate'] ?? 0) as num) * 100;
    final avgMs = stat['avg_duration_ms'] ?? 0;
    final maxMs = stat['max_duration_ms'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: [
                _MiniStat(label: '调用', value: '$count'),
                _MiniStat(
                    label: '成功率', value: '${successRate.toStringAsFixed(1)}%'),
                _MiniStat(label: '平均', value: '${avgMs}ms'),
                _MiniStat(label: '最大', value: '${maxMs}ms'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}

class _FailureReasonTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _FailureReasonTile(this.item);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.warning_amber, color: Colors.red, size: 20),
      title: Text(item['reason'] ?? '', style: const TextStyle(fontSize: 13)),
      trailing: Text('${item['count']}次',
          style: const TextStyle(color: Colors.red)),
      dense: true,
    );
  }
}
