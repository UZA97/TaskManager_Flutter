import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mail_repository.dart';
import '../models/mail_account.dart';
import '../models/mail_message.dart';
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

class MailMessagesNotifier extends AsyncNotifier<List<MailMessage>> {
  @override
  Future<List<MailMessage>> build() async {
    final service = ref.watch(mailCheckServiceProvider);
    return service.fetchMessages();
  }

  Future<void> loadMore() async {
    final service = ref.read(mailCheckServiceProvider);
    final token = service.nextPageToken;
    if (token == null) return;

    final current = state.value ?? [];
    final more = await service.fetchMessages(pageToken: token);
    state = AsyncData([...current, ...more]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      final service = ref.read(mailCheckServiceProvider);
      return service.fetchMessages();
    });
  }
}

class SelectedMailNotifier extends Notifier<MailMessage?> {
  @override
  MailMessage? build() => null;

  void select(MailMessage? message) => state = message;
}

final selectedMailProvider =
    NotifierProvider<SelectedMailNotifier, MailMessage?>(
  SelectedMailNotifier.new,
);
final mailMessagesProvider =
    AsyncNotifierProvider<MailMessagesNotifier, List<MailMessage>>(
  MailMessagesNotifier.new,
);

final mailAccountProvider =
    AsyncNotifierProvider<MailAccountNotifier, TaskMailAccount?>(
  MailAccountNotifier.new,
);
