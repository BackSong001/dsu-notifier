import 'package:flutter/material.dart';

import 'models/notice.dart';

class NoticeListScreen extends StatelessWidget {
  const NoticeListScreen({super.key, required this.notices});

  final List<Notice> notices;

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) {
      return const Center(child: Text('공지사항이 없습니다.'));
    }
    return ListView.builder(
      itemCount: notices.length,
      itemBuilder: (context, index) {
        final notice = notices[index];
        return ListTile(
          title: Text(notice.title),
          subtitle: Row(
            children: [
              Text(notice.publishedAt),
              const SizedBox(width: 8),
              const Text('· 조회'),
              const SizedBox(width: 4),
              Text(_formatCount(notice.viewCount)),
            ],
          ),
          trailing: Text(notice.number?.toString() ?? '고정'),
        );
      },
    );
  }

  String _formatCount(int count) => count.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => ',',
      );
}
