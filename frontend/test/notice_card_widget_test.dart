import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsu_notifier/main.dart';
import 'test_fixtures.dart';

void main() {
  const title = '매우 긴 공지 제목입니다. 수강신청과 졸업에 관한 상세 안내를 반드시 확인해 주세요.';
  for (final pinned in [false, true]) {
    testWidgets(
      'renders a compact ${pinned ? 'pinned' : 'normal'} card with a truncated inline title',
      (tester) async {
        var opened = false;
        var saved = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  child: NoticeCard(
                    notice: makeNotice(
                      title: title,
                      isNotice: pinned,
                      number: pinned ? null : 831,
                    ),
                    saved: false,
                    onTap: () => opened = true,
                    onToggleSaved: () => saved = true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(title),
        );
        expect(paragraph.maxLines, 1);
        expect(paragraph.overflow, TextOverflow.ellipsis);
        expect(paragraph.didExceedMaxLines, isTrue);
        expect(
          tester.getSize(find.byType(NoticeCard)).height,
          lessThanOrEqualTo(120),
        );
        if (pinned) {
          expect(find.byType(IconButton), findsNothing);
          final badge = tester.getRect(find.text('고정 공지'));
          final heading = tester.getRect(find.text(title));
          expect(badge.right, lessThan(heading.left));
          expect((badge.center.dy - heading.center.dy).abs(), lessThan(2));
        } else {
          final button = find.byType(IconButton);
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          await tester.tap(button);
          expect(saved, isTrue);
          expect(opened, isFalse);
        }
        await tester.tap(find.text(title));
        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('hides saved stars on pinned cards and supports enlarged text', (
    tester,
  ) async {
    for (final pinned in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  child: NoticeCard(
                    notice: makeNotice(
                      title: title,
                      isNotice: pinned,
                      number: pinned ? null : 831,
                    ),
                    saved: true,
                    onTap: () {},
                    onToggleSaved: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('저장 취소'), pinned ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
