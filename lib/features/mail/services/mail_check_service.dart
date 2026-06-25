import 'dart:async';
import 'package:enough_mail/enough_mail.dart' as enough_mail;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notification/notification_service.dart';
import '../data/mail_repository.dart';
import '../models/mail_account.dart';

class MailCheckService {
  enough_mail.MailClient? _mailClient;
  final MailRepository _repo;

  MailCheckService(this._repo);

  Future<void> start(TaskMailAccount account) async {
    await stop();

    try {
      final mailAccount = enough_mail.MailAccount.fromManualSettings(
        name: account.email,
        email: account.email,
        userName: account.email,
        password: account.password,
        incomingHost: account.imapServer,
        incomingPort: account.imapPort,
        incomingType: enough_mail.ServerType.imap,
        incomingSocketType: enough_mail.SocketType.ssl,
        outgoingHost: '',
        outgoingPort: 465,
        outgoingType: enough_mail.ServerType.smtp,
        outgoingSocketType: enough_mail.SocketType.ssl,
      );

      _mailClient = enough_mail.MailClient(mailAccount, isLogEnabled: false);

      await _mailClient!.connect();
      await _mailClient!.selectInbox();

      // 새 메일 이벤트 리스너
      _mailClient!.eventBus.on<enough_mail.MailLoadEvent>().listen((event) {
        final subject = event.message.decodeSubject() ?? '(제목 없음)';
        final from = event.message.fromEmail ?? account.email;
        NotificationService.show(title: '📧 새 메일 - $from', body: subject);
      });

      // 폴링 시작
      await _mailClient!.startPolling(
        Duration(minutes: account.pollIntervalMinutes),
      );
    } catch (e) {
      // 연결 실패 시 조용히 무시
    }
  }

  Future<void> stop() async {
    await _mailClient?.stopPolling();
    await _mailClient?.disconnect();
    _mailClient = null;
  }

  Future<bool> testConnection(TaskMailAccount account) async {
    try {
      final mailAccount = enough_mail.MailAccount.fromManualSettings(
        name: account.email,
        email: account.email,
        userName: account.email,
        password: account.password,
        incomingHost: account.imapServer,
        incomingPort: account.imapPort,
        incomingType: enough_mail.ServerType.imap,
        incomingSocketType: enough_mail.SocketType.ssl,
        outgoingHost: '',
        outgoingPort: 465,
        outgoingType: enough_mail.ServerType.smtp,
        outgoingSocketType: enough_mail.SocketType.ssl,
      );

      final client = enough_mail.MailClient(mailAccount, isLogEnabled: false);
      await client.connect();
      await client.disconnect();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final mailCheckServiceProvider = Provider<MailCheckService>((ref) {
  final repo = ref.watch(mailRepositoryProvider);
  return MailCheckService(repo);
});
