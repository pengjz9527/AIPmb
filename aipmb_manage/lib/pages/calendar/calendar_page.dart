import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/providers/calendar_provider.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';
import 'package:aipmb_manage/models/calendar_gen_progress.dart';
import 'package:aipmb_manage/widgets/timeline_widget.dart';

class CalendarPage extends ConsumerStatefulWidget {
  final String userName;
  const CalendarPage({super.key, required this.userName});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  Timer? _pollTimer;
  bool _isGenerating = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    setState(() => _isGenerating = true);

    try {
      // 启动异步生成
      await ApiClient().post(ApiConfig.generateCalendarAsync(widget.userName));

      if (!mounted) return;

      // 显示进度弹窗
      _showProgressDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('启动生成失败: $e')),
      );
    }
  }

  void _showProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CalendarGeneratingDialog(
        userName: widget.userName,
        onDone: () {
          ref.invalidate(calendarProvider(widget.userName));
          setState(() => _isGenerating = false);
        },
        onError: (msg) {
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('生成失败: $msg')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendarAsync = ref.watch(calendarProvider(widget.userName));

    return Scaffold(
      appBar: AppBar(title: Text('${widget.userName} 纪念日历')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGenerating ? null : _startGeneration,
        icon: _isGenerating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(_isGenerating ? '生成中...' : 'AI 生成日历'),
      ),
      body: calendarAsync.when(
        data: (calendar) {
          if (calendar == null || calendar.events.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无纪念日历',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('点击右下角按钮，让 AI 为你生成\n用户与银行的专属纪念日历',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return TimelineWidget(events: calendar.events);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }
}

/// 日历生成进度弹窗
class _CalendarGeneratingDialog extends StatefulWidget {
  final String userName;
  final VoidCallback onDone;
  final void Function(String msg) onError;

  const _CalendarGeneratingDialog({
    required this.userName,
    required this.onDone,
    required this.onError,
  });

  @override
  State<_CalendarGeneratingDialog> createState() =>
      _CalendarGeneratingDialogState();
}

class _CalendarGeneratingDialogState extends State<_CalendarGeneratingDialog> {
  CalendarGenProgress? _progress;
  String? _errorMsg;
  Timer? _timer;

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
            .get(ApiConfig.calendarStatus(widget.userName));
        final data = res.data;
        if (data == null || data['data'] == null) return;

        final progress =
            CalendarGenProgress.fromJson(data['data'] as Map<String, dynamic>);

        if (!mounted) return;
        setState(() => _progress = progress);

        if (progress.isDone) {
          _timer?.cancel();
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (!mounted) return;
            Navigator.of(context).pop();
            widget.onDone();
          });
        } else if (progress.isError) {
          _timer?.cancel();
          setState(() => _errorMsg = progress.message);
          widget.onError(progress.message);
        }
      } catch (_) {
        // 轮询错误忽略，继续重试
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.orange, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('AI 正在生成纪念日历',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          if (p?.isError == true || p?.isDone == true)
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

  Widget _buildContent(CalendarGenProgress? p) {
    if (_errorMsg != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          const Text('生成失败',
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

    if (p.isDone) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 56, color: Colors.green.shade400),
          const SizedBox(height: 12),
          const Text('生成完成！',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(p.message,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
      );
    }

    // 进度步骤
    final steps = p.steps;
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
              colors: [
                Colors.orange.shade50,
                Colors.amber.shade50,
              ],
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
              Text(p.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('第 ${p.step + 1}/${p.totalSteps} 步',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 步骤列表
        if (steps.isNotEmpty)
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final isActive = index == p.step;
            final isCompleted = index < p.step;
            final isPending = index > p.step;

            IconData icon;
            Color color;
            if (isCompleted) {
              icon = Icons.check_circle;
              color = Colors.green.shade400;
            } else if (isActive) {
              icon = _iconForStep(step.id);
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
                        Text(step.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isActive ? FontWeight.w600 : FontWeight.w400,
                              color:
                                  isPending ? Colors.grey.shade400 : Colors.black87,
                            )),
                        if (isActive && step.detail != null) ...[
                          const SizedBox(height: 2),
                          Text(step.detail!,
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

  IconData _iconForStep(String stepId) {
    switch (stepId) {
      case 'collecting':
        return Icons.storage;
      case 'sampling':
        return Icons.analytics;
      case 'reasoning':
        return Icons.psychology;
      case 'generating':
        return Icons.auto_awesome;
      case 'building':
        return Icons.calendar_month;
      default:
        return Icons.hourglass_top;
    }
  }
}
