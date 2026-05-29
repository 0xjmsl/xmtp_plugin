// Smoke test: the lab screen builds and shows its first section + log panel.
// (Lower cards live in a scroll view and aren't laid out in the test viewport,
// so we assert on what's on-screen at first paint.)

import 'package:flutter_test/flutter_test.dart';

import 'package:db_key_lab/main.dart';

void main() {
  testWidgets('Lab screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const DbKeyLabApp());
    await tester.pump();

    expect(find.text('XMTP DB Key Lab'), findsOneWidget);
    expect(find.text('1. Keys (generate / export / import)'), findsOneWidget);
    expect(find.text('Gen identity'), findsOneWidget);
    expect(find.text('Gen DB key'), findsOneWidget);
    expect(find.text('LOG'), findsOneWidget);
  });
}
