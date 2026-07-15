import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aipmb_app/config/design_tokens.dart';

/// 毛玻璃卡片 — 半透明模糊背景 + 柔和圆角 + 阴影
///
/// 适用于任何需要高级质感卡片的场景。
/// 配合有图案/渐变/图片的背景效果最佳。
class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadiusGeometry borderRadius;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;
  final double? width;
  final double? height;

  /// 是否在挂载时播放入场动画
  final bool animateOnMount;
  /// 列表中的序号（用于交错动画延迟计算）
  final int? staggerIndex;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.12,
    this.padding = const EdgeInsets.all(DesignTokens.spacingMD),
    this.margin = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(DesignTokens.radiusMD)),
    this.shadows,
    this.onTap,
    this.backgroundColor,
    this.border,
    this.width,
    this.height,
    this.animateOnMount = false,
    this.staggerIndex,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveShadows = shadows ?? DesignTokens.shadowCard;
    final effectiveBg = backgroundColor ?? Colors.white.withValues(alpha: opacity);

    final card = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: borderRadius,
        border: border,
        boxShadow: effectiveShadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: borderRadius.resolve(Directionality.of(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return _wrapAnimation(
        GestureDetector(onTap: onTap, child: card),
      );
    }
    return _wrapAnimation(card);
  }

  Widget _wrapAnimation(Widget widget) {
    if (!animateOnMount) return widget;
    final delay = staggerIndex != null
        ? DesignTokens.staggerDelay(staggerIndex!)
        : DesignTokens.staggerBase;
    return widget
        .animate(delay: delay, autoPlay: true)
        .fadeIn(
          duration: DesignTokens.durationEntrance,
          curve: DesignTokens.curveEntrance,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          duration: DesignTokens.durationEntrance,
          curve: DesignTokens.curveEntrance,
        );
  }
}

/// 渐变边框卡片 — 产品推荐、AI 推荐等强调类卡片
class GradientBorderCard extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadiusGeometry borderRadius;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;

  const GradientBorderCard({
    super.key,
    required this.child,
    this.gradient = const LinearGradient(
      colors: [Color(0xFF6C4DFF), Color(0xFFE040FB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    this.padding = const EdgeInsets.all(DesignTokens.spacingMD),
    this.margin = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(DesignTokens.radiusMD)),
    this.borderWidth = 1.5,
    this.shadows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveShadows = shadows ?? DesignTokens.shadowCard;
    final radius = borderRadius is BorderRadius
        ? borderRadius as BorderRadius
        : BorderRadius.circular(DesignTokens.radiusMD);

    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: effectiveShadows,
        gradient: gradient,
      ),
      child: Container(
        margin: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius.subtract(BorderRadius.circular(borderWidth)),
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
