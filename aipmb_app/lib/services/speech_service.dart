import 'dart:async';

/// 语音识别服务 (Stub — 待集成 speech_to_text 插件)
class SpeechService {
  final _resultController = StreamController<String>.broadcast();
  final _finalController = StreamController<String>.broadcast();

  bool _isInitialized = false;
  bool _isListening = false;

  /// 实时识别结果流
  Stream<String> get onResult => _resultController.stream;

  /// 最终识别结果流
  Stream<String> get onFinalResult => _finalController.stream;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  /// 初始化语音识别
  Future<bool> initialize() async {
    // TODO: 集成 speech_to_text 插件后实现
    _isInitialized = false;
    return false;
  }

  /// 开始录音识别
  Future<void> startListening({String locale = 'zh-CN'}) async {
    // TODO: 集成 speech_to_text 插件后实现
    _isListening = false;
  }

  /// 停止录音
  Future<void> stopListening() async {
    _isListening = false;
  }

  void dispose() {
    _resultController.close();
    _finalController.close();
  }
}
