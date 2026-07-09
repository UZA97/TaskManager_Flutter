import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/settings/settings_category.dart';
import '../../../core/settings/settings_category_provider.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/update/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/settings/app_settings.dart';
import '../../memo/providers/note_provider.dart';

class SettingsDetailView extends ConsumerWidget {
  const SettingsDetailView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(settingsCategoryProvider);

    return switch (category) {
      SettingsCategory.general => _GeneralSettings(),
      SettingsCategory.appearance => _AppearanceSettings(),
      SettingsCategory.notification => _NotificationSettings(),
      SettingsCategory.productivity => _PlaceholderSettings(label: '생산성'),
      SettingsCategory.security => _SecuritySettings(),
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
          const SizedBox(height: 16),
          const _SectionHeader(title: '날짜 형식'),
          const SizedBox(height: 8),
          SegmentedButton<AppDateFormat>(
            segments: const [
              ButtonSegment(
                value: AppDateFormat.iso,
                label: Text('yyyy-mm-dd'),
              ),
              ButtonSegment(
                value: AppDateFormat.korean,
                label: Text('yyyy년 mm월 dd일'),
              ),
              ButtonSegment(value: AppDateFormat.us, label: Text('mm/dd/yyyy')),
            ],
            selected: {settings.dateFormat},
            onSelectionChanged: (value) =>
                ref.read(settingsProvider.notifier).setDateFormat(value.first),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(title: '시간 형식'),
          const SizedBox(height: 8),
          SegmentedButton<AppTimeFormat>(
            segments: const [
              ButtonSegment(value: AppTimeFormat.h24, label: Text('14:30')),
              ButtonSegment(value: AppTimeFormat.h12, label: Text('2:30 PM')),
            ],
            selected: {settings.timeFormat},
            onSelectionChanged: (value) =>
                ref.read(settingsProvider.notifier).setTimeFormat(value.first),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(title: '휴지통'),
          _TrashSection(),
        ],
      ),
    );
  }
}

class _TrashSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TrashSection> createState() => _TrashSectionState();
}

