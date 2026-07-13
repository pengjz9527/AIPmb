import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// AI 服务页底部输入栏 — 文字优先 + 左侧语音按钮
/// 提交后跳转至对话页
class AiServiceInputBar extends StatefulWidget {
  const AiServiceInputBar({super.key});

  @override
  State<AiServiceInputBar> createState() => _AiServiceInputBarState();
}

class _AiServiceInputBarState extends State<AiServiceInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String text) {
    final msg = text.trim();
    if (msg.isEmpty) return;
    _controller.clear();
    context.push('/chat?msg=${Uri.encodeComponent(msg)}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 加号按钮
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: Colors.grey.shade600),
              onPressed: () {},
              tooltip: '更多',
              visualDensity: VisualDensity.compact,
            ),
            // 语音按钮
            IconButton(
              icon: Icon(Icons.mic_outlined, color: Colors.grey.shade600),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('语音功能开发中'), duration: Duration(seconds: 1)),
                );
              },
              tooltip: '语音输入',
              visualDensity: VisualDensity.compact,
            ),
            // 输入框
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: '问问小易...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: _submit,
                maxLines: 1,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 4),
            // 发送按钮
            IconButton(
              icon: Icon(
                Icons.send_rounded,
                color: _hasText ? theme.colorScheme.primary : Colors.grey.shade400,
              ),
              onPressed: _hasText ? () => _submit(_controller.text) : null,
              tooltip: '发送',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
