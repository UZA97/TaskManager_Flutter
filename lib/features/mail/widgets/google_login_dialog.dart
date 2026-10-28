import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/google_account_provider.dart';

class GoogleLoginDialog extends ConsumerStatefulWidget {
  const GoogleLoginDialog({super.key});

  @override
  ConsumerState<GoogleLoginDialog> createState() => _GoogleLoginDialogState();
}

class _GoogleLoginDialogState extends ConsumerState<GoogleLoginDialog> {
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    String? error;
    try {
      final ok = await ref.read(googleAccountProvider.notifier).signIn();
      if (!ok) error = 'Google 로그인에 실패했습니다. 다시 시도해주세요';
    } catch (e, st) {
      // 예외가 나도 스피너가 멈춰 있지 않도록
      print('[GoogleLogin] 팝업 로그인 예외: $e\n$st');
      error = 'Google 로그인 중 오류가 발생했습니다: $e';
    }
    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 앱 아이콘
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.task_alt,
                size: 40,
                color: Color(0xFF4A90E2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'TaskManager',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '메모, 캘린더, 메일을 한 곳에서',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // 구글 로그인 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 1,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.g_mobiledata,
                            size: 24,
                            color: Color(0xFF4285F4),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Google로 로그인',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // 게스트 버튼
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: const BorderSide(color: Color(0xFFDDDDDD)),
                ),
                child: const Text(
                  '게스트로 시작',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '게스트는 메일 연동 없이 메모, 캘린더, 지도를 사용할 수 있어요',
              style: TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
