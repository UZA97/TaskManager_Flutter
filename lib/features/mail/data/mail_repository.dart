import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../models/mail_account.dart';
import 'package:drift/drift.dart';

class MailRepository {
  final AppDatabase _db;

  MailRepository(this._db);

  Future<TaskMailAccount?> getAccount() async {
    final row = await (_db.select(
      _db.settingTable,
    )..where((t) => t.key.equals('mail_account'))).getSingleOrNull();
    if (row == null) return null;
    return TaskMailAccount.fromJson(jsonDecode(row.value));
  }

  Future<void> saveAccount(TaskMailAccount account) async {
    await _db
        .into(_db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(
            key: 'mail_account',
            value: jsonEncode(account.toJson()),
          ),
        );
  }

  Future<void> deleteAccount() async {
    await (_db.delete(
      _db.settingTable,
    )..where((t) => t.key.equals('mail_account'))).go();
  }
}

final mailRepositoryProvider = Provider<MailRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return MailRepository(db);
});
