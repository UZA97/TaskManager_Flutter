import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/mail_provider.dart';
import '../widgets/mail_login_dialog.dart';

class MailView extends ConsumerWidget {
  const MailView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(mailAccountProvider);

    return accountAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (account) {
        if (account == null) {
          return _buildNotLoggedInView(context);
        }
        return _buildMailListView(account.email);
      },
    );
  }

  Widget _buildNotLoggedInView(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMailListView(String email) {
    // 추후 메일 목록 구현
    return Center(
      child: Text(
        '$email 로그인됨\n메일 목록 준비중',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}
