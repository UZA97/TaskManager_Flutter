import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/features/briefing/briefing_sources.dart';

void main() {
  test('Google 뉴스 RSS 파싱: 언론사 분리, 엔티티 복원, 개수 제한', () {
    const rss = '''
<rss><channel><title>Google 뉴스</title>
<item><title>“특검” 현장검증 시작 &amp; 논란 - 경향신문</title><link>https://news.google.com/a?oc=5&amp;x=1</link></item>
<item><title><![CDATA[CDATA 제목 - 한겨레]]></title><link>https://news.google.com/b</link></item>
<item><title>언론사 없음</title><link>https://news.google.com/c</link></item>
</channel></rss>''';

    final items = parseNewsRss(rss, count: 2);
    expect(items.length, 2);
    expect(items[0].title, '“특검” 현장검증 시작 & 논란');
    expect(items[0].source, '경향신문');
    expect(items[0].url, 'https://news.google.com/a?oc=5&x=1');
    expect(items[1].title, 'CDATA 제목');
    expect(items[1].source, '한겨레');

    final all = parseNewsRss(rss);
    expect(all[2].title, '언론사 없음');
    expect(all[2].source, '');
  });

  test('이번 주 = 월요일 ~ 일요일 (월·주 경계 포함)', () {
    expect(currentWeek(DateTime(2026, 10, 28, 15)), (
      DateTime(2026, 10, 26),
      DateTime(2026, 11, 1),
    ));
    // 월요일, 일요일 당일
    expect(currentWeek(DateTime(2026, 10, 26)).$1, DateTime(2026, 10, 26));
    expect(currentWeek(DateTime(2026, 11, 1)).$1, DateTime(2026, 10, 26));
    // 연도 경계
    expect(currentWeek(DateTime(2027, 1, 1)), (
      DateTime(2026, 12, 28),
      DateTime(2027, 1, 3),
    ));
  });

  test('날씨 코드 → 설명', () {
    expect(weatherInfo(0).$1, '맑음');
    expect(weatherInfo(61).$1, '비');
    expect(weatherInfo(73).$1, '눈');
    expect(weatherInfo(1234).$1, '알 수 없음');
  });
}
