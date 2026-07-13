import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aipmb_app/models/risk_assessment.dart';
import 'package:aipmb_app/providers/risk_assessment_provider.dart';

/// 风险测评问卷数据
class _Question {
  final String title;
  final List<String> options;
  const _Question({required this.title, required this.options});
}

/// 10 道测评题
const _questions = [
  _Question(
    title: '1. 您的年龄段是？',
    options: ['A. 60岁以上', 'B. 50-59岁', 'C. 40-49岁', 'D. 30-39岁', 'E. 18-29岁'],
  ),
  _Question(
    title: '2. 您的投资经验年限？',
    options: ['A. 无投资经验', 'B. 1年以内', 'C. 1-3年', 'D. 3-5年', 'E. 5年以上'],
  ),
  _Question(
    title: '3. 您对金融产品的了解程度？',
    options: ['A. 完全不了解', 'B. 了解一点', 'C. 一般了解', 'D. 比较了解', 'E. 非常了解'],
  ),
  _Question(
    title: '4. 您家庭收入来源的稳定性？',
    options: ['A. 无稳定收入', 'B. 不太稳定', 'C. 一般稳定', 'D. 比较稳定', 'E. 非常稳定'],
  ),
  _Question(
    title: '5. 您计划投资的资产占家庭总资产的比例？',
    options: ['A. 小于5%', 'B. 5%-10%', 'C. 10%-25%', 'D. 25%-50%', 'E. 大于50%'],
  ),
  _Question(
    title: '6. 您愿意承担的投资风险水平？',
    options: ['A. 保本最重要，不愿承担任何风险', 'B. 低风险，接受较小波动', 'C. 中等风险，追求稳健增长', 'D. 较高风险，接受较大波动', 'E. 高风险高收益，追求最大回报'],
  ),
  _Question(
    title: '7. 您的主要投资目标是？',
    options: ['A. 资产保值，跑赢存款利率', 'B. 跑赢通货膨胀', 'C. 稳健增值', 'D. 资产较快增长', 'E. 追求最大回报'],
  ),
  _Question(
    title: '8. 如果您的投资出现20%的亏损，您会？',
    options: ['A. 全部卖出，不再投资', 'B. 卖出一部分，减少损失', 'C. 观望等待市场回暖', 'D. 追加投资摊低成本', 'E. 大幅追加投资'],
  ),
  _Question(
    title: '9. 您的预期投资期限是？',
    options: ['A. 少于1年', 'B. 1-3年', 'C. 3-5年', 'D. 5-10年', 'E. 10年以上'],
  ),
  _Question(
    title: '10. 您对投资资金流动性的要求？',
    options: ['A. 随时需要取用', 'B. 1个月内可能需要', 'C. 3个月内可能需要', 'D. 6个月内可能需要', 'E. 1年以上不需要'],
  ),
];

/// 根据总分计算风险等级
String _calculateLevel(int totalScore) {
  if (totalScore <= 20) return 'C1';
  if (totalScore <= 30) return 'C2';
  if (totalScore <= 38) return 'C3';
  if (totalScore <= 45) return 'C4';
  return 'C5';
}

class RiskAssessmentPage extends ConsumerStatefulWidget {
  final String userName;

  const RiskAssessmentPage({super.key, required this.userName});

  @override
  ConsumerState<RiskAssessmentPage> createState() => _RiskAssessmentPageState();
}

class _RiskAssessmentPageState extends ConsumerState<RiskAssessmentPage> {
  final _pageController = PageController();
  int _currentPage = 0;
  final _answers = List.filled(10, 0); // 每题分值 1-5，0 表示未作答
  bool _submitting = false;

  /// 当前页面是否已作答
  bool get _currentAnswered => _answers[_currentPage] > 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectOption(int score) {
    setState(() {
      _answers[_currentPage] = score;
    });
  }

  void _goToPage(int page) {
    if (page >= 0 && page < 10) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goNext() {
    if (_currentPage < 9) {
      _goToPage(_currentPage + 1);
    }
  }

  void _goPrev() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
  }

  bool get _allAnswered => _answers.every((a) => a > 0);

  Future<void> _submit() async {
    if (!_allAnswered || _submitting) return;

    setState(() => _submitting = true);

    final totalScore = _answers.fold(0, (a, b) => a + b);
    final level = _calculateLevel(totalScore);
    final now = DateTime.now();
    final expiry = now.add(const Duration(days: 365));
    final expiryStr =
        '${expiry.year}/${expiry.month.toString().padLeft(2, '0')}/${expiry.day.toString().padLeft(2, '0')}';

    try {
      final result = await submitRiskAssessment(
        userName: widget.userName,
        riskLevel: level,
        expiryDate: expiryStr,
      );

      if (result['code'] == 0) {
        ref.invalidate(riskAssessmentProvider);
        if (mounted) {
          // 显示结果弹窗
          _showResultDialog(level, totalScore, expiryStr);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('提交失败: ${result['message'] ?? '未知错误'}')),
          );
          setState(() => _submitting = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e')),
        );
        setState(() => _submitting = false);
      }
    }
  }

  void _showResultDialog(String level, int totalScore, String expiryStr) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
            const SizedBox(width: 8),
            const Text('测评完成', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('您的投资风险测评结果：', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Text(
                    level,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    RiskAssessment.levelLabel(level),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('测评得分：$totalScore / 50', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text('有效期至：$expiryStr', style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.pop();
            },
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('投资风险测评'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // 进度条
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Text(
                  '${_currentPage + 1} / 10',
                  style: TextStyle(fontSize: 14, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentPage + 1) / 10,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 题目区域
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemCount: 10,
              itemBuilder: (context, index) {
                final q = _questions[index];
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),
                      ...List.generate(5, (i) {
                        final score = i + 1; // A=1, B=2, C=3, D=4, E=5
                        final isSelected = _answers[index] == score;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => _selectOption(score),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                color: isSelected
                                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : Colors.grey.shade400,
                                        width: isSelected ? 2 : 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Center(
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      q.options[i],
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isSelected ? theme.colorScheme.primary : null,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),

          // 底部导航按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  // 上一题
                  if (_currentPage > 0)
                    OutlinedButton(
                      onPressed: _goPrev,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: const Text('上一题'),
                    ),
                  const Spacer(),
                  // 进度圆点
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(10, (i) {
                      final answered = _answers[i] > 0;
                      final isCurrent = i == _currentPage;
                      return Container(
                        width: isCurrent ? 10 : 8,
                        height: isCurrent ? 10 : 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: answered
                              ? theme.colorScheme.primary
                              : isCurrent
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade300,
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  // 下一题 / 提交
                  if (_currentPage < 9)
                    FilledButton(
                      onPressed: _currentAnswered ? _goNext : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: const Text('下一题'),
                    )
                  else
                    FilledButton(
                      onPressed: _allAnswered && !_submitting ? _submit : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('提交测评'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
