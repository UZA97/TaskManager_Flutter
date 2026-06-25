import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mail_repository.dart';
import '../models/mail_account.dart';
import '../services/mail_check_service.dart';

class MailAccountNotifier extends AsyncNotifier<TaskMailAccount?> {
  @override
  Future<TaskMailAccount?> build() async {
    final repo = ref.watch(mailRepositoryProvider);
    return repo.getAccount();
  }

  Future<void> saveAccount(TaskMailAccount account) async {
    final repo = ref.read(mailRepositoryProvider);
    await repo.saveAccount(account);

    // 폴링 서비스 재시작
    final service = ref.read(mailCheckServiceProvider);
    service.start(account);

    state = AsyncData(account);
  }

  Future<void> deleteAccount() async {
    final repo = ref.read(mailRepositoryProvider);
    await repo.deleteAccount();

    final service = ref.read(mailCheckServiceProvider);
    service.stop();

    state = const AsyncData(null);
  }
}

final mailAccountProvider =
    AsyncNotifierProvider<MailAccountNotifier, TaskMailAccount?>(
      MailAccountNotifier.new,
    );
