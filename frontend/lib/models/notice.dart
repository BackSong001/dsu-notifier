class Notice {
  const Notice({
    required this.id,
    required this.boardCode,
    required this.boardName,
    required this.sourceIdx,
    required this.number,
    required this.title,
    required this.author,
    required this.publishedAt,
    required this.viewCount,
    required this.url,
    required this.isNotice,
    required this.importanceStatus,
    this.firstCollectedAt,
  });

  final String id;
  final String boardCode;
  final String boardName;
  final String sourceIdx;
  final int? number;
  final String title;
  final String author;
  final String publishedAt;
  final int viewCount;
  final String url;
  final bool isNotice;
  final String? importanceStatus;
  final String? firstCollectedAt;

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
        id: json['id'] as String,
        boardCode: json['board_code'] as String,
        boardName: json['board_name'] as String,
        sourceIdx: json['source_idx'] as String,
        number: json['number'] as int?,
        title: json['title'] as String,
        author: json['author'] as String,
        publishedAt: json['published_at'] as String,
        viewCount: json['view_count'] as int,
        url: json['url'] as String,
        isNotice: json['is_notice'] as bool,
        importanceStatus: json['importance_status'] as String?,
        firstCollectedAt: json['first_collected_at'] as String?,
      );

  /// 게시일(published_at) 기준 KST로 오늘/어제인 경우만 New 표시
  bool get isNew {
    if (publishedAt.isEmpty) return false;
    try {
      final published = DateTime.parse(publishedAt).toUtc();
      final now = DateTime.now().toUtc();
      // KST(UTC+9) 기준으로 날짜 비교
      final kstNow = now.add(const Duration(hours: 9));
      final kstPublished = published.add(const Duration(hours: 9));

      final today = DateTime(kstNow.year, kstNow.month, kstNow.day);
      final pubDate = DateTime(kstPublished.year, kstPublished.month, kstPublished.day);

      final diffDays = today.difference(pubDate).inDays;
      return diffDays >= 0 && diffDays <= 1; // 오늘(0) 또는 어제(1)
    } catch (_) {
      return false;
    }
  }

  /// 고정 공지이면서 새로운 공지인 경우 (고정 공지만 표시)
  bool get isPinnedAndNew => isNotice && isNew;
}
