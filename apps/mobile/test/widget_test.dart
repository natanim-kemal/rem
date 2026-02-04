import 'package:flutter_test/flutter_test.dart';
import 'package:rem/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RemApp());
    expect(find.text('REM'), findsOneWidget);
  });
}
