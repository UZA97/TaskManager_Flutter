import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/mail_provider.dart';
import '../services/google_auth_service.dart';
import '../models/mail_account.dart';

class MailLoginDialog extends ConsumerStatefulWidget {
  const MailLoginDialog({super.key});

  @override
  ConsumerState<MailLoginDialog> createState() => _MailLoginDialogState();
}

class _MailLoginDialogState extends ConsumerState<MailLoginDialog> {
  bool _isGoogleLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final result = await GoogleAuthService().signIn();
      if (result == null) {
        if (mounted) _showSnackBar('로그인 실패', isError: true);
        return;
      }

      final account = TaskMailAccount(
        email: result.email,
        imapServer: 'imap.gmail.com',
        imapPort: 993,
        pollIntervalMinutes: 5,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );

      await ref.read(mailAccountProvider.notifier).saveAccount(account);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showSnackBar('로그인 실패: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(mailAccountProvider.notifier).deleteAccount();
    if (mounted) Navigator.pop(context);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF4A90E2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(mailAccountProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        child: accountAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
          data: (account) =>
              account != null ? _buildLoggedInView(account) : _buildLoginView(),
        ),
      ),
    );
  }

  Widget _buildLoginView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '메일 계정 연동',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          '계정을 연동하면 새 메일 알림을 받을 수 있어요',
          style: TextStyle(fontSize: 13, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Google 로그인
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isGoogleLoading ? null : _signInWithGoogle,
            icon: _isGoogleLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.mail, size: 18),
            label: const Text('Google로 로그인'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA4335),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Outlook (준비중)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: null, // 준비중
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('Outlook (준비중)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0078D4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              disabledBackgroundColor: const Color(0xFF0078D4).withOpacity(0.4),
              disabledForegroundColor: Colors.white54,
            ),
          ),
        ),
        const SizedBox(height: 16),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  Widget _buildLoggedInView(TaskMailAccount account) {
    final isGmail = account.imapServer == 'imap.gmail.com';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '메일 계정',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        // 계정 카드
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDDDDD)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isGmail
                      ? const Color(0xFFEA4335).withOpacity(0.1)
                      : const Color(0xFF0078D4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.mail,
                  color: isGmail
                      ? const Color(0xFFEA4335)
                      : const Color(0xFF0078D4),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGmail ? 'Gmail' : 'Outlook',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      account.email,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.green, size: 6),
                    SizedBox(width: 4),
                    Text(
                      '연결됨',
                      style: TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('로그아웃'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                ),
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// 팝업 띄우는 헬퍼 함수
Future<void> showMailLoginDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (context) => const MailLoginDialog(),
  );
}
