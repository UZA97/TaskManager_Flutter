import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'styled_text_controller.dart';

/// 텍스트를 직접 편집하는 블록 (type 이름은 appflowy 문서와 동일)
const textBlockTypes = {
  'paragraph',
  'heading',
  'todo_list',
  'bulleted_list',
  'numbered_list',
  'quote',
  collapsibleSectionType, // 제목이 텍스트, 내용은 하위 블록
};

/// 목록처럼 Enter를 치면 같은 종류가 이어지는 블록
const continuingBlockTypes = {'todo_list', 'bulleted_list', 'numbered_list'};

// 텍스트가 아닌 블록 (기존 에디터와 같은 type 이름)
const dividerType = 'divider';
const localImageType = 'local_image';
const localFileType = 'local_file';
const localLocationType = 'local_location';
const localCodeType = 'local_code';
const collapsibleSectionType = 'collapsible_section';

/// 에디터의 한 줄(블록). 문서의 트리 구조는 [depth](들여쓰기)로 펼쳐서 다룸.
class EditorBlock {
  EditorBlock({
    required this.type,
    this.depth = 0,
    Map<String, Object?>? data,
    List<Map<String, Object?>>? delta,
    this.raw,
  }) : data = {...?data},
       controller = StyledTextController.fromDelta(delta ?? const []),
       focusNode = FocusNode();

  /// 텍스트가 아닌 블록 (이미지·파일·위치·코드·구분선 등)
  factory EditorBlock.object(
    String type,
    Map<String, Object?> data, {
    int depth = 0,
  }) =>
      EditorBlock(type: type, depth: depth, raw: {'type': type, 'data': data});

  factory EditorBlock.divider() => EditorBlock.object(dividerType, {});

  factory EditorBlock.image(String src, {double width = 300}) =>
      EditorBlock.object(localImageType, {'src': src, 'width': width});

  factory EditorBlock.file(String src, String fileName) =>
      EditorBlock.object(localFileType, {'src': src, 'fileName': fileName});

  factory EditorBlock.location(String name, double lat, double lng) =>
      EditorBlock.object(localLocationType, {
        'name': name,
        'lat': lat,
        'lng': lng,
      });

  factory EditorBlock.code({String code = '', String language = 'dart'}) =>
      EditorBlock.object(localCodeType, {'code': code, 'language': language});

  String type;
  int depth;

  /// delta 외의 블록 속성 (checked, level, align ...). 저장할 때 그대로 보존.
  final Map<String, Object?> data;

  /// 텍스트가 아닌 블록의 원본 JSON. 모르는 속성·자식까지 그대로 보존.
  final Map<String, Object?>? raw;

  final StyledTextController controller;
  final FocusNode focusNode;

  /// `/` 메뉴를 이 줄 아래에 띄우기 위한 위치 연결
  final LayerLink layerLink = LayerLink();

  /// 화면에 그려진 텍스트 폭 (위/아래 방향키에서 첫 줄·마지막 줄 판정용)
  double width = 0;

  bool get isText => raw == null && textBlockTypes.contains(type);
  bool get isSection => type == collapsibleSectionType;
  bool get checked => data['checked'] == true;
  int get level => (data['level'] as num?)?.toInt() ?? 1;
  bool get collapsed => data['collapsed'] == true;
  String? get align => data['align'] as String?;

  /// 텍스트가 아닌 블록의 속성 (src, width, code ...). 바꾸면 그대로 저장됨.
  Map<String, Object?> get rawData =>
      (raw!['data'] ??= <String, Object?>{}) as Map<String, Object?>;

  /// 블록 종류 변경. 이전 종류에만 쓰던 속성은 정리.
  void changeType(String newType, {int? level}) {
    type = newType;
    data
      ..remove('checked')
      ..remove('level')
      ..remove('collapsed')
      ..remove('backgroundColor');
    if (newType == 'todo_list') data['checked'] = false;
    if (newType == 'heading') data['level'] = level ?? 1;
    if (newType == collapsibleSectionType) data['collapsed'] = false;
  }

