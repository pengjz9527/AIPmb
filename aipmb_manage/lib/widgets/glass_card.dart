import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aipmb_manage/config/design_tokens.dart';

/// 毛玻璃卡片 — 半透明模糊背景 + 柔和圆角 + 阴影
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
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

/// 渐变边框卡片
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
      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
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
        child: Padding(padding: padding, child: child),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
