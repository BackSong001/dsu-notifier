import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsu_notifier/main.dart';
import 'package:dsu_notifier/models/notice.dart';

import 'test_fixtures.dart';

void main() {
  final notices = List<Notice>.generate(
    21,
    (index) => makeNotice(title: '공지 $index', number: index + 1),
  );

  testWidgets('renders 19 notices and moves through bottom pagination', (
    tester,
  ) async {
    await tester.pumpWidget(DsuNotifierApp(initialNotices: notices));
    await tester.pumpAndSettle();

    expect(find.text('전체 21건'), findsOneWidget);
    expect(find.text('1 / 2 페이지'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('공지 18'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('공지 18'), findsOneWidget);

    final pageTwo = find.ancestor(
      of: find.text('2'),
      matching: find.byType(OutlinedButton),
    );
    tester.widget<OutlinedButton>(pageTwo).onPressed!();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('공지 19'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('공지 20'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('공지 20'), findsOneWidget);
  });

  testWidgets('searches notices and shows alarm notices from the menu', (
    tester,
  ) async {
    await tester.pumpWidget(DsuNotifierApp(initialNotices: notices));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '공지 20');
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    expect(find.byType(NoticeCard), findsOneWidget);
    expect(find.byType(NoticeCard), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('알람공지'));
    await tester.pumpAndSettle();
    expect(find.text('알람공지'), findsOneWidget);
    expect(find.text('조건에 맞는 공지사항이 없습니다.'), findsOneWidget);
  });

  testWidgets('turns on a board alarm and lists its notices', (tester) async {
    await tester.pumpWidget(DsuNotifierApp(initialNotices: notices));
    await tester.pumpAndSettle();

    expect(find.text('모집'), findsOneWidget);
    expect(find.byTooltip('학사 알림 켜기'), findsOneWidget);
    expect(find.byTooltip('알림 켜기'), findsNothing);
    await tester.tap(find.byTooltip('학사 알림 켜기'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('학사 알림 끄기'), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('알람공지'));
    await tester.pumpAndSettle();

    expect(find.text('공지 0'), findsOneWidget);
    expect(find.text('알림을 설정한 게시판의 공지입니다.'), findsOneWidget);
  });

  testWidgets('opens alarm notices from the app bar button', (tester) async {
    await tester.pumpWidget(DsuNotifierApp(initialNotices: notices));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('알람공지'));
    await tester.pumpAndSettle();

    expect(find.text('알람공지'), findsOneWidget);
    expect(find.text('알림을 설정한 게시판의 공지입니다.'), findsOneWidget);
  });

  testWidgets('keeps pinned notices before newer normal notices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mixedNotices = [
      makeNotice(title: '신규 추가 공지', number: 900),
      makeNotice(
        title: '고정 안내 공지',
        number: null,
        isNotice: true,
        importanceStatus: 'true',
      ),
    ];
    await tester.pumpWidget(DsuNotifierApp(initialNotices: mixedNotices));
    await tester.pumpAndSettle();

    final cards = tester.widgetList<NoticeCard>(find.byType(NoticeCard));
    expect(cards.first.notice.isNotice, isTrue);
    expect(cards.last.notice.title, '신규 추가 공지');
  });
}
