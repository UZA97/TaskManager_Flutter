import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:taskmanager/core/theme/app_colors.dart';

import '../../../core/hotkey/quick_memo_hotkey.dart';
import '../../../core/settings/settings_provider.dart';

/// 설정 > 일반: 빠른 메모 단축키 (현재 키 표시 + 변경)
class QuickMemoHotKeyRow extends ConsumerWidget {
  const QuickMemoHotKeyRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spec = ref.watch(
      settingsProvider.select((s) => s.value?.quickMemoHotKey),
    );
    final shortcut = QuickMemoShortcut.parse(spec);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('빠른 메모 단축키', style: TextStyle(fontSize: 14)),
                Text(
                  '어느 프로그램에서든 눌러 빠른 메모 창 열기',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (shortcut == null)
            const Text(
              '사용 안 함',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            )
          else
            KeyCaps(labels: shortcut.labels),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (_) => _RecordDialog(current: shortcut),
              );
              if (result != null && result != spec) {
                await ref
                    .read(settingsProvider.notifier)
                    .setQuickMemoHotKey(result);
              }
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }
}

/// 키보드 키 모양으로 보여 줌 (Ctrl + Alt + M)
class KeyCaps extends StatelessWidget {
  const KeyCaps({super.key, required this.labels, this.large = false});

  final List<String> labels;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final fontSize = large ? 16.0 : 12.0;
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Text(
              '+',
              style: TextStyle(fontSize: fontSize, color: Colors.grey),
            ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: large ? 10 : 6,
              vertical: large ? 5 : 2,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              labels[i],
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

/// 새 단축키를 눌러 기록하는 창. 저장하면 spec 문자열을 돌려줌 ('off' 포함)
class _RecordDialog extends StatefulWidget {
  const _RecordDialog({required this.current});

  final QuickMemoShortcut? current;

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  /// 지금 누르고 있는 보조 키 (아직 글자 키를 안 누른 상태 표시용)
  List<String> _pressing = const [];
  QuickMemoShortcut? _recorded;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 기록하는 동안 앱의 단축키를 잠시 해제 (눌러도 빠른 메모가 열리지 않고,
    // 같은 키를 다시 고를 때 '다른 프로그램이 사용 중'으로 잘못 나오지 않게)
    QuickMemoHotKeyService.instance.pause();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    // 저장하면 설정 변경으로 새 키가 등록되고, 취소하면 원래 키를 다시 등록
    QuickMemoHotKeyService.instance.resume();
    super.dispose();
  }

  List<HotKeyModifier> get _modifiersPressed {
    final pressed = HardwareKeyboard.instance.physicalKeysPressed;
    return [
      HotKeyModifier.control,
      HotKeyModifier.alt,
      HotKeyModifier.shift,
      HotKeyModifier.meta,
    ].where((m) => m.physicalKeys.any(pressed.contains)).toList();
  }

  bool _onKey(KeyEvent event) {
    final mods = _modifiersPressed;
    if (QuickMemoShortcut.isModifierKey(event.physicalKey)) {
      // 보조 키만 누르는 중: 화면에만 보여 줌
      setState(
        () => _pressing = QuickMemoShortcut(mods, '').labels..removeLast(),
      );
      return true;
    }
    if (event is! KeyDownEvent) return true;
    // Esc만 누르면 창 닫기
    if (mods.isEmpty && event.logicalKey == LogicalKeyboardKey.escape) {
      return false;
    }
    final name = QuickMemoShortcut.keyNameOf(event.physicalKey);
    if (name == null) {
      setState(() => _error = '글자(A~Z)·숫자·F1~F12·Space 키만 쓸 수 있습니다');
      return true;
    }
    final shortcut = QuickMemoShortcut(mods, name);
    var error = shortcut.problem;
    if (error == null && shortcut.isTakenByOtherApp()) {
      error = '다른 프로그램이 이미 쓰고 있는 단축키입니다';
    }
    setState(() {
      _recorded = shortcut;
      _pressing = const [];
      _error = error;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final shown = _pressing.isNotEmpty
        ? _pressing
        : (_recorded ?? widget.current)?.labels;
    final canSave = _recorded != null && _error == null;
    return AlertDialog(
      backgroundColor: context.popupSurface,
      title: const Text('빠른 메모 단축키', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '새로 쓸 키 조합을 눌러 주세요',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 40,
              child: Center(
                child: shown == null
                    ? const Text('사용 안 함', style: TextStyle(color: Colors.grey))
                    : KeyCaps(labels: shown, large: true),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 18,
              child: Text(
                _error ??
                    (_recorded != null
                        ? '사용할 수 있는 단축키입니다'
                        : '예: Ctrl + Alt + M, Ctrl + Shift + Space'),
                style: TextStyle(
                  fontSize: 12,
                  color: _error != null
                      ? Colors.red
                      : _recorded != null
                      ? context.accent
                      : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(QuickMemoShortcut.defaultSpec),
          child: const Text('기본값'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(QuickMemoShortcut.offSpec),
          child: const Text('사용 안 함'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: canSave
              ? () => Navigator.of(context).pop(_recorded!.spec)
              : null,
          child: const Text('저장'),
        ),
      ],
    );
  }
}
