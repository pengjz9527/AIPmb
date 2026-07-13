import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/providers/chat_provider.dart';
import 'package:aipmb_app/models/suggestion.dart';
import 'package:aipmb_app/models/chat_message.dart';
import 'package:aipmb_app/widgets/chat/message_bubble.dart';
import 'package:aipmb_app/widgets/chat/chat_input_bar.dart';
import 'package:aipmb_app/widgets/chat/streaming_text.dart';
import 'package:aipmb_app/services/stt_service.dart';

/// 全屏 AI 对话页面 — 统一入口，后端自动路由
class FullChatPage extends ConsumerStatefulWidget {
  final String? initialMessage;

  const FullChatPage({super.key, this.initialMessage});

  @override
  ConsumerState<FullChatPage> createState() => _FullChatPageState();
}

class _FullChatPageState extends ConsumerState<FullChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isStreaming = false;
  bool _initialSent = false;
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
    final notifier = ref.read(chatMessagesProvider.notifier);
    notifier.ensureConnected();

    // 流式结束时重置状态
    notifier.onStreamingDone = () {
      if (mounted) setState(() => _isStreaming = false);
    };

    // 若有初始消息，连接建立后自动发送
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_initialSent) {
          _initialSent = true;
          _sendMessage(widget.initialMessage!);
        }
      });
    }
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
            CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              ref.watch(chatMessagesProvider.notifier).activeAgentName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showClearDialog(context),
            tooltip: '清空对话',
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: messages.isEmpty && widget.initialMessage == null
                ? _buildEmptyState()
                : _buildMessageList(messages, suggestionsMap),
          ),
          // 思考中指示器
          if (_isStreaming)
            StreamingText(
              agentName: '小易',
              currentStep: ref.read(chatMessagesProvider.notifier).currentStepName,
            ),
          // 输入栏
          ChatInputBar(
            controller: _inputController,
            onSubmitted: _sendMessage,
            onMicPressed: () => _toggleMic(),
            hintText: '问小易任何问题...',
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
          CircleAvatar(
            radius: 36,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.smart_toy,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text('AI 助手小易', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('随时为你服务', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 28),
          _buildQuickPrompts(),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts() {
    const prompts = [
      '我的账户余额',
      '收支分析',
      '帮我制定理财方案',
      '推荐适合我的产品',
      '我的消费画像',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: prompts.map((p) => ActionChip(
          label: Text(p, style: const TextStyle(fontSize: 13)),
          onPressed: () => _sendMessage(p),
        )).toList(),
      ),
    );
  }

  Widget _buildMessageList(List<ChatMessage> messages, Map<String, List<NextSuggestion>> suggestionsMap) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final suggestions = suggestionsMap[msg.id] ?? [];
        return MessageBubble(
          message: msg,
          agentName: ref.read(chatMessagesProvider.notifier).activeAgentName,
          nextSuggestions: suggestions.isNotEmpty ? suggestions : null,
          onSuggestionTap: (s) => _sendMessage(s.prompt),
        );
      },
    );
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() => _isStreaming = true);

    ref.read(chatMessagesProvider.notifier).sendMessage(text);
    _inputController.clear();

    // 滚动到底部
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

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空对话'),
        content: const Text('确定要清空所有对话记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 清空消息列表
              ref.read(chatMessagesProvider.notifier).clearMessages();
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
