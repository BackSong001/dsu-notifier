import 'package:flutter_test/flutter_test.dart';
import 'package:dsu_notifier/api_client.dart';
import 'package:dsu_notifier/models/notice.dart';
import 'test_fixtures.dart';

void main() {
  test('gets notices from the backend and maps API fields', () async {
    final client = NoticeApiClient(
      fetch: (uri) async => noticeResponse(noticeJson()),
    );

    final result = await client.getNotices(boardCode: 'MN2000194');

    expect(result.items, hasLength(1));
    expect(result.items.single, isA<Notice>());
    expect(result.items.single.title, '수강신청 안내');
    expect(result.items.single.viewCount, 1234);
    expect(result.items.single.number, 831);
    expect(result.nextCursor, isNull);
  });

  test('preserves a null number for a pinned notice', () async {
    final client = NoticeApiClient(
      fetch: (uri) async => noticeResponse(
        noticeJson(
          id: 'notice-2',
          sourceIdx: '103600',
          number: null,
          title: '중요 학사 공지',
          isNotice: true,
          importanceStatus: 'true',
        ),
      ),
    );

    final result = await client.getNotices();

    expect(result.items.single.number, isNull);
    expect(result.items.single.importanceStatus, 'true');
  });

  test('gets enabled notice alarm preferences', () async {
    final client = NoticeApiClient(
      fetch: (uri) async => {
        'notice_ids': ['notice-1', 'notice-2'],
      },
    );

    expect(await client.getNoticePreferences('device-1'), {
      'notice-1',
      'notice-2',
    });
  });
}
