import 'package:taskmanager/core/theme/app_colors.dart';
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
    // _SettingsCategoryItem(
    //   category: SettingsCategory.productivity,
    //   icon: Icons.bolt,
    //   label: '생산성',
    // ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 16, 14, 12),
          child: Text(
            '설정',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              for (final item in _categoryItems)
                _CategoryTile(
                  item: item,
                  selected: selected == item.category,
                  onTap: () => ref
                      .read(settingsCategoryProvider.notifier)
                      .select(item.category),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 카테고리 한 줄 (할 일 사이드 패널과 같은 둥근 선택 표시)
class _CategoryTile extends StatelessWidget {
  final _SettingsCategoryItem item;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: selected ? context.selectedTint : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 17,
                    color: selected ? context.accent : muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
