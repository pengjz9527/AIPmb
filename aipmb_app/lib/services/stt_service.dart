import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// 语音识别服务（全局单例）
class SttService {
  static final SttService _instance = SttService._();
  factory SttService() => _instance;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _isListening = false;
  String _localeId = '';

  /// 识别结果回调
  void Function(String text)? onResult;
  /// 错误回调
  void Function(String error)? onError;
  /// 状态变化回调
  void Function(bool listening)? onStatusChanged;

  SttService._();

  bool get isListening => _isListening;
  bool get isAvailable => _speech.isAvailable;

  /// 初始化语音识别，返回是否可用
  Future<bool> init() async {
    if (_initialized) return _speech.isAvailable;

    _initialized = await _speech.initialize(
      onStatus: (status) {
        final listening = status == 'listening';
        if (listening != _isListening) {
          _isListening = listening;
          onStatusChanged?.call(listening);
        }
      },
      onError: (error) {
        _isListening = false;
        onStatusChanged?.call(false);
        onError?.call(_errorMessage(error.errorMsg));
      },
    );

    if (_initialized) {
      // 优先使用系统当前语言，回退到中文检测
      final sysLocale = await _speech.systemLocale();
      final sysId = sysLocale?.localeId ?? '';
      if (sysId.startsWith('zh')) {
        _localeId = sysId;
      } else {
        // 检查 zh_CN 是否已安装
        final locales = await _speech.locales();
        final zhLocale = locales.firstWhere(
          (l) => l.localeId.startsWith('zh'),
          orElse: () => stt.LocaleName('', ''),
        );
        _localeId = zhLocale.localeId.isNotEmpty ? zhLocale.localeId : '';
      }
    }

    return _initialized;
  }

  /// 开始监听
  Future<void> startListening() async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) {
        onError?.call('设备不支持语音识别或未授权麦克风');
        return;
      }
    }

    _isListening = true;
    onStatusChanged?.call(true);
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _isListening = false;
          onStatusChanged?.call(false);
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            onResult?.call(words);
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      localeId: _localeId.isNotEmpty ? _localeId : null,
      listenOptions: stt.SpeechListenOptions(
        autoPunctuation: true,
      ),
    );
  }

  /// 停止监听
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      onStatusChanged?.call(false);
    }
  }

  /// 将 sst 原生错误信息转为用户可读中文提示
  String _errorMessage(String raw) {
    switch (raw) {
      case 'error-network':
        return '语音服务连接失败（需联网且安装 Google 语音服务）';
      case 'error-no-match':
        return '未识别到语音，请重新说一遍';
      case 'error-audio':
        return '麦克风异常，请检查权限';
      case 'error-recognizer-busy':
        return '语音服务忙，请稍后重试';
      default:
        return '语音识别异常: $raw';
    }
  }
}
