import 'package:flutter_test/flutter_test.dart';

import 'package:lilly/main.dart';

void main() {
  testWidgets('Lilly app boots', (tester) async {
    await tester.pumpWidget(const VisionChatApp());
    expect(find.text('Preparing Lilly'), findsOneWidget);
  });
}
