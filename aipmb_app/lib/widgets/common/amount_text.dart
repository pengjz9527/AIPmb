import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 金额格式化文本组件 — 支持数字滚动动画
class AmountText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final bool showSymbol;
  final bool compact;
  final bool animate;

  const AmountText({
    super.key,
    required this.amount,
    this.style,
    this.showSymbol = true,
    this.compact = false,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    if (animate) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: amount),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Text(
            Formatting.formatAmount(value, showSymbol: showSymbol, compact: compact),
            style: style ?? Theme.of(context).textTheme.bodyMedium,
          );
        },
      );
    }
    return Text(
      Formatting.formatAmount(amount, showSymbol: showSymbol, compact: compact),
      style: style ?? Theme.of(context).textTheme.bodyMedium,
    );
  }
}

/// 金额格式化
class Formatting {
  Formatting._();

  static String formatAmount(double value, {bool showSymbol = true, bool compact = false}) {
    final prefix = showSymbol ? '¥' : '';

    if (compact) {
      if (value.abs() >= 100000000) {
        return '$prefix${(value / 100000000).toStringAsFixed(2)}亿';
      }
      if (value.abs() >= 10000) {
        return '$prefix${(value / 10000).toStringAsFixed(2)}万';
      }
    }

    final formatter = NumberFormat('#,##0.00', 'zh_CN');
    return '$prefix${formatter.format(value)}';
  }
}
