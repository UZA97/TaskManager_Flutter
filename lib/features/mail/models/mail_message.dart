import 'dart:typed_data';

class MailMessage {
  final String id;
  final String threadId;
  final String subject;
  final String from;
  final String preview;
  final DateTime date;
  final bool isRead;

  const MailMessage({
    required this.id,
    this.threadId = '',
    required this.subject,
    required this.from,
    required this.preview,
    required this.date,
    required this.isRead,
  });

  MailMessage asRead() => MailMessage(
    id: id,
    threadId: threadId,
    subject: subject,
    from: from,
    preview: preview,
    date: date,
    isRead: true,
  );
}

/// 메일 본문. 원래 글자 인코딩(utf-8, euc-kr 등) 그대로의 바이트.
/// 글자 변환은 본문을 보여 주는 웹뷰가 [charset]을 보고 함.
class MailBody {
  final Uint8List bytes;
  final String charset;
  final bool isHtml;

  const MailBody({
    required this.bytes,
    required this.charset,
    required this.isHtml,
  });
}
