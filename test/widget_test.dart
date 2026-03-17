import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunch_lucky/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: LunchLuckyApp()));

    // Verify that the title is present.
    expect(find.text('Lunch-Luckvicky'), findsWidgets);
  });
}
