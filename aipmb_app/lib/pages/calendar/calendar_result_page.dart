import 'package:flutter/material.dart';
import 'package:aipmb_app/services/calendar_api.dart';
import 'package:aipmb_app/services/api_client.dart';

/// 纪念日历结果页面 — 展示 AI 识别的人生纪念事件
class CalendarResultPage extends StatefulWidget {
  final String userName;

  const CalendarResultPage({super.key, required this.userName});

  @override
  State<CalendarResultPage> createState() => _CalendarResultPageState();
}

class _CalendarResultPageState extends State<CalendarResultPage> {
  final CalendarApi _api = CalendarApi(ApiClient());
  Map<String, dynamic>? _calendarData;
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    try {
      final data = await _api.getCalendar(widget.userName);
      if (!mounted) return;
      setState(() {
        _calendarData = data;
        _events = (data['events'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载日历失败: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的纪念日历',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_error ?? '未知错误',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadCalendar, child: const Text('重试')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('暂未发现纪念事件',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('AI 正在持续学习您的消费习惯',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    // 按月份分组
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in _events) {
      final date = e['date'] as String? ?? '';
      final monthKey = date.length >= 7 ? date.substring(0, 7) : '未知';
      grouped.putIfAbsent(monthKey, () => []).add(e);
    }
    final months = grouped.keys.toList()..sort();

    final generatedAt = _calendarData?['generated_at'] as String? ?? '';
    final generatedDisplay = _formatDate(generatedAt);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 页头
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade100,
                Colors.pink.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(Icons.auto_awesome, size: 36, color: Colors.orange),
              const SizedBox(height: 12),
              const Text('AI 发现的珍贵时刻',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('共有 ${_events.length} 个值得纪念的人生事件',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              if (generatedDisplay.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('生成时间: $generatedDisplay',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 按月份展示事件
        ...months.map((month) => _buildMonthSection(month, grouped[month]!)),
      ],
    );
  }

  Widget _buildMonthSection(String month, List<Map<String, dynamic>> events) {
    final displayMonth = _formatMonth(month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 月份标题
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 12),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.orange.shade600),
              const SizedBox(width: 6),
              Text(displayMonth,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  )),
            ],
          ),
        ),

        // 该月份的事件卡片
        ...events.map((e) => _buildEventCard(e)),
      ],
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final title = event['title'] as String? ?? '';
    final description = event['description'] as String? ?? '';
    final eventType = event['event_type'] as String? ?? '';
    final date = event['date'] as String? ?? '';
    final importance = event['importance'] as int? ?? 5;

    final typeInfo = _eventTypeInfo(eventType);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 事件类型图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: typeInfo.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeInfo.icon, color: typeInfo.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      // 重要性星星
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          (importance / 2).ceil().clamp(1, 5),
                          (i) => Icon(Icons.star,
                              size: 12, color: Colors.amber.shade400),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(description,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeInfo.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(typeInfo.label,
                            style: TextStyle(
                                fontSize: 11, color: typeInfo.color)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatEventDate(date),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _EventTypeInfo _eventTypeInfo(String type) {
    switch (type) {
      case 'milestone':
        return _EventTypeInfo(Icons.flag, Colors.blue, '里程碑');
      case 'life_change':
        return _EventTypeInfo(Icons.home, Colors.teal, '生活变迁');
      case 'major_purchase':
        return _EventTypeInfo(Icons.shopping_cart, Colors.purple, '重要消费');
      case 'emotion':
        return _EventTypeInfo(Icons.favorite, Colors.pink, '情感记忆');
      case 'growth':
        return _EventTypeInfo(Icons.trending_up, Colors.green, '成长轨迹');
      default:
        return _EventTypeInfo(Icons.star, Colors.orange, '纪念');
    }
  }

  String _formatMonth(String yyyymm) {
    if (yyyymm.length < 7) return yyyymm;
    final year = yyyymm.substring(0, 4);
    final month = yyyymm.substring(5, 7);
    return '$year 年 $month 月';
  }

  String _formatEventDate(String dateStr) {
    if (dateStr.length < 10) return dateStr;
    return '${dateStr.substring(5, 7)}月${dateStr.substring(8, 10)}日';
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _EventTypeInfo {
  final IconData icon;
  final Color color;
  final String label;
  const _EventTypeInfo(this.icon, this.color, this.label);
}
