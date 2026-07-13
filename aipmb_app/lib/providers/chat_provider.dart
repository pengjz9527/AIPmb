import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_app/models/chat_message.dart';
import 'package:aipmb_app/models/thinking_step.dart';
import 'package:aipmb_app/models/suggestion.dart';
import 'package:aipmb_app/services/api_client.dart';
import 'package:aipmb_app/services/websocket_service.dart';
import 'package:aipmb_app/config/api_config.dart';
import 'package:aipmb_app/providers/auth_provider.dart';

final webSocketProvider = Provider<WebSocketService>((ref) => WebSocketService());

/// 建议响应式存储 — UI 直接 watch 即可刷新
final suggestionsProvider = StateProvider<Map<String, List<NextSuggestion>>>((ref) => {});

final chatMessagesProvider = StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
  return ChatMessagesNotifier(ref.read(webSocketProvider), ref);
});

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final WebSocketService _ws;
  final Ref _ref;
  StreamSubscription<WsEvent>? _subscription;
  String _streamingContent = '';
  String? _currentMsgId;
  List<ThinkingStep> _pendingThinkingSteps = [];
  String _reasoningBuffer = '';

  /// 全局稳定的会话 ID，App 生命周期内不变，确保连续对话上下文保持
  final String _sessionId = 'mobile_${DateTime.now().millisecondsSinceEpoch}';
  bool _sessionConnected = false;

  /// 存储每条 AI 消息的建议（以消息 ID 为 key）
  final Map<String, List<NextSuggestion>> _suggestionsMap = {};

  /// 当前活跃 Agent
  String? _activeAgentId;
  String get activeAgentId => _activeAgentId ?? 'general_assistant';
  String? _activeAgentName;
  String get activeAgentName => _activeAgentName ?? '小易';

  /// 动态获取当前登录用户名（用于长期记忆关联）
  String get _userName {
    final auth = _ref.read(authProvider);
    return auth.asData?.value?.name ?? '';
  }

  /// 流式响应完成回调，用于 UI 层重置 streaming 状态
  void Function()? onStreamingDone;

  String get sessionId => _sessionId;
  bool get isSessionConnected => _sessionConnected;

  ChatMessagesNotifier(this._ws, this._ref) : super([]) {
    _subscription = _ws.events.listen(_handleEvent);
  }

  String? _currentStepName;

  /// 获取当前正在执行的思考步骤名称
  String? get currentStepName => _currentStepName;

  void _handleEvent(WsEvent event) {
    switch (event.type) {
      case 'thinking_step':
        final step = ThinkingStep(
          stepId: event.stepId ?? '',
          skillName: event.skillName ?? '',
          displayName: event.displayName ?? event.skillName ?? '',
          message: event.stepMessage ?? '',
          status: event.stepStatus == 'completed'
              ? ThinkingStepStatus.completed
              : event.stepStatus == 'error'
                  ? ThinkingStepStatus.error
                  : ThinkingStepStatus.invoking,
        );
        // Update or add step
        final idx = _pendingThinkingSteps.indexWhere((s) => s.stepId == step.stepId);
        if (idx >= 0) {
          _pendingThinkingSteps[idx] = step;
        } else {
          _pendingThinkingSteps.add(step);
        }
        // 更新当前步骤名称
        if (step.status == ThinkingStepStatus.invoking) {
          _currentStepName = step.displayName.isNotEmpty ? step.displayName : step.skillName;
        }
        break;

      case 'reasoning_chunk':
        _reasoningBuffer += event.content;
        break;

      case 'thinking_done':
        // Thinking phase complete — attach to current message
        _currentStepName = null;
        _attachThinkingToCurrentMessage();
        break;

      case 'agent_changed':
        _activeAgentId = event.changedAgentId;
        _activeAgentName = event.changedAgentName;
        state = [...state]; // 触发 UI 重建以更新 AppBar 标题
        break;

      case 'ai_chunk':
        _streamingContent += event.content;
        if (_currentMsgId != null) {
          // Update existing streaming message
          state = [
            for (final m in state)
              if (m.id == _currentMsgId)
                ChatMessage(
                  id: m.id,
                  role: ChatRole.assistant,
                  content: _streamingContent,
                  timestamp: m.timestamp,
                  thinkingSteps: m.thinkingSteps,
                  reasoningContent: m.reasoningContent,
                )
              else
                m,
          ];
        } else {
          // First chunk — create the message
          _currentMsgId = DateTime.now().millisecondsSinceEpoch.toString();
          state = [
            ...state,
            ChatMessage(
              id: _currentMsgId!,
              role: ChatRole.assistant,
              content: _streamingContent,
              timestamp: DateTime.now(),
              thinkingSteps: List.from(_pendingThinkingSteps),
              reasoningContent: _reasoningBuffer.isNotEmpty ? _reasoningBuffer : null,
            ),
          ];
        }
        break;

      case 'ai_done':
        // Finalize — attach remaining thinking steps
        _attachThinkingToCurrentMessage();
        // Store next_suggestions
        if (_currentMsgId != null && event.nextSuggestions.isNotEmpty) {
          _suggestionsMap[_currentMsgId!] = event.nextSuggestions
              .map((s) => NextSuggestion.fromJson(s as Map<String, dynamic>))
              .toList();
          // 更新响应式 suggestionsProvider
          _ref.read(suggestionsProvider.notifier).state = Map.from(_suggestionsMap);
          state = [...state]; // 触发 UI 重建以显示气泡内建议
        }
        _streamingContent = '';
        _pendingThinkingSteps = [];
        _reasoningBuffer = '';
        _currentStepName = null;
        _currentMsgId = null;
        onStreamingDone?.call();
        break;

      case 'error':
        final errorMsg = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: ChatRole.system,
          content: event.content,
          timestamp: DateTime.now(),
        );
        state = [...state, errorMsg];
        _streamingContent = '';
        _pendingThinkingSteps = [];
        _reasoningBuffer = '';
        _currentMsgId = null;
        onStreamingDone?.call();
        break;
    }
  }

  void _attachThinkingToCurrentMessage() {
    if (_currentMsgId != null && _pendingThinkingSteps.isNotEmpty) {
      state = [
        for (final m in state)
          if (m.id == _currentMsgId)
            ChatMessage(
              id: m.id,
              role: m.role,
              content: m.content,
              timestamp: m.timestamp,
              thinkingSteps: List.from(_pendingThinkingSteps),
              reasoningContent: _reasoningBuffer.isNotEmpty ? _reasoningBuffer : null,
            )
          else
            m,
      ];
    }
  }

  void clearMessages() {
    state = [];
    _suggestionsMap.clear();
  }

  /// 获取指定消息的建议列表
  List<NextSuggestion> getSuggestionsFor(String messageId) =>
      _suggestionsMap[messageId] ?? [];

  /// 获取最新一条 AI 消息的建议列表
  List<NextSuggestion> get latestSuggestions {
    for (final msg in state.reversed) {
      if (msg.role == ChatRole.assistant) {
        final suggestions = _suggestionsMap[msg.id];
        if (suggestions != null && suggestions.isNotEmpty) return suggestions;
      }
    }
    return [];
  }

  /// 确保已连接到稳定的会话
  void ensureConnected() {
    if (!_sessionConnected) {
      _ws.connect(_sessionId, userName: _userName);
      _sessionConnected = true;
    }
  }

  void sendMessage(String text, {String? agentId}) {
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: text,
      agentId: agentId,
      timestamp: DateTime.now(),
    );
    state = [...state, msg];
    _ws.send(text, agentId: agentId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ws.dispose();
    _sessionConnected = false;
    super.dispose();
  }
}

final chatSessionsProvider = FutureProvider<List<ChatSession>>((ref) async {
  final api = ApiClient();
  final list = await api.getList(ApiConfig.chatSessions);
  return list.map((e) => ChatSession.fromJson(e as Map<String, dynamic>)).toList();
});