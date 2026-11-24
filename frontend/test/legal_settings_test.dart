import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsu_notifier/main.dart';
import 'package:dsu_notifier/settings_page.dart';

void main() {
  testWidgets('opens offline policies through settings without a login', (
    tester,
  ) async {
    await tester.pumpWidget(const DsuNotifierApp(initialNotices: []));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    expect(find.text('약관 및 정책'), findsOneWidget);
    expect(find.textContaining('공식 앱이 아닙니다'), findsOneWidget);
    for (final title in ['개인정보처리방침', '서비스 이용약관', '데이터 삭제 및 권리 행사']) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(find.textContaining('2026-11-18'), findsOneWidget);
      expect(find.textContaining('jhgu2014@gmail.com'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('학교 소식과 학식을 한눈에'), findsOneWidget);
  });

  testWidgets(
    'copies a deletion request with only the public installation ID',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            copied = (call.arguments as Map)['text'] as String;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(home: SettingsPage(deviceId: 'test-installation')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('삭제 요청 내용 복사'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('삭제 요청 내용 복사'));
      await tester.pumpAndSettle();
      expect(copied, contains('test-installation'));
      expect(copied, contains('jhgu2014@gmail.com'));
      expect(copied, isNot(contains('secret')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('supports large text on a narrow settings screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const SettingsPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('문의 및 데이터 삭제 요청'), 200);
    expect(tester.takeException(), isNull);
  });
}
