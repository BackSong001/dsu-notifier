import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';
import 'settings_page.dart';
import 'models/notice.dart';

const _native = MethodChannel('dsu_notifier/native');
const _apiUrl = String.fromEnvironment('SUPABASE_FUNCTIONS_URL');
const _apiKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _pageSize = 19;

// KST timezone offset
const _kstOffset = Duration(hours: 9);

const _boards = <({String code, String label})>[
  (code: 'MN2000194', label: '학사'),
  (code: 'MN2000191', label: '공지/행사'),
  (code: 'job_plus', label: '취업'),
  (code: 'MN2000197', label: '모집'),
  (code: 'MN2000195', label: '장학'),
  (code: 'MN2000196', label: '입찰'),
];

enum _CafeteriaMenuType { info, newMillennium, globalVillageMealPlan }

class _CafeteriaMenu {
  const _CafeteriaMenu({
    required this.label,
    required this.icon,
    required this.type,
  });
  final String label;
  final IconData icon;
  final _CafeteriaMenuType type;
}

const _cafeteriaMenus = [
  _CafeteriaMenu(
    label: '학식정보',
    icon: Icons.info_outline,
    type: _CafeteriaMenuType.info,
  ),
  _CafeteriaMenu(
    label: '글빌학식',
    icon: Icons.restaurant,
    type: _CafeteriaMenuType.globalVillageMealPlan,
  ),
  _CafeteriaMenu(
    label: '뉴밀학식',
    icon: Icons.restaurant_menu,
    type: _CafeteriaMenuType.newMillennium,
  ),
];

/// 글로벌빌리지 식단표 전용 페이지
class _GlobalVillageMealPlanPage extends StatefulWidget {
  const _GlobalVillageMealPlanPage({
    required this.client,
    required this.deviceId,
  });
  final NoticeApiClient? client;
  final String? deviceId;

  @override
  State<_GlobalVillageMealPlanPage> createState() =>
      _GlobalVillageMealPlanPageState();
}

