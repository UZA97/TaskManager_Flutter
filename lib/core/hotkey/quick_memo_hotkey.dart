import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// 빠른 메모 단축키. 설정에는 "control,alt|M" 처럼 저장 ('off'면 사용 안 함)
@immutable
class QuickMemoShortcut {
  const QuickMemoShortcut(this.modifiers, this.key);

  /// 기본값: Ctrl + Alt + M
  static const defaultSpec = 'control,alt|M';
  static const offSpec = 'off';

  final List<HotKeyModifier> modifiers;

  /// 글자 키 이름: A~Z, 0~9, F1~F12, Space
  final String key;

  /// 쓸 수 있는 키와 Windows 가상 키 코드
  static final Map<String, int> _virtualKeys = {
    for (var i = 0; i < 26; i++) String.fromCharCode(0x41 + i): 0x41 + i,
    for (var i = 0; i < 10; i++) '$i': 0x30 + i,
    for (var i = 1; i <= 12; i++) 'F$i': 0x6F + i,
    'Space': 0x20,
  };

  static final Map<PhysicalKeyboardKey, String> _physicalNames = {
    for (final k in [
      PhysicalKeyboardKey.keyA, PhysicalKeyboardKey.keyB, //
      PhysicalKeyboardKey.keyC, PhysicalKeyboardKey.keyD,
      PhysicalKeyboardKey.keyE, PhysicalKeyboardKey.keyF,
      PhysicalKeyboardKey.keyG, PhysicalKeyboardKey.keyH,
      PhysicalKeyboardKey.keyI, PhysicalKeyboardKey.keyJ,
      PhysicalKeyboardKey.keyK, PhysicalKeyboardKey.keyL,
      PhysicalKeyboardKey.keyM, PhysicalKeyboardKey.keyN,
      PhysicalKeyboardKey.keyO, PhysicalKeyboardKey.keyP,
      PhysicalKeyboardKey.keyQ, PhysicalKeyboardKey.keyR,
      PhysicalKeyboardKey.keyS, PhysicalKeyboardKey.keyT,
      PhysicalKeyboardKey.keyU, PhysicalKeyboardKey.keyV,
      PhysicalKeyboardKey.keyW, PhysicalKeyboardKey.keyX,
      PhysicalKeyboardKey.keyY, PhysicalKeyboardKey.keyZ,
    ])
      k: k.debugName!.replaceFirst('Key ', ''),
    PhysicalKeyboardKey.digit0: '0',
    PhysicalKeyboardKey.digit1: '1',
    PhysicalKeyboardKey.digit2: '2',
    PhysicalKeyboardKey.digit3: '3',
    PhysicalKeyboardKey.digit4: '4',
    PhysicalKeyboardKey.digit5: '5',
    PhysicalKeyboardKey.digit6: '6',
    PhysicalKeyboardKey.digit7: '7',
    PhysicalKeyboardKey.digit8: '8',
    PhysicalKeyboardKey.digit9: '9',
    PhysicalKeyboardKey.f1: 'F1',
    PhysicalKeyboardKey.f2: 'F2',
    PhysicalKeyboardKey.f3: 'F3',
    PhysicalKeyboardKey.f4: 'F4',
    PhysicalKeyboardKey.f5: 'F5',
    PhysicalKeyboardKey.f6: 'F6',
    PhysicalKeyboardKey.f7: 'F7',
    PhysicalKeyboardKey.f8: 'F8',
    PhysicalKeyboardKey.f9: 'F9',
    PhysicalKeyboardKey.f10: 'F10',
    PhysicalKeyboardKey.f11: 'F11',
    PhysicalKeyboardKey.f12: 'F12',
    PhysicalKeyboardKey.space: 'Space',
  };

  /// 표시·저장 순서
  static const _modifierOrder = [
    HotKeyModifier.control,
    HotKeyModifier.alt,
    HotKeyModifier.shift,
    HotKeyModifier.meta,
  ];

  /// 누른 키 → 단축키 이름 (쓸 수 없는 키면 null)
  static String? keyNameOf(PhysicalKeyboardKey key) => _physicalNames[key];

  static bool isModifierKey(PhysicalKeyboardKey key) =>
      _modifierOrder.any((m) => m.physicalKeys.contains(key));

  /// 저장 문자열 → 단축키 ('off'·잘못된 값이면 null)
  static QuickMemoShortcut? parse(String? spec) {
    if (spec == null || spec == offSpec) return null;
    final parts = spec.split('|');
    if (parts.length != 2 || !_virtualKeys.containsKey(parts[1])) return null;
    final names = parts[0].split(',').where((s) => s.isNotEmpty).toSet();
    final mods = _modifierOrder.where((m) => names.contains(m.name)).toList();
    if (mods.isEmpty) return null;
    return QuickMemoShortcut(mods, parts[1]);
  }