class _TrashSectionState extends ConsumerState<_TrashSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final trashAsync = ref.watch(trashProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              icon: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
              ),
              label: trashAsync.when(
                loading: () => const Text('불러오는 중...'),
                error: (e, _) => const Text('오류'),
                data: (notes) => Text('삭제된 메모 ${notes.length}개'),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _confirmEmptyTrash(context),
              icon: const Icon(
                Icons.delete_forever,
                size: 16,
                color: Colors.red,
              ),
              label: const Text('전체 비우기', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        if (_isExpanded)
          trashAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
            data: (notes) => notes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      '휴지통이 비어있습니다',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : Column(
                    children: [
                      ...notes.map(
                        (note) => ListTile(
                          dense: true,
                          title: Text(
                            note.title.isEmpty ? '제목 없음' : note.title,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '삭제됨: ${_formatDate(note.deletedAt!)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.restore,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                tooltip: '복원',
                                onPressed: () => ref
                                    .read(trashProvider.notifier)
                                    .restore(note.id!),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_forever,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                tooltip: '영구 삭제',
                                onPressed: () =>
                                    _confirmDelete(context, note.id!),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (notes.length % 20 == 0)
                        TextButton(
                          onPressed: () =>
                              ref.read(trashProvider.notifier).loadMore(),
                          child: const Text('더 보기'),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return '${date.year}.${date.month}.${date.day}';
  }

  Future<void> _confirmEmptyTrash(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('휴지통 비우기'),
        content: const Text('휴지통의 모든 메모가 영구 삭제됩니다. 계속할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('비우기'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(trashProvider.notifier).emptyTrash();
    }
  }

  Future<void> _confirmDelete(BuildContext context, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('영구 삭제'),
        content: const Text('이 메모를 영구 삭제할까요? 복원할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(trashProvider.notifier).permanentlyDelete(id);
    }
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
          const SizedBox(height: 16),
          const _SectionHeader(title: '글꼴 크기'),
          const SizedBox(height: 8),
          SegmentedButton<AppFontSize>(
            segments: const [
              ButtonSegment(value: AppFontSize.small, label: Text('작게')),
              ButtonSegment(value: AppFontSize.medium, label: Text('보통')),
              ButtonSegment(value: AppFontSize.large, label: Text('크게')),
            ],
            selected: {settings.fontSize},
            onSelectionChanged: (value) =>
                ref.read(settingsProvider.notifier).setFontSize(value.first),
          ),
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

class _NotificationSettings extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (settings) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _SectionHeader(title: '알림'),
          _SettingsRow(
            title: '알림 활성화',
            subtitle: '모든 알림을 켜거나 끕니다',
            trailing: Switch(
              value: settings.notificationEnabled,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setNotificationEnabled(v),
            ),
          ),
        ],
      ),
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

class _SecuritySettings extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SecuritySettings> createState() => _SecuritySettingsState();
}

class _SecuritySettingsState extends ConsumerState<_SecuritySettings> {
  Future<bool> _hasPassword() =>
      ref.read(settingsProvider.notifier).hasPassword();

  Future<void> _showPasswordDialog({bool isChange = false}) async {
    await showDialog(
      context: context,
      builder: (context) => _PasswordDialog(isChange: isChange),
    );
    setState(() {}); // 다이얼로그 닫힌 후 UI 갱신
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (settings) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _SectionHeader(title: '앱 잠금'),
          FutureBuilder<bool>(
            future: _hasPassword(),
            builder: (context, snapshot) {
              final hasPw = snapshot.data ?? false;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingsRow(
                    title: '잠금 모드',
                    subtitle: '앱 시작 및 트레이 복귀 시 비밀번호 입력',
                    trailing: Switch(
                      value: settings.lockEnabled,
                      onChanged: (v) async {
                        if (v && !hasPw) {
                          await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('비밀번호 미등록'),
                              content: const Text('비밀번호 등록 후 이용하세요'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('확인'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                        ref.read(settingsProvider.notifier).setLockEnabled(v);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!hasPw)
                        OutlinedButton.icon(
                          onPressed: () => _showPasswordDialog(isChange: false),
                          icon: const Icon(Icons.lock_outline, size: 16),
                          label: const Text('비밀번호 등록'),
                        ),
                      if (hasPw)
                        OutlinedButton.icon(
                          onPressed: () => _showPasswordDialog(isChange: true),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('비밀번호 변경'),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PasswordDialog extends ConsumerStatefulWidget {
  final bool isChange;
  const _PasswordDialog({required this.isChange});

  @override
  ConsumerState<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<_PasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pw = _newController.text;
    final confirm = _confirmController.text;

    if (pw.length < 4) {
      setState(() => _error = '비밀번호는 최소 4자리입니다');
      return;
    }
    if (pw.length > 36) {
      setState(() => _error = '비밀번호는 최대 36자리입니다');
      return;
    }
    if (pw != confirm) {
      setState(() => _error = '비밀번호가 일치하지 않습니다');
      return;
    }

    // 변경 시 현재 비밀번호 검증
    if (widget.isChange) {
      final ok = await ref
          .read(settingsProvider.notifier)
          .verifyPassword(_currentController.text);
      if (!ok) {
        setState(() => _error = '현재 비밀번호가 틀렸습니다');
        return;
      }
    }

    await ref.read(settingsProvider.notifier).setPassword(pw);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isChange ? '비밀번호 변경' : '비밀번호 등록',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (widget.isChange) ...[
              TextField(
                controller: _currentController,
                obscureText: !_showCurrent,
                decoration: InputDecoration(
                  hintText: '현재 비밀번호',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showCurrent ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _showCurrent = !_showCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _newController,
              obscureText: !_showNew,
              decoration: InputDecoration(
                hintText: '새 비밀번호 (4~36자)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showNew ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _showNew = !_showNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: !_showConfirm,
              decoration: InputDecoration(
                hintText: '비밀번호 확인',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
                errorText: _error,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirm ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