  /// 입력창이 지금 만들어져 있는지 (긴 메모는 화면 근처의 줄만 만듦).
  /// FocusNode.context는 입력창이 사라진 뒤에도 남아 있어 mounted로 확인.
  bool get isOnScreen => focusNode.context?.mounted ?? false;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

/// appflowy 문서 JSON → 블록 목록
List<EditorBlock> blocksFromJson(String content) {
  final document = (jsonDecode(content) as Map)['document'] as Map;
  final result = <EditorBlock>[];

  void visit(List<Object?> children, int depth) {
    for (final child in children.whereType<Map>()) {
      final node = Map<String, Object?>.from(child);
      final type = node['type'] as String? ?? 'paragraph';
      final data = Map<String, Object?>.from(
        (node['data'] as Map?) ?? const {},
      );
      // 화면 깊이 = 트리 깊이 + 추가 들여쓰기 (저장할 때 다시 계산해서 넣음)
      final extra = (data.remove(extraIndentKey) as num?)?.toInt() ?? 0;
      if (!textBlockTypes.contains(type)) {
        // 수정 가능한 복사본 (원래 data가 없던 블록은 그대로 없이)
        if (node.containsKey('data')) node['data'] = data;
        result.add(EditorBlock(type: type, depth: depth + extra, raw: node));
        continue;
      }
      final delta = (data.remove('delta') as List?)
          ?.whereType<Map>()
          .map((op) => Map<String, Object?>.from(op))
          .toList();
      result.add(
        EditorBlock(type: type, depth: depth + extra, data: data, delta: delta),
      );
      visit((node['children'] as List?) ?? const [], depth + 1);
    }
  }

  visit((document['children'] as List?) ?? const [], 0);
  if (result.isEmpty) result.add(EditorBlock(type: 'paragraph'));
  return result;
}

/// 블록 목록 → appflowy 문서 JSON (들여쓰기를 다시 트리로)
/// 업노트처럼 바로 위 줄보다 더 깊이 들여쓴 만큼 (appflowy 트리로는 표현할 수 없는 부분).
/// 기존 에디터는 이 값을 모르므로 트리 깊이만큼만 들여써서 보여줌.
const extraIndentKey = 'extra_indent';

/// 저장할 때의 트리 깊이. 화면 깊이 = 트리 깊이 + [extraIndentKey].
/// 바로 앞의 더 얕게 들여쓴 텍스트 블록의 자식으로 저장함.
/// (기존 메모처럼 한 단계씩만 들여쓴 문서는 트리 깊이 = 화면 깊이)
List<int> treeDepthsOf(List<EditorBlock> blocks) {
  final ancestors = <int>[]; // 자식을 가질 수 있는 조상들의 화면 깊이
  final depths = <int>[];
  for (final block in blocks) {
    while (ancestors.isNotEmpty && ancestors.last >= block.depth) {
      ancestors.removeLast();
    }
    depths.add(ancestors.length);
    if (block.raw == null) ancestors.add(block.depth);
  }
  return depths;
}

Map<String, Object?> blocksToJson(List<EditorBlock> blocks) {
  final rootChildren = <Object?>[];
  // 트리 깊이별로 자식을 가질 수 있는 마지막 텍스트 블록
  final parents = <Map<String, Object?>>[];
  final depths = treeDepthsOf(blocks);

  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    final depth = depths[i];
    final extra = block.depth - depth;
    final raw = block.raw;
    final Map<String, Object?> node;
    if (raw == null) {
      node = {
        'type': block.type,
        'data': {
          ...block.data,
          'delta': block.controller.toDelta(),
          if (extra > 0) extraIndentKey: extra,
        },
      };
    } else if (extra > 0) {
      node = {
        ...raw,
        'data': {...?(raw['data'] as Map?), extraIndentKey: extra},
      };
    } else {
      node = raw; // 원본 그대로
    }
    final siblings = depth == 0
        ? rootChildren
        : (parents[depth - 1]['children'] ??= <Object?>[]) as List<Object?>;
    siblings.add(node);

    parents.removeRange(depth, parents.length);
    if (raw == null) parents.add(node);
  }

  return {
    'document': {'type': 'page', 'children': rootChildren},
  };
}
