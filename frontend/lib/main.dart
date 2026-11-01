import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_client.dart';

const _native = MethodChannel('dsu_notifier/native');
const _apiUrl = String.fromEnvironment('SUPABASE_FUNCTIONS_URL');
const _apiKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() => runApp(const DsuNotifierApp());

class DsuNotifierApp extends StatelessWidget {
  const DsuNotifierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSU 공지',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF091521),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF62E6D4),
          brightness: Brightness.dark,
        ),
        fontFamily: 'sans',
      ),
      home: const NoticeHomePage(),
    );
  }
}

class NoticeHomePage extends StatefulWidget {
  const NoticeHomePage({super.key});

  @override
  State<NoticeHomePage> createState() => _NoticeHomePageState();
}

class _NoticeHomePageState extends State<NoticeHomePage> {
  bool _notificationsEnabled = false;

  final _notices = <(String, String, String, String, String, String)>[
    (
      '수강신청 안내',
      '학사',
      '2026.10.29',
      '1,234',
      '831',
      'https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000194&mode=view&idx=103653',
    ),
    (
      '2026-2 중간성적 학생열람 안내',
      '학사',
      '2026.10.28',
      '349',
      '고정',
      'https://www.dongseo.ac.kr/',
    ),
    (
      '동서대학교 주요 행사 안내',
      '공지/행사',
      '2026.10.27',
      '812',
      '204',
      'https://www.dongseo.ac.kr/',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _loadNotices();
    _registerForPush();
  }

  Future<void> _registerForPush() async {
    if (_apiUrl.isEmpty) return;
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    // The current token is needed for the initial device registration.
    // ignore: deprecated_member_use
    final token = await messaging.getToken();
    if (token == null) return;
    final client = NoticeApiClient(baseUrl: _apiUrl, apiKey: _apiKey);
    await client.registerDevice(
      deviceId: token,
      fcmToken: token,
      platform: 'android',
    );
    await client.savePreferences(token, {'MN2000194': true});
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final url = message.data['url'];
      if (url is String) _openNotice(url);
    });
  }

  Future<void> _loadNotices() async {
    if (_apiUrl.isEmpty) return;
    final page = await NoticeApiClient(
      baseUrl: _apiUrl,
      apiKey: _apiKey,
    ).getNotices();
    if (!mounted) return;
    setState(() {
      _notices
        ..clear()
        ..addAll(
          page.items.map(
            (notice) => (
              notice.title,
              notice.boardName,
              notice.publishedAt,
              _formatCount(notice.viewCount),
              notice.number?.toString() ?? '고정',
              notice.url,
            ),
          ),
        );
    });
  }

  String _formatCount(int count) => count.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );

  Future<void> _requestNotificationPermission() async {
    final enabled =
        await _native.invokeMethod<bool>('requestNotifications') ?? false;
    if (mounted) setState(() => _notificationsEnabled = enabled);
  }

  Future<void> _showTestNotification() async {
    await _native.invokeMethod<void>('showTestNotification');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('테스트 알림을 보냈습니다.')));
  }

  Future<void> _openNotice(String url) {
    return _native.invokeMethod<void>('openUrl', {'url': url});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DSU 공지'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '알림 권한',
            onPressed: _requestNotificationPermission,
            icon: Icon(
              _notificationsEnabled
                  ? Icons.notifications
                  : Icons.notifications_none,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text(
            '오늘의 공지',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '동서대학교의 새 소식을 한곳에서 확인하세요.',
            style: TextStyle(color: Colors.white.withAlpha(170)),
          ),
          const SizedBox(height: 24),
          _PulseCard(
            enabled: _notificationsEnabled,
            onPressed: _showTestNotification,
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '최신 공지',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              Text(
                '방금 확인',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._notices.map(
            (notice) => _NoticeTile(
              notice: notice,
              onTap: () => _openNotice(notice.$6),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseCard extends StatelessWidget {
  const _PulseCard({required this.enabled, required this.onPressed});
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF102C3A),
        border: Border.all(color: const Color(0xFF245568)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Color(0xFF62E6D4), size: 32),
          const SizedBox(width: 14),
          Expanded(child: Text(enabled ? '알림이 켜져 있습니다' : '알림을 켜고 새 공지를 받아보세요')),
          FilledButton(onPressed: onPressed, child: const Text('테스트')),
        ],
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice, required this.onTap});
  final (String, String, String, String, String, String) notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF102331),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    notice.$2,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    notice.$5,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                notice.$1,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${notice.$3}  ·  조회 ${notice.$4}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
