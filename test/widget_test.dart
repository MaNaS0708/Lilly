import 'package:flutter_test/flutter_test.dart';

import 'package:lilly/main.dart';

void main() {
  testWidgets('Lilly app boots', (tester) async {
    await tester.pumpWidget(const LillyApp());
    expect(find.text('Choose Voice Languages'), findsOneWidget);
  });
}
