import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// 资产分布饼图组件
class WealthPieChart extends StatelessWidget {
  final List<WealthSegment> segments;
  final double size;

  const WealthPieChart({
    super.key,
    required this.segments,
    this.size = 160,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return SizedBox(
        height: size,
        child: const Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey))),
      );
    }

    return Row(
      children: [
        // 饼图
        SizedBox(
          width: size,
          height: size,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {},
              ),
              sections: _buildSections(context),
              centerSpaceRadius: size * 0.2,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // 图例
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: segments.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _colors[entry.key % _colors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.value.label,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entry.value.percentage.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(BuildContext context) {
    return segments.asMap().entries.map((entry) {
      final color = _colors[entry.key % _colors.length];
      return PieChartSectionData(
        value: entry.value.amount,
        color: color,
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        showTitle: false,
        radius: size * 0.22,
        badgeWidget: entry.value.percentage > 10
            ? Text('${entry.value.percentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
            : null,
        badgePositionPercentageOffset: 0.6,
      );
    }).toList();
  }

  static const List<Color> _colors = [
    Color(0xFF1A73E8), // 蓝
    Color(0xFF34A853), // 绿
    Color(0xFFEA4335), // 红
    Color(0xFFFBBC05), // 黄
    Color(0xFF9C27B0), // 紫
    Color(0xFFFF6D00), // 橙
  ];
}

/// 资产分布段数据
class WealthSegment {
  final String label;
  final double amount;
  final double percentage;

  const WealthSegment({
    required this.label,
    required this.amount,
    required this.percentage,
  });
}
