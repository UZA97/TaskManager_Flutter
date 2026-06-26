import 'package:flutter/material.dart';
import '../../mail/widgets/mail_login_dialog.dart';
import '../../mail/providers/mail_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(mailAccountProvider);
    final isLoggedIn = accountAsync.value != null;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '설정',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text('메일', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.mail,
              color: isLoggedIn ? const Color(0xFF4A90E2) : Colors.grey,
            ),
            title: Text(isLoggedIn ? accountAsync.value!.email : '계정 없음'),
            subtitle: Text(
              isLoggedIn ? '연결됨' : '로그인이 필요합니다',
              style: TextStyle(
                color: isLoggedIn ? Colors.green : Colors.grey,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showMailLoginDialog(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFFDDDDDD)),
            ),
          ),
        ],
      ),
    );
  }
}
