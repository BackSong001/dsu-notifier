import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _contactEmail = 'jhgu2014@gmail.com';

Future<Map<String, dynamic>> _loadPolicies() async =>
    jsonDecode(await rootBundle.loadString('assets/legal/policies.json'))
        as Map<String, dynamic>;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.deviceId});

  final String? deviceId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('동서알리미', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('대학 공지를 모아 전하는 개인 개발 앱입니다.\n동서대학교 및 정부기관의 공식 앱이 아닙니다.'),
            const SizedBox(height: 28),
            Text('약관 및 정책', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final document in const [
              ('privacy', '개인정보처리방침'),
              ('terms', '서비스 이용약관'),
              ('deletion', '데이터 삭제 및 권리 행사'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(document.$2),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PolicyPage(id: document.$1, title: document.$2),
                  ),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('오픈소스 라이선스'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  showLicensePage(context: context, applicationName: '동서알리미'),
            ),
            const Divider(height: 32),
            Text(
              '문의 및 데이터 삭제 요청',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const SelectableText('운영자 백송\n$_contactEmail'),
            const SizedBox(height: 12),
            SelectableText('설치 ID: ${deviceId ?? '연결된 기기가 없습니다.'}'),
            const SizedBox(height: 12),
            const Text(
              '계정 가입 없이 이용합니다. 데이터 삭제는 이메일로 요청할 수 있습니다. 앱 제거·알림 끄기만으로 서버 데이터가 삭제되지는 않습니다.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_outlined),
              label: const Text('삭제 요청 내용 복사'),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        '받는 사람: $_contactEmail\n제목: 동서알리미 데이터 삭제 요청\n'
                        '설치 ID: ${deviceId ?? '확인할 수 없음 — 식별 방법 안내를 요청합니다.'}\n'
                        '위 설치의 기기 정보, 구독, 저장 공지 연결 및 발송 기록 삭제를 요청합니다.\n'
                        '기기 소유 확인 절차를 안내해 주세요.\n인증 비밀값·푸시 토큰·신분증은 보내지 마세요.',
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('요청 내용을 복사했습니다. 이메일로 보내 주세요.'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PolicyPage extends StatefulWidget {
  const PolicyPage({super.key, required this.id, required this.title});

  final String id;
  final String title;

  @override
  State<PolicyPage> createState() => _PolicyPageState();
}

class _PolicyPageState extends State<PolicyPage> {
  late Future<Map<String, dynamic>> _policies = _loadPolicies();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _policies,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('정책 문서를 불러오지 못했습니다.'),
                  TextButton(
                    onPressed: () =>
                        setState(() => _policies = _loadPolicies()),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          final document = (data['documents'] as List)
              .cast<Map<String, dynamic>>()
              .firstWhere((document) => document['id'] == widget.id);
          return Scrollbar(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '시행일 ${data['effectiveDate']} · 문서 버전 ${data['version']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                for (final section in document['sections'] as List) ...[
                  const SizedBox(height: 24),
                  Text(
                    section['heading'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    section['body'] as String,
                    style: const TextStyle(height: 1.65),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}
