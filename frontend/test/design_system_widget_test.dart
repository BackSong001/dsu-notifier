import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsu_notifier/main.dart';
import 'package:dsu_notifier/models/notice.dart';

import 'test_fixtures.dart';

void main() {
  final notices = List<Notice>.generate(
    21,
    (index) =>
        makeNotice(id: 'notice-$index', title: '공지 $index', number: index + 1),
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
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(find.text('공지 18'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('2'),
      100,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
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
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(find.text('공지 20'), findsOneWidget);
  });

  testWidgets('searches notices and opens alarm settings from the menu', (
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
    await tester.tap(find.text('알람설정'));
    await tester.pumpAndSettle();
    expect(find.text('알람설정'), findsOneWidget);
    expect(find.text('알림을 켠 게시판이 없습니다.'), findsOneWidget);
  });

  testWidgets('turns on a board alarm and lists that board', (tester) async {
    await tester.pumpWidget(DsuNotifierApp(initialNotices: notices));
    await tester.pumpAndSettle();

    expect(find.text('모집'), findsOneWidget);
    expect(find.byTooltip('학사 알림 켜기'), findsOneWidget);
    await tester.tap(find.byTooltip('학사 알림 켜기'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('학사 알림 끄기'), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('알람설정'));
    await tester.pumpAndSettle();

    expect(find.text('학사'), findsOneWidget);
    expect(find.text('게시판 전체 알림'), findsOneWidget);
  });

  testWidgets('opens alarm settings from the app bar button', (tester) async {
    await tester.pumpWidget(DsuNotifierApp(initialNotices: notices));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('알람설정'));
    await tester.pumpAndSettle();

    expect(find.text('알람설정'), findsOneWidget);
    expect(find.text('알림을 켠 게시판이 없습니다.'), findsOneWidget);
  });

  testWidgets('keeps cafeteria meal search out of regular notices', (
    tester,
  ) async {
    await tester.pumpWidget(DsuNotifierApp(initialNotices: notices));
    await tester.pumpAndSettle();

    expect(find.text('글로벌빌리지 "식단표" 검색 결과'), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();

    expect(find.text('학식정보'), findsOneWidget);
    expect(find.text('글빌학식'), findsOneWidget);
    expect(find.text('뉴밀학식'), findsOneWidget);
  });

  testWidgets(
    'opens and closes the Global Village meal page without leaving home',
    (tester) async {
      await tester.pumpWidget(DsuNotifierApp(initialNotices: notices));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('학식 메뉴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('글빌학식'));
      await tester.pumpAndSettle();

      expect(find.text('글빌학식'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('동서알리미'), findsOneWidget);
    },
  );

  testWidgets('opens New Millennium URL without popping the home route', (
    tester,
  ) async {
    const channel = MethodChannel('dsu_notifier/native');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(DsuNotifierApp(initialNotices: notices));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('뉴밀학식'));
    await tester.pumpAndSettle();

    expect(find.text('동서알리미'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves a notice with the star and lists it in saved notices', (
    tester,
  ) async {
    await tester.pumpWidget(DsuNotifierApp(initialNotices: notices));
    await tester.pumpAndSettle();

    expect(find.byTooltip('공지 저장'), findsWidgets);
    await tester.tap(find.byTooltip('공지 저장').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('저장 취소'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장된 공지'));
    await tester.pumpAndSettle();

    expect(find.text('저장된 공지'), findsOneWidget);
    expect(find.text('공지 0'), findsOneWidget);
    expect(find.text('별표를 누른 공지만 모아 보여드립니다.'), findsOneWidget);
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
    expect(cards, hasLength(2));
    expect(cards.first.notice.isNotice, isTrue);
    expect(cards.first.notice.title, '고정 안내 공지');
    expect(cards.last.notice.title, '신규 추가 공지');
  });

  testWidgets('resets to the first page when switching boards', (tester) async {
    await tester.pumpWidget(DsuNotifierApp(initialNotices: notices));
    await tester.pumpAndSettle();

    await tester.tap(find.text('공지/행사'));
    await tester.pumpAndSettle();

    expect(find.text('공지/행사 공지사항'), findsOneWidget);
    expect(find.text('1 / 1 페이지'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
}
