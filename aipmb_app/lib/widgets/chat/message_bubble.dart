import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:aipmb_app/models/chat_message.dart';
import 'package:aipmb_app/models/suggestion.dart';
import 'package:aipmb_app/models/thinking_step.dart';
import 'package:aipmb_app/widgets/chat/thinking_panel.dart';
import 'package:aipmb_app/widgets/chat/markdown_table_cards.dart';
import 'package:aipmb_app/services/tts_service.dart';

/// AI 对话消息气泡组件
class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final String? agentName;
  final List<NextSuggestion>? nextSuggestions;
  final void Function(NextSuggestion suggestion)? onSuggestionTap;

  const MessageBubble({
    super.key,
    required this.message,
    this.agentName,
    this.nextSuggestions,
    this.onSuggestionTap,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _detailExpanded = false;
  bool _isSpeaking = false;

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == ChatRole.user;
    final isSystem = widget.message.role == ChatRole.system;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isUser && !isSystem) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  widget.agentName != null ? Icons.smart_toy : Icons.smart_toy_outlined,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _bubbleColor(context, isUser, isSystem),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                ),
                child: _buildContent(context, isUser),
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 16,
                child: Icon(Icons.person, size: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _bubbleColor(BuildContext context, bool isUser, bool isSystem) {
    if (isSystem) return Colors.red.shade50;
    if (isUser) return Theme.of(context).colorScheme.primary;
    return Colors.grey.shade100;
  }

  Widget _buildContent(BuildContext context, bool isUser) {
    if (isUser) {
      return Text(widget.message.content, style: const TextStyle(color: Colors.white, fontSize: 14));
    }

    if (widget.message.role == ChatRole.system) {
      return Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.message.content,
              style: TextStyle(color: Colors.red.shade900, fontSize: 13),
            ),
          ),
        ],
      );
    }

    // AI 消息 — 思考过程面板 + Markdown 内容 + 建议列表
    return _buildAiContent(context);
  }

  /// 检测内容是否包含 Markdown 表格
  bool _hasTable(String text) {
    final lines = text.split('\n');
    return lines.any((l) => l.trim().startsWith('|'));
  }

  /// 使用移动端适配渲染：表格转卡片，其余用 Markdown
  Widget _buildMobileMarkdown(String text) {
    final config = _buildMarkdownConfig(context);
    if (!_hasTable(text)) {
      return MarkdownBlock(data: text, config: config);
    }

    final widgets = MobileMarkdownRenderer.buildWidgets(context, text, config: config);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  /// 构建带链接点击处理的 MarkdownConfig
  MarkdownConfig _buildMarkdownConfig(BuildContext context) {
    return MarkdownConfig.defaultConfig.copy(
      configs: [
        LinkConfig(
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          onTap: (url) => _handleMarkdownLink(context, url),
        ),
      ],
    );
  }

  /// 处理 Markdown 链接点击，解析 /product 和 /buy 路由
  void _handleMarkdownLink(BuildContext context, String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (uri.path == '/product') {
      final productName = uri.queryParameters['product_name'] ?? '';
      if (productName.isNotEmpty) {
        context.push('/product/detail?product_name=${Uri.encodeComponent(productName)}');
      }
    } else if (uri.path == '/buy') {
      final productName = uri.queryParameters['product_name'] ?? '';
      if (productName.isNotEmpty) {
        context.push('/purchase?product_name=${Uri.encodeComponent(productName)}');
      }
    }
  }

  Widget _buildAiContent(BuildContext context) {
    final thinkingSteps = widget.message.thinkingSteps;
    final hasThinking = thinkingSteps != null && thinkingSteps.isNotEmpty;
    final content = widget.message.content;

    // 解析 ---DETAIL--- 分隔符
    final detailIdx = content.indexOf('---DETAIL---');

    Widget markdownSection;
    if (detailIdx >= 0) {
      final summary = content.substring(0, detailIdx).trim();
      final detail = content.substring(detailIdx + '---DETAIL---'.length).trim();

      markdownSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMobileMarkdown(summary),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _detailExpanded = !_detailExpanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _detailExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _detailExpanded ? '收起详细分析' : '查看详细分析',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_detailExpanded) ...[
            const SizedBox(height: 4),
            _buildMobileMarkdown(detail),
          ],
        ],
      );
    } else {
      markdownSection = _buildMobileMarkdown(content);
    }

    // 构建完整 AI 内容：Markdown + 建议列表
    final children = <Widget>[markdownSection];

    final suggestions = widget.nextSuggestions;
    if (suggestions != null && suggestions.isNotEmpty && widget.onSuggestionTap != null) {
      children.add(_buildSuggestionsSection(suggestions));
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );

    // 思考过程面板
    if (hasThinking) {
      final steps = thinkingSteps
          .whereType<ThinkingStep>()
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ThinkingPanel(
            steps: steps,
            reasoningContent: widget.message.reasoningContent,
          ),
          body,
        ],
      );
    }

    // AI 回复语音播放按钮
    if (widget.message.role == ChatRole.assistant && widget.message.content.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          body,
          _buildSpeakerButton(widget.message.content),
        ],
      );
    }
    return body;
  }

  /// 气泡内分组建议列表
  Widget _buildSuggestionsSection(List<NextSuggestion> allSuggestions) {
    final continueItems = allSuggestions.where((s) => s.group == 'continue').toList();
    final rootItems = allSuggestions.where((s) => s.group != 'continue').toList();

    final widgets = <Widget>[];

    // "继续深入" 分组
    if (continueItems.isNotEmpty) {
      widgets.add(const Divider(height: 20, thickness: 0.5));
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          '继续深入：',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));
      for (final item in continueItems) {
        widgets.add(_buildSuggestionItem(item));
      }
    }

    // "看看其他分析主题" 分组
    if (rootItems.isNotEmpty) {
      widgets.add(const Divider(height: 20, thickness: 0.5));
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          '看看其他分析主题：',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));
      for (final item in rootItems) {
        widgets.add(_buildSuggestionItem(item));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  /// 单条建议条目
  Widget _buildSuggestionItem(NextSuggestion suggestion) {
    return InkWell(
      onTap: () => widget.onSuggestionTap?.call(suggestion),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(
              Icons.arrow_forward_ios,
              size: 10,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                suggestion.label,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// AI 消息底部的语音播放按钮
  Widget _buildSpeakerButton(String content) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleTts(content),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isSpeaking ? Icons.stop : Icons.volume_up,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isSpeaking ? '停止' : '播放',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTts(String content) async {
    final tts = TtsService();
    if (_isSpeaking) {
      await tts.stop();
      setState(() => _isSpeaking = false);
    } else {
      final ok = await tts.speak(content);
      if (ok) {
        setState(() => _isSpeaking = true);
        Future.delayed(const Duration(seconds: 60), () {
          if (mounted) setState(() => _isSpeaking = false);
        });
      }
    }
  }
}
