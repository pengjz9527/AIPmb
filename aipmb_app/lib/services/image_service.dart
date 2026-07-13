import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aipmb_app/services/api_client.dart';
import 'package:aipmb_app/config/api_config.dart';

/// 图片选择和上传服务
class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// 从相册选择图片
  Future<XFile?> pickFromGallery() async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
  }

  /// 拍照
  Future<XFile?> pickFromCamera() async {
    return _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
  }

  /// 上传图片到服务器
  Future<String?> uploadImage(XFile imageFile) async {
    final api = ApiClient();
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.name,
        ),
      });

      final response = await api.postMultipart(
        ApiConfig.uploadImage,
        formData,
      );

      return response['data']?['url'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// 获取图片文件（用于预览）
  File? getFile(XFile? xFile) {
    if (xFile == null) return null;
    return File(xFile.path);
  }
}

/// 需要在 api_config.dart 中添加:
/// static const String uploadImage = '/api/v1/upload/image';
