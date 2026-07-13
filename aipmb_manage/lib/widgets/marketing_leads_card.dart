import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aipmb_manage/config/api_config.dart';
import 'package:aipmb_manage/services/api_client.dart';

class MarketingLeadsCard extends StatefulWidget {
  final String userName;
  const MarketingLeadsCard({super.key, required this.userName});

  @override
  State<MarketingLeadsCard> createState() => _MarketingLeadsCardState();
}

class _MarketingLeadsCardState extends State<MarketingLeadsCard> {
  Map<String, dynamic>? _cachedLeads;
  bool _loadingCache = true;

  // 流式分析状态
  bool _isAnalyzing = false;
  String _statusMessage = '';
  final List<_StreamEvent> _streamEvents = [];
  Map<String, dynamic>? _streamResult;
  String? _streamError;

  final ScrollController _scrollController = ScrollController();
  html.EventSource? _currentEventSource;

  @override
  void initState() {
    super.initState();
    _loadCachedLeads();
  }

  @override
  void dispose() {
    _currentEventSource?.close();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedLeads() async {
    try {
      final res =
          await ApiClient().get(ApiConfig.marketingLeads(widget.userName));
      final data = res.data['data'] as Map<String, dynamic>?;
      if (data != null && data['generated_at'] != null) {
        setState(() => _cachedLeads = data);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingCache = false);
  }

  Future<void> _startAnalysis() async {
    setState(() {
      _isAnalyzing = true;
      _statusMessage = '准备分析...';
      _streamEvents.clear();
      _streamResult = null;
      _streamError = null;
    });

    try {
      // Flutter Web 上使用原生 EventSource API 接收 SSE 流
      final uri = Uri.parse(ApiConfig.marketingLeadsStream(widget.userName));
      final eventSource = html.EventSource(uri.toString());

      eventSource.onMessage.listen((html.MessageEvent e) {
        final rawData = e.data as String?;
        if (rawData == null) return;
        try {
          final data = json.decode(rawData) as Map<String, dynamic>;
          _handleStreamEvent(data);
        } catch (_) {}
      });

      eventSource.onError.listen((_) {
        eventSource.close();
        if (mounted && _isAnalyzing) {
          setState(() {
            _streamError = 'SSE 连接中断';
            _isAnalyzing = false;
          });
        }
      });

      // 保存引用以便后续清理
      _currentEventSource = eventSource;
    } catch (e) {
      if (mounted) {
        setState(() {
          _streamError = '分析失败: $e';
          _isAnalyzing = false;
        });
      }
    }
  }

  void _handleStreamEvent(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';

    if (!mounted) return;

    switch (type) {
      case 'status':
        setState(() => _statusMessage = data['message'] as String? ?? '');
        break;
      case 'reasoning':
        _streamEvents.add(_StreamEvent(
          type: 'reasoning',
          content: data['content'] as String? ?? '',
        ));
        setState(() {});
        _scrollToBottom();
        break;
      case 'content':
        _streamEvents.add(_StreamEvent(
          type: 'content',
          content: data['content'] as String? ?? '',
        ));
        setState(() {});
        _scrollToBottom();
        break;
      case 'done':
        _currentEventSource?.close();
        final result = data['result'] as Map<String, dynamic>?;
        setState(() {
          _streamResult = result;
          _cachedLeads = result;
          _isAnalyzing = false;
          _statusMessage = '';
        });
        break;
      case 'error':
        _currentEventSource?.close();
        setState(() {
          _streamError = data['message'] as String? ?? '未知错误';
          _isAnalyzing = false;
        });
        break;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: Colors.amber.shade700, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('营销线索分析',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                if (_cachedLeads != null && !_isAnalyzing)
                  TextButton.icon(
                    onPressed: _startAnalysis,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('重新分析', style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ),
          const Divider(),
          if (_loadingCache)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_isAnalyzing)
            _buildAnalyzingSection()
          else if (_streamError != null)
            _buildErrorSection()
          else if (_cachedLeads != null)
            _buildLeadsSection(_cachedLeads!)
          else
            _buildEmptySection(),
        ],
      ),
    );
  }

  Widget _buildEmptySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('暂无分析记录',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _startAnalysis,
            icon: const Icon(Icons.psychology, size: 18),
            label: const Text('开始线索分析'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_streamError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _startAnalysis,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingSection() {
    return SizedBox(
      height: 400,
      child: Column(
        children: [
          // 状态条
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_statusMessage,
                      style: TextStyle(
                          fontSize: 12, color: Colors.blue.shade700)),
                ),
              ],
            ),
          ),
          // AI 推理过程区域
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _streamEvents.length,
              itemBuilder: (_, index) {
                final event = _streamEvents[index];
                return _buildStreamEventTile(event);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamEventTile(_StreamEvent event) {
    final isReasoning = event.type == 'reasoning';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isReasoning
            ? Colors.amber.shade50
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isReasoning
              ? Colors.amber.shade200
              : Colors.blue.shade200,
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isReasoning ? Icons.psychology : Icons.text_snippet,
            size: 14,
            color: isReasoning
                ? Colors.amber.shade700
                : Colors.blue.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event.content,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isReasoning
                    ? Colors.amber.shade900
                    : Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadsSection(Map<String, dynamic> data) {
    final leads = (data['leads'] as List<dynamic>?) ?? [];
    final insight = data['user_insight'] as String? ?? '';
    final generatedAt = data['generated_at'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 生成时间
          if (generatedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.access_time,
                      size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('生成时间: ${_formatTime(generatedAt)}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          // 用户洞察
          if (insight.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(insight,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ),
          // 线索列表
          if (leads.isNotEmpty)
            ...leads.map((lead) {
              final l = lead as Map<String, dynamic>;
              return _buildLeadItem(l);
            }),
        ],
      ),
    );
  }

  Widget _buildLeadItem(Map<String, dynamic> lead) {
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
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _leadTypeColor(type).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(type,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _leadTypeColor(type))),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(priority,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: priorityColor)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(reason,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3)),
            if (action.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.campaign_outlined,
                      size: 12, color: Colors.teal.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(action,
                        style: TextStyle(
                            fontSize: 11,
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
}

class _StreamEvent {
  final String type; // 'reasoning' | 'content'
  final String content;
  const _StreamEvent({required this.type, required this.content});
}
