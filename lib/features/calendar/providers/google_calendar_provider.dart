import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../mail/data/mail_repository.dart';
import '../../mail/services/google_auth_service.dart';
import '../providers/event_provider.dart';

class GoogleCalendarNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final mailRepo = ref.watch(mailRepositoryProvider);
    final account = await mailRepo.getAccount();
    return account != null && !account.isOutlook;
  }

  Future<void> connect() async {
    final authService = GoogleAuthService();
    final result = await authService.signIn();
    if (result == null) return;

    // 기존 mail account에 token 업데이트 or 새로 저장
    final mailRepo = ref.read(mailRepositoryProvider);
    final existing = await mailRepo.getAccount();

    if (existing != null && !existing.isOutlook) {
      // 이미 Gmail 계정 있으면 token만 업데이트
      await mailRepo.saveAccount(
        existing.copyWith(
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
        ),
      );
    }

    state = const AsyncData(true);
    ref.invalidate(eventListProvider);
  }

  Future<void> disconnect() async {
    state = const AsyncData(false);
  }
}

final googleCalendarProvider =
    AsyncNotifierProvider<GoogleCalendarNotifier, bool>(
      GoogleCalendarNotifier.new,
    );
