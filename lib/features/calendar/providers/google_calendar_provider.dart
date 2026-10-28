import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/google_account_provider.dart';
import '../../../core/database/database_provider.dart';
import '../providers/event_provider.dart';

class GoogleCalendarNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final account = await ref.watch(googleAccountProvider.future);
    return account != null;
  }

  // 구글 로그인은 googleAccountProvider에서만 처리
  Future<void> connect() async {
    final ok = await ref.read(googleAccountProvider.notifier).ensureSignedIn();
    state = AsyncData(ok);
    if (ok) ref.invalidate(eventListProvider);
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
