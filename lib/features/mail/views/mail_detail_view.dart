import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/mail_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class MailDetailView extends ConsumerWidget {
  const MailDetailView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(mailAccountProvider);
    final selectedMail = ref.watch(selectedMailProvider);

    if (accountAsync.value == null) {
      return Center(
        child: Icon(Icons.mail_outline, size: 64, color: Colors.grey[300]),
      );
    }

    if (selectedMail == null) {
      return const Center(
        child: Text('메일을 선택하세요', style: TextStyle(color: Colors.grey)),
      );
    }

    // 메일 선택 시 읽음 처리
    if (!selectedMail.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(mailMessagesProvider.notifier).markAsRead(selectedMail.id);
      });
    }

    final account = accountAsync.value!;
    final isOutlook = account.isOutlook;

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
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF4A90E2),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedMail.from,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${selectedMail.date.year}.${selectedMail.date.month}.${selectedMail.date.day} '
                      '${selectedMail.date.hour.toString().padLeft(2, '0')}:'
                      '${selectedMail.date.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // 답장 버튼
              ElevatedButton.icon(
                onPressed: () async {
                  final url = isOutlook
                      ? Uri.parse('https://outlook.live.com/mail/0/')
                      : Uri.parse('https://mail.google.com/');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.reply, size: 16),
                label: const Text('답장'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
