import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:aipmb_manage/config/design_tokens.dart';

/// 骨架屏占位组件
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 16.0,
    this.borderRadius = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// 骨架屏卡片列表
class ShimmerCardList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const ShimmerCardList({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(itemCount, (i) {
        return Padding(
          padding: const EdgeInsets.only(
            left: DesignTokens.spacingMD,
            right: DesignTokens.spacingMD,
            bottom: DesignTokens.spacingSM,
          ),
          child: ShimmerBox(
            height: itemHeight,
            borderRadius: DesignTokens.radiusMD,
          ),
        );
      }),
    );
  }
}

/// 骨架屏段落
class ShimmerParagraph extends StatelessWidget {
  final int lineCount;
  final double lastLineWidthRatio;

  const ShimmerParagraph({
    super.key,
    this.lineCount = 3,
    this.lastLineWidthRatio = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lineCount, (i) {
        final isLast = i == lineCount - 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ShimmerBox(
            width: isLast ? 200.0 * lastLineWidthRatio : double.infinity,
            height: 14.0,
            borderRadius: 4.0,
          ),
        );
      }),
    );
  }
}
