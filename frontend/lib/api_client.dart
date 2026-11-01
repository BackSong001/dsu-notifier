import 'dart:convert';
import 'dart:io';

import 'models/notice.dart';

typedef JsonFetcher = Future<Map<String, dynamic>> Function(Uri uri);

class NoticePage {
  const NoticePage({required this.items, required this.nextCursor});

  final List<Notice> items;
  final String? nextCursor;
}

class NoticeApiClient {
  NoticeApiClient({
    this.baseUrl = 'https://<supabase-project-ref>.supabase.co/functions/v1',
    JsonFetcher? fetch,
  }) : _fetch = fetch ?? _fetchJson;

  final String baseUrl;
  final JsonFetcher _fetch;

  Future<NoticePage> getNotices({String? boardCode, int limit = 20, String? cursor}) async {
    final query = <String, String>{'limit': '$limit'};
    if (boardCode != null) query['board_code'] = boardCode;
    if (cursor != null) query['cursor'] = cursor;
    final uri = Uri.parse('$baseUrl/notices').replace(queryParameters: query);
    final json = await _fetch(uri);
    return NoticePage(
      items: (json['items'] as List<dynamic>)
          .map((item) => Notice.fromJson(item as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor'] as String?,
    );
  }

  static Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(json['error'] ?? 'HTTP ${response.statusCode}');
      }
      return json;
    } finally {
      client.close();
    }
  }
}
