/// 手机银行用户模型
class AppUser {
  final String phone;
  final String name;
  final String createdAt;

  const AppUser({
    required this.phone,
    required this.name,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        phone: json['phone'] as String? ?? '',
        name: json['name'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'name': name,
        'created_at': createdAt,
      };

  /// 是否为有效登录用户
  bool get isLoggedIn => phone.isNotEmpty && name.isNotEmpty;

  /// 用户名首字（用于头像展示）
  String get initial => name.isNotEmpty ? name[0] : '?';
}
