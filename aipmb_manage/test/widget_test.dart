import 'package:flutter_test/flutter_test.dart';
import 'package:aipmb_manage/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AipmbManageApp());
  });
}