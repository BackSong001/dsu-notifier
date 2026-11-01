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
      );
}
