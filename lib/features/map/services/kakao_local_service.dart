import 'dart:convert';
import 'package:http/http.dart' as http;
import 'location_search_result.dart';

const _kakaoApiKey = '1f92288a5ce8ee39198cccbc8632fec5';

class KakaoLocalService {
  static const _baseUrl = 'https://dapi.kakao.com/v2/local';

  Map<String, String> get _headers => {
    'Authorization': 'KakaoAK $_kakaoApiKey',
  };

  // 키워드 검색 (장소)
  Future<List<LocationSearchResult>> search(String query) async {
    final uri = Uri.parse(
      '$_baseUrl/search/keyword.json'
      '?query=$query'
      '&size=10',
    );

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) throw Exception('검색 실패');

    final data = jsonDecode(response.body);
    final items = data['documents'] as List<dynamic>? ?? [];

    return items.map((item) {
      return LocationSearchResult(
        name: item['place_name'] as String,
        address:
            item['road_address_name'] as String? ??
            item['address_name'] as String? ??
            '',
        lat: double.parse(item['y'] as String),
        lng: double.parse(item['x'] as String),
      );
    }).toList();
  }

  Future<List<LocationSearchResult>> searchByCategory({
    required String categoryCode,
    required double lat,
    required double lng,
    int radius = 2000,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/search/category.json'
      '?category_group_code=$categoryCode'
      '&x=$lng'
      '&y=$lat'
      '&radius=$radius'
      '&size=15',
    );

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) throw Exception('카테고리 검색 실패');

    final data = jsonDecode(response.body);
    final items = data['documents'] as List<dynamic>? ?? [];

    return items.map((item) {
      return LocationSearchResult(
        name: item['place_name'] as String,
        address:
            item['road_address_name'] as String? ??
            item['address_name'] as String? ??
            '',
        lat: double.parse(item['y'] as String),
        lng: double.parse(item['x'] as String),
      );
    }).toList();
  }
}
