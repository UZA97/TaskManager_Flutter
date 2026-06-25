import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mail_account.dart';
import '../providers/mail_provider.dart';
import '../services/mail_check_service.dart';

enum MailPlatform { gmail, outlook }

class MailSettingsView extends ConsumerStatefulWidget {
  const MailSettingsView({super.key});

  @override
  ConsumerState<MailSettingsView> createState() => _MailSettingsViewState();
}

class _MailSettingsViewState extends ConsumerState<MailSettingsView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  MailPlatform _selectedPlatform = MailPlatform.gmail;
  bool _showPassword = false;
  int _pollInterval = 5;
  bool _isTesting = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _imapServer => _selectedPlatform == MailPlatform.gmail
      ? 'imap.gmail.com'
      : 'imap-mail.outlook.com';

  String get _platformName =>
      _selectedPlatform == MailPlatform.gmail ? 'Gmail' : 'Outlook';

  String get _emailHint => _selectedPlatform == MailPlatform.gmail
      ? 'example@gmail.com'
      : 'example@outlook.com';

  Future<void> _testConnection() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('이메일과 비밀번호를 입력하세요', isError: true);
      return;
    }

    setState(() => _isTesting = true);

    final account = TaskMailAccount(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      imapServer: _imapServer,
      imapPort: 993,
      pollIntervalMinutes: _pollInterval,
    );

    final service = ref.read(mailCheckServiceProvider);
    final success = await service.testConnection(account);

    setState(() => _isTesting = false);

    if (success) {
      _showSnackBar('연결 성공!');
    } else {
      _showSnackBar('연결 실패. 이메일/비밀번호를 확인하세요', isError: true);
    }
  }

  Future<void> _save() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('모든 항목을 입력하세요', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final account = TaskMailAccount(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      imapServer: _imapServer,
      imapPort: 993,
      pollIntervalMinutes: _pollInterval,
    );

    await ref.read(mailAccountProvider.notifier).saveAccount(account);
    setState(() => _isSaving = false);
    _showSnackBar('저장되었습니다');
  }

  Future<void> _logout() async {
    await ref.read(mailAccountProvider.notifier).deleteAccount();
    _emailController.clear();
    _passwordController.clear();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF4A90E2),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF4A90E2)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(mailAccountProvider);

    return accountAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (account) {
        if (account != null) {
          return _buildLoggedInView(account);
        }
        return _buildLoginView();
      },
    );
  }

  // 로그인 후 화면
  Widget _buildLoggedInView(TaskMailAccount account) {
    final isGmail = account.imapServer == 'imap.gmail.com';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '메일 계정',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),

          // 계정 카드
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDDDDDD)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // 플랫폼 아이콘
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isGmail
                        ? const Color(0xFFEA4335).withOpacity(0.1)
                        : const Color(0xFF0078D4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.mail,
                    color: isGmail
                        ? const Color(0xFFEA4335)
                        : const Color(0xFF0078D4),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // 계정 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGmail ? 'Gmail' : 'Outlook',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.email,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${account.pollIntervalMinutes}분마다 확인',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // 연결 상태
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.green, size: 8),
                      SizedBox(width: 4),
                      Text(
                        '연결됨',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 로그아웃 버튼
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('로그아웃'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // 로그인 화면
  Widget _buildLoginView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16), // 24 → 16으로 줄임
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '메일 계정 설정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 플랫폼 선택 — 세로로 배치
          const Text('플랫폼', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Column(
            // Row → Column으로 변경
            children: [
              _PlatformButton(
                label: 'Gmail',
                color: const Color(0xFFEA4335),
                isSelected: _selectedPlatform == MailPlatform.gmail,
                onTap: () =>
                    setState(() => _selectedPlatform = MailPlatform.gmail),
              ),
              const SizedBox(height: 8),
              _PlatformButton(
                label: 'Outlook',
                color: const Color(0xFF0078D4),
                isSelected: _selectedPlatform == MailPlatform.outlook,
                onTap: () =>
                    setState(() => _selectedPlatform = MailPlatform.outlook),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 이메일
          const Text(
            '이메일 주소',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            decoration: _inputDecoration(_emailHint),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),

          // 비밀번호
          const Text(
            '앱 비밀번호',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: _inputDecoration('App Password').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 폴링 주기 — Wrap으로
          const Text(
            '폴링 주기',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [3, 5, 10, 30].map((min) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<int>(
                    value: min,
                    groupValue: _pollInterval,
                    onChanged: (v) => setState(() => _pollInterval = v!),
                    activeColor: const Color(0xFF4A90E2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Text('$min분', style: const TextStyle(fontSize: 12)),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // 안내
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Color(0xFFF9A825),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selectedPlatform == MailPlatform.gmail
                        ? 'Google 계정 → 보안 → 앱 비밀번호에서 발급하세요.'
                        : 'Microsoft 계정 → 보안 → 앱 비밀번호에서 발급하세요.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFF9A825),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 버튼 — 세로로
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isTesting ? null : _testConnection,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF4A90E2)),
                foregroundColor: const Color(0xFF4A90E2),
              ),
              child: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('연결 테스트'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}

// 플랫폼 선택 버튼
class _PlatformButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlatformButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : const Color(0xFFDDDDDD),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mail, color: isSelected ? color : Colors.grey, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
