import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:aipmb_app/config/api_config.dart';

/// WebSocket 消息事件
class WsEvent {
  final String type; // 'ai_chunk', 'ai_done', 'error', 'thinking_step', 'reasoning_chunk', 'thinking_done', 'agent_changed'
  final String content;
  final Map<String, dynamic>? agent;
  final List<dynamic> cards;
  final bool isFinal;
  // thinking 相关
  final String? stepId;
  final String? skillName;
  final String? displayName;
  final String? stepStatus;
  final String? stepMessage;
  // 建议 相关
  final List<dynamic> nextSuggestions;
  // Agent 切换相关
  final String? changedAgentId;
  final String? changedAgentName;

  const WsEvent({
    required this.type,
    required this.content,
    this.agent,
    this.cards = const [],
    this.isFinal = false,
    this.stepId,
    this.skillName,
    this.displayName,
    this.stepStatus,
    this.stepMessage,
    this.nextSuggestions = const [],
    this.changedAgentId,
    this.changedAgentName,
  });
}

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<WsEvent>? _eventController;
  bool _isConnected = false;

  Stream<WsEvent> get events {
    _eventController ??= StreamController<WsEvent>.broadcast();
    return _eventController!.stream;
  }

  bool get isConnected => _isConnected;

  void connect(String sessionId, {String? userName}) {
    if (_isConnected) disconnect();

    // 确保 StreamController 可用（可能之前被关闭）
    _eventController ??= StreamController<WsEvent>.broadcast();

    // 构建带 query 参数的 URI，传递 userName 用于长期记忆关联
    String wsPath = '${ApiConfig.chatWs}/$sessionId';
    if (userName != null && userName.isNotEmpty) {
      wsPath += '?user_name=${Uri.encodeComponent(userName)}';
    }
    final uri = Uri.parse('${ApiConfig.wsUrl}$wsPath');
    _channel = WebSocketChannel.connect(uri);
    _isConnected = true;

    _channel!.stream.listen(
      (data) {
        try {
          final decoded = jsonDecode(data as String);
          final type = decoded['type'] ?? 'ai_chunk';
          final content = decoded['content'] ?? '';
          final agent = decoded['agent'] as Map<String, dynamic>?;
          final cards = decoded['cards'] as List<dynamic>? ?? [];
          final nextSuggestions = (decoded['next_suggestions'] as List<dynamic>?) ?? [];
          final changedAgentId = type == 'agent_changed'
              ? (decoded['agent_id'] as String?)
              : null;
          final changedAgentName = type == 'agent_changed'
              ? (decoded['agent_name'] as String?)
              : null;

          _eventController?.sink.add(WsEvent(
            type: type,
            content: content,
            agent: agent,
            cards: cards,
            isFinal: decoded['is_final'] == true,
            stepId: decoded['step_id'] as String?,
            skillName: decoded['skill_name'] as String?,
            displayName: decoded['display_name'] as String?,
            stepStatus: decoded['status'] as String?,
            stepMessage: decoded['message'] as String?,
            nextSuggestions: nextSuggestions,
            changedAgentId: changedAgentId,
            changedAgentName: changedAgentName,
          ));
        } catch (e) {
          _eventController?.sink.add(WsEvent(
            type: 'error',
            content: '解析消息失败: $e',
          ));
        }
      },
      onDone: () {
        _isConnected = false;
      },
      onError: (error) {
        _isConnected = false;
        _eventController?.sink.add(WsEvent(
          type: 'error',
          content: 'WebSocket连接错误: $error',
        ));
      },
    );
  }

  void send(String message, {String? agentId}) {
    if (!_isConnected || _channel == null) return;
    final payload = jsonEncode({
      'content': message,
      'content_type': 'text',
      if (agentId != null) 'agent_id': agentId,
    });
    _channel!.sink.add(payload);
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }

  /// 仅断开连接，不关闭 StreamController（因为 Service 是全局单例）
  void dispose() {
    disconnect();
    // 注意：不关闭 _eventController，因为 WebSocketService 是全局单例
    // 多个 ChatMessagesNotifier 实例可能共享同一个 Service
  }
}
