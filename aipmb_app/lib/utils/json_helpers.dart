/// JSON 解析安全工具函数
///
/// 后端 API 返回的数字字段可能是 num（整数/浮点）也可能是 String，
/// 直接调 .toDouble() 在 String 上会抛 NoSuchMethodError。
library;

double parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

int parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}