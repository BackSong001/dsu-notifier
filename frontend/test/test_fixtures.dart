import 'package:dsu_notifier/models/notice.dart';

Map<String, dynamic> noticeJson({
  String id = 'notice-1',
  String sourceIdx = '103653',
  int? number = 831,
  String title = '수강신청 안내',
  String boardCode = 'MN2000194',
  String boardName = '학사',
  String publishedAt = '2026-10-29',
  bool isNotice = false,
  String? importanceStatus,
}) {
  return {
    'id': id,
    'board_code': boardCode,
    'board_name': boardName,
    'source_idx': sourceIdx,
    'number': number,
    'title': title,
    'author': '교무처',
    'published_at': publishedAt,
    'view_count': 1234,
    'url': 'https://www.dongseo.ac.kr/kr/index.php?idx=$sourceIdx',
    'is_notice': isNotice,
    'importance_status': importanceStatus,
  };
}

Map<String, dynamic> noticeResponse(Map<String, dynamic> notice) => {
  'items': [notice],
  'next_cursor': null,
};

Notice makeNotice({
  String id = 'notice-1',
  String title = 'Backend에서 받은 공지',
  int? number = 831,
  int viewCount = 1234,
  bool isNotice = false,
  String? importanceStatus,
  String boardCode = 'MN2000194',
  String boardName = '학사',
  String publishedAt = '2026-10-29',
}) {
  return Notice.fromJson({
    ...noticeJson(
      id: id,
      title: title,
      boardCode: boardCode,
      boardName: boardName,
      publishedAt: publishedAt,
      number: number,
      isNotice: isNotice,
      importanceStatus: importanceStatus,
    ),
    'view_count': viewCount,
  });
}
