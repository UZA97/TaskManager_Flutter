import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/google_account_provider.dart';
import '../data/mail_repository.dart';
import '../models/mail_account.dart';
import '../models/mail_message.dart';
import '../services/mail_check_service.dart';

class MailAccountNotifier extends AsyncNotifier<TaskMailAccount?> {
  @override
  Future<TaskMailAccount?> build() async {
    final repo = ref.watch(mailRepositoryProvider);
    final account = await repo.getAccount();
    if (account == null || !account.isGmail) return null;

    // Gmail은 구글 로그인 상태를 따름 (토큰 없이 남은 계정 정보는 무시)
    final google = await ref.watch(googleAccountProvider.future);
    if (google == null || google.email != account.email) return null;
    return account;
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

  /// 선택한 메일을 Gmail 휴지통으로 이동. 실제로 삭제된 개수 반환
  Future<int> trash(Set<String> ids) async {
    final trashed = await ref
        .read(mailCheckServiceProvider)
        .trashMessages(ids.toList());
    if (trashed.isEmpty) return 0;

    state = AsyncData([
      for (final m in state.value ?? <MailMessage>[])
        if (!trashed.contains(m.id)) m,
    ]);
    if (trashed.contains(ref.read(selectedMailProvider)?.id)) {
      ref.read(selectedMailProvider.notifier).select(null);
    }
    return trashed.length;
  }

  /// 받은편지함 전체 읽음 처리. 처리한 개수 (실패 시 null)
  Future<int?> markAllAsRead() async {
    final count = await ref.read(mailCheckServiceProvider).markAllAsRead();
    if (count == null) return null;
    final current = state.value ?? [];
    state = AsyncData([
      for (final m in current)
        m.isRead
            ? m
            : MailMessage(
                id: m.id,
                subject: m.subject,
                from: m.from,
                preview: m.preview,
                date: m.date,
                isRead: true,
              ),
    ]);
    return count;
  }

  Future<void> markAsRead(String messageId) async {
    final service = ref.read(mailCheckServiceProvider);
    await service.markAsRead(messageId);
    // 로컬 상태 업데이트
    final current = state.value ?? [];
    state = AsyncData(
      current
          .map(
            (m) => m.id == messageId
                ? MailMessage(
                    id: m.id,
                    subject: m.subject,
                    from: m.from,
                    preview: m.preview,
                    date: m.date,
                    isRead: true,
                  )
                : m,
          )
          .toList(),
    );
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
