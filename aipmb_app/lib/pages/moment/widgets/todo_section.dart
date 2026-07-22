import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/providers/recommendation_provider.dart';
import 'package:aipmb_app/widgets/cards/todo_card.dart';
import 'package:aipmb_app/pages/moment/widgets/section_header.dart';

class TodoSection extends ConsumerWidget {
  const TodoSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: '待办提醒'),
        todosAsync.when(
          data: (todos) => todos.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: Text('暂无待办'))
              : Column(
                  children: todos.take(3).toList().asMap().entries.map((e) {
                    final t = e.value;
                    return TodoCard(
                      item: t,
                      index: e.key,
                      onTap: () {
                        if (t.type == 'payment_due') {
                          context.push(
                            '/channel/payment'
                            '?payment_no=${Uri.encodeComponent(t.paymentNo ?? '')}'
                            '&payment_type=${Uri.encodeComponent(t.paymentTypeLabel ?? '')}',
                          );
                        } else if (t.type == 'credit_repayment') {
                          context.push('/held-products');
                        } else if (t.type == 'spending_alert') {
                          context.push('/chat?msg=${Uri.encodeComponent('帮我分析最近的消费明细')}');
                        }
                      },
                    );
                  }).toList(),
                ),
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('加载失败: $e')),
        ),
      ],
    );
  }
}
