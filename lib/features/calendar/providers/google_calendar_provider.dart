import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../mail/services/google_auth_service.dart';
import '../providers/event_provider.dart';
import '../../../core/database/database.dart';

class GoogleCalendarNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final db = ref.watch(databaseProvider);
    final row = await (db.select(
      db.settingTable,
    )..where((t) => t.key.equals('calendar_access_token'))).getSingleOrNull();
    return row != null && row.value.isNotEmpty;
  }

  Future<void> connect() async {
    final authService = GoogleAuthService();
    final result = await authService.signInForCalendar();
    if (result == null) return;

    final db = ref.read(databaseProvider);
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(
            key: 'calendar_access_token',
            value: result.accessToken,
          ),
        );
    if (result.refreshToken != null) {
      await db
          .into(db.settingTable)
          .insertOnConflictUpdate(
            SettingTableCompanion.insert(
              key: 'calendar_refresh_token',
              value: result.refreshToken!,
            ),
          );
    }
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(
            key: 'calendar_email',
            value: result.email,
          ),
        );

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
