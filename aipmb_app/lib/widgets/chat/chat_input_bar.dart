import 'package:flutter/material.dart';

/// 聊天输入栏组件
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String text) onSubmitted;
  final VoidCallback? onMicPressed;
  final VoidCallback? onImagePressed;
  final String hintText;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.onMicPressed,
    this.onImagePressed,
    this.hintText = '输入消息...',
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Row(
          children: [
            // 语音按钮
            IconButton(
              icon: const Icon(Icons.mic_outlined),
              onPressed: widget.onMicPressed,
              tooltip: '语音输入',
            ),
            // 输入框
            Expanded(
              child: TextField(
                controller: widget.controller,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: widget.onSubmitted,
                maxLines: 4,
                minLines: 1,
              ),
            ),
            const SizedBox(width: 4),
            // 图片按钮
            IconButton(
              icon: const Icon(Icons.image_outlined),
              onPressed: widget.onImagePressed,
              tooltip: '发送图片',
            ),
            // 发送按钮
            IconButton(
              icon: Icon(
                Icons.send,
                color: _hasText
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).disabledColor,
              ),
              onPressed: _hasText
                  ? () => widget.onSubmitted(widget.controller.text)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
