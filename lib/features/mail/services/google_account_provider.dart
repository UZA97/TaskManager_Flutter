import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../calendar/providers/google_calendar_provider.dart';
import '../providers/mail_provider.dart';
import 'google_auth_service.dart';

class GoogleAccount {
  final String email;
  final String accessToken;

  const GoogleAccount({required this.email, required this.accessToken});
}

class GoogleAccountNotifier extends AsyncNotifier<GoogleAccount?> {
  @override
  Future<GoogleAccount?> build() async {
    final db = ref.watch(databaseProvider);
    final email = await GoogleAuthService.getSavedEmail(db);
    if (email == null) return null;
    final token = await GoogleAuthService.getAccessToken(
      db,
      GoogleAuthService(),
    );
    if (token == null) return null;
    return GoogleAccount(email: email, accessToken: token);
  }

  Future<void> signIn() async {
    final authService = GoogleAuthService();
    final result = await authService.signIn();
    if (result == null) return;

    final db = ref.read(databaseProvider);
    await GoogleAuthService.saveTokens(db, result);
    state = AsyncData(
      GoogleAccount(email: result.email, accessToken: result.accessToken),
    );

    // 메일/캘린더 provider 갱신
    ref.invalidate(mailAccountProvider);
    ref.invalidate(googleCalendarProvider);
  }

  Future<void> signOut() async {
    final db = ref.read(databaseProvider);
    // 기존 키들
    await GoogleAuthService.clearTokens(db);
    // 레거시 키 정리
    for (final key in [
      'calendar_access_token',
      'calendar_refresh_token',
      'calendar_email',
      'mail_account',
    ]) {
      await (db.delete(db.settingTable)..where((t) => t.key.equals(key))).go();
    }
    state = const AsyncData(null);
    ref.invalidate(mailAccountProvider);
    ref.invalidate(googleCalendarProvider);
  }
}

final googleAccountProvider =
    AsyncNotifierProvider<GoogleAccountNotifier, GoogleAccount?>(
      GoogleAccountNotifier.new,
    );
