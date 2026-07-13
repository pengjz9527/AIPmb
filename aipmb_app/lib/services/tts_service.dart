import 'package:flutter_tts/flutter_tts.dart';

/// 文字转语音服务（全局单例）
class TtsService {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;

  TtsService._();

  bool get isSpeaking => _isSpeaking;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((msg) => _isSpeaking = false);
    _initialized = true;
  }

  /// 朗读文本，返回 true 表示成功开始播放
  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;
    await _ensureInit();
    await stop();
    final result = await _tts.speak(text);
    if (result == 1) {
      _isSpeaking = true;
      return true;
    }
    return false;
  }

  /// 停止朗读
  Future<void> stop() async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
    }
  }

  /// 暂停朗读
  Future<void> pause() async {
    await _tts.pause();
  }

  void dispose() {
    _tts.stop();
  }
}
