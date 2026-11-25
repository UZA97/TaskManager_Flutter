import 'package:taskmanager/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/mail_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/mail_body_view.dart';

/// Gmail 웹에서 이 계정의 [threadId] 대화를 여는 주소 (없으면 받은편지함)
Uri gmailThreadUrl(String email, String threadId) => Uri.parse(
  'https://mail.google.com/mail/'
  '${email.isEmpty ? '' : '?authuser=${Uri.encodeQueryComponent(email)}'}'
  '${threadId.isEmpty ? '' : '#all/$threadId'}',
);

class MailDetailView extends ConsumerWidget {
  const MailDetailView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(mailAccountProvider);
    final selectedMail = ref.watch(selectedMailProvider);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;

    if (accountAsync.value == null) {
      return Center(child: Icon(Icons.mail_outline, size: 64, color: muted));
    }

    if (selectedMail == null) {
      return Center(
        child: Text('메일을 선택하세요', style: TextStyle(color: muted)),
      );
    }

    // 메일 선택 시 읽음 처리
    if (!selectedMail.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(mailMessagesProvider.notifier).markAsRead(selectedMail.id);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 제목 (할 일 화면과 같은 큰 제목)
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 24, 24, 12),
          child: Text(
            selectedMail.subject,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 0, 24, 0),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.person, color: muted, size: 18),
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${selectedMail.date.year}.${selectedMail.date.month}.${selectedMail.date.day} '
                      '${selectedMail.date.hour.toString().padLeft(2, '0')}:'
                      '${selectedMail.date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              // 삭제 (Gmail 휴지통으로 이동)
              IconButton(
                tooltip: '삭제',
                icon: const Icon(Icons.delete_outline, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surfaceContainerHigh,
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('메일 삭제'),
                      content: const Text(
                        '이 메일을 삭제할까요?\n'
                        'Gmail 휴지통으로 이동하며, 30일 안에는 Gmail에서 복구할 수 있습니다.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('삭제'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  final deleted = await ref
                      .read(mailMessagesProvider.notifier)
                      .trash({selectedMail.id});
                  if (deleted == 0 && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('메일 삭제에 실패했습니다'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 6),
              // 답장: Gmail에서 이 메일 대화를 열어 답장
              FilledButton.icon(
                onPressed: () => launchUrl(
                  gmailThreadUrl(
                    accountAsync.value?.email ?? '',
                    selectedMail.threadId,
                  ),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.reply, size: 16),
                label: const Text('답장'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.accent,
                  foregroundColor: scheme.onPrimary,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 16, 24, 0),
          child: Divider(height: 1, color: context.lineSubtle),
        ),
        Expanded(child: MailBodyView(mail: selectedMail)),
      ],
    );
  }
}
