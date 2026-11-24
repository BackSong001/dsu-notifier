import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_fixtures.dart';
import 'package:dsu_notifier/main.dart';

void main() {
  testWidgets('shows a dashboard with five latest notices and shortcuts', (
    tester,
  ) async {
    final notices = List.generate(
      6,
      (index) => makeNotice(
        id: 'notice-$index',
        title: '최근 공지 $index',
        boardCode: index.isEven ? 'MN2000194' : 'MN2000191',
        boardName: index.isEven ? '학사' : '공지/행사',
        publishedAt: '2026-11-${(index + 10).toString().padLeft(2, '0')}',
      ),
    );
    notices[0] = makeNotice(
      id: 'failed-pin',
      title: '사라진 고정 공지',
      isNotice: true,
      importanceStatus: 'failed',
      publishedAt: '2026-11-20',
    );
    await tester.pumpWidget(DsuNotifierApp(initialNotices: notices));
    await tester.pumpAndSettle();

    expect(find.text('학교 소식과 학식을 한눈에'), findsOneWidget);
    expect(find.text('공지사항 전체 보기'), findsOneWidget);
    expect(find.text('글빌학식'), findsOneWidget);
    expect(find.text('알람설정'), findsOneWidget);
    expect(find.text('최근 공지'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('최근 공지 1'),
      300,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    for (var index = 1; index <= 5; index++) {
      expect(find.text('최근 공지 $index'), findsOneWidget);
    }
    expect(find.text('최근 공지 0'), findsNothing);
    expect(find.text('사라진 고정 공지'), findsNothing);
  });

  testWidgets('opens all-board alarm settings from the dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      DsuNotifierApp(initialNotices: [makeNotice(title: '홈 공지')]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('알람설정'));
    await tester.pumpAndSettle();

    expect(find.text('게시판별 새 공지 알림을 설정하세요.'), findsOneWidget);
    expect(find.text('학사'), findsOneWidget);
    expect(find.text('공지/행사'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsWidgets);
  });
}