class _GlobalVillageMealPlanPageState
    extends State<_GlobalVillageMealPlanPage> {
  List<Notice> _notices = [];
  bool _loading = true;
  String? _error;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMealPlanNotices();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMealPlanNotices() async {
    if (widget.client == null) {
      setState(() {
        _loading = false;
        _error = '서버 연결 설정이 필요합니다.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 공지/행사 게시판에서 '식단표' 검색
      final result = await widget.client!.getNotices(
        boardCode: 'MN2000191',
        limit: 50,
        search: '식단표',
      );
      if (!mounted) return;
      setState(() {
        _notices = result.items;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '식단표를 불러오지 못했습니다: $e';
        });
      }
    }
  }

  Future<void> _openNotice(String url) async {
    try {
      await _native.invokeMethod<void>('openUrl', {'url': url});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('공지 링크를 열 수 없습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '글빌학식',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: _DsuColors.primary,
          ),
        ),
        centerTitle: true,
        backgroundColor: _DsuColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadMealPlanNotices,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadMealPlanNotices,
                child: _notices.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: const Center(child: Text('식단표 공지가 없습니다.')),
                          ),
                        ],
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        itemCount: _notices.length,
                        itemBuilder: (context, index) {
                          final notice = _notices[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: NoticeCard(
                              notice: notice,
                              onTap: () => _openNotice(notice.url),
                              saved: false,
                              onToggleSaved: null,
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}

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

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() => runApp(const DsuNotifierApp());

class DsuNotifierApp extends StatelessWidget {
  const DsuNotifierApp({
    super.key,
    this.initialNotices,
    this.client,
    this.deviceId,
  });

  final List<Notice>? initialNotices;
  final NoticeApiClient? client;
  final String? deviceId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '동서알리미',
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
      home: NoticeHomePage(
        initialNotices: initialNotices,
        client: client,
        deviceId: deviceId,
      ),
    );
  }
}

class NoticeHomePage extends StatefulWidget {
  const NoticeHomePage({
    super.key,
    this.initialNotices,
    this.client,
    this.deviceId,
  });

  final List<Notice>? initialNotices;
  final NoticeApiClient? client;
  final String? deviceId;

  @override
  State<NoticeHomePage> createState() => _NoticeHomePageState();
}

class _NoticeHomePageState extends State<NoticeHomePage>
    with WidgetsBindingObserver {
  late List<Notice> _notices;
  int _totalCount = 0;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _selectedBoard = _boards.first.code;
  String _selectedMenu = '공지사항';
  String _query = '';
  int _page = 1;
  bool _loading = false;
  String? _deviceId;
  NoticeApiClient? _client;
  String? _loadError;
  String? _pushError;
  bool _permissionGranted = true;
  bool _preferencesReady = false;
  bool _registering = false;
  int _preferenceGeneration = 0;
  int _loadGeneration = 0;
  final _cursors = <String?>[null];
  String? _nextCursor;
  final _savingBoards = <String>{};
  final _savingNotices = <String>{};
  StreamSubscription<String>? _tokenSubscription;
  bool get _fixtureMode => widget.initialNotices != null;
  bool get _canSave => _fixtureMode || (_deviceId != null && _preferencesReady);
  final _alarmBoards = <String>{};
  final _savedNotices = <String>{};
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notices = [...(widget.initialNotices ?? <Notice>[])];
    _client =
        widget.client ??
        (_apiUrl.isEmpty
            ? null
            : NoticeApiClient(baseUrl: _apiUrl, apiKey: _apiKey));
    _deviceId = widget.deviceId;
    _loadNotices();
    if (widget.client == null && !_fixtureMode) _registerForPush();
    if (_deviceId != null) _restorePreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _scrollController.dispose();
    _foregroundMessageSubscription?.cancel();
    _tokenSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_fixtureMode &&
        widget.client == null &&
        _apiUrl.isNotEmpty) {
      _updatePermission();
      _loadNotices(resetPage: true); // Auto-refresh on resume for new notices
    }
  }

  Future<void> _updatePermission() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (mounted)
        setState(
          () => _permissionGranted =
              settings.authorizationStatus == AuthorizationStatus.authorized,
        );
    } catch (_) {
      if (mounted) setState(() => _pushError = '알림 상태를 확인하지 못했습니다.');
    }
  }

  Future<void> _restorePreferences() async {
    if (_savingBoards.isNotEmpty || _savingNotices.isNotEmpty) return;
    final generation = ++_preferenceGeneration;
    if (mounted) setState(() => _preferencesReady = false);
    try {
      final boards = await _client!.getPreferences(_deviceId!);
      final saved = await _client!.getNoticePreferences(_deviceId!);
      if (!mounted || generation != _preferenceGeneration) return;
      setState(() {
        _preferencesReady = true;
        _alarmBoards
          ..clear()
          ..addAll(
            boards.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key),
          );
        _savedNotices
          ..clear()
          ..addAll(saved);
      });
    } catch (_) {
      if (mounted) setState(() => _pushError = '설정을 불러오지 못했습니다. 다시 연결해 주세요.');
    }
  }

  Future<void> _registerForPush() async {
    if (_apiUrl.isEmpty || _registering) return;
    _registering = true;
    try {
      final identity = await _native.invokeMapMethod<String, String>(
        'deviceIdentity',
      );
      if (identity == null) throw StateError('DEVICE_IDENTITY_UNAVAILABLE');
      _client = NoticeApiClient(
        baseUrl: _apiUrl,
        apiKey: _apiKey,
        deviceSecret: identity['secret'],
      );
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (mounted)
        setState(
          () => _permissionGranted =
              settings.authorizationStatus == AuthorizationStatus.authorized,
        );
      _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );
      Future<void> register(String token) async {
        try {
          await _client!.registerDevice(
            deviceId: identity['id']!,
            fcmToken: token,
            platform: 'android',
          );
          if (!mounted) return;
          setState(() {
            _deviceId = identity['id'];
            _pushError = null;
          });
          await _restorePreferences();
          if (mounted && _selectedMenu == '저장된 공지')
            await _loadNotices(resetPage: true);
        } catch (_) {
          if (mounted)
            setState(() => _pushError = '알림 연결에 실패했습니다. 다시 연결해 주세요.');
        }
      }

      // HTTP v1 발송은 FID 대신 기존 FCM 토큰을 사용한다.
      // ignore: deprecated_member_use
      final token = await messaging.getToken().timeout(
        const Duration(seconds: 20),
      );
      if (token != null) await register(token);
      if (token == null && mounted)
        setState(() => _pushError = '알림 토큰을 가져오지 못했습니다.');
      _tokenSubscription?.cancel();
      // ignore: deprecated_member_use
      _tokenSubscription = messaging.onTokenRefresh.listen(register);
    } catch (_) {
      if (mounted) setState(() => _pushError = '알림 연결에 실패했습니다. 다시 연결해 주세요.');
    } finally {
      _registering = false;
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _loadNotices(resetPage: true);
    final notification = message.notification;
    await _native.invokeMethod<void>('showNotification', {
      'title': notification?.title ?? '새 공지 알림',
      'body': notification?.body ?? '새 공지사항이 등록되었습니다.',
      'url': message.data['url'],
      'notice_id': message.data['notice_id'],
    });
  }

  void _resetScroll() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _loadNotices({bool resetPage = false}) async {
    if (resetPage) {
      _resetScroll();
      _page = 1;
      _cursors
        ..clear()
        ..add(null);
    }
    if (_fixtureMode) return;
    final generation = ++_loadGeneration;
    if (_client == null) {
      setState(() => _loadError = 'SERVER_NOT_CONFIGURED: 서버 연결 설정이 필요합니다.');
      return;
    }
    final menu = _selectedMenu;
    final board = _selectedBoard;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      if (menu == '알람설정') {
        if (_deviceId != null) await _restorePreferences();
        return;
      }
      final result = menu == '저장된 공지'
          ? _deviceId == null
                ? const NoticePage(items: [], nextCursor: null)
                : await _client!.getSavedNotices(
                    _deviceId!,
                    limit: _pageSize,
                    cursor: _cursors[_page - 1],
                    search: _query,
                  )
          : await _client!.getNotices(
              boardCode: board,
              limit: _pageSize,
              cursor: _cursors[_page - 1],
              search: _query,
            );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _notices = result.items;
        _nextCursor = result.nextCursor;
        _totalCount = result.totalCount ?? _notices.length;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resetScroll();
      });
    } catch (error) {
      if (mounted && generation == _loadGeneration)
        setState(() => _loadError = '목록을 불러오지 못했습니다: $error');
    } finally {
      if (mounted && generation == _loadGeneration)
        setState(() => _loading = false);
    }
  }

  List<Notice> get _visibleNotices {
    final source = !_fixtureMode
        ? _notices
        : _selectedMenu == '저장된 공지'
        ? _notices.where((notice) => _savedNotices.contains(notice.id))
        : _notices.where((notice) => notice.boardCode == _selectedBoard);
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? source.toList()
        : source
              .where((notice) => notice.title.toLowerCase().contains(query))
              .toList();

    // Show both pinned and regular notices (no deduplication by source_idx)
    // Sort: pinned first, then by date descending
    final notices = filtered.toList();
    notices.sort((a, b) {
      if (a.isNotice == b.isNotice)
        return b.publishedAt.compareTo(a.publishedAt);
      return a.isNotice ? -1 : 1;
    });
    return notices;
  }

  // Split into pinned and regular for display
  List<Notice> get _pinnedNotices =>
      _visibleNotices.where((n) => n.isNotice).toList();
  List<Notice> get _regularNotices =>
      _visibleNotices.where((n) => !n.isNotice).toList();

  int get _pageCount {
    if (_fixtureMode)
      return (_visibleNotices.length / _pageSize).ceil().clamp(1, 999999);
    // API returns total_count for proper pagination
    if (_totalCount == 0) return 1;
    return (_totalCount / _pageSize).ceil().clamp(1, 999999);
  }

  // Combined list for pagination: pinned + regular
  List<Notice> get _allNotices => [..._pinnedNotices, ..._regularNotices];

  List<Notice> get _pageNotices {
    final start = _fixtureMode ? (_page - 1) * _pageSize : 0;
    return _allNotices.skip(start).take(_pageSize).toList();
  }

  void _handleCafeteriaMenu(_CafeteriaMenu menu) {
    Navigator.pop(context);
    switch (menu.type) {
      case _CafeteriaMenuType.info:
        _showCafeteriaInfoDialog();
        break;
      case _CafeteriaMenuType.globalVillageMealPlan:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _GlobalVillageMealPlanPage(
              client: _client,
              deviceId: _deviceId,
            ),
          ),
        );
        break;
      case _CafeteriaMenuType.newMillennium:
        _openNewMillenniumMenu();
        break;
    }
  }

  void _showCafeteriaInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.restaurant, color: _DsuColors.primary, size: 28),
            const SizedBox(width: 12),
            const Text(
              '학식 이용 안내',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(
                title: '글로벌빌리지',
                color: _DsuColors.primary.withOpacity(0.1),
                details: [
                  '중식: 11:00 ~ 13:30',
                  '석식: 17:00 ~ 18:30',
                  '가격: 6,000원 (카드 결제)',
                  '위치: 글로벌빌리지 6층',
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                title: '뉴밀레니엄',
                color: Colors.orange.withOpacity(0.1),
                details: [
                  '중식: 11:30 ~ 13:30',
                  '가격: 7,000원 (현금, 계좌이체)',
                  '위치: 뉴밀레니엄관 15층',
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required Color color,
    required List<String> details,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _DsuColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _DsuColors.text,
            ),
          ),
          const SizedBox(height: 10),
          ...details.map(
            (detail) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: _DsuColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _DsuColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openNewMillenniumMenu() async {
    const url = 'https://www.lunchmenu.co.kr/menu/latest?rsat_div=ALL';
    try {
      await _native.invokeMethod<void>('openUrl', {'url': url});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('링크를 열 수 없습니다.')));
      }
    }
  }

  void _selectMenu(String menu) {
    if (menu == '학사별 공지사항' || menu == '키워드 알람') return;
    Navigator.pop(context);
    if (menu == '설정') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SettingsPage(deviceId: _deviceId),
        ),
      );
      return;
    }
    // 동서학식 메뉴는 PopupMenuButton으로 이동
    setState(() {
      _selectedMenu = menu;
      _page = 1;
    });
    _loadNotices(resetPage: true);
  }

  void _openAlarmSettings() {
    setState(() {
      _selectedMenu = '알람설정';
      _page = 1;
    });
    _loadNotices(resetPage: true);
  }

  void _selectBoard(String board) {
    setState(() {
      _selectedBoard = board;
      _selectedMenu = '공지사항';
      _page = 1;
      _query = '';
      _searchController.clear();
      _cursors
        ..clear()
        ..add(null);
    });
    _resetScroll();
    _loadNotices(resetPage: true);
  }

  void _search() {
    setState(() {
      _query = _searchController.text;
      _page = 1;
    });
    _loadNotices(resetPage: true);
  }

  Future<void> _toggleBoardAlarm(String boardCode) async {
    if (!_canSave || _savingBoards.contains(boardCode)) return;
    final enabled = !_alarmBoards.contains(boardCode);
    setState(() => _savingBoards.add(boardCode));
    try {
      if (!_fixtureMode)
        await _client!.savePreferences(_deviceId!, {boardCode: enabled});
      if (mounted)
        setState(() {
          if (enabled) {
            _alarmBoards.add(boardCode);
          } else {
            _alarmBoards.remove(boardCode);
          }
        });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알람 설정을 저장하지 못했습니다. 다시 시도해 주세요.')),
        );
    } finally {
      if (mounted) setState(() => _savingBoards.remove(boardCode));
    }
  }

  Future<void> _toggleSavedNotice(String noticeId) async {
    if (!_canSave || _savingNotices.contains(noticeId)) return;
    final saved = !_savedNotices.contains(noticeId);
    setState(() => _savingNotices.add(noticeId));
    try {
      if (!_fixtureMode)
        await _client!.saveNoticePreference(_deviceId!, noticeId, saved);
      if (!mounted) return;
      setState(() {
        if (saved) {
          _savedNotices.add(noticeId);
        } else {
          _savedNotices.remove(noticeId);
        }
      });
      if (_selectedMenu == '저장된 공지') await _loadNotices(resetPage: true);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공지 저장에 실패했습니다. 다시 시도해 주세요.')),
        );
    } finally {
      if (mounted) setState(() => _savingNotices.remove(noticeId));
    }
  }

  Future<void> _openNotice(String url) async {
    try {
      await _native.invokeMethod<void>('openUrl', {'url': url});
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('공지 링크를 열 수 없습니다.')));
    }
  }

  void _changePage(int page) {
    if (_loading) return;
    if (!_fixtureMode && page > _cursors.length) _cursors.add(_nextCursor);
    setState(() => _page = page);
    _resetScroll();
    _loadNotices();
  }

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
          '동서알리미',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: _DsuColors.primary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '알람설정',
            onPressed: _openAlarmSettings,
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_selectedMenu == '공지사항') _buildBoardTabs(),
            if (!_fixtureMode && !_permissionGranted)
              MaterialBanner(
                content: Text('알림 권한이 꺼져 있습니다. 설정에서 허용해 주세요.'),
                actions: [
                  TextButton(
                    onPressed: () async {
                      try {
                        await _native.invokeMethod<void>(
                          'openNotificationSettings',
                        );
                      } on PlatformException catch (error) {
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('알림 설정을 열 수 없습니다: ${error.code}'),
                            ),
                          );
                      }
                    },
                    child: const Text('설정 열기'),
                  ),
                ],
              )
            else if (!_fixtureMode && _pushError != null)
              MaterialBanner(
                content: Text(_pushError!),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await _registerForPush();
                    },
                    child: const Text('다시 연결'),
                  ),
                ],
              ),
            Expanded(child: _buildContent(pageCount)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(int pageCount) {
    if (_selectedMenu == '알람설정') return _buildAlarmSettingsContent();
    final notices = _pageNotices;
    final hasStatus = _loading || _loadError != null || notices.isEmpty;
    return RefreshIndicator(
      onRefresh: _refreshNotices,
      color: _DsuColors.primary,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 28, 18),
          itemCount: (hasStatus ? 1 : notices.length) + 2,
          itemBuilder: (context, index) {
            if (index == 0) return _buildListHeader(pageCount);
            if (index == (hasStatus ? 2 : notices.length + 1)) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    _buildPagination(pageCount),
                    if (kDebugMode && _selectedMenu == '공지사항')
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
            if (hasStatus) {
              return SizedBox(
                height: 220,
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _loadError ?? '조건에 맞는 공지사항이 없습니다.',
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: () => _loadNotices(resetPage: true),
                              child: Text(
                                _loadError == null ? '새로고침' : '다시 시도',
                              ),
                            ),
                          ],
                        ),
                ),
              );
            }
            final notice = notices[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NoticeCard(
                notice: notice,
                onTap: () => _openNotice(notice.url),
                saved: _savedNotices.contains(notice.id),
                onToggleSaved: _canSave && !_savingNotices.contains(notice.id)
                    ? () => _toggleSavedNotice(notice.id)
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildListHeader(int pageCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '오늘의 공지',
          style: const TextStyle(
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
                _selectedMenu == '저장된 공지'
                    ? '저장된 공지'
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
                tooltip:
                    '${_boardLabel(_selectedBoard)} 알림 ${_alarmBoards.contains(_selectedBoard) ? '끄기' : '켜기'}',
                onPressed: _canSave && !_savingBoards.contains(_selectedBoard)
                    ? () => _toggleBoardAlarm(_selectedBoard)
                    : null,
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
          _selectedMenu == '저장된 공지'
              ? '별표를 누른 공지만 모아 보여드립니다.'
              : '동서대학교의 ${_boardLabel(_selectedBoard)} 소식을 확인하세요.',
          style: const TextStyle(color: _DsuColors.secondaryText),
        ),
        const SizedBox(height: 20),
        if (_selectedMenu == '공지사항') ...[
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
                  child: const Text('검색'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 20,
          children: [
            Text(
              _fixtureMode
                  ? '전체 ${_visibleNotices.length}건'
                  : '전체 $_totalCount건 · 현재 ${_visibleNotices.length}건',
              style: const TextStyle(color: _DsuColors.secondaryText),
            ),
            Text(
              _fixtureMode ? '$_page / $pageCount 페이지' : '$_page 페이지',
              style: const TextStyle(color: _DsuColors.tertiaryText),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildAlarmSettingsContent() {
    final boards = _boards
        .where((board) => _alarmBoards.contains(board.code))
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘의 알람',
            style: TextStyle(
              color: _DsuColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '알람설정',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _DsuColors.text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '알림을 켠 게시판을 관리합니다.',
            style: TextStyle(color: _DsuColors.secondaryText),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: boards.isEmpty
                ? const Center(child: Text('알림을 켠 게시판이 없습니다.'))
                : ListView.separated(
                    itemCount: boards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final board = boards[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        color: _DsuColors.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: _DsuColors.border),
                        ),
                        child: ListTile(
                          title: Text(
                            board.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text('게시판 전체 알림'),
                          trailing: IconButton(
                            tooltip: '${board.label} 알림 끄기',
                            onPressed:
                                _canSave && !_savingBoards.contains(board.code)
                                ? () => _toggleBoardAlarm(board.code)
                                : null,
                            color: _DsuColors.primary,
                            icon: const Icon(Icons.notifications_active),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardTabs() {
    final tabHeight =
        52.0 + (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 40);
    return Container(
      height: tabHeight,
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
                  height: tabHeight,
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
    const maxVisible =
        5; // Show 1 2 3 ... n (max 5 page buttons + prev/next + ellipsis)
    final pages = <int>[];

    if (pageCount <= maxVisible + 2) {
      // Small page count: show all
      for (var i = 1; i <= pageCount; i++) {
        pages.add(i);
      }
    } else {
      // Show 1, 2, 3, ..., n
      pages.add(1);
      pages.add(2);
      pages.add(3);
      if (pageCount > 4) {
        pages.add(-1); // ellipsis marker
      }
      pages.add(pageCount);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: '이전 페이지',
          onPressed: _page > 1 && !_loading
              ? () => _changePage(_page - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        ...pages.map((page) {
          if (page == -1) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  '...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: SizedBox(
              width: 48,
              height: 48,
              child: page == _page
                  ? FilledButton(
                      onPressed: null,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        disabledBackgroundColor: _DsuColors.primary,
                        disabledForegroundColor: _DsuColors.surface,
                      ),
                      child: Text('$page'),
                    )
                  : OutlinedButton(
                      onPressed: _loading ? null : () => _changePage(page),
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text('$page'),
                    ),
            ),
          );
        }),
        IconButton(
          tooltip: '다음 페이지',
          onPressed: _page < pageCount && !_loading
              ? () => _changePage(_page + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '페이지 이동',
          onPressed: _loading ? null : () => _showPageJumpDialog(pageCount),
          icon: const Icon(Icons.find_in_page),
        ),
      ],
    );
  }

  void _showPageJumpDialog(int maxPage) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('페이지 이동'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('1 ~ $maxPage 페이지 중 이동할 페이지를 입력하세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '페이지 번호',
                hintText: '예: 5',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(controller.text.trim());
              Navigator.pop(context);
              if (page != null && page >= 1 && page <= maxPage) {
                _changePage(page);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('1 ~ $maxPage 사이의 숫자를 입력해 주세요.')),
                );
              }
            },
            child: const Text('이동'),
          ),
        ],
      ),
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
                  '동서알리미\n대학 공지 알림',
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
            _buildCafeteriaSubmenu(),
            _menuTile('알람설정', Icons.notifications_active_outlined),
            _menuTile('저장된 공지', Icons.star_outline),
            _menuTile('설정', Icons.settings_outlined),
            _menuTile('키워드 알람', Icons.manage_search_outlined, enabled: false),
          ],
        ),
      ),
    );
  }

  Widget _buildCafeteriaSubmenu() {
    return ExpansionTile(
      leading: const Icon(Icons.restaurant_outlined),
      title: const Text('학식 메뉴'),
      iconColor: _DsuColors.primary,
      collapsedIconColor: _DsuColors.text,
      children: _cafeteriaMenus.map((menu) {
        return ListTile(
          leading: Icon(menu.icon, color: _DsuColors.text),
          title: Text(menu.label),
          onTap: () => _handleCafeteriaMenu(menu),
        );
      }).toList(),
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
  const NoticeCard({
    super.key,
    required this.notice,
    required this.onTap,
    required this.saved,
    required this.onToggleSaved,
  });

  final Notice notice;
  final VoidCallback onTap;
  final bool saved;
  final VoidCallback? onToggleSaved;

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (notice.isNotice)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _DsuColors.primaryLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin,
                            size: 12,
                            color: _DsuColors.primary,
                          ),
                          SizedBox(width: 3),
                          Text(
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
                  // New badge (KST 24시간 이내)
                  if (notice.isNew && !notice.isNotice)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _DsuColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'New',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      notice.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _DsuColors.text,
                        fontSize: 16,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!notice.isNotice)
                    IconButton(
                      tooltip: saved ? '저장 취소' : '공지 저장',
                      onPressed: onToggleSaved,
                      color: saved
                          ? _DsuColors.primary
                          : _DsuColors.tertiaryText,
                      icon: Icon(saved ? Icons.star : Icons.star_border),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    '${notice.author}  |  ${notice.publishedAt}',
                    style: const TextStyle(
                      color: _DsuColors.tertiaryText,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '조회 ${_formatCount(notice.viewCount)}',
                    style: const TextStyle(
                      color: _DsuColors.tertiaryText,
                      fontSize: 12,
                    ),
                  ),
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
