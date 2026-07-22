import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/providers/recommendation_provider.dart';
import 'package:aipmb_app/widgets/cards/promo_card.dart';
import 'package:aipmb_app/pages/moment/widgets/section_header.dart';

class PromoSection extends ConsumerWidget {
  const PromoSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promosAsync = ref.watch(promosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '专属优惠'),
        promosAsync.when(
          data: (promos) => promos.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: Text('暂无优惠'))
              : GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.8,
                  children: promos.map((p) => PromoCard(item: p)).toList(),
                ),
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
