class TaskMailAccount {
  final String email;
  final String password;
  final String imapServer;
  final int imapPort;
  final int pollIntervalMinutes;

  const TaskMailAccount({
    required this.email,
    required this.password,
    required this.imapServer,
    required this.imapPort,
    this.pollIntervalMinutes = 5,
  });

  factory TaskMailAccount.fromJson(Map<String, dynamic> json) {
    return TaskMailAccount(
      email: json['email'] as String,
      password: json['password'] as String,
      imapServer: json['imapServer'] as String,
      imapPort: json['imapPort'] as int,
      pollIntervalMinutes: json['pollIntervalMinutes'] as int? ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'imapServer': imapServer,
      'imapPort': imapPort,
      'pollIntervalMinutes': pollIntervalMinutes,
    };
  }

  static String inferImapServer(String email) {
    if (email.endsWith('@gmail.com')) return 'imap.gmail.com';
    if (email.endsWith('@outlook.com') ||
        email.endsWith('@hotmail.com') ||
        email.endsWith('@live.com'))
      return 'imap-mail.outlook.com';
    return '';
  }
}
