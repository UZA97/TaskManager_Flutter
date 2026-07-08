import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_category.dart';

class SettingsCategoryNotifier extends Notifier<SettingsCategory> {
  @override
  SettingsCategory build() => SettingsCategory.general;

  void select(SettingsCategory category) => state = category;
}

final settingsCategoryProvider =
    NotifierProvider<SettingsCategoryNotifier, SettingsCategory>(
      SettingsCategoryNotifier.new,
    );
