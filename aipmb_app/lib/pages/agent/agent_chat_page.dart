import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/providers/chat_provider.dart';
import 'package:aipmb_app/widgets/chat/message_bubble.dart';
import 'package:aipmb_app/widgets/chat/chat_input_bar.dart';
import 'package:aipmb_app/services/stt_service.dart';

class AgentChatPage extends ConsumerStatefulWidget {
  final String agentId;
  final String agentName;

  const AgentChatPage({super.key, required this.agentId, required this.agentName});

  @override
  ConsumerState<AgentChatPage> createState() => _AgentChatPageState();
}

class _AgentChatPageState extends ConsumerState<AgentChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final bool _isThinking = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _connectSession();
    _initStt();
  }

  void _initStt() {
    final stt = SttService();
    stt.onResult = (text) {
      if (text.trim().isNotEmpty && mounted) {
        _inputController.text = text;
        _sendMessage(text);
      }
    };
    stt.onStatusChanged = (listening) {
      if (mounted) setState(() => _isListening = listening);
    };
    stt.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音识别: $error')),
        );
      }
    };
  }

  void _connectSession() {
    ref.read(chatMessagesProvider.notifier).ensureConnected();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final suggestionsMap = ref.watch(suggestionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined, size: 20),
            const SizedBox(width: 8),
            Text(widget.agentName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final suggestions = suggestionsMap[msg.id] ?? [];
                      return MessageBubble(
                        message: msg,
                        agentName: widget.agentName,
                        nextSuggestions: suggestions.isNotEmpty ? suggestions : null,
                        onSuggestionTap: (s) => _sendMessage(s.prompt),
                      );
                    },
                  ),
          ),
          if (_isThinking)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('思考中...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
          ChatInputBar(
            controller: _inputController,
            onSubmitted: _sendMessage,
            onMicPressed: () => _toggleMic(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy_outlined, size: 64, color: Theme.of(context).colorScheme.primaryContainer),
          const SizedBox(height: 16),
          Text(widget.agentName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('有什么可以帮您的？', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          _buildQuickActions(),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => context.push('/agent/${widget.agentId}/report?name=${Uri.encodeComponent(widget.agentName)}'),
            icon: const Icon(Icons.analytics_outlined, size: 18),
            label: const Text('一键深度分析'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = _getQuickActionsForAgent(widget.agentId);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: actions.map((action) => ActionChip(
        label: Text(action, style: const TextStyle(fontSize: 13)),
        onPressed: () => _sendMessage(action),
      )).toList(),
    );
  }

  List<String> _getQuickActionsForAgent(String agentId) {
    switch (agentId) {
      case 'financial_planner':
        return ['帮我制定理财方案', '分析我的资产配置', '如何优化收益'];
      case 'consumption_analyst':
        return ['没有收入能撑多久', '分析我的消费结构', '降低消费建议'];
      case 'income_expense_analyst':
        return ['分析收支状况', '消费结构分析', '省钱建议', '整理差旅报销'];
      case 'life_assistant':
        return ['推荐适合我的产品', '有什么优惠活动', '根据我的画像推荐'];
      case 'user_profiler':
        return ['我是怎样的人', '给我有趣的建议', '分析我的消费画像'];
      default:
        return ['你好', '帮我分析一下', '有什么建议'];
    }
  }

  Future<void> _toggleMic() async {
    final stt = SttService();
    if (_isListening) {
      await stt.stopListening();
    } else {
      final ok = await stt.init();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('语音识别功能不可用，请检查麦克风权限')),
          );
        }
        return;
      }
      await stt.startListening();
    }
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    ref.read(chatMessagesProvider.notifier).sendMessage(text, agentId: widget.agentId);
    _inputController.clear();
    // Auto-scroll to bottom after sending
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
