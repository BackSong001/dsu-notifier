import 'dart:convert';
import 'dart:io';

import 'models/notice.dart';

typedef JsonFetcher = Future<Map<String, dynamic>> Function(Uri uri);

class NoticePage {
  const NoticePage({required this.items, required this.nextCursor, this.totalCount});

  final List<Notice> items;
  final String? nextCursor;
  final int? totalCount;
}

class NoticeApiClient {
  NoticeApiClient({
    this.baseUrl = 'https://<supabase-project-ref>.supabase.co/functions/v1',
    this.apiKey,
    this.deviceSecret,
    JsonFetcher? fetch,
  }) : _fetch = fetch ?? ((uri) => _fetchJson(uri, apiKey, deviceSecret));

  final String baseUrl;
  final String? apiKey;
  final String? deviceSecret;
  final JsonFetcher _fetch;

  Future<NoticePage> getNotices({
    String? boardCode,
    int limit = 20,
    String? cursor,
    String? search,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (boardCode != null) query['board_code'] = boardCode;
    if (cursor != null) query['cursor'] = cursor;
    if (search != null && search.isNotEmpty) query['search'] = search;
    final uri = Uri.parse('$baseUrl/notices').replace(queryParameters: query);
    final json = await _fetch(uri);
    return NoticePage(
      items: (json['items'] as List<dynamic>)
          .map((item) => Notice.fromJson(item as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor'] as String?,
      totalCount: json['total_count'] as int?,
    );
  }

  Future<NoticePage> getSavedNotices(
    String deviceId, {
    int limit = 19,
    String? cursor,
    String? search,
  }) async {
    final json = await _fetchDevice('/devices/$deviceId/saved-notices', {
      'limit': '$limit',
      if (cursor != null) 'cursor': cursor,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return NoticePage(
      items: (json['items'] as List)
          .map((item) => Notice.fromJson(item as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor'] as String?,
      totalCount: json['total_count'] as int?,
    );
  }

  Future<Map<String, dynamic>> _fetchDevice(
    String path, [
    Map<String, String>? query,
  ]) => _fetch(Uri.parse('$baseUrl$path').replace(queryParameters: query));

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

  Future<Map<String, bool>> getPreferences(String deviceId) async {
    final json = await _fetch(
      Uri.parse('$baseUrl/devices/$deviceId/preferences'),
    );
    final boards = json['boards'] as Map<String, dynamic>? ?? {};
    return boards.map((board, enabled) => MapEntry(board, enabled == true));
  }

  Future<Set<String>> getNoticePreferences(String deviceId) async {
    final json = await _fetch(
      Uri.parse('$baseUrl/devices/$deviceId/notice-preferences'),
    );
    return ((json['notice_ids'] as List<dynamic>?) ?? [])
        .whereType<String>()
        .toSet();
  }

  Future<Map<String, dynamic>> saveNoticePreference(
    String deviceId,
    String noticeId,
    bool enabled,
  ) {
    return _send('/devices/$deviceId/notice-preferences', 'PUT', {
      'notice_id': noticeId,
      'enabled': enabled,
    });
  }

  Future<Map<String, dynamic>> _send(
    String path,
    String method,
    Map<String, dynamic> payload,
  ) async {
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client
          .openUrl(method, Uri.parse('$baseUrl$path'))
          .timeout(const Duration(seconds: 20));
      if (deviceSecret != null)
        request.headers.set('x-device-secret', deviceSecret!);
      request.headers.contentType = ContentType.json;
      if (apiKey != null) {
        request.headers.set('apikey', apiKey!);
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      }
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));
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
    String? deviceSecret,
  ) async {
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 20));
      if (deviceSecret != null)
        request.headers.set('x-device-secret', deviceSecret);
      if (apiKey != null) {
        request.headers.set('apikey', apiKey);
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      }
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));
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
