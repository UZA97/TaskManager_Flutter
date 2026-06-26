import 'dart:convert';
import 'package:enough_mail/enough_mail.dart' as enough_mail;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notification/notification_service.dart';
import '../data/mail_repository.dart';
import '../models/mail_account.dart';
import 'google_auth_service.dart';
import '../models/mail_message.dart';

class MailCheckService {
  enough_mail.MailClient? _mailClient;
  final MailRepository _repo;
  final GoogleAuthService _authService = GoogleAuthService();

  MailCheckService(this._repo);

  Future<void> start(TaskMailAccount account) async {
    await stop();

    try {
      final accessToken = await _getValidAccessToken(account);
      if (accessToken == null) return;

      final auth = enough_mail.OauthAuthentication(
        account.email,
        enough_mail.OauthToken(
          accessToken: accessToken,
          expiresIn: 3600,
          refreshToken: account.refreshToken ?? '',
          scope: 'https://mail.google.com/',
          tokenType: 'Bearer',
          created: DateTime.now().toUtc(),
        ),
      );

      final mailAccount = enough_mail.MailAccount.fromManualSettingsWithAuth(
        name: account.email,
        email: account.email,
        userName: account.email,
        incomingHost: account.imapServer,
        outgoingHost: 'smtp.gmail.com',
        auth: auth,
        incomingType: enough_mail.ServerType.imap,
        outgoingType: enough_mail.ServerType.smtp,
        incomingPort: account.imapPort,
        outgoingPort: 465,
        incomingSocketType: enough_mail.SocketType.ssl,
        outgoingSocketType: enough_mail.SocketType.ssl,
      );

      _mailClient = enough_mail.MailClient(mailAccount, isLogEnabled: false);
      await _mailClient!.connect();
      await _mailClient!.selectInbox();

      _mailClient!.eventBus.on<enough_mail.MailLoadEvent>().listen((event) {
        final subject = event.message.decodeSubject() ?? '(제목 없음)';
        final from = event.message.fromEmail ?? account.email;
        NotificationService.show(title: '📧 새 메일 - $from', body: subject);
      });

      await _mailClient!.startPolling(
        Duration(minutes: account.pollIntervalMinutes),
      );
    } catch (e) {
      print('MailCheckService error: $e');
    }
  }

  Future<List<MailMessage>> fetchMessages({int count = 20}) async {
    final account = await _repo.getAccount();
    if (account == null) return [];

    try {
      final accessToken = await _getValidAccessToken(account);
      if (accessToken == null) return [];

      final auth = enough_mail.OauthAuthentication(
        account.email,
        enough_mail.OauthToken(
          accessToken: accessToken,
          expiresIn: 3600,
          refreshToken: account.refreshToken ?? '',
          scope: 'https://mail.google.com/',
          tokenType: 'Bearer',
          created: DateTime.now().toUtc(),
        ),
      );

      final mailAccount = enough_mail.MailAccount.fromManualSettingsWithAuth(
        name: account.email,
        email: account.email,
        userName: account.email,
        incomingHost: account.imapServer,
        outgoingHost: 'smtp.gmail.com',
        auth: auth,
        incomingType: enough_mail.ServerType.imap,
        outgoingType: enough_mail.ServerType.smtp,
        incomingPort: account.imapPort,
        outgoingPort: 465,
        incomingSocketType: enough_mail.SocketType.ssl,
        outgoingSocketType: enough_mail.SocketType.ssl,
      );

      final client = enough_mail.MailClient(mailAccount, isLogEnabled: false);
      await client.connect();
      await client.selectInbox();

      final messages = await client.fetchMessages(
        count: count,
        fetchPreference: enough_mail.FetchPreference.envelope,
      );

      await client.disconnect();

      return messages.map((msg) {
        return MailMessage(
          subject: msg.decodeSubject() ?? '(제목 없음)',
          from: msg.fromEmail ?? '',
          preview:
              msg.decodeTextPlainPart()?.substring(
                0,
                msg.decodeTextPlainPart()!.length > 100
                    ? 100
                    : msg.decodeTextPlainPart()!.length,
              ) ??
              '',
          date: msg.decodeDate() ?? DateTime.now(),
          isRead: msg.isSeen ?? false,
        );
      }).toList();
    } catch (e) {
      print('fetchMessages error: $e');
      return [];
    }
  }

  Future<String?> _getValidAccessToken(TaskMailAccount account) async {
    if (account.accessToken != null) return account.accessToken;
    if (account.refreshToken == null) return null;

    final newToken = await _authService.refreshAccessToken(
      account.refreshToken!,
    );
    if (newToken != null) {
      final updated = account.copyWith(accessToken: newToken);
      await _repo.saveAccount(updated);
    }
    return newToken;
  }

  Future<void> stop() async {
    await _mailClient?.stopPolling();
    await _mailClient?.disconnect();
    _mailClient = null;
  }

  Future<bool> testConnection(TaskMailAccount account) async {
    try {
      final accessToken = await _getValidAccessToken(account);
      if (accessToken == null) return false;

      final auth = enough_mail.OauthAuthentication(
        account.email,
        enough_mail.OauthToken(
          accessToken: accessToken,
          expiresIn: 3600,
          refreshToken: account.refreshToken ?? '',
          scope: 'https://mail.google.com/',
          tokenType: 'Bearer',
          created: DateTime.now().toUtc(),
        ),
      );

      final mailAccount = enough_mail.MailAccount.fromManualSettingsWithAuth(
        name: account.email,
        email: account.email,
        userName: account.email,
        incomingHost: account.imapServer,
        outgoingHost: 'smtp.gmail.com',
        auth: auth,
        incomingType: enough_mail.ServerType.imap,
        outgoingType: enough_mail.ServerType.smtp,
        incomingPort: account.imapPort,
        outgoingPort: 465,
        incomingSocketType: enough_mail.SocketType.ssl,
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
