import 'package:flutter/material.dart';

/// 统一设计令牌 — 圆角、阴影、间距、动画时长
class DesignTokens {
  DesignTokens._();

  // ── 圆角系统 ──
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 999.0;

  // ── 阴影层级 ──
  static const List<BoxShadow> shadowSubtle = [
    BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> shadowCard = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> shadowElevated = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> shadowModal = [
    BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 20)),
  ];

  // ── 间距系统 ──
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // ── 动画时长 ──
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationEntrance = Duration(milliseconds: 400);
  static const Curve curveStandard = Curves.easeOutCubic;
  static const Curve curveEntrance = Curves.easeOutQuart;
  static const Curve curveBounce = Curves.easeOutBack;

  // ── 列表交错动画 ──
  /// 每个卡片入场延迟间隔
  static const Duration staggerInterval = Duration(milliseconds: 80);
  /// 首个卡片入场延迟
  static const Duration staggerBase = Duration(milliseconds: 100);

  /// 计算第 index 个元素的入场延迟
  static Duration staggerDelay(int index) =>
      staggerBase + staggerInterval * index;
}
