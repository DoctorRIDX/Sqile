import 'package:flutter_test/flutter_test.dart';
import 'package:sqile/main.dart';

void main() {
  testWidgets('Sqile app renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SqileApp());
    expect(find.text('SQILE'), findsOneWidget);
    expect(find.text('Website preview'), findsOneWidget);
  });
}
