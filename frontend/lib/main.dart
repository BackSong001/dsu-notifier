import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';
import 'models/notice.dart';

const _native = MethodChannel('dsu_notifier/native');
const _apiUrl = String.fromEnvironment('SUPABASE_FUNCTIONS_URL');
const _apiKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _pageSize = 19;

const _boards = <({String code, String label})>[
  (code: 'MN2000194', label: '학사'),
  (code: 'MN2000191', label: '공지/행사'),
  (code: 'job_plus', label: '취업'),
  (code: 'MN2000197', label: '모집'),
  (code: 'MN2000195', label: '장학'),
  (code: 'MN2000196', label: '입찰'),
];

class _DsuColors {
  static const primary = Color(0xFFE11837);
  static const primaryLight = Color(0xFFFCE8EC);
  static const background = Color(0xFFF7F7F8);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF222222);
  static const secondaryText = Color(0xFF555555);
  static const tertiaryText = Color(0xFF777777);
  static const border = Color(0xFFDDDDDD);
  static const borderLight = Color(0xFFEEEEEE);
}

Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() => runApp(const DsuNotifierApp());

class DsuNotifierApp extends StatelessWidget {
  const DsuNotifierApp({super.key, this.initialNotices});

  final List<Notice>? initialNotices;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '동서대학교 공지',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _DsuColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _DsuColors.primary,
          primary: _DsuColors.primary,
          onPrimary: _DsuColors.surface,
          surface: _DsuColors.surface,
          onSurface: _DsuColors.text,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _DsuColors.surface,
          foregroundColor: _DsuColors.text,
          elevation: 0,
          toolbarHeight: 64,
          titleTextStyle: TextStyle(
            color: _DsuColors.primary,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: _DsuColors.surface,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: _DsuColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: _DsuColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: _DsuColors.primary, width: 2),
          ),
        ),
      ),
      home: NoticeHomePage(initialNotices: initialNotices),
    );
  }
}

class NoticeHomePage extends StatefulWidget {
  const NoticeHomePage({super.key, this.initialNotices});

  final List<Notice>? initialNotices;

  @override
  State<NoticeHomePage> createState() => _NoticeHomePageState();
}

