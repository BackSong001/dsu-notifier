import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
    final notices = query.isEmpty
        ? source.toList()
        : source
              .where((notice) => notice.title.toLowerCase().contains(query))
              .toList();
    // Sort: pinned first, then by date descending
    notices.sort((a, b) {
      if (a.isNotice == b.isNotice) return b.publishedAt.compareTo(a.publishedAt);
      return a.isNotice ? -1 : 1;
    });
    return notices;
  }

  // Split into pinned and regular for display
  List<Notice> get _pinnedNotices => _visibleNotices.where((n) => n.isNotice).toList();
  List<Notice> get _regularNotices => _visibleNotices.where((n) => !n.isNotice).toList();

  int get _pageCount => _fixtureMode
      ? (_visibleNotices.length / _pageSize).ceil().clamp(1, 999999)
      : _page + (_nextCursor == null ? 0 : 1);

  // Combined list for pagination: pinned + regular
  List<Notice> get _allNotices => [..._pinnedNotices, ..._regularNotices];

  List<Notice> get _pageNotices {
    final start = _fixtureMode ? (_page - 1) * _pageSize : 0;
    return _allNotices.skip(start).take(_pageSize).toList();
  }

  void _selectMenu(String menu) {
    if (menu == '학사별 공지사항' || menu == '키워드 알람') return;
    Navigator.pop(context);
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
          '동서대학교',
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
            if (!_fixtureMode &&
                (!_canSave || !_permissionGranted || _pushError != null))
              MaterialBanner(
                content: Text(
                  !_permissionGranted
                      ? '알림 권한이 꺼져 있습니다. 설정에서 허용해 주세요.'
                      : _pushError ?? '알림 연결 후 저장과 알람 설정을 사용할 수 있습니다.',
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      if (!_permissionGranted) {
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
                      } else {
                        await _registerForPush();
                      }
                    },
                    child: Text(!_permissionGranted ? '설정 열기' : '다시 연결'),
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
              child: FilledButton(onPressed: _search, child: const Text('검색')),
            ),
          ],
        ),
        const SizedBox(height: 18),
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
    final first = (_page - 1).clamp(1, (pageCount - 2).clamp(1, pageCount));
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
        for (var page = first; page <= pageCount && page < first + 5; page++)
          Padding(
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
          ),
        IconButton(
          tooltip: '다음 페이지',
          onPressed: _page < pageCount && !_loading
              ? () => _changePage(_page + 1)
              : null,
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
            _menuTile('알람설정', Icons.notifications_active_outlined),
            _menuTile('저장된 공지', Icons.star_outline),
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
