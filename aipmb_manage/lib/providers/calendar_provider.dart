import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aipmb_manage/models/calendar_event.dart';
import 'package:aipmb_manage/services/api_client.dart';
import 'package:aipmb_manage/config/api_config.dart';

final calendarProvider = FutureProvider.family<MemorialCalendar?, String>((ref, name) async {
  try {
    final res = await ApiClient().get(ApiConfig.calendar(name));
    return MemorialCalendar.fromJson(res.data['data']);
  } catch (_) {
    return null;
  }
});