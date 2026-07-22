import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/providers/recommendation_provider.dart';
import 'package:aipmb_app/pages/moment/widgets/section_header.dart';

class NeighborhoodSection extends ConsumerStatefulWidget {
  const NeighborhoodSection({super.key});

  @override
  ConsumerState<NeighborhoodSection> createState() => _NeighborhoodSectionState();
}

class _NeighborhoodSectionState extends ConsumerState<NeighborhoodSection> {
  bool _activated = false;

  void _activate() {
    if (_activated) return;
    setState(() => _activated = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_activated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '生活圈'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _activate,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7C4DFF).withValues(alpha: 0.06),
                      const Color(0xFF448AFF).withValues(alpha: 0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.map_outlined, size: 40, color: const Color(0xFF7C4DFF)),
                    const SizedBox(height: 12),
                    const Text(
                      '发现你的生活圈',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '从交易数据中分析居住地、工作地和常去商户',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '点击探索',
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF7C4DFF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF7C4DFF)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final dataAsync = ref.watch(neighborhoodProvider);

    return dataAsync.when(
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '生活圈'),
          _buildLocationCard(data),
          const SizedBox(height: 12),
          _buildMerchantsCard(data),
          const SizedBox(height: 12),
          _buildCommuteCard(data),
        ],
      ),
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('加载失败: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => ref.invalidate(neighborhoodProvider),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> data) {
    final location = data['location_inference'] as Map<String, dynamic>? ?? {};
    final locationHints = location['location_hints'] as Map<String, dynamic>? ?? {};
    final hints = locationHints.entries.take(3).toList();
    final workplace = (data['workplace_inference'] as List<dynamic>?)?.take(3).toList() ?? [];
    final branches = (data['branches'] as List<dynamic>?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.home_outlined, size: 20, color: Colors.indigo.shade400),
                const SizedBox(width: 8),
                Text('居住区域', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.indigo.shade400)),
              ],
            ),
            const SizedBox(height: 8),
            if (branches.isNotEmpty)
              ...branches.take(2).map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('开户行：${b.toString()}', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              )),
            if (hints.isNotEmpty)
              ...hints.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.place, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${e.key} (${e.value}次)', style: const TextStyle(fontSize: 13))),
                  ],
                ),
              )),
            if (workplace.isNotEmpty) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Icon(Icons.work_outline, size: 20, color: Colors.blue.shade400),
                  const SizedBox(width: 8),
                  Text('工作区域', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue.shade400)),
                ],
              ),
              const SizedBox(height: 8),
              ...workplace.map((w) {
                final wm = w as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.business, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('${wm['name']} (${wm['count']}次)', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              }),
            ],
            if (branches.isEmpty && hints.isEmpty && workplace.isEmpty)
              const Text('暂无居住/工作区域数据', style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantsCard(Map<String, dynamic> data) {
    final merchants = data['offline_merchants_by_category'] as Map<String, dynamic>? ?? {};
    final topDetail = (data['top_offline_detail'] as List<dynamic>?)?.take(5).toList() ?? [];

    if (merchants.isEmpty && topDetail.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store_outlined, size: 20, color: Colors.teal.shade400),
                const SizedBox(width: 8),
                Text('常去商户', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.teal.shade400)),
              ],
            ),
            const SizedBox(height: 8),
            if (merchants.isNotEmpty)
              ...merchants.entries.take(3).map((cat) {
                final items = (cat.value as List<dynamic>?)?.take(3).toList() ?? [];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('▸ ${cat.key}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      ...items.map((m) {
                        final mm = m as Map<String, dynamic>;
                        final name = mm['name'] ?? '';
                        final count = mm['count'] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 2),
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              Expanded(child: Text('$name', style: const TextStyle(fontSize: 13))),
                              Text('$count次', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            if (merchants.isEmpty && topDetail.isNotEmpty)
              Column(
                children: topDetail.map((m) {
                  final mm = m as Map<String, dynamic>;
                  final name = mm['name'] ?? '';
                  final amount = mm['amount'] ?? '';
                  final count = mm['count'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.store, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(child: Text('$name', style: const TextStyle(fontSize: 13))),
                        Text('¥${amount.toString()} ($count次)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommuteCard(Map<String, dynamic> data) {
    final commute = data['commute_analysis'] as Map<String, dynamic>? ?? {};

    if (commute.isEmpty) return const SizedBox.shrink();

    final sorted = commute.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    final topCommute = sorted.take(5);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus_outlined, size: 20, color: Colors.orange.shade400),
                const SizedBox(width: 8),
                Text('通勤方式', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange.shade400)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: topCommute.map((e) {
                return Chip(
                  avatar: Icon(_commuteIcon(e.key), size: 16),
                  label: Text('${e.key} ${e.value}次', style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _commuteIcon(String type) {
    switch (type) {
      case '地铁':
        return Icons.subway;
      case '公交':
        return Icons.directions_bus;
      case '打车':
        return Icons.local_taxi;
      case '共享单车':
        return Icons.pedal_bike;
      case '开车':
        return Icons.directions_car;
      case '火车':
        return Icons.train;
      default:
        return Icons.alt_route;
    }
  }
}
