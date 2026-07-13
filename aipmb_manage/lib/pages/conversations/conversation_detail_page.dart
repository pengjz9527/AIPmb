import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/providers/conversation_provider.dart';
import 'package:aipmb_manage/models/conversation.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';

class ConversationDetailPage extends ConsumerStatefulWidget {
  final String userName;
  final String sessionId;
  const ConversationDetailPage({super.key, required this.userName, required this.sessionId});

  @override
  ConsumerState<ConversationDetailPage> createState() => _ConversationDetailPageState();
}

class _ConversationDetailPageState extends ConsumerState<ConversationDetailPage> {
  bool _analyzing = false;

  @override
  Widget build(BuildContext context) {
    final query = ConversationDetailQuery(userName: widget.userName, sessionId: widget.sessionId);
    final detailAsync = ref.watch(conversationDetailProvider(query));

    return Scaffold(
      appBar: AppBar(title: const Text('对话详情')),
      body: detailAsync.when(
        data: (detail) {
          if (detail == null) return const Center(child: Text('会话不存在'));
          return _buildDetail(context, detail);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, ConversationDetail detail) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 会话元信息
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '会话 ID: ${detail.sessionId}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (detail.source == 'realtime')
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
                if (detail.businessTypes.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: detail.businessTypes.map((bt) {
                      return Chip(
                        label: Text(bt),
                        backgroundColor: _businessColor(bt).withOpacity(0.12),
                        side: BorderSide.none,
                      );
                    }).toList(),
                  )
                else
                  Row(
                    children: [
                      const Text('未标注业务维度', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _analyzing ? null : () => _analyze(context),
                        icon: _analyzing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome, size: 16),
                        label: Text(_analyzing ? '分析中...' : 'AI 分析'),
                      ),
                    ],
                  ),
                if (detail.summary.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.summarize, size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            detail.summary,
                            style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (detail.compressed) ...[
                  const SizedBox(height: 8),
                  Text(
                    '（该会话已压缩，仅显示摘要）',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 消息列表
        if (detail.messages.isEmpty && detail.compressed)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('原始消息已压缩', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...detail.messages.map((msg) => _MessageBubble(msg: msg)),
      ],
    );
  }

  Future<void> _analyze(BuildContext context) async {
    setState(() => _analyzing = true);
    try {
      await ApiClient().post(
        ApiConfig.analyzeConversation(widget.userName),
        data: {'session_id': widget.sessionId},
      );
      // 刷新详情
      ref.invalidate(conversationDetailProvider(
        ConversationDetailQuery(userName: widget.userName, sessionId: widget.sessionId),
      ));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 分析完成')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析失败: $e')),
        );
      }
    } finally {
      setState(() => _analyzing = false);
    }
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
}

class _MessageBubble extends StatelessWidget {
  final ConversationMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
          border: Border.all(
            color: isUser ? Colors.blue.shade100 : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUser ? '用户' : 'AI 助手',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isUser ? Colors.blue.shade700 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              msg.content,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
