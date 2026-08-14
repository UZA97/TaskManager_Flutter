import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../mail/services/google_account_provider.dart';
import '../../mail/services/google_auth_service.dart';
import '../providers/event_provider.dart';

class GoogleCalendarNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final db = ref.watch(databaseProvider);
    final email = await GoogleAuthService.getSavedEmail(db);
    return email != null;
  }

  Future<void> connect() async {
    // 이미 구글 로그인 되어있으면 바로 연동
    final account = ref.read(googleAccountProvider).value;
    if (account != null) {
      state = const AsyncData(true);
      ref.invalidate(eventListProvider);
      return;
    }
    // 안되어있으면 로그인 요청
    await ref.read(googleAccountProvider.notifier).signIn();
    state = const AsyncData(true);
    ref.invalidate(eventListProvider);
  }

  Future<void> disconnect() async {
    final db = ref.read(databaseProvider);
    for (final key in [
      'calendar_access_token',
      'calendar_refresh_token',
      'calendar_email',
    ]) {
      await (db.delete(db.settingTable)..where((t) => t.key.equals(key))).go();
    }
    state = const AsyncData(false);
  }
}

final googleCalendarProvider =
    AsyncNotifierProvider<GoogleCalendarNotifier, bool>(
      GoogleCalendarNotifier.new,
    );
