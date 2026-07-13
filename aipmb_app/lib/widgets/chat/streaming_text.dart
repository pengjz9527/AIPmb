import 'package:flutter/material.dart';

/// 流式文本输入指示器（思考中/正在输入动画）
class StreamingText extends StatefulWidget {
  final String? agentName;
  final String? currentStep;

  const StreamingText({super.key, this.agentName, this.currentStep});

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _dotsAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _dotsAnimation = IntTween(begin: 0, end: 3).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AI 头像
          CircleAvatar(
            radius: 14,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.smart_toy, size: 14),
          ),
          const SizedBox(width: 8),
          // Agent 名称
          if (widget.agentName != null)
            Text(
              widget.agentName!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          const SizedBox(width: 8),
          // 加载指示器
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 6),
          // 文字
          Text(
            widget.currentStep ?? '思考中',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          // 动态点
          AnimatedBuilder(
            animation: _dotsAnimation,
            builder: (context, child) {
              return Text(
                '.' * _dotsAnimation.value,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              );
            },
          ),
        ],
      ),
    );
  }
}