class _NoticeHomePageState extends State<NoticeHomePage> {
  late List<Notice> _notices;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _selectedBoard = _boards.first.code;
  String _selectedMenu = '공지사항';
  String _query = '';
  int _page = 1;
  bool _loading = false;
  String? _deviceId;
  final _alarmBoards = <String>{};
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  @override
  void initState() {
    super.initState();
    _notices = [...(widget.initialNotices ?? _fallbackNotices)];
    _requestNotificationPermission();
    _loadNotices();
    _registerForPush();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _foregroundMessageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestNotificationPermission() async {
    await _native.invokeMethod<bool>('requestNotifications');
  }

  Future<void> _registerForPush() async {
    if (_apiUrl.isEmpty) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      // The initial token is required before the device can receive a push.
      // ignore: deprecated_member_use
      final token = await messaging.getToken().timeout(
        const Duration(seconds: 15),
      );
      if (token == null) return;
      _deviceId = token;
      final client = NoticeApiClient(baseUrl: _apiUrl, apiKey: _apiKey);
      await client.registerDevice(
        deviceId: token,
        fcmToken: token,
        platform: 'android',
      );
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final url = message.data['url'];
        if (url is String) _openNotice(url);
      });
      developer.log('FCM device registration succeeded', name: 'dsu_notifier');
      if (mounted) setState(() {});
    } catch (error) {
      developer.log(
        'FCM device registration failed: $error',
        name: 'dsu_notifier',
      );
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _loadNotices(resetPage: true);
    final notification = message.notification;
    await _native.invokeMethod<void>('showNotification', {
      'title': notification?.title ?? '새 공지 알림',
      'body': notification?.body ?? '새 공지사항이 등록되었습니다.',
      'url': message.data['url'],
    });
  }

  Future<void> _loadNotices({bool resetPage = false}) async {
    if (_apiUrl.isEmpty || widget.initialNotices != null) return;
    if (resetPage) {
      _scrollController.jumpTo(0);
      setState(() => _page = 1);
    }
    setState(() => _loading = true);
    try {
      final boardCode = _selectedMenu == '공지사항' ? _selectedBoard : null;
      final page = await NoticeApiClient(
        baseUrl: _apiUrl,
        apiKey: _apiKey,
      ).getNotices(boardCode: boardCode, limit: _pageSize);
      if (mounted) {
        setState(() {
          _notices = boardCode == null
              ? page.items
              : [
                  ..._notices.where((notice) => notice.boardCode != boardCode),
                  ...page.items,
                ];
        });
      }
    } catch (error) {
      developer.log('Notice loading failed: $error', name: 'dsu_notifier');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAlarmNotices() async {
    if (_apiUrl.isEmpty || widget.initialNotices != null) return;
    if (_deviceId == null) {
      setState(() => _notices = []);
      return;
    }
    setState(() {
      _loading = true;
      _page = 1;
    });
    try {
      final page = await NoticeApiClient(
        baseUrl: _apiUrl,
        apiKey: _apiKey,
      ).getNotices(deviceId: _deviceId, alarmOnly: true, limit: 100);
      if (!mounted) return;
      setState(() => _notices = page.items);
      if (page.items.isNotEmpty) {
        await NoticeApiClient(
          baseUrl: _apiUrl,
          apiKey: _apiKey,
        ).markNotificationsRead(
          _deviceId!,
          page.items.map((notice) => notice.id).toList(),
        );
      }
    } catch (error) {
      developer.log(
        'Alarm notice loading failed: $error',
        name: 'dsu_notifier',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Notice> get _visibleNotices {
    final source = _selectedMenu == '알람공지'
        ? _notices.where((notice) => _alarmBoards.contains(notice.boardCode))
        : _notices.where((notice) => notice.boardCode == _selectedBoard);
    final query = _query.trim().toLowerCase();
    final notices = query.isEmpty
        ? source.toList()
        : source
              .where((notice) => notice.title.toLowerCase().contains(query))
              .toList();
    notices.sort((a, b) {
      if (a.isNotice == b.isNotice) return 0;
      return a.isNotice ? -1 : 1;
    });
    return notices;
  }

  int get _pageCount =>
      (_visibleNotices.length / _pageSize).ceil().clamp(1, 999999);

  List<Notice> get _pageNotices {
    final start = (_page - 1) * _pageSize;
    return _visibleNotices.skip(start).take(_pageSize).toList();
  }

  void _selectMenu(String menu) {
    if (menu == '학사별 공지사항' || menu == '키워드 알람') return;
    Navigator.pop(context);
    setState(() {
      _selectedMenu = menu;
      _page = 1;
    });
    if (menu == '알람공지') _loadAlarmNotices();
  }

  void _openAlarmNotices() {
    setState(() {
      _selectedMenu = '알람공지';
      _page = 1;
    });
    _loadAlarmNotices();
  }

  void _selectBoard(String board) {
    setState(() {
      _selectedBoard = board;
      _selectedMenu = '공지사항';
      _page = 1;
    });
    _scrollController.jumpTo(0);
    _loadNotices(resetPage: true);
  }

  void _search() {
    setState(() {
      _query = _searchController.text;
      _page = 1;
    });
  }

  Future<void> _toggleBoardAlarm(String boardCode) async {
    final enabled = !_alarmBoards.contains(boardCode);
    setState(() {
      if (enabled) {
        _alarmBoards.add(boardCode);
      } else {
        _alarmBoards.remove(boardCode);
      }
    });
    if (_deviceId == null || _apiUrl.isEmpty) return;
    try {
      await NoticeApiClient(
        baseUrl: _apiUrl,
        apiKey: _apiKey,
      ).savePreferences(_deviceId!, {boardCode: enabled});
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (enabled) {
          _alarmBoards.remove(boardCode);
        } else {
          _alarmBoards.add(boardCode);
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('알림 설정을 저장하지 못했습니다: $error')));
    }
  }

  Future<void> _openNotice(String url) =>
      _native.invokeMethod<void>('openUrl', {'url': url});

  Future<void> _showTestNotification() async {
    await _native.invokeMethod<void>('showTestNotification');
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('테스트 알림을 보냈습니다.')));
    }
  }

  Future<void> _refreshNotices() => _loadNotices(resetPage: true);

  @override
  Widget build(BuildContext context) {
    final pageCount = _pageCount;
    if (_page > pageCount) _page = pageCount;
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: const Text(
          '동서대학교',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: _DsuColors.primary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '알람공지',
            onPressed: _openAlarmNotices,
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_selectedMenu == '공지사항') _buildBoardTabs(),
            Expanded(child: _buildContent(pageCount)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(int pageCount) {
    final notices = _pageNotices;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘의 공지',
            style: TextStyle(
              color: _DsuColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedMenu == '알람공지'
                      ? '알람공지'
                      : '${_boardLabel(_selectedBoard)} 공지사항',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _DsuColors.text,
                  ),
                ),
              ),
              if (_selectedMenu == '공지사항')
                IconButton(
                  tooltip: _alarmBoards.contains(_selectedBoard)
                      ? '${_boardLabel(_selectedBoard)} 알림 끄기'
                      : '${_boardLabel(_selectedBoard)} 알림 켜기',
                  onPressed: () => _toggleBoardAlarm(_selectedBoard),
                  color: _alarmBoards.contains(_selectedBoard)
                      ? _DsuColors.primary
                      : _DsuColors.tertiaryText,
                  icon: Icon(
                    _alarmBoards.contains(_selectedBoard)
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _selectedMenu == '알람공지'
                ? '알림을 설정한 게시판의 공지입니다.'
                : '수업부터 졸업까지, 꼭 알아야 할 학사 소식',
            style: const TextStyle(color: _DsuColors.secondaryText),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '검색어를 입력해 주세요',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _search,
                  style: FilledButton.styleFrom(
                    backgroundColor: _DsuColors.primary,
                    foregroundColor: _DsuColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text('검색'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '전체 ${_visibleNotices.length}건',
                style: const TextStyle(color: _DsuColors.secondaryText),
              ),
              Text(
                '$_page / $pageCount 페이지',
                style: const TextStyle(color: _DsuColors.tertiaryText),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _DsuColors.primary),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshNotices,
                    color: _DsuColors.primary,
                    child: ScrollbarTheme(
                      data: ScrollbarThemeData(
                        thumbColor: const WidgetStatePropertyAll(
                          _DsuColors.tertiaryText,
                        ),
                        trackColor: const WidgetStatePropertyAll(
                          _DsuColors.borderLight,
                        ),
                        trackVisibility: const WidgetStatePropertyAll(true),
                        thickness: const WidgetStatePropertyAll(6),
                        radius: const Radius.circular(3),
                      ),
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: notices.isEmpty
                              ? ListView(
                                  controller: _scrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(
                                      height: 180,
                                      child: Center(
                                        child: Text('조건에 맞는 공지사항이 없습니다.'),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  controller: _scrollController,
                                  itemCount: notices.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (_, index) => NoticeCard(
                                    notice: notices[index],
                                    onTap: () =>
                                        _openNotice(notices[index].url),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          _buildPagination(pageCount),
          if (_selectedMenu == '공지사항')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showTestNotification,
                child: const Text('테스트'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBoardTabs() {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: _DsuColors.surface,
        border: Border(bottom: BorderSide(color: _DsuColors.borderLight)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _boards
              .map(
                (board) => SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextButton(
                      onPressed: () => _selectBoard(board.code),
                      style: TextButton.styleFrom(
                        foregroundColor: _selectedBoard == board.code
                            ? _DsuColors.primary
                            : _DsuColors.secondaryText,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 11),
                            child: Text(
                              board.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedBoard == board.code
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 2,
                            width: 54,
                            child: ColoredBox(
                              color: _selectedBoard == board.code
                                  ? _DsuColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildPagination(int pageCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: '이전 페이지',
          onPressed: _page > 1 ? () => setState(() => _page--) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        for (var page = 1; page <= pageCount && page <= 5; page++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: SizedBox(
              width: 40,
              height: 40,
              child: page == _page
                  ? FilledButton(
                      onPressed: null,
                      style: FilledButton.styleFrom(
                        disabledBackgroundColor: _DsuColors.primary,
                        disabledForegroundColor: _DsuColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('$page'),
                    )
                  : OutlinedButton(
                      onPressed: () => setState(() => _page = page),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _DsuColors.secondaryText,
                        side: const BorderSide(color: _DsuColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('$page'),
                    ),
            ),
          ),
        IconButton(
          tooltip: '다음 페이지',
          onPressed: _page < pageCount ? () => setState(() => _page++) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  '동서대학교\n공지센터',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _DsuColors.primary,
                  ),
                ),
              ),
            ),
            _menuTile('공지사항', Icons.campaign_outlined),
            _menuTile('학사별 공지사항', Icons.school_outlined, enabled: false),
            _menuTile('알람공지', Icons.notifications_active_outlined),
            _menuTile('키워드 알람', Icons.manage_search_outlined, enabled: false),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(String label, IconData icon, {bool enabled = true}) {
    return ListTile(
      enabled: enabled,
      selected: _selectedMenu == label,
      selectedColor: _DsuColors.primary,
      leading: Icon(icon),
      title: Text(enabled ? label : '$label · 추후 예정'),
      onTap: enabled ? () => _selectMenu(label) : null,
    );
  }

  String _boardLabel(String code) =>
      _boards.firstWhere((board) => board.code == code).label;
}

class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.notice, required this.onTap});

  final Notice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: _DsuColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _DsuColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (notice.isNotice)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _DsuColors.primaryLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.push_pin,
                            size: 12,
                            color: _DsuColors.primary,
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            '고정 공지',
                            style: TextStyle(
                              color: _DsuColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                notice.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _DsuColors.text,
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${notice.author}  |  ${notice.publishedAt}',
                      style: const TextStyle(
                        color: _DsuColors.tertiaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '조회 ${_formatCount(notice.viewCount)}',
                    style: const TextStyle(
                      color: _DsuColors.tertiaryText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    notice.number?.toString() ?? '고정',
                    style: const TextStyle(
                      color: _DsuColors.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatCount(int count) => count.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (match) => ',',
);

const _fallbackNotices = <Notice>[
  Notice(
    id: 'sample-1',
    boardCode: 'MN2000194',
    boardName: '학사',
    sourceIdx: '103653',
    number: 831,
    title: '수강신청 안내',
    author: '교무처',
    publishedAt: '2026-10-29',
    viewCount: 1234,
    url:
        'https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000194&mode=view&idx=103653',
    isNotice: false,
    importanceStatus: null,
  ),
  Notice(
    id: 'sample-2',
    boardCode: 'MN2000194',
    boardName: '학사',
    sourceIdx: '103600',
    number: null,
    title: '2026-2 중간성적 학생열람 안내',
    author: '교무처',
    publishedAt: '2026-10-28',
    viewCount: 349,
    url: 'https://www.dongseo.ac.kr/',
    isNotice: true,
    importanceStatus: 'true',
  ),
  Notice(
    id: 'sample-3',
    boardCode: 'MN2000194',
    boardName: '학사',
    sourceIdx: '103599',
    number: 830,
    title: '학사 일정 안내',
    author: '교무처',
    publishedAt: '2026-10-27',
    viewCount: 204,
    url: 'https://www.dongseo.ac.kr/',
    isNotice: false,
    importanceStatus: null,
  ),
];
