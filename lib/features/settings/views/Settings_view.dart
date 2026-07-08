import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/settings/settings_category.dart';
import '../../../core/settings/settings_category_provider.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(settingsCategoryProvider);

    final items = [
      (SettingsCategory.general, Icons.settings, '일반'),
      (SettingsCategory.appearance, Icons.palette, '외관'),
      (SettingsCategory.notification, Icons.notifications, '알림'),
      (SettingsCategory.productivity, Icons.bolt, '생산성'),
      (SettingsCategory.security, Icons.lock, '보안'),
      (SettingsCategory.advanced, Icons.tune, '고급'),
      (SettingsCategory.info, Icons.info, '정보'),
    ];

    return ListView(
      children: items.map((item) {
        final (category, icon, label) = item;
        final isSelected = selected == category;
        return ListTile(
          leading: Icon(
            icon,
            size: 18,
            color: isSelected ? const Color(0xFF4A90E2) : Colors.grey,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? const Color(0xFF4A90E2) : null,
            ),
          ),
          selected: isSelected,
          selectedTileColor: const Color(0xFFE8F0FE),
          onTap: () =>
              ref.read(settingsCategoryProvider.notifier).select(category),
        );
      }).toList(),
    );
  }
}
