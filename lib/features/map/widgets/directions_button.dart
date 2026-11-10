import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/kakao_local_service.dart';

/// 카카오맵 길찾기 수단 (카카오맵 웹의 target 값)
enum DirectionsMode {
  traffic('대중교통 (버스·지하철)', Icons.directions_bus_outlined),
  car('자동차', Icons.directions_car_outlined),
  walk('도보', Icons.directions_walk);

  const DirectionsMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// [name]([lat],[lng])까지 가는 길을 브라우저의 카카오맵에서 연다.
/// 출발지는 카카오맵 화면에서 고른다 (API 비용 없음, 좌표 변환 1번만 호출).
Future<void> openDirections({
  required String name,
  required double lat,
  required double lng,
  required DirectionsMode mode,
}) async {
  // 카카오맵 링크는 쉼표로 이름·좌표를 나눔
  final safeName = name.trim().isEmpty ? '도착지' : name.replaceAll(',', ' ');
  Uri uri;
  try {
    final coord = await KakaoLocalService().toKakaoMapCoord(lat, lng);
    if (coord == null) throw Exception('좌표 변환 실패');
    uri = Uri.https('map.kakao.com', '/', {
      'map_type': 'TYPE_MAP',
      'target': mode.name,
      'rt': ',,${coord.x},${coord.y}',
      'rt1': '',
      'rt2': safeName,
      'rtIds': ',',
      'rtTypes': ',',
    });
  } catch (_) {
    // 변환이 안 되면 도착지만 넣은 공개 링크 (수단은 카카오맵에서 고름)
    uri = Uri.parse(
      'https://map.kakao.com/link/to/'
      '${Uri.encodeComponent(safeName)},$lat,$lng',
    );
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// 길찾기 버튼: 누르면 수단(대중교통·자동차·도보)을 고르는 메뉴
class DirectionsButton extends StatelessWidget {
  const DirectionsButton({
    super.key,
    required this.name,
    required this.lat,
    required this.lng,
    this.compact = false,
  });

  final String name;
  final double lat;
  final double lng;

  /// 아이콘만 작게 (목록·메모 블록 안)
  final bool compact;

  Future<void> _showMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(
      box.size.bottomLeft(Offset.zero),
      ancestor: overlay,
    );
    final mode = await showMenu<DirectionsMode>(
      context: context,
      position: RelativeRect.fromRect(
        topLeft & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final m in DirectionsMode.values)
          PopupMenuItem(
            value: m,
            height: 36,
            child: Row(
              children: [
                Icon(m.icon, size: 18),
                const SizedBox(width: 10),
                Text(m.label, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
      ],
    );
    if (mode == null) return;
    await openDirections(name: name, lat: lat, lng: lng, mode: mode);
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) => compact
          ? IconButton(
              icon: const Icon(Icons.directions_outlined, size: 16),
              tooltip: '길찾기',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: () => _showMenu(buttonContext),
            )
          : TextButton.icon(
              icon: const Icon(Icons.directions_outlined, size: 18),
              label: const Text('길찾기'),
              onPressed: () => _showMenu(buttonContext),
            ),
    );
  }
}
