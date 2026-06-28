class MailMessage {
  final String id;
  final String subject;
  final String from;
  final String preview;
  final DateTime date;
  final bool isRead;

  const MailMessage({
    required this.id,
    required this.subject,
    required this.from,
    required this.preview,
    required this.date,
    required this.isRead,
  });
}
