// Basic smoke test for the doremi app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:doremi/main.dart';

void main() {
  testWidgets('Home page shows the three stage cards', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MusicMvpApp());

    // The home page header.
    expect(find.text('너두! 도레미!'), findsOneWidget);
    expect(find.text('고양이와 함께 시작하는 음악 탐험'), findsOneWidget);

    // Each learning stage is offered as a card.
    expect(find.text('1단계'), findsOneWidget);
    expect(find.text('2단계'), findsOneWidget);
    expect(find.text('3단계'), findsOneWidget);
  });
}
