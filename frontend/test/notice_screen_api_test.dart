import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dsu_notifier/notice_list_screen.dart';
import 'test_fixtures.dart';

void main() {
  testWidgets('renders notices supplied by the backend client', (tester) async {
    final notice = makeNotice();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: NoticeListScreen(notices: [notice]))),
    );

    expect(find.text('Backend에서 받은 공지'), findsOneWidget);
    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('831'), findsOneWidget);
  });
}
