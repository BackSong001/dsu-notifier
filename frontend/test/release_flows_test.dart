import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsu_notifier/main.dart';
import 'package:dsu_notifier/api_client.dart';
import 'test_fixtures.dart';

Future<void> openNotices(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('공지사항').first);
  await tester.pumpAndSettle();
}

class FakeClient extends NoticeApiClient {
  bool fail = false;
  @override
  Future<NoticePage> getNotices({
    String? boardCode,
    int limit = 20,
    String? cursor,
    String? search,
  }) async {
    if (fail) throw Exception('HTTP_ERROR');
    return NoticePage(items: [makeNotice(title: '실제 목록')], nextCursor: null);
  }

  @override
  Future<NoticePage> getSavedNotices(
    String deviceId, {
    int limit = 19,
    String? cursor,
    String? search,
  }) async => NoticePage(
    items: [makeNotice(id: 'old', title: '오래된 저장 공지')],
    nextCursor: null,
  );
  @override
  Future<Map<String, bool>> getPreferences(String deviceId) async => {};
  @override
  Future<Set<String>> getNoticePreferences(String deviceId) async => {'old'};
}

class DelayedPreferencesClient extends FakeClient {
  final preferences = Completer<Set<String>>();
  @override
  Future<Set<String>> getNoticePreferences(String deviceId) =>
      preferences.future;
}

void main() {
  testWidgets('returns from alarm settings and fetches old saved notices', (
    tester,
  ) async {
    final client = FakeClient();
    await tester.pumpWidget(
      DsuNotifierApp(client: client, deviceId: 'test-device'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('알람설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장된 공지'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('오래된 저장 공지'), findsOneWidget);
  });
  testWidgets('shows API error and retries without sample notices', (
    tester,
  ) async {
    final client = FakeClient()..fail = true;
    await tester.pumpWidget(DsuNotifierApp(client: client));
    await tester.pumpAndSettle();
    await openNotices(tester);
    expect(find.textContaining('HTTP_ERROR'), findsOneWidget);
    expect(find.text('수강신청 안내'), findsNothing);
    client.fail = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('실제 목록'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('공지 저장'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('blocks writes until preferences are restored', (tester) async {
    final client = DelayedPreferencesClient();
    await tester.pumpWidget(
      DsuNotifierApp(client: client, deviceId: 'test-device'),
    );
    await tester.pumpAndSettle();
    await openNotices(tester);
    final button = find.ancestor(
      of: find.byTooltip('공지 저장'),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(button).onPressed, isNull);
    client.preferences.complete({});
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(button).onPressed, isNotNull);
  });

  testWidgets(
    'small screen with enlarged text and keyboard remains scrollable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(DsuNotifierApp(client: FakeClient()));
      await tester.pumpAndSettle();
      await openNotices(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
