import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/providers/tagging_provider.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';
import 'package:aipmb_manage/models/product_match_result.dart';
import 'package:aipmb_manage/models/profile_portrait_result.dart';
import 'package:aipmb_manage/widgets/tag_chip.dart';

class TaggingPage extends ConsumerStatefulWidget {
  final String userName;
  const TaggingPage({super.key, required this.userName});

  @override
  ConsumerState<TaggingPage> createState() => _TaggingPageState();
}

class _TaggingPageState extends ConsumerState<TaggingPage> {
  bool _isGeneratingTags = false;
  bool _isMatching = false;
  bool _isPortrait = false;
  ProductMatchResult? _matchResult;
  ProfilePortraitResult? _portraitResult;
  final Map<String, bool> _expandedDetails = {};

  Future<void> _generateTags() async {
    setState(() => _isGeneratingTags = true);
    try {
      await ApiClient().post(ApiConfig.generateTags(widget.userName));
      ref.invalidate(userTagsProvider(widget.userName));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('标签生成成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('生成失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingTags = false);
    }
  }

  Future<void> _startMatching() async {
    setState(() => _isMatching = true);

    try {
      await ApiClient().post(ApiConfig.startProductMatching(widget.userName));
      if (!mounted) return;
      _showMatchingDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMatching = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('启动匹配失败: $e')));
    }
  }

  void _showMatchingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _MatchingProgressDialog(
        userName: widget.userName,
        onDone: (ProductMatchResult result) {
          ref.invalidate(userTagsProvider(widget.userName));
          setState(() {
            _matchResult = result;
            _isMatching = false;
          });
        },
        onError: (msg) {
          setState(() => _isMatching = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('匹配失败: $msg')));
        },
      ),
    );
  }

  Future<void> _startPortrait() async {
    setState(() => _isPortrait = true);

    try {
      await ApiClient().post(ApiConfig.startPortrait(widget.userName));
      if (!mounted) return;
      _showPortraitDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPortrait = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('启动画像生成失败: $e')));
    }
  }

  void _showPortraitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PortraitProgressDialog(
        userName: widget.userName,
        onDone: (ProfilePortraitResult result) {
          ref.invalidate(userTagsProvider(widget.userName));
          setState(() {
            _portraitResult = result;
            _isPortrait = false;
          });
        },
        onError: (msg) {
          setState(() => _isPortrait = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('画像生成失败: $msg')));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(userTagsProvider(widget.userName));

    return Scaffold(
      appBar: AppBar(title: Text('${widget.userName} 标签')),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(left: 32),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              heroTag: 'tags',
              onPressed: _isGeneratingTags ? null : _generateTags,
              icon: _isGeneratingTags
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isGeneratingTags ? '生成中...' : 'AI 生成标签'),
            ),
            const SizedBox(width: 12),
            FloatingActionButton.extended(
              heroTag: 'match',
              onPressed: _isMatching ? null : _startMatching,
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              icon: _isMatching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.psychology),
              label: Text(_isMatching ? '匹配中...' : 'AI 匹配产品'),
            ),
            const SizedBox(width: 12),
            FloatingActionButton.extended(
              heroTag: 'portrait',
              onPressed: _isPortrait ? null : _startPortrait,
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              icon: _isPortrait
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.person_pin),
              label: Text(_isPortrait ? '生成中...' : '用户性格画像'),
            ),
          ],
        ),
      ),
      body: tagsAsync.when(
        data: (tag) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 标签区域
              if (tag != null && tag.tags.isNotEmpty) ...[
                Text('生成时间: ${tag.generatedAt}',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('使用模型: ${tag.modelUsed}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tag.tags
                      .map((t) =>
                          TagChip(name: t.name, reasoning: t.reasoning))
                      .toList(),
                ),
                const SizedBox(height: 24),
                Text('标签详情',
                    style: Theme.of(context).textTheme.titleMedium),
                ...tag.tags.map((t) => Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name,
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Text(t.reasoning,
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    )),
              ] else ...[
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.label_off, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('暂无标签',
                          style: TextStyle(fontSize: 16, color: Colors.grey)),
                      SizedBox(height: 4),
                      Text('点击右下角按钮生成标签并匹配产品',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              ],

              // 匹配结果区域
              if (_matchResult != null) ...[  
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 8),
                _buildMatchResult(_matchResult!),
              ],
              
              // 性格画像结果区域
              if (_portraitResult != null) ...[
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 8),
                _buildPortraitResult(_portraitResult!),
              ],

              const SizedBox(height: 100), // 底部留白避免被 FAB 遮挡
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _buildMatchResult(ProductMatchResult result) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.psychology, color: Colors.deepPurple, size: 22),
            const SizedBox(width: 8),
            Text('AI 匹配产品',
                style:
                    theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text('生成时间: ${result.generatedAt} · 模型: ${result.modelUsed}',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),

        // 风评警告
        if (result.riskWarning != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.riskWarning!,
                    style: TextStyle(
                        fontSize: 13, color: Colors.amber.shade900, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

        // 风评信息
        if (result.hasRiskAssessment && result.riskLevel != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user, color: Colors.green.shade700, size: 18),
                const SizedBox(width: 8),
                Text('风险评估: ${result.riskLevel}',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),

        // 产品列表
        ...result.matchedProducts.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          return _buildProductCard(p, i, theme);
        }),
      ],
    );
  }

  Widget _buildProductCard(MatchedProduct p, int index, ThemeData theme) {
    final isTop = index == 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isTop ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isTop
            ? BorderSide(color: Colors.deepPurple.shade200, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                if (isTop)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('最佳匹配',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                if (isTop) const SizedBox(width: 8),
                Expanded(
                  child: Text(p.productName,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _scoreColor(p.matchScore).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${p.matchPercent}%',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _scoreColor(p.matchScore))),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 银行 + 类别 + 风险
            Row(
              children: [
                _infoChip(p.bank, Icons.account_balance, Colors.blue),
                const SizedBox(width: 6),
                _infoChip(p.category, Icons.category, Colors.teal),
                if (p.riskLevel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _infoChip(p.riskLevel, Icons.shield, Colors.orange),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // 描述
            if (p.description.isNotEmpty)
              Text(p.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 8),

            // 推荐理由
            if (p.matchReason.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 16, color: Colors.deepPurple.shade400),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(p.matchReason,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.deepPurple.shade700,
                              height: 1.4)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 0.8) return Colors.green.shade700;
    if (score >= 0.6) return Colors.orange.shade700;
    return Colors.grey.shade600;
  }

  Widget _buildPortraitResult(ProfilePortraitResult result) {
    final theme = Theme.of(context);
    final sectionIcons = {
      '画像速写': Icons.dashboard_customize,
      '消费人格': Icons.psychology_alt,
      '数据洞察': Icons.insights,
      '灵感推荐': Icons.auto_awesome,
    };
    final sectionColors = {
      '画像速写': Colors.indigo,
      '消费人格': Colors.deepOrange,
      '数据洞察': Colors.amber.shade700,
      '灵感推荐': Colors.teal,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_pin, color: Colors.teal, size: 22),
            const SizedBox(width: 8),
            Text('用户性格画像',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('生成时间: ${result.generatedAt} · 模型: ${result.modelUsed}',
                style: theme.textTheme.bodySmall),
            if (result.privacyMasked) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield, size: 12, color: Colors.blue.shade600),
                    const SizedBox(width: 3),
                    Text('隐私保护',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // 各板块
        ...result.sections.asMap().entries.map((entry) {
          final i = entry.key;
          final section = entry.value;
          final icon = sectionIcons[section.title] ?? Icons.article_outlined;
          final color =
              sectionColors[section.title] ?? Colors.grey.shade700;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 18, color: color),
                            const SizedBox(width: 6),
                            Text(section.title,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: color)),
                          ],
                        ),
                      ),
                      if (i == 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('画像数据由 AI 生成',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.indigo.shade400)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildSectionContent(section.content, color, section.title),
                  // 详情分析入口
                  if (section.hasDetail) ...[
                    const SizedBox(height: 8),
                    _buildDetailToggle(section, color),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 根据板块类型渲染内容：标签/Chip 或 文本
  Widget _buildSectionContent(String content, Color color, String sectionTitle) {
    // 数据洞察板块：按换行拆分，每条独立一行卡片
    if (sectionTitle == '数据洞察') {
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length <= 1) {
        return _buildTagCloud(content, color);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          final parts = line.split(':');
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                if (parts.length >= 2) ...[
                  Text(parts[0].trim(),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(parts.sublist(1).join(':').trim(),
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  ),
                ] else
                  Expanded(
                    child: Text(line.trim(),
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  ),
              ],
            ),
          );
        }).toList(),
      );
    }

    // 其他板块：标签云
    return _buildTagCloud(content, color);
  }

  /// 将 · 或 , 分隔的内容渲染为 Chip 标签云
  Widget _buildTagCloud(String content, Color color) {
    final tags = content
        .split(RegExp(r'[·,，]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (tags.isEmpty) {
      return Text(content, style: const TextStyle(fontSize: 14, height: 1.6));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.map((tag) {
        // 检查是否是点睛句（不含标签特征的短句）
        final isHighlight = !RegExp(r'[%：:·/kK万元笔次]').hasMatch(tag) && tag.length <= 18;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isHighlight
                ? color.withValues(alpha: 0.12)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlight
                  ? color.withValues(alpha: 0.25)
                  : Colors.grey.shade300,
            ),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 13,
              color: isHighlight ? color : Colors.grey.shade700,
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 可展开的详情分析区域
  Widget _buildDetailToggle(PortraitSection section, Color color) {
    final key = '${section.title}';
    final isExpanded = _expandedDetails[key] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expandedDetails[key] = !isExpanded),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  isExpanded ? '收起详情' : '详情分析',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey('detail_$key'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: color.withValues(alpha: 0.4), width: 3),
                ),
              ),
              child: Text(
                section.detail,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ========== 用户性格画像进度弹窗 ==========

class _MatchingProgressDialog extends StatefulWidget {
  final String userName;
  final void Function(ProductMatchResult result) onDone;
  final void Function(String msg) onError;

  const _MatchingProgressDialog({
    required this.userName,
    required this.onDone,
    required this.onError,
  });

  @override
  State<_MatchingProgressDialog> createState() =>
      _MatchingProgressDialogState();
}

class _MatchingProgressDialogState extends State<_MatchingProgressDialog> {
  Map<String, dynamic>? _progress;
  String? _errorMsg;
  Timer? _timer;

  // 步骤定义
  static const _steps = [
    {"id": "checking_tags", "label": "检查用户标签", "icon": Icons.label},
    {"id": "generating_tags", "label": "AI 正在生成用户标签", "icon": Icons.auto_awesome,
     "detail": "分析消费数据，提取用户画像标签..."},
    {"id": "checking_risk", "label": "检查风险评估等级", "icon": Icons.security},
    {"id": "loading_products", "label": "加载银行产品库", "icon": Icons.inventory_2},
    {"id": "matching", "label": "AI 正在智能匹配产品", "icon": Icons.psychology,
     "detail": "根据用户标签和风评，从银行产品库中匹配最合适的产品..."},
    {"id": "ranking", "label": "排序推荐结果", "icon": Icons.format_list_numbered},
    {"id": "done", "label": "匹配完成", "icon": Icons.check_circle},
  ];

  final Map<String, IconData> _iconMap = {
    for (final s in _steps) s["id"] as String: s["icon"] as IconData,
  };
  final Map<String, String?> _detailMap = {
    for (final s in _steps) s["id"] as String: s["detail"] as String?,
  };

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final res = await ApiClient()
            .get(ApiConfig.productMatchingStatus(widget.userName));
        final data = res.data;
        if (data == null || data['data'] == null) return;

        final progress = data['data'] as Map<String, dynamic>;

        if (!mounted) return;
        setState(() => _progress = progress);

        final status = progress['status'] ?? '';
        if (status == 'done') {
          _timer?.cancel();
          final result = progress['result'];
          if (result != null && result is Map<String, dynamic> &&
              !result.containsKey('error')) {
            final matchResult = ProductMatchResult.fromJson(result);
            Future.delayed(const Duration(milliseconds: 1200), () {
              if (!mounted) return;
              Navigator.of(context).pop();
              widget.onDone(matchResult);
            });
          } else {
            final errMsg = result?['error'] ?? '未知错误';
            setState(() => _errorMsg = errMsg);
            widget.onError(errMsg);
          }
        }
      } catch (_) {
        // 轮询错误忽略
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.psychology, color: Colors.deepPurple, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('AI 正在匹配产品',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          if (_errorMsg != null || p?['status'] == 'done')
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: _buildContent(p),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic>? p) {
    if (_errorMsg != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          const Text('匹配失败',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_errorMsg ?? '未知错误',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      );
    }

    if (p == null) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 20),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在启动 AI 引擎...'),
        ],
      );
    }

    final status = p['status'] ?? '';
    if (status == 'done') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 56, color: Colors.green.shade400),
          const SizedBox(height: 12),
          const Text('匹配完成！',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(p['message'] ?? '',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
      );
    }

    // 进度步骤
    final step = p['step'] ?? 0;
    final totalSteps = p['total_steps'] ?? _steps.length;
    final message = p['message'] ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 当前消息
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade50, Colors.purple.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('第 ${step + 1}/$totalSteps 步',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 步骤列表
        ...List.generate(_steps.length, (index) {
          final s = _steps[index];
          final isActive = index == step;
          final isCompleted = index < step;
          final isPending = index > step;

          IconData icon;
          Color color;
          if (isCompleted) {
            icon = Icons.check_circle;
            color = Colors.green.shade400;
          } else if (isActive) {
            icon = _iconMap[s["id"]] ?? Icons.hourglass_top;
            color = Theme.of(context).colorScheme.primary;
          } else {
            icon = Icons.radio_button_unchecked;
            color = Colors.grey.shade300;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(icon, color: color, size: isActive ? 22 : 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s["label"] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w400,
                            color:
                                isPending ? Colors.grey.shade400 : Colors.black87,
                          )),
                      if (isActive && _detailMap[s["id"]] != null) ...[
                        const SizedBox(height: 2),
                        Text(_detailMap[s["id"]]!,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
                if (isCompleted)
                  Icon(Icons.check, size: 16, color: Colors.green.shade400),
                if (isActive)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ========== 用户性格画像进度弹窗 ==========

class _PortraitProgressDialog extends StatefulWidget {
  final String userName;
  final void Function(ProfilePortraitResult result) onDone;
  final void Function(String msg) onError;

  const _PortraitProgressDialog({
    required this.userName,
    required this.onDone,
    required this.onError,
  });

  @override
  State<_PortraitProgressDialog> createState() =>
      _PortraitProgressDialogState();
}

class _PortraitProgressDialogState extends State<_PortraitProgressDialog> {
  Map<String, dynamic>? _progress;
  String? _errorMsg;
  Timer? _timer;

  static const _steps = [
    {"id": "collecting", "label": "收集消费数据", "icon": Icons.storage},
    {"id": "calling_skill", "label": "调用用户画像 Skill", "icon": Icons.person_search,
     "detail": "Skill 正在从账户、交易流水中提取多维度消费数据..."},
    {"id": "reasoning", "label": "AI 正在生成性格画像", "icon": Icons.psychology,
     "detail": "AI 正在分析消费行为，描绘用户的人生画像与消费人格..."},
    {"id": "masking", "label": "隐私信息屏蔽处理", "icon": Icons.shield,
     "detail": "对商户名称、具体金额、地理位置等敏感信息进行脱敏处理..."},
    {"id": "done", "label": "生成完成", "icon": Icons.check_circle},
  ];

  final Map<String, IconData> _iconMap = {
    for (final s in _steps) s["id"] as String: s["icon"] as IconData,
  };
  final Map<String, String?> _detailMap = {
    for (final s in _steps) s["id"] as String: s["detail"] as String?,
  };

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final res = await ApiClient()
            .get(ApiConfig.portraitStatus(widget.userName));
        final data = res.data;
        if (data == null || data['data'] == null) return;

        final progress = data['data'] as Map<String, dynamic>;

        if (!mounted) return;
        setState(() => _progress = progress);

        final status = progress['status'] ?? '';
        if (status == 'done') {
          _timer?.cancel();
          final result = progress['result'];
          if (result != null && result is Map<String, dynamic> &&
              !result.containsKey('error')) {
            final portraitResult = ProfilePortraitResult.fromJson(result);
            Future.delayed(const Duration(milliseconds: 1200), () {
              if (!mounted) return;
              Navigator.of(context).pop();
              widget.onDone(portraitResult);
            });
          } else {
            final errMsg = result?['error'] ?? '未知错误';
            setState(() => _errorMsg = errMsg);
            widget.onError(errMsg);
          }
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.person_pin, color: Colors.teal, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('AI 正在生成性格画像',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          if (_errorMsg != null || p?['status'] == 'done')
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: _buildContent(p),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic>? p) {
    if (_errorMsg != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          const Text('画像生成失败',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_errorMsg ?? '未知错误',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      );
    }

    if (p == null) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 20),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在启动 AI 引擎...'),
        ],
      );
    }

    final status = p['status'] ?? '';
    if (status == 'done') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 56, color: Colors.green.shade400),
          const SizedBox(height: 12),
          const Text('画像生成完成！',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(p['message'] ?? '',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
      );
    }

    final step = p['step'] ?? 0;
    final totalSteps = p['total_steps'] ?? _steps.length;
    final message = p['message'] ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade50, Colors.cyan.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('第 ${step + 1}/$totalSteps 步',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(_steps.length, (index) {
          final s = _steps[index];
          final isActive = index == step;
          final isCompleted = index < step;
          final isPending = index > step;

          IconData icon;
          Color color;
          if (isCompleted) {
            icon = Icons.check_circle;
            color = Colors.green.shade400;
          } else if (isActive) {
            icon = _iconMap[s["id"]] ?? Icons.hourglass_top;
            color = Theme.of(context).colorScheme.primary;
          } else {
            icon = Icons.radio_button_unchecked;
            color = Colors.grey.shade300;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(icon, color: color, size: isActive ? 22 : 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s["label"] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w400,
                            color:
                                isPending ? Colors.grey.shade400 : Colors.black87,
                          )),
                      if (isActive && _detailMap[s["id"]] != null) ...[
                        const SizedBox(height: 2),
                        Text(_detailMap[s["id"]]!,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
                if (isCompleted)
                  Icon(Icons.check, size: 16, color: Colors.green.shade400)
                else if (isActive)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
