class TaskMailAccount {
  final String email;
  final String imapServer;
  final int imapPort;
  final int pollIntervalMinutes;
  final String? accessToken;
  final String? refreshToken;

  const TaskMailAccount({
    required this.email,
    required this.imapServer,
    required this.imapPort,
    this.pollIntervalMinutes = 1,
    this.accessToken,
    this.refreshToken,
  });

  bool get isOutlook => imapServer == 'outlook';

  // password 제거, token 기반으로 변경
  factory TaskMailAccount.fromJson(Map<String, dynamic> json) {
    return TaskMailAccount(
      email: json['email'] as String,
      imapServer: json['imapServer'] as String,
      imapPort: json['imapPort'] as int,
      pollIntervalMinutes: json['pollIntervalMinutes'] as int? ?? 5,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'email': email,
    'imapServer': imapServer,
    'imapPort': imapPort,
    'pollIntervalMinutes': pollIntervalMinutes,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };

  TaskMailAccount copyWith({
    String? accessToken,
    String? refreshToken,
    int? pollIntervalMinutes,
  }) => TaskMailAccount(
    email: email,
    imapServer: imapServer,
    imapPort: imapPort,
    pollIntervalMinutes: pollIntervalMinutes ?? this.pollIntervalMinutes,
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
  );
}
