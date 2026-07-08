import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/settings/settings_category.dart';
import '../../../core/settings/settings_category_provider.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/update/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsDetailView extends ConsumerWidget {
  const SettingsDetailView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(settingsCategoryProvider);

    return switch (category) {
      SettingsCategory.general => _GeneralSettings(),
      SettingsCategory.appearance => _AppearanceSettings(),
      SettingsCategory.notification => _PlaceholderSettings(label: '알림'),
      SettingsCategory.productivity => _PlaceholderSettings(label: '생산성'),
      SettingsCategory.security => _PlaceholderSettings(label: '보안'),
      SettingsCategory.advanced => _PlaceholderSettings(label: '고급'),
      SettingsCategory.info => _InfoSettings(),
    };
  }
}

// 일반
class _GeneralSettings extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (settings) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _SectionHeader(title: '일반'),
          _SettingsRow(
            title: '트레이 모드',
            subtitle: '창 닫기 시 트레이로 최소화',
            trailing: Switch(
              value: settings.trayModeEnabled,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setTrayMode(v),
            ),
          ),
        ],
      ),
    );
  }
}

// 외관
class _AppearanceSettings extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (settings) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _SectionHeader(title: '외관'),
          _SettingsRow(
            title: '다크 모드',
            subtitle: '어두운 테마 사용',
            trailing: Switch(
              value: settings.themeMode == ThemeMode.dark,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(title: '테마 색상'),
          const SizedBox(height: 8),
          _ThemeColorPicker(),
        ],
      ),
    );
  }
}

class _PlaceholderSettings extends StatelessWidget {
  final String label;
  const _PlaceholderSettings({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('$label 설정', style: const TextStyle(color: Colors.grey)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ThemeColorPicker extends ConsumerWidget {
  static const _colors = [
    (Color(0xFF4A90E2), '블루'),
    (Color(0xFF3F51B5), '인디고'),
    (Color(0xFF9C27B0), '퍼플'),
    (Color(0xFF009688), '티엘'),
    (Color(0xFF4CAF50), '그린'),
    (Color(0xFFFF9800), '오렌지'),
    (Color(0xFFF44336), '레드'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _colors.map((item) {
        final (color, label) = item;
        final isSelected = settings?.themeColor.value == color.value;

        return GestureDetector(
          onTap: () => ref.read(settingsProvider.notifier).setThemeColor(color),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.onSurface,
                          width: 3,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _InfoSettings extends StatefulWidget {
  @override
  State<_InfoSettings> createState() => _InfoSettingsState();
}

class _InfoSettingsState extends State<_InfoSettings> {
  final _updateService = UpdateService();
  bool _isChecking = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _statusMessage;
  UpdateCheckResult? _checkResult;

  Future<void> _checkUpdate() async {
    setState(() {
      _isChecking = true;
      _statusMessage = null;
      _checkResult = null;
    });

    final result = await _updateService.checkForUpdate();
    setState(() {
      _isChecking = false;
      _checkResult = result;
      if (result.error != null) {
        _statusMessage = '오류: ${result.error}';
      } else if (!result.hasUpdate) {
        _statusMessage = '최신 버전입니다 (${result.currentVersion})';
      }
    });
  }

  Future<void> _startUpdate() async {
    if (_checkResult?.downloadUrl == null) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _statusMessage = '다운로드 중...';
    });

    await _updateService.downloadAndInstall(
      _checkResult!.downloadUrl!,
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
          _statusMessage = '다운로드 중... ${(progress * 100).toStringAsFixed(0)}%';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _SectionHeader(title: '정보'),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '-';
            return _SettingsRow(
              title: '버전',
              trailing: Text(
                version,
                style: const TextStyle(color: Colors.grey),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        const _SectionHeader(title: '업데이트'),
        if (_statusMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _statusMessage!,
              style: TextStyle(
                fontSize: 12,
                color: _checkResult?.hasUpdate == true
                    ? Colors.green
                    : Colors.grey,
              ),
            ),
          ),
        if (_isDownloading)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(value: _downloadProgress),
          ),
        if (_checkResult?.hasUpdate == true && !_isDownloading)
          ElevatedButton.icon(
            onPressed: _startUpdate,
            icon: const Icon(Icons.download, size: 16),
            label: Text('${_checkResult!.latestVersion}으로 업데이트'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
            ),
          )
        else if (!_isChecking && !_isDownloading)
          OutlinedButton.icon(
            onPressed: _checkUpdate,
            icon: _isChecking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: const Text('업데이트 확인'),
          ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget trailing;

  const _SettingsRow({
    required this.title,
    this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
