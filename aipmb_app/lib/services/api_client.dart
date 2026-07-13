import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aipmb_app/config/api_config.dart';
import 'dart:convert';

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;

  late Dio _dio;

  ApiClient._() {
    _initDio();
  }

  Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final userName = prefs.getString('login_name') ?? '';
        if (userName.isNotEmpty) {
          // HTTP Header 不支持直接传输 UTF-8 中文，需要进行 URL 编码
          options.headers['x-user-name'] = Uri.encodeComponent(userName);
        }
        handler.next(options);
      },
    ));
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
    return dio;
  }

  void _initDio() {
    _dio = _createDio();
  }

  /// 更新服务器地址并重建 HTTP 客户端（无需重启 APP）
  void updateBaseUrl(String baseUrl) {
    ApiConfig.setBaseUrl(baseUrl);
    _dio.close();
    _initDio();
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters, Duration? timeout}) async {
    Options? options;
    if (timeout != null) {
      options = Options(
        receiveTimeout: timeout,
        sendTimeout: timeout,
      );
    }
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> post(String path, {dynamic data}) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: data);
    return response.data ?? {};
  }

  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? queryParameters}) async {
    final response = await _dio.get<Map<String, dynamic>>(path, queryParameters: queryParameters);
    final data = response.data?['data'];
    if (data is List) return data;
    return [];
  }

  /// Multipart 表单上传（图片/文件）
  Future<Map<String, dynamic>> postMultipart(String path, FormData formData) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
      ),
    );
    return response.data ?? {};
  }
}
