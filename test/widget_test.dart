// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stockar/data/repo.dart';
import 'package:stockar/main.dart';

void main() {
  testWidgets('BoutiqueApp smoke test', (WidgetTester tester) async {
    final repo = Repo();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: repo, child: const BoutiqueApp()),
    );
    expect(find.byType(BoutiqueApp), findsOneWidget);
  });
}
