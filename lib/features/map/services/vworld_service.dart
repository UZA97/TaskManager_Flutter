import 'dart:convert';
import 'package:http/http.dart' as http;

const _apiKey = '8301697C-80F6-35C7-BCB2-F890D4B0409B';

class VworldSearchResult {
  final String name;
  final String address;
  final double lat;
  final double lng;

  const VworldSearchResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

class VworldService {
  // 키워드 검색 (POI)
  Future<List<VworldSearchResult>> search(String query) async {
    final uri = Uri.parse(
      'https://api.vworld.kr/req/search'
      '?service=search'
      '&request=search'
      '&version=2.0'
      '&crs=EPSG:4326'
      '&size=10'
      '&page=1'
      '&query=$query'
      '&type=place'
      '&format=json'
      '&errorformat=json'
      '&key=$_apiKey',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('검색 실패');

    final data = jsonDecode(response.body);
    final status = data['response']['status'] as String;
    if (status != 'OK') return [];

    final items = data['response']['result']['items'] as List<dynamic>? ?? [];

    return items.map((item) {
      final point = item['point'];
      return VworldSearchResult(
        name: item['title'] as String,
        address:
            item['address']?['road'] as String? ??
            item['address']?['parcel'] as String? ??
            '',
        lat: double.parse(point['y'] as String),
        lng: double.parse(point['x'] as String),
      );
    }).toList();
  }

  // 주소 검색 (지오코딩)
  Future<List<VworldSearchResult>> searchAddress(String query) async {
    final uri = Uri.parse(
      'https://api.vworld.kr/req/search'
      '?service=search'
      '&request=search'
      '&version=2.0'
      '&crs=EPSG:4326'
      '&size=10'
      '&page=1'
      '&query=$query'
      '&type=address'
      '&format=json'
      '&errorformat=json'
      '&key=$_apiKey',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('주소 검색 실패');

    final data = jsonDecode(response.body);
    final status = data['response']['status'] as String;
    if (status != 'OK') return [];

    final items = data['response']['result']['items'] as List<dynamic>? ?? [];

    return items.map((item) {
      final point = item['point'];
      return VworldSearchResult(
        name:
            item['address']?['road'] as String? ??
            item['address']?['parcel'] as String? ??
            query,
        address: item['address']?['parcel'] as String? ?? '',
        lat: double.parse(point['y'] as String),
        lng: double.parse(point['x'] as String),
      );
    }).toList();
  }

  // 정적 지도 이미지 URL (메모 블록용)
  static String staticImageUrl({
    required double lat,
    required double lng,
    int width = 300,
    int height = 150,
    int zoom = 15,
  }) {
    return 'https://api.vworld.kr/req/image'
        '?service=image'
        '&request=getmap'
        '&version=2.0'
        '&crs=EPSG:4326'
        '&center=$lng,$lat'
        '&zoom=$zoom'
        '&size=$width,$height'
        '&format=png'
        '&key=$_apiKey';
  }
}
