import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dsu_notifier/main.dart';

void main() {
  testWidgets('shows notice list and notification test action', (tester) async {
    await tester.pumpWidget(const DsuNotifierApp());
    await tester.pumpAndSettle();
    expect(find.text('오늘의 공지'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('수강신청 안내'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('수강신청 안내'), findsOneWidget);
    expect(find.text('테스트'), findsOneWidget);
  });
}
