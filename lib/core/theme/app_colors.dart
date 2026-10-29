import 'package:flutter/material.dart';

/// 배경 등 기본 색을 만들 때 쓰는 고정 색 (테마색을 바꿔도 배경은 그대로)
const appSeedColor = Color(0xFF4A90E2);

/// 다크 모드: 새까맣지 않은 배경, 새하얗지 않은 글씨
const darkBackground = Color(0xFF262626);
const darkText = Color(0xFFDADADA);

/// 다크 모드 색 (배경·글씨)을 덮어씀
ColorScheme withDarkColors(ColorScheme scheme) => scheme.copyWith(
  surface: darkBackground,
  surfaceContainerLowest: const Color(0xFF202020),
  surfaceContainerLow: const Color(0xFF2B2B2B),
  surfaceContainer: const Color(0xFF2F2F2F),
  surfaceContainerHigh: const Color(0xFF353535),
  surfaceContainerHighest: const Color(0xFF3C3C3C),
  onSurface: darkText,
  onSurfaceVariant: const Color(0xFFB4B4B4),
);

extension AppColors on BuildContext {
  /// 설정의 테마색: 활성화된 아이콘·버튼·강조 표시에 사용
  Color get accent => Theme.of(this).colorScheme.primary;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// 메뉴·팝업 바탕 (밝게: 흰색, 다크 모드: 배경보다 조금 밝은 회색)
  Color get popupSurface => isDark ? const Color(0xFF353535) : Colors.white;

  /// 선택된 항목 바탕 (테마색을 옅게)
  Color get selectedTint => accent.withValues(alpha: isDark ? 0.25 : 0.12);

  /// 구분선·테두리
  Color get line => isDark ? const Color(0xFF404040) : const Color(0xFFDDDDDD);

  /// 옅은 구분선
  Color get lineSubtle =>
      isDark ? const Color(0xFF363636) : const Color(0xFFEEEEEE);

  /// 옅은 회색 바탕 (탭, 코드 블록 등)
  Color get surfaceSoft =>
      isDark ? const Color(0xFF303030) : const Color(0xFFF5F5F5);

  /// 더 옅은 회색 바탕 (달력 빈 칸 등)
  Color get surfaceMuted =>
      isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF9F9F9);
}
