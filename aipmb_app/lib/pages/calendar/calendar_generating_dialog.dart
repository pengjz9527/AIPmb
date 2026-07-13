import 'package:flutter/material.dart';
import 'package:aipmb_app/services/calendar_api.dart';
import 'package:aipmb_app/services/api_client.dart';

/// 日历生成进度弹窗 — 全屏展示 AI 生成各步骤
class CalendarGeneratingDialog extends StatefulWidget {
  final String userName;
  final VoidCallback? onDone;
  final VoidCallback? onError;

  const CalendarGeneratingDialog({
    super.key,
    required this.userName,
    this.onDone,
    this.onError,
  });

  @override
  State<CalendarGeneratingDialog> createState() =>
      _CalendarGeneratingDialogState();
}

class _CalendarGeneratingDialogState extends State<CalendarGeneratingDialog>
    with SingleTickerProviderStateMixin {
  final CalendarApi _api = CalendarApi(ApiClient());
  CalendarGenProgress? _progress;
  String? _errorMsg;
  bool _started = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startGeneration();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    setState(() => _started = true);
    try {
      await _api.startGeneration(widget.userName);
      _api.pollUntilDone(
        widget.userName,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
        interval: const Duration(seconds: 1),
      ).then((result) {
        if (!mounted) return;
        if (result != null) {
          _pulseController.stop();
          // 短暂停留让用户看到"完成"，然后关闭
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!mounted) return;
            Navigator.of(context).pop(true);
            widget.onDone?.call();
          });
        } else {
          setState(() => _errorMsg = '生成失败，请稍后重试');
          widget.onError?.call();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = e.toString());
      widget.onError?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('AI 正在生成纪念日历',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            if (_progress?.isError == true || _progress?.isDone == true)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
          ],
        ),
        body: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_started) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMsg != null) {
      return _buildError();
    }

    final p = _progress;
    if (p == null) {
      return _buildWaiting();
    }

    if (p.isDone) {
      return _buildDone(p);
    }

    return _buildSteps(p);
  }

  Widget _buildWaiting() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text('正在启动 AI 引擎...',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text('生成失败',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_errorMsg ?? '未知错误',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDone(CalendarGenProgress p) {
    final eventCount = p.result?['event_count'] ?? 0;
    return Center(
      child: FadeTransition(
        opacity: _pulseAnim,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green.shade400),
            const SizedBox(height: 20),
            const Text('生成完成！',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('共发现 $eventCount 个珍贵的人生时刻',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSteps(CalendarGenProgress p) {
    final steps = p.steps;
    if (steps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(p.message,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 顶部进度消息
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                p.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Text(
                '第 ${p.step + 1}/${p.totalSteps} 步',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),

        // 步骤列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final stepId = step['id'] ?? '';
              final isActive = index == p.step;
              final isCompleted = index < p.step;
              final isPending = index > p.step;

              IconData icon;
              Color color;
              if (isCompleted) {
                icon = Icons.check_circle;
                color = Colors.green.shade400;
              } else if (isActive) {
                icon = _iconForStep(stepId);
                color = Theme.of(context).colorScheme.primary;
              } else {
                icon = Icons.radio_button_unchecked;
                color = Colors.grey.shade300;
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: isActive
                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isActive
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    // 步骤指示器
                    AnimatedScale(
                      duration: const Duration(milliseconds: 300),
                      scale: isActive ? 1.15 : 1.0,
                      child: Icon(icon, color: color, size: isActive ? 26 : 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step['label'] ?? '',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                              color: isPending ? Colors.grey.shade400 : Colors.black87,
                            ),
                          ),
                          if (isActive && step['detail'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              step['detail'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isCompleted)
                      Icon(Icons.check, size: 18, color: Colors.green.shade400)
                    else if (isActive)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
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
