import 'package:flutter/material.dart';
import 'package:aipmb_app/pages/moment/widgets/section_header.dart';

class HiddenHabitsSection extends StatelessWidget {
  const HiddenHabitsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '隐秘习惯'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.psychology_outlined, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text(
                  '隐秘习惯发现即将上线',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI 帮你发现那些藏在交易流水中的消费模式和隐秘习惯',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
