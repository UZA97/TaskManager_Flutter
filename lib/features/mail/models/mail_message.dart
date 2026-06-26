class MailMessage {
  final String subject;
  final String from;
  final String preview;
  final DateTime date;
  final bool isRead;

  const MailMessage({
    required this.subject,
    required this.from,
    required this.preview,
    required this.date,
    required this.isRead,
  });
}
