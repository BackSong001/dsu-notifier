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
    this.apiKey,
    JsonFetcher? fetch,
  }) : _fetch = fetch ?? ((uri) => _fetchJson(uri, apiKey));

  final String baseUrl;
  final String? apiKey;
  final JsonFetcher _fetch;

  Future<NoticePage> getNotices({
    String? boardCode,
    int limit = 20,
    String? cursor,
  }) async {
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

  Future<Map<String, dynamic>> registerDevice({
    required String deviceId,
    required String fcmToken,
    required String platform,
  }) {
    return _send('/devices/register', 'POST', {
      'device_id': deviceId,
      'fcm_token': fcmToken,
      'platform': platform,
    });
  }

  Future<Map<String, dynamic>> savePreferences(
    String deviceId,
    Map<String, bool> boards,
  ) {
    return _send('/devices/$deviceId/preferences', 'PUT', {'boards': boards});
  }

  Future<Map<String, dynamic>> _send(
    String path,
    String method,
    Map<String, dynamic> payload,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers.contentType = ContentType.json;
      if (apiKey != null) {
        request.headers.set('apikey', apiKey!);
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      }
      request.write(jsonEncode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final result = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw Exception(result['error'] ?? 'HTTP ${response.statusCode}');
      return result;
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> _fetchJson(
    Uri uri,
    String? apiKey,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      if (apiKey != null) {
        request.headers.set('apikey', apiKey);
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      }
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
