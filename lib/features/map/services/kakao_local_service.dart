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

  /// 좌표 → 주소 (건물 이름이 있으면 그것을 이름으로). 못 찾으면 null
  Future<LocationSearchResult?> coordToAddress(double lat, double lng) async {
    final uri = Uri.parse('$_baseUrl/geo/coord2address.json?x=$lng&y=$lat');
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final items = jsonDecode(response.body)['documents'] as List<dynamic>?;
    if (items == null || items.isEmpty) return null;
    final doc = items.first as Map<String, dynamic>;
    final road = doc['road_address'] as Map<String, dynamic>?;
    final jibun = doc['address'] as Map<String, dynamic>?;
    final address =
        road?['address_name'] as String? ??
        jibun?['address_name'] as String? ??
        '';
    if (address.isEmpty) return null;
    final building = (road?['building_name'] as String? ?? '').trim();
    return LocationSearchResult(
      name: building.isNotEmpty ? building : address,
      address: address,
      lat: lat,
      lng: lng,
    );
  }

  /// WGS84 → 카카오맵 웹 내부 좌표(WCONGNAMUL). 길찾기 링크용. 실패하면 null
  Future<({int x, int y})?> toKakaoMapCoord(double lat, double lng) async {
    final uri = Uri.parse(
      '$_baseUrl/geo/transcoord.json'
      '?x=$lng&y=$lat&input_coord=WGS84&output_coord=WCONGNAMUL',
    );
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;
    final items = jsonDecode(response.body)['documents'] as List<dynamic>?;
    if (items == null || items.isEmpty) return null;
    final doc = items.first as Map<String, dynamic>;
    return (
      x: (doc['x'] as num).round(),
      y: (doc['y'] as num).round(),
    );
  }

  /// 지도 바탕 그림에 아이콘으로 그려지는 종류
  /// (지하철역·학교·공공기관·병원·주유소·은행·문화시설·관광명소·대형마트·숙박)
  /// 주차장은 주차대행 업체 등 엉뚱한 곳이 섞여 제외
  static const iconCategories = [
    'SW8', 'SC4', 'PO3', 'HP8', 'OL7', 'BK9', //
    'CT1', 'AT4', 'MT1', 'AD5',
  ];

  /// [lat],[lng]에서 [radius]m 안의 가장 가까운 장소 (지도 아이콘을 누른 것으로 봄).
  /// 종류마다 가장 가까운 1곳씩 동시에 찾아 그중 가장 가까운 것. 없으면 null
  Future<LocationSearchResult?> nearestPlace(
    double lat,
    double lng, {
    required int radius,
  }) async {
    final results = await Future.wait(
      iconCategories.map(
        (code) => _nearestInCategory(
          code,
          lat,
          lng,
          radius,
        ).catchError((Object _) => null),
      ),
    );
    (LocationSearchResult, double)? best;
    for (final r in results) {
      if (r != null && (best == null || r.$2 < best.$2)) best = r;
    }
    return best?.$1;
  }

  /// 거리에 곱하는 값 (작을수록 우선). 은행·마트·숙박은 지점이 많아 뒤로
  static const _categoryWeight = {'BK9': 2.0, 'MT1': 1.5, 'AD5': 1.5};

  /// 지도에 아이콘으로 안 그려지는 자잘한 곳
  static final _minorPlace = RegExp(r'ATM|365코너|자동화기기|주차장|주차대행');

  /// 그 종류에서 가장 가까운 곳과 순위 점수(가중 거리)
  Future<(LocationSearchResult, double)?> _nearestInCategory(
    String code,
    double lat,
    double lng,
    int radius,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/search/category.json'
      '?category_group_code=$code&x=$lng&y=$lat'
      '&radius=$radius&sort=distance&size=5',
    );
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final items = jsonDecode(response.body)['documents'] as List<dynamic>?;
    final item = items
        ?.cast<Map<String, dynamic>>()
        .where((i) => !_minorPlace.hasMatch(i['place_name'] as String? ?? ''))
        .firstOrNull;
    if (item == null) return null;
    final distance = int.tryParse(item['distance'] as String? ?? '') ?? radius;
    final road = item['road_address_name'] as String? ?? '';
    return (
      LocationSearchResult(
        name: item['place_name'] as String,
        address: road.isNotEmpty ? road : item['address_name'] as String? ?? '',
        lat: double.parse(item['y'] as String),
        lng: double.parse(item['x'] as String),
      ),
      distance * (_categoryWeight[code] ?? 1.0),
    );
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
