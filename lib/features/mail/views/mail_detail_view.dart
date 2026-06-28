import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/mail_provider.dart';
import '../widgets/mail_login_dialog.dart';

class MailDetailView extends ConsumerWidget {
  const MailDetailView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(mailAccountProvider);
    final selectedMail = ref.watch(selectedMailProvider);

    // 로그인 안 됐으면 안내 화면
    if (accountAsync.value == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mail_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              '메일 서비스를 이용하려면\n로그인이 필요합니다',
              style: TextStyle(fontSize: 15, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => showMailLoginDialog(context),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('로그인'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // 메일 선택 안 됐으면
    if (selectedMail == null) {
      return const Center(
        child: Text(
          '메일을 선택하세요',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedMail.subject,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.person,
                    color: Color(0xFF4A90E2), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedMail.from,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${selectedMail.date.year}.'
                      '${selectedMail.date.month}.'
                      '${selectedMail.date.day} '
                      '${selectedMail.date.hour.toString().padLeft(2, '0')}:'
                      '${selectedMail.date.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                selectedMail.preview.isEmpty ? '(내용 없음)' : selectedMail.preview,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
