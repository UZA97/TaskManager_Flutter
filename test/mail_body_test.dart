import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/features/mail/models/mail_message.dart';
import 'package:taskmanager/features/mail/services/mail_check_service.dart';
import 'package:taskmanager/features/mail/views/mail_detail_view.dart';
import 'package:taskmanager/features/mail/widgets/mail_body_view.dart';

void main() {
  test('mail date comes from internalDate, not the RFC 2822 header', () {
    final received = DateTime(2026, 11, 24, 10, 0);
    final mail = parseGmailMessage('m1', {
      'threadId': 't1',
      'internalDate': '${received.millisecondsSinceEpoch}',
      'snippet': 'hi',
      'labelIds': ['INBOX', 'UNREAD'],
      'payload': {
        'headers': [
          {'name': 'Subject', 'value': '제목'},
          {'name': 'From', 'value': 'a@b.c'},
          {'name': 'Date', 'value': 'Tue, 24 Nov 2026 10:00:00 +0900'},
        ],
      },
    })!;
    expect(mail.date, received);
    expect(mail.threadId, 't1');
    expect(mail.isRead, isFalse);
    expect(mail.asRead().threadId, 't1');
  });

  test('finds html part before plain, skips attachments, reads charset', () {
    final payload = {
      'mimeType': 'multipart/mixed',
      'parts': [
        {
          'mimeType': 'multipart/alternative',
          'parts': [
            {
              'mimeType': 'text/plain',
              'filename': '',
              'headers': [
                {'name': 'Content-Type', 'value': 'text/plain; charset=UTF-8'},
              ],
            },
            {
              'mimeType': 'text/html',
              'filename': '',
              'headers': [
                {
                  'name': 'Content-Type',
                  'value': 'text/html; charset="ks_c_5601-1987"',
                },
              ],
            },
          ],
        },
        {'mimeType': 'text/html', 'filename': 'attached.html'},
      ],
    };
    final html = findMailBodyPart(payload, 'text/html')!;
    expect(html['filename'], '');
    expect(mailPartCharset(html), 'ks_c_5601-1987');
    final plain = findMailBodyPart(payload, 'text/plain')!;
    expect(mailPartCharset(plain), 'UTF-8');
    expect(mailPartCharset(const {'headers': []}), 'utf-8');
  });

  test('page keeps original bytes and escapes plain text', () {
    // euc-kr "한" = B7 E5 (웹뷰가 charset을 보고 글자로 바꿈)
    final html = String.fromCharCodes(
      mailPageBytes(
        MailBody(
          bytes: Uint8List.fromList([0x3C, 0x62, 0x3E, 0xB7, 0xE5]),
          charset: 'euc-kr',
          isHtml: true,
        ),
      ),
    );
    expect(html, contains('<meta charset="euc-kr">'));
    expect(html, contains("script-src 'none'"));
    expect(html, contains('<b>·å'));

    final plain = latin1.decode(
      mailPageBytes(
        MailBody(
          bytes: Uint8List.fromList(utf8.encode('a<b & c>')),
          charset: 'utf-8"><script>',
          isHtml: false,
        ),
      ),
    );
    expect(plain, contains('a&lt;b &amp; c&gt;'));
    expect(plain, contains('<meta charset="utf-8script">'));
  });

  test('reply opens the thread for the signed-in account', () {
    expect(
      gmailThreadUrl('me@gmail.com', 'abc123').toString(),
      'https://mail.google.com/mail/?authuser=me%40gmail.com#all/abc123',
    );
    expect(gmailThreadUrl('', '').toString(), 'https://mail.google.com/mail/');
  });
}