  String get spec => '${modifiers.map((m) => m.name).join(',')}|$key';

  /// 화면에 보일 이름 (예: Ctrl + Alt + M)
  List<String> get labels => [
    for (final m in modifiers)
      switch (m) {
        HotKeyModifier.control => 'Ctrl',
        HotKeyModifier.alt => 'Alt',
        HotKeyModifier.shift => 'Shift',
        HotKeyModifier.meta => 'Win',
        _ => m.name,
      },
    key,
  ];

  String get label => labels.join(' + ');

  /// 다른 프로그램의 평범한 단축키(Ctrl+S 등)를 빼앗지 않도록
  /// 보조 키 2개 이상, 또는 Win 키를 함께 써야 함. 문제가 있으면 이유를 돌려줌
  String? get problem {
    final hasWin = modifiers.contains(HotKeyModifier.meta);
    if (modifiers.length < 2 && !hasWin) {
      return 'Ctrl·Alt·Shift 중 2개 이상(또는 Win 키)과 함께 눌러 주세요';
    }
    return null;
  }

  HotKey toHotKey() {
    final physical = _physicalNames.entries
        .firstWhere((e) => e.value == key)
        .key;
    return HotKey(
      identifier: 'quick_memo',
      key: physical,
      modifiers: modifiers,
      scope: HotKeyScope.system,
    );
  }

  /// 이미 다른 프로그램이 이 단축키를 쓰고 있으면 true.
  /// (Windows에 잠깐 등록해 보고 바로 해제. 이 앱이 등록한 것도 '사용 중'으로 나오므로
  ///  확인 전에 앱의 단축키를 해제해 둘 것)
  bool isTakenByOtherApp() {
    if (!Platform.isWindows) return false;
    try {
      const probeId = 0x5A11;
      var fs = 0x4000; // MOD_NOREPEAT
      for (final m in modifiers) {
        fs |= switch (m) {
          HotKeyModifier.alt => 0x1,
          HotKeyModifier.control => 0x2,
          HotKeyModifier.shift => 0x4,
          HotKeyModifier.meta => 0x8,
          _ => 0,
        };
      }
      final ok = _registerHotKey(nullptr, probeId, fs, _virtualKeys[key]!);
      if (ok == 0) return true;
      _unregisterHotKey(nullptr, probeId);
      return false;
    } catch (_) {
      return false; // 확인할 수 없으면 막지 않음
    }
  }

  @override
  bool operator ==(Object other) =>
      other is QuickMemoShortcut && other.spec == spec;

  @override
  int get hashCode => spec.hashCode;
}

final _user32 = DynamicLibrary.open('user32.dll');
final _registerHotKey = _user32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Uint32, Uint32),
      int Function(Pointer<Void>, int, int, int)
    >('RegisterHotKey');
final _unregisterHotKey = _user32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Int32),
      int Function(Pointer<Void>, int)
    >('UnregisterHotKey');

/// 앱 전체에서 하나뿐인 빠른 메모 단축키 등록 관리
class QuickMemoHotKeyService {
  QuickMemoHotKeyService._();
  static final instance = QuickMemoHotKeyService._();

  VoidCallback? onPressed;
  QuickMemoShortcut? _shortcut;
  HotKey? _registered;

  /// 등록·해제가 겹치지 않게 한 번에 하나씩 처리
  Future<void> _queue = Future.value();

  Future<void> _serial(Future<void> Function() task) =>
      _queue = _queue.then((_) => task()).catchError((Object e) {
        debugPrint('빠른 메모 단축키 처리 실패: $e');
      });

  QuickMemoShortcut? get current => _shortcut;

  /// 단축키를 바꿔 등록 (null이면 해제)
  Future<void> apply(QuickMemoShortcut? shortcut) => _serial(() async {
    _shortcut = shortcut;
    await _unregister();
    await _register();
  });

  /// 단축키를 새로 누르는 동안 잠깐 해제 (누르면 빠른 메모가 열리지 않게)
  Future<void> pause() => _serial(_unregister);

  /// pause 뒤 원래 단축키를 다시 등록 (이미 등록돼 있으면 그대로)
  Future<void> resume() => _serial(_register);

  Future<void> _register() async {
    final s = _shortcut;
    if (s == null || _registered != null) return;
    final hotKey = s.toHotKey();
    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (_) => onPressed?.call(),
      );
      _registered = hotKey;
    } catch (e) {
      debugPrint('빠른 메모 단축키 등록 실패: $e');
    }
  }

  Future<void> _unregister() async {
    final r = _registered;
    _registered = null;
    if (r == null) return;
    try {
      await hotKeyManager.unregister(r);
    } catch (e) {
      debugPrint('빠른 메모 단축키 해제 실패: $e');
    }
  }
}
