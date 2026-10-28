import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_provider.dart';
import '../../features/calendar/providers/event_provider.dart';
import '../../features/mail/models/mail_account.dart';
import '../../features/mail/providers/mail_provider.dart';
import 'google_auth_service.dart';

class GoogleAccount {
  final String email;

  const GoogleAccount({required this.email});
}

// 구글 로그인 상태의 단일 관리 지점
// 메일 / 캘린더 / 설정(드라이브)은 모두 이 provider로 로그인·로그아웃·토큰 조회
class GoogleAccountNotifier extends AsyncNotifier<GoogleAccount?> {
  @override
  Future<GoogleAccount?> build() async {
    final db = ref.watch(databaseProvider);
    final email = await GoogleAuthService.getSavedEmail(db);
    if (email == null) return null;
    if (!await GoogleAuthService.hasRefreshToken(db)) return null;
    return GoogleAccount(email: email);
  }

  // 로그인 성공 여부 반환
  Future<bool> signIn() async {
    print('[GoogleLogin] 1. OAuth 시작');
    final result = await GoogleAuthService.signIn();
    if (result == null) {
      print('[GoogleLogin] OAuth 실패/취소');
      return false;
    }

    print('[GoogleLogin] 2. 토큰 저장 (${result.email})');
    final db = ref.read(databaseProvider);
    await GoogleAuthService.saveTokens(db, result);
    if (!await GoogleAuthService.hasRefreshToken(db)) {
      // refresh token 없이는 1시간 뒤 모든 기능이 끊기므로 실패 처리
      print('[GoogleLogin] refresh token 없음 → 실패 처리');
      await GoogleAuthService.clearTokens(db);
      return false;
    }
    state = AsyncData(GoogleAccount(email: result.email));
    print('[GoogleLogin] 3. 로그인 상태 반영');

    // 여기부터는 부가 작업 — 실패하거나 늦어져도 로그인 자체는 성공
    try {
      await linkGmail().timeout(const Duration(seconds: 10));
      print('[GoogleLogin] 4. Gmail 연결 완료');
    } catch (e, st) {
      print('[GoogleLogin] Gmail 연결 실패(로그인은 유지): $e\n$st');
    }
    // googleCalendarProvider / mailAccountProvider는 이 provider를 watch하므로
    // 자동 갱신됨 (여기서 invalidate하면 CircularDependencyError)
    ref.invalidate(eventListProvider);
    print('[GoogleLogin] 5. 완료');
    return true;
  }

  // 이미 로그인 되어 있으면 그대로, 아니면 로그인 창
  Future<bool> ensureSignedIn() async {
    final account = await future;
    if (account != null) return true;
    return signIn();
  }

  // 로그인된 구글 계정을 메일 계정으로 연결
  Future<void> linkGmail() async {
    final account = state.value;
    if (account == null) return;
    final mailAccount = await ref.read(mailAccountProvider.future);
    if (mailAccount?.email == account.email) return;

    await ref
        .read(mailAccountProvider.notifier)
        .saveAccount(
          TaskMailAccount(
            email: account.email,
            imapServer: 'imap.gmail.com',
            imapPort: 993,
            pollIntervalMinutes: mailAccount?.pollIntervalMinutes ?? 5,
          ),
        );
    ref.invalidate(mailMessagesProvider);
  }

  Future<void> signOut() async {
    final db = ref.read(databaseProvider);
    await GoogleAuthService.clearTokens(db);
    // 레거시 키 정리
    for (final key in [
      'calendar_access_token',
      'calendar_refresh_token',
      'calendar_email',
    ]) {
      await (db.delete(db.settingTable)..where((t) => t.key.equals(key))).go();
    }

    final mailAccount = await ref.read(mailAccountProvider.future);
    if (mailAccount != null) {
      await ref.read(mailAccountProvider.notifier).deleteAccount();
    }

    state = const AsyncData(null);
    ref.invalidate(mailMessagesProvider);
    ref.invalidate(eventListProvider);
  }

  // 유효한 access token. 로그인 안 되어 있거나 갱신 실패 시 null
  Future<String?> getAccessToken() async {
    final db = ref.read(databaseProvider);
    final token = await GoogleAuthService.getAccessToken(db);
    if (token == null && state.value != null) {
      // refresh token이 무효화되어 정리된 경우 로그아웃 상태 반영
      if (await GoogleAuthService.getSavedEmail(db) == null) {
        state = const AsyncData(null);
      }
    }
    return token;
  }
}

final googleAccountProvider =
    AsyncNotifierProvider<GoogleAccountNotifier, GoogleAccount?>(
      GoogleAccountNotifier.new,
    );
