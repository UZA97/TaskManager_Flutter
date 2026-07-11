import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/settings/settings_category.dart';
import '../../../core/settings/settings_category_provider.dart';

class _SettingsCategoryItem {
  const _SettingsCategoryItem({
    required this.category,
    required this.icon,
    required this.label,
  });

  final SettingsCategory category;
  final IconData icon;
  final String label;
}

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  /// 설정 사이드바에 노출할 카테고리 목록입니다.
  static const List<_SettingsCategoryItem> _categoryItems = [
    _SettingsCategoryItem(
      category: SettingsCategory.general,
      icon: Icons.settings,
      label: '일반',
    ),
    _SettingsCategoryItem(
      category: SettingsCategory.appearance,
      icon: Icons.palette,
      label: '외관',
    ),
    _SettingsCategoryItem(
      category: SettingsCategory.notification,
      icon: Icons.notifications,
      label: '알림',
    ),
    _SettingsCategoryItem(
      category: SettingsCategory.productivity,
      icon: Icons.bolt,
      label: '생산성',
    ),
    _SettingsCategoryItem(
      category: SettingsCategory.security,
      icon: Icons.lock,
      label: '보안',
    ),
    _SettingsCategoryItem(
      category: SettingsCategory.advanced,
      icon: Icons.tune,
      label: '고급',
    ),
    _SettingsCategoryItem(
      category: SettingsCategory.info,
      icon: Icons.info,
      label: '정보',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(settingsCategoryProvider);

    return ListView(
      children: _categoryItems.map((item) {
        final isSelected = selected == item.category;
        return ListTile(
          leading: Icon(
            item.icon,
            size: 18,
            color: isSelected ? const Color(0xFF4A90E2) : Colors.grey,
          ),
          title: Text(
            item.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? const Color(0xFF4A90E2) : null,
            ),
          ),
          selected: isSelected,
          selectedTileColor: const Color(0xFFE8F0FE),
          onTap: () =>
              ref.read(settingsCategoryProvider.notifier).select(item.category),
        );
      }).toList(),
    );
  }
}
