// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $FolderTableTable extends FolderTable
    with TableInfo<$FolderTableTable, FolderTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FolderTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id)',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _favoriteSortOrderMeta = const VerificationMeta(
    'favoriteSortOrder',
  );
  @override
  late final GeneratedColumn<double> favoriteSortOrder =
      GeneratedColumn<double>(
        'favorite_sort_order',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.0),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    parentId,
    sortOrder,
    createdAt,
    isPinned,
    isFavorite,
    favoriteSortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<FolderTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('favorite_sort_order')) {
      context.handle(
        _favoriteSortOrderMeta,
        favoriteSortOrder.isAcceptableOrUnknown(
          data['favorite_sort_order']!,
          _favoriteSortOrderMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FolderTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      favoriteSortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}favorite_sort_order'],
      )!,
    );
  }

  @override
  $FolderTableTable createAlias(String alias) {
    return $FolderTableTable(attachedDatabase, alias);
  }
}

class FolderTableData extends DataClass implements Insertable<FolderTableData> {
  final int id;
  final String name;
  final int? parentId;
  final double sortOrder;
  final String createdAt;
  final bool isPinned;
  final bool isFavorite;
  final double favoriteSortOrder;
  const FolderTableData({
    required this.id,
    required this.name,
    this.parentId,
    required this.sortOrder,
    required this.createdAt,
    required this.isPinned,
    required this.isFavorite,
    required this.favoriteSortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    map['sort_order'] = Variable<double>(sortOrder);
    map['created_at'] = Variable<String>(createdAt);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['favorite_sort_order'] = Variable<double>(favoriteSortOrder);
    return map;
  }

  FolderTableCompanion toCompanion(bool nullToAbsent) {
    return FolderTableCompanion(
      id: Value(id),
      name: Value(name),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      isPinned: Value(isPinned),
      isFavorite: Value(isFavorite),
      favoriteSortOrder: Value(favoriteSortOrder),
    );
  }

  factory FolderTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderTableData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      sortOrder: serializer.fromJson<double>(json['sortOrder']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      favoriteSortOrder: serializer.fromJson<double>(json['favoriteSortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'parentId': serializer.toJson<int?>(parentId),
      'sortOrder': serializer.toJson<double>(sortOrder),
      'createdAt': serializer.toJson<String>(createdAt),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'favoriteSortOrder': serializer.toJson<double>(favoriteSortOrder),
    };
  }

  FolderTableData copyWith({
    int? id,
    String? name,
    Value<int?> parentId = const Value.absent(),
    double? sortOrder,
    String? createdAt,
    bool? isPinned,
    bool? isFavorite,
    double? favoriteSortOrder,
  }) => FolderTableData(
    id: id ?? this.id,
    name: name ?? this.name,
    parentId: parentId.present ? parentId.value : this.parentId,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    favoriteSortOrder: favoriteSortOrder ?? this.favoriteSortOrder,
  );
  FolderTableData copyWithCompanion(FolderTableCompanion data) {
    return FolderTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      favoriteSortOrder: data.favoriteSortOrder.present
          ? data.favoriteSortOrder.value
          : this.favoriteSortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('favoriteSortOrder: $favoriteSortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    parentId,
    sortOrder,
    createdAt,
    isPinned,
    isFavorite,
    favoriteSortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.parentId == this.parentId &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.isPinned == this.isPinned &&
          other.isFavorite == this.isFavorite &&
          other.favoriteSortOrder == this.favoriteSortOrder);
}

class FolderTableCompanion extends UpdateCompanion<FolderTableData> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> parentId;
  final Value<double> sortOrder;
  final Value<String> createdAt;
  final Value<bool> isPinned;
  final Value<bool> isFavorite;
  final Value<double> favoriteSortOrder;
  const FolderTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.favoriteSortOrder = const Value.absent(),
  });
  FolderTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.parentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required String createdAt,
    this.isPinned = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.favoriteSortOrder = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<FolderTableData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? parentId,
    Expression<double>? sortOrder,
    Expression<String>? createdAt,
    Expression<bool>? isPinned,
    Expression<bool>? isFavorite,
    Expression<double>? favoriteSortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (favoriteSortOrder != null) 'favorite_sort_order': favoriteSortOrder,
    });
  }

  FolderTableCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? parentId,
    Value<double>? sortOrder,
    Value<String>? createdAt,
    Value<bool>? isPinned,
    Value<bool>? isFavorite,
    Value<double>? favoriteSortOrder,
  }) {
    return FolderTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      favoriteSortOrder: favoriteSortOrder ?? this.favoriteSortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (favoriteSortOrder.present) {
      map['favorite_sort_order'] = Variable<double>(favoriteSortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FolderTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('favoriteSortOrder: $favoriteSortOrder')
          ..write(')'))
        .toString();
  }
}

class $NoteTableTable extends NoteTable
    with TableInfo<$NoteTableTable, NoteTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id)',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<double> sortOrder = GeneratedColumn<double>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isImportantMeta = const VerificationMeta(
    'isImportant',
  );
  @override
  late final GeneratedColumn<bool> isImportant = GeneratedColumn<bool>(
    'is_important',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_important" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _favoriteSortOrderMeta = const VerificationMeta(
    'favoriteSortOrder',
  );
  @override
  late final GeneratedColumn<double> favoriteSortOrder =
      GeneratedColumn<double>(
        'favorite_sort_order',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.0),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    content,
    createdAt,
    updatedAt,
    folderId,
    sortOrder,
    deletedAt,
    isPinned,
    isImportant,
    isFavorite,
    favoriteSortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_important')) {
      context.handle(
        _isImportantMeta,
        isImportant.isAcceptableOrUnknown(
          data['is_important']!,
          _isImportantMeta,
        ),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('favorite_sort_order')) {
      context.handle(
        _favoriteSortOrderMeta,
        favoriteSortOrder.isAcceptableOrUnknown(
          data['favorite_sort_order']!,
          _favoriteSortOrderMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sort_order'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isImportant: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_important'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      favoriteSortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}favorite_sort_order'],
      )!,
    );
  }

  @override
  $NoteTableTable createAlias(String alias) {
    return $NoteTableTable(attachedDatabase, alias);
  }
}

class NoteTableData extends DataClass implements Insertable<NoteTableData> {
  final int id;
  final String title;
  final String content;
  final String createdAt;
  final String updatedAt;
  final int? folderId;
  final double sortOrder;
  final String? deletedAt;
  final bool isPinned;
  final bool isImportant;
  final bool isFavorite;
  final double favoriteSortOrder;
  const NoteTableData({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    required this.sortOrder,
    this.deletedAt,
    required this.isPinned,
    required this.isImportant,
    required this.isFavorite,
    required this.favoriteSortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<int>(folderId);
    }
    map['sort_order'] = Variable<double>(sortOrder);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_important'] = Variable<bool>(isImportant);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['favorite_sort_order'] = Variable<double>(favoriteSortOrder);
    return map;
  }

  NoteTableCompanion toCompanion(bool nullToAbsent) {
    return NoteTableCompanion(
      id: Value(id),
      title: Value(title),
      content: Value(content),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      sortOrder: Value(sortOrder),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      isPinned: Value(isPinned),
      isImportant: Value(isImportant),
      isFavorite: Value(isFavorite),
      favoriteSortOrder: Value(favoriteSortOrder),
    );
  }

  factory NoteTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTableData(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      folderId: serializer.fromJson<int?>(json['folderId']),
      sortOrder: serializer.fromJson<double>(json['sortOrder']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isImportant: serializer.fromJson<bool>(json['isImportant']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      favoriteSortOrder: serializer.fromJson<double>(json['favoriteSortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'folderId': serializer.toJson<int?>(folderId),
      'sortOrder': serializer.toJson<double>(sortOrder),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isImportant': serializer.toJson<bool>(isImportant),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'favoriteSortOrder': serializer.toJson<double>(favoriteSortOrder),
    };
  }

  NoteTableData copyWith({
    int? id,
    String? title,
    String? content,
    String? createdAt,
    String? updatedAt,
    Value<int?> folderId = const Value.absent(),
    double? sortOrder,
    Value<String?> deletedAt = const Value.absent(),
    bool? isPinned,
    bool? isImportant,
    bool? isFavorite,
    double? favoriteSortOrder,
  }) => NoteTableData(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    folderId: folderId.present ? folderId.value : this.folderId,
    sortOrder: sortOrder ?? this.sortOrder,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    isPinned: isPinned ?? this.isPinned,
    isImportant: isImportant ?? this.isImportant,
    isFavorite: isFavorite ?? this.isFavorite,
    favoriteSortOrder: favoriteSortOrder ?? this.favoriteSortOrder,
  );
  NoteTableData copyWithCompanion(NoteTableCompanion data) {
    return NoteTableData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isImportant: data.isImportant.present
          ? data.isImportant.value
          : this.isImportant,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      favoriteSortOrder: data.favoriteSortOrder.present
          ? data.favoriteSortOrder.value
          : this.favoriteSortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTableData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isImportant: $isImportant, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('favoriteSortOrder: $favoriteSortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    content,
    createdAt,
    updatedAt,
    folderId,
    sortOrder,
    deletedAt,
    isPinned,
    isImportant,
    isFavorite,
    favoriteSortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTableData &&
          other.id == this.id &&
          other.title == this.title &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.folderId == this.folderId &&
          other.sortOrder == this.sortOrder &&
          other.deletedAt == this.deletedAt &&
          other.isPinned == this.isPinned &&
          other.isImportant == this.isImportant &&
          other.isFavorite == this.isFavorite &&
          other.favoriteSortOrder == this.favoriteSortOrder);
}

class NoteTableCompanion extends UpdateCompanion<NoteTableData> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> content;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int?> folderId;
  final Value<double> sortOrder;
  final Value<String?> deletedAt;
  final Value<bool> isPinned;
  final Value<bool> isImportant;
  final Value<bool> isFavorite;
  final Value<double> favoriteSortOrder;
  const NoteTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isImportant = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.favoriteSortOrder = const Value.absent(),
  });
  NoteTableCompanion.insert({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.folderId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isImportant = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.favoriteSortOrder = const Value.absent(),
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<NoteTableData> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? folderId,
    Expression<double>? sortOrder,
    Expression<String>? deletedAt,
    Expression<bool>? isPinned,
    Expression<bool>? isImportant,
    Expression<bool>? isFavorite,
    Expression<double>? favoriteSortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (folderId != null) 'folder_id': folderId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isImportant != null) 'is_important': isImportant,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (favoriteSortOrder != null) 'favorite_sort_order': favoriteSortOrder,
    });
  }

  NoteTableCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? content,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int?>? folderId,
    Value<double>? sortOrder,
    Value<String?>? deletedAt,
    Value<bool>? isPinned,
    Value<bool>? isImportant,
    Value<bool>? isFavorite,
    Value<double>? favoriteSortOrder,
  }) {
    return NoteTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderId: folderId ?? this.folderId,
      sortOrder: sortOrder ?? this.sortOrder,
      deletedAt: deletedAt ?? this.deletedAt,
      isPinned: isPinned ?? this.isPinned,
      isImportant: isImportant ?? this.isImportant,
      isFavorite: isFavorite ?? this.isFavorite,
      favoriteSortOrder: favoriteSortOrder ?? this.favoriteSortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<double>(sortOrder.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isImportant.present) {
      map['is_important'] = Variable<bool>(isImportant.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (favoriteSortOrder.present) {
      map['favorite_sort_order'] = Variable<double>(favoriteSortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('folderId: $folderId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isPinned: $isPinned, ')
          ..write('isImportant: $isImportant, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('favoriteSortOrder: $favoriteSortOrder')
          ..write(')'))
        .toString();
  }
}

class $TagTableTable extends TagTable
    with TableInfo<$TagTableTable, TagTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $TagTableTable createAlias(String alias) {
    return $TagTableTable(attachedDatabase, alias);
  }
}

class TagTableData extends DataClass implements Insertable<TagTableData> {
  final int id;
  final String name;
  const TagTableData({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  TagTableCompanion toCompanion(bool nullToAbsent) {
    return TagTableCompanion(id: Value(id), name: Value(name));
  }

  factory TagTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagTableData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  TagTableData copyWith({int? id, String? name}) =>
      TagTableData(id: id ?? this.id, name: name ?? this.name);
  TagTableData copyWithCompanion(TagTableCompanion data) {
    return TagTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagTableData(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagTableData && other.id == this.id && other.name == this.name);
}

class TagTableCompanion extends UpdateCompanion<TagTableData> {
  final Value<int> id;
  final Value<String> name;
  const TagTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  TagTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<TagTableData> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  TagTableCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return TagTableCompanion(id: id ?? this.id, name: name ?? this.name);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $NoteTagTableTable extends NoteTagTable
    with TableInfo<$NoteTagTableTable, NoteTagTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTagTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<int> noteId = GeneratedColumn<int>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id)',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [noteId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteTagTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {noteId, tagId};
  @override
  NoteTagTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTagTableData(
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}note_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $NoteTagTableTable createAlias(String alias) {
    return $NoteTagTableTable(attachedDatabase, alias);
  }
}

class NoteTagTableData extends DataClass
    implements Insertable<NoteTagTableData> {
  final int noteId;
  final int tagId;
  const NoteTagTableData({required this.noteId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['note_id'] = Variable<int>(noteId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  NoteTagTableCompanion toCompanion(bool nullToAbsent) {
    return NoteTagTableCompanion(noteId: Value(noteId), tagId: Value(tagId));
  }

  factory NoteTagTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTagTableData(
      noteId: serializer.fromJson<int>(json['noteId']),
      tagId: serializer.fromJson<int>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'noteId': serializer.toJson<int>(noteId),
      'tagId': serializer.toJson<int>(tagId),
    };
  }

  NoteTagTableData copyWith({int? noteId, int? tagId}) => NoteTagTableData(
    noteId: noteId ?? this.noteId,
    tagId: tagId ?? this.tagId,
  );
  NoteTagTableData copyWithCompanion(NoteTagTableCompanion data) {
    return NoteTagTableData(
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTagTableData(')
          ..write('noteId: $noteId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(noteId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTagTableData &&
          other.noteId == this.noteId &&
          other.tagId == this.tagId);
}

class NoteTagTableCompanion extends UpdateCompanion<NoteTagTableData> {
  final Value<int> noteId;
  final Value<int> tagId;
  final Value<int> rowid;
  const NoteTagTableCompanion({
    this.noteId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NoteTagTableCompanion.insert({
    required int noteId,
    required int tagId,
    this.rowid = const Value.absent(),
  }) : noteId = Value(noteId),
       tagId = Value(tagId);
  static Insertable<NoteTagTableData> custom({
    Expression<int>? noteId,
    Expression<int>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (noteId != null) 'note_id': noteId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NoteTagTableCompanion copyWith({
    Value<int>? noteId,
    Value<int>? tagId,
    Value<int>? rowid,
  }) {
    return NoteTagTableCompanion(
      noteId: noteId ?? this.noteId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (noteId.present) {
      map['note_id'] = Variable<int>(noteId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTagTableCompanion(')
          ..write('noteId: $noteId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentTableTable extends AttachmentTable
    with TableInfo<$AttachmentTableTable, AttachmentTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<int> noteId = GeneratedColumn<int>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id)',
    ),
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    noteId,
    fileName,
    filePath,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttachmentTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttachmentTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}note_id'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttachmentTableTable createAlias(String alias) {
    return $AttachmentTableTable(attachedDatabase, alias);
  }
}

class AttachmentTableData extends DataClass
    implements Insertable<AttachmentTableData> {
  final int id;
  final int noteId;
  final String fileName;
  final String filePath;
  final String createdAt;
  const AttachmentTableData({
    required this.id,
    required this.noteId,
    required this.fileName,
    required this.filePath,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['note_id'] = Variable<int>(noteId);
    map['file_name'] = Variable<String>(fileName);
    map['file_path'] = Variable<String>(filePath);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  AttachmentTableCompanion toCompanion(bool nullToAbsent) {
    return AttachmentTableCompanion(
      id: Value(id),
      noteId: Value(noteId),
      fileName: Value(fileName),
      filePath: Value(filePath),
      createdAt: Value(createdAt),
    );
  }

  factory AttachmentTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentTableData(
      id: serializer.fromJson<int>(json['id']),
      noteId: serializer.fromJson<int>(json['noteId']),
      fileName: serializer.fromJson<String>(json['fileName']),
      filePath: serializer.fromJson<String>(json['filePath']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'noteId': serializer.toJson<int>(noteId),
      'fileName': serializer.toJson<String>(fileName),
      'filePath': serializer.toJson<String>(filePath),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  AttachmentTableData copyWith({
    int? id,
    int? noteId,
    String? fileName,
    String? filePath,
    String? createdAt,
  }) => AttachmentTableData(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    fileName: fileName ?? this.fileName,
    filePath: filePath ?? this.filePath,
    createdAt: createdAt ?? this.createdAt,
  );
  AttachmentTableData copyWithCompanion(AttachmentTableCompanion data) {
    return AttachmentTableData(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentTableData(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('fileName: $fileName, ')
          ..write('filePath: $filePath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, noteId, fileName, filePath, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentTableData &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.fileName == this.fileName &&
          other.filePath == this.filePath &&
          other.createdAt == this.createdAt);
}

class AttachmentTableCompanion extends UpdateCompanion<AttachmentTableData> {
  final Value<int> id;
  final Value<int> noteId;
  final Value<String> fileName;
  final Value<String> filePath;
  final Value<String> createdAt;
  const AttachmentTableCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.fileName = const Value.absent(),
    this.filePath = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AttachmentTableCompanion.insert({
    this.id = const Value.absent(),
    required int noteId,
    required String fileName,
    required String filePath,
    required String createdAt,
  }) : noteId = Value(noteId),
       fileName = Value(fileName),
       filePath = Value(filePath),
       createdAt = Value(createdAt);
  static Insertable<AttachmentTableData> custom({
    Expression<int>? id,
    Expression<int>? noteId,
    Expression<String>? fileName,
    Expression<String>? filePath,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (fileName != null) 'file_name': fileName,
      if (filePath != null) 'file_path': filePath,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AttachmentTableCompanion copyWith({
    Value<int>? id,
    Value<int>? noteId,
    Value<String>? fileName,
    Value<String>? filePath,
    Value<String>? createdAt,
  }) {
    return AttachmentTableCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<int>(noteId.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentTableCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('fileName: $fileName, ')
          ..write('filePath: $filePath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SettingTableTable extends SettingTable
    with TableInfo<$SettingTableTable, SettingTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingTableData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingTableTable createAlias(String alias) {
    return $SettingTableTable(attachedDatabase, alias);
  }
}

class SettingTableData extends DataClass
    implements Insertable<SettingTableData> {
  final String key;
  final String value;
  const SettingTableData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingTableCompanion toCompanion(bool nullToAbsent) {
    return SettingTableCompanion(key: Value(key), value: Value(value));
  }

  factory SettingTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingTableData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingTableData copyWith({String? key, String? value}) =>
      SettingTableData(key: key ?? this.key, value: value ?? this.value);
  SettingTableData copyWithCompanion(SettingTableCompanion data) {
    return SettingTableData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingTableData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingTableData &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingTableCompanion extends UpdateCompanion<SettingTableData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingTableCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingTableData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingTableCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EventTableTable extends EventTable
    with TableInfo<$EventTableTable, EventTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _eventDateMeta = const VerificationMeta(
    'eventDate',
  );
  @override
  late final GeneratedColumn<String> eventDate = GeneratedColumn<String>(
    'event_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alarmEnabledMeta = const VerificationMeta(
    'alarmEnabled',
  );
  @override
  late final GeneratedColumn<bool> alarmEnabled = GeneratedColumn<bool>(
    'alarm_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("alarm_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _alarmTimeMeta = const VerificationMeta(
    'alarmTime',
  );
  @override
  late final GeneratedColumn<String> alarmTime = GeneratedColumn<String>(
    'alarm_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('09:00'),
  );
  static const VerificationMeta _alarmDaysBeforeMeta = const VerificationMeta(
    'alarmDaysBefore',
  );
  @override
  late final GeneratedColumn<int> alarmDaysBefore = GeneratedColumn<int>(
    'alarm_days_before',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _googleEventIdMeta = const VerificationMeta(
    'googleEventId',
  );
  @override
  late final GeneratedColumn<String> googleEventId = GeneratedColumn<String>(
    'google_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _locationNameMeta = const VerificationMeta(
    'locationName',
  );
  @override
  late final GeneratedColumn<String> locationName = GeneratedColumn<String>(
    'location_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationLatMeta = const VerificationMeta(
    'locationLat',
  );
  @override
  late final GeneratedColumn<double> locationLat = GeneratedColumn<double>(
    'location_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationLngMeta = const VerificationMeta(
    'locationLng',
  );
  @override
  late final GeneratedColumn<double> locationLng = GeneratedColumn<double>(
    'location_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<String> startTime = GeneratedColumn<String>(
    'start_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<String> endTime = GeneratedColumn<String>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isAllDayMeta = const VerificationMeta(
    'isAllDay',
  );
  @override
  late final GeneratedColumn<bool> isAllDay = GeneratedColumn<bool>(
    'is_all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    eventDate,
    createdAt,
    alarmEnabled,
    alarmTime,
    alarmDaysBefore,
    isCompleted,
    priority,
    googleEventId,
    locationName,
    locationLat,
    locationLng,
    startDate,
    endDate,
    startTime,
    endTime,
    isAllDay,
    content,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('event_date')) {
      context.handle(
        _eventDateMeta,
        eventDate.isAcceptableOrUnknown(data['event_date']!, _eventDateMeta),
      );
    } else if (isInserting) {
      context.missing(_eventDateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('alarm_enabled')) {
      context.handle(
        _alarmEnabledMeta,
        alarmEnabled.isAcceptableOrUnknown(
          data['alarm_enabled']!,
          _alarmEnabledMeta,
        ),
      );
    }
    if (data.containsKey('alarm_time')) {
      context.handle(
        _alarmTimeMeta,
        alarmTime.isAcceptableOrUnknown(data['alarm_time']!, _alarmTimeMeta),
      );
    }
    if (data.containsKey('alarm_days_before')) {
      context.handle(
        _alarmDaysBeforeMeta,
        alarmDaysBefore.isAcceptableOrUnknown(
          data['alarm_days_before']!,
          _alarmDaysBeforeMeta,
        ),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('google_event_id')) {
      context.handle(
        _googleEventIdMeta,
        googleEventId.isAcceptableOrUnknown(
          data['google_event_id']!,
          _googleEventIdMeta,
        ),
      );
    }
    if (data.containsKey('location_name')) {
      context.handle(
        _locationNameMeta,
        locationName.isAcceptableOrUnknown(
          data['location_name']!,
          _locationNameMeta,
        ),
      );
    }
    if (data.containsKey('location_lat')) {
      context.handle(
        _locationLatMeta,
        locationLat.isAcceptableOrUnknown(
          data['location_lat']!,
          _locationLatMeta,
        ),
      );
    }
    if (data.containsKey('location_lng')) {
      context.handle(
        _locationLngMeta,
        locationLng.isAcceptableOrUnknown(
          data['location_lng']!,
          _locationLngMeta,
        ),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    if (data.containsKey('is_all_day')) {
      context.handle(
        _isAllDayMeta,
        isAllDay.isAcceptableOrUnknown(data['is_all_day']!, _isAllDayMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      eventDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_date'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      alarmEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}alarm_enabled'],
      )!,
      alarmTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alarm_time'],
      )!,
      alarmDaysBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}alarm_days_before'],
      )!,
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      googleEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}google_event_id'],
      )!,
      locationName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_name'],
      ),
      locationLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}location_lat'],
      ),
      locationLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}location_lng'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      ),
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_time'],
      ),
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_time'],
      ),
      isAllDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_all_day'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
    );
  }

  @override
  $EventTableTable createAlias(String alias) {
    return $EventTableTable(attachedDatabase, alias);
  }
}

class EventTableData extends DataClass implements Insertable<EventTableData> {
  final int id;
  final String title;
  final String eventDate;
  final String createdAt;
  final bool alarmEnabled;
  final String alarmTime;
  final int alarmDaysBefore;
  final bool isCompleted;
  final int priority;
  final String googleEventId;
  final String? locationName;
  final double? locationLat;
  final double? locationLng;
  final String? startDate;
  final String? endDate;
  final String? startTime;
  final String? endTime;
  final bool isAllDay;
  final String? content;
  const EventTableData({
    required this.id,
    required this.title,
    required this.eventDate,
    required this.createdAt,
    required this.alarmEnabled,
    required this.alarmTime,
    required this.alarmDaysBefore,
    required this.isCompleted,
    required this.priority,
    required this.googleEventId,
    this.locationName,
    this.locationLat,
    this.locationLng,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    required this.isAllDay,
    this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['event_date'] = Variable<String>(eventDate);
    map['created_at'] = Variable<String>(createdAt);
    map['alarm_enabled'] = Variable<bool>(alarmEnabled);
    map['alarm_time'] = Variable<String>(alarmTime);
    map['alarm_days_before'] = Variable<int>(alarmDaysBefore);
    map['is_completed'] = Variable<bool>(isCompleted);
    map['priority'] = Variable<int>(priority);
    map['google_event_id'] = Variable<String>(googleEventId);
    if (!nullToAbsent || locationName != null) {
      map['location_name'] = Variable<String>(locationName);
    }
    if (!nullToAbsent || locationLat != null) {
      map['location_lat'] = Variable<double>(locationLat);
    }
    if (!nullToAbsent || locationLng != null) {
      map['location_lng'] = Variable<double>(locationLng);
    }
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<String>(startDate);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<String>(endDate);
    }
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<String>(startTime);
    }
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<String>(endTime);
    }
    map['is_all_day'] = Variable<bool>(isAllDay);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    return map;
  }

  EventTableCompanion toCompanion(bool nullToAbsent) {
    return EventTableCompanion(
      id: Value(id),
      title: Value(title),
      eventDate: Value(eventDate),
      createdAt: Value(createdAt),
      alarmEnabled: Value(alarmEnabled),
      alarmTime: Value(alarmTime),
      alarmDaysBefore: Value(alarmDaysBefore),
      isCompleted: Value(isCompleted),
      priority: Value(priority),
      googleEventId: Value(googleEventId),
      locationName: locationName == null && nullToAbsent
          ? const Value.absent()
          : Value(locationName),
      locationLat: locationLat == null && nullToAbsent
          ? const Value.absent()
          : Value(locationLat),
      locationLng: locationLng == null && nullToAbsent
          ? const Value.absent()
          : Value(locationLng),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      isAllDay: Value(isAllDay),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
    );
  }

  factory EventTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventTableData(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      eventDate: serializer.fromJson<String>(json['eventDate']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      alarmEnabled: serializer.fromJson<bool>(json['alarmEnabled']),
      alarmTime: serializer.fromJson<String>(json['alarmTime']),
      alarmDaysBefore: serializer.fromJson<int>(json['alarmDaysBefore']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      priority: serializer.fromJson<int>(json['priority']),
      googleEventId: serializer.fromJson<String>(json['googleEventId']),
      locationName: serializer.fromJson<String?>(json['locationName']),
      locationLat: serializer.fromJson<double?>(json['locationLat']),
      locationLng: serializer.fromJson<double?>(json['locationLng']),
      startDate: serializer.fromJson<String?>(json['startDate']),
      endDate: serializer.fromJson<String?>(json['endDate']),
      startTime: serializer.fromJson<String?>(json['startTime']),
      endTime: serializer.fromJson<String?>(json['endTime']),
      isAllDay: serializer.fromJson<bool>(json['isAllDay']),
      content: serializer.fromJson<String?>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'eventDate': serializer.toJson<String>(eventDate),
      'createdAt': serializer.toJson<String>(createdAt),
      'alarmEnabled': serializer.toJson<bool>(alarmEnabled),
      'alarmTime': serializer.toJson<String>(alarmTime),
      'alarmDaysBefore': serializer.toJson<int>(alarmDaysBefore),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'priority': serializer.toJson<int>(priority),
      'googleEventId': serializer.toJson<String>(googleEventId),
      'locationName': serializer.toJson<String?>(locationName),
      'locationLat': serializer.toJson<double?>(locationLat),
      'locationLng': serializer.toJson<double?>(locationLng),
      'startDate': serializer.toJson<String?>(startDate),
      'endDate': serializer.toJson<String?>(endDate),
      'startTime': serializer.toJson<String?>(startTime),
      'endTime': serializer.toJson<String?>(endTime),
      'isAllDay': serializer.toJson<bool>(isAllDay),
      'content': serializer.toJson<String?>(content),
    };
  }

  EventTableData copyWith({
    int? id,
    String? title,
    String? eventDate,
    String? createdAt,
    bool? alarmEnabled,
    String? alarmTime,
    int? alarmDaysBefore,
    bool? isCompleted,
    int? priority,
    String? googleEventId,
    Value<String?> locationName = const Value.absent(),
    Value<double?> locationLat = const Value.absent(),
    Value<double?> locationLng = const Value.absent(),
    Value<String?> startDate = const Value.absent(),
    Value<String?> endDate = const Value.absent(),
    Value<String?> startTime = const Value.absent(),
    Value<String?> endTime = const Value.absent(),
    bool? isAllDay,
    Value<String?> content = const Value.absent(),
  }) => EventTableData(
    id: id ?? this.id,
    title: title ?? this.title,
    eventDate: eventDate ?? this.eventDate,
    createdAt: createdAt ?? this.createdAt,
    alarmEnabled: alarmEnabled ?? this.alarmEnabled,
    alarmTime: alarmTime ?? this.alarmTime,
    alarmDaysBefore: alarmDaysBefore ?? this.alarmDaysBefore,
    isCompleted: isCompleted ?? this.isCompleted,
    priority: priority ?? this.priority,
    googleEventId: googleEventId ?? this.googleEventId,
    locationName: locationName.present ? locationName.value : this.locationName,
    locationLat: locationLat.present ? locationLat.value : this.locationLat,
    locationLng: locationLng.present ? locationLng.value : this.locationLng,
    startDate: startDate.present ? startDate.value : this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    startTime: startTime.present ? startTime.value : this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    isAllDay: isAllDay ?? this.isAllDay,
    content: content.present ? content.value : this.content,
  );
  EventTableData copyWithCompanion(EventTableCompanion data) {
    return EventTableData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      eventDate: data.eventDate.present ? data.eventDate.value : this.eventDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      alarmEnabled: data.alarmEnabled.present
          ? data.alarmEnabled.value
          : this.alarmEnabled,
      alarmTime: data.alarmTime.present ? data.alarmTime.value : this.alarmTime,
      alarmDaysBefore: data.alarmDaysBefore.present
          ? data.alarmDaysBefore.value
          : this.alarmDaysBefore,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      priority: data.priority.present ? data.priority.value : this.priority,
      googleEventId: data.googleEventId.present
          ? data.googleEventId.value
          : this.googleEventId,
      locationName: data.locationName.present
          ? data.locationName.value
          : this.locationName,
      locationLat: data.locationLat.present
          ? data.locationLat.value
          : this.locationLat,
      locationLng: data.locationLng.present
          ? data.locationLng.value
          : this.locationLng,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      isAllDay: data.isAllDay.present ? data.isAllDay.value : this.isAllDay,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventTableData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('eventDate: $eventDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('alarmEnabled: $alarmEnabled, ')
          ..write('alarmTime: $alarmTime, ')
          ..write('alarmDaysBefore: $alarmDaysBefore, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('priority: $priority, ')
          ..write('googleEventId: $googleEventId, ')
          ..write('locationName: $locationName, ')
          ..write('locationLat: $locationLat, ')
          ..write('locationLng: $locationLng, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('isAllDay: $isAllDay, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    eventDate,
    createdAt,
    alarmEnabled,
    alarmTime,
    alarmDaysBefore,
    isCompleted,
    priority,
    googleEventId,
    locationName,
    locationLat,
    locationLng,
    startDate,
    endDate,
    startTime,
    endTime,
    isAllDay,
    content,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTableData &&
          other.id == this.id &&
          other.title == this.title &&
          other.eventDate == this.eventDate &&
          other.createdAt == this.createdAt &&
          other.alarmEnabled == this.alarmEnabled &&
          other.alarmTime == this.alarmTime &&
          other.alarmDaysBefore == this.alarmDaysBefore &&
          other.isCompleted == this.isCompleted &&
          other.priority == this.priority &&
          other.googleEventId == this.googleEventId &&
          other.locationName == this.locationName &&
          other.locationLat == this.locationLat &&
          other.locationLng == this.locationLng &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.isAllDay == this.isAllDay &&
          other.content == this.content);
}

class EventTableCompanion extends UpdateCompanion<EventTableData> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> eventDate;
  final Value<String> createdAt;
  final Value<bool> alarmEnabled;
  final Value<String> alarmTime;
  final Value<int> alarmDaysBefore;
  final Value<bool> isCompleted;
  final Value<int> priority;
  final Value<String> googleEventId;
  final Value<String?> locationName;
  final Value<double?> locationLat;
  final Value<double?> locationLng;
  final Value<String?> startDate;
  final Value<String?> endDate;
  final Value<String?> startTime;
  final Value<String?> endTime;
  final Value<bool> isAllDay;
  final Value<String?> content;
  const EventTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.eventDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.alarmEnabled = const Value.absent(),
    this.alarmTime = const Value.absent(),
    this.alarmDaysBefore = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.priority = const Value.absent(),
    this.googleEventId = const Value.absent(),
    this.locationName = const Value.absent(),
    this.locationLat = const Value.absent(),
    this.locationLng = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.isAllDay = const Value.absent(),
    this.content = const Value.absent(),
  });
  EventTableCompanion.insert({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    required String eventDate,
    required String createdAt,
    this.alarmEnabled = const Value.absent(),
    this.alarmTime = const Value.absent(),
    this.alarmDaysBefore = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.priority = const Value.absent(),
    this.googleEventId = const Value.absent(),
    this.locationName = const Value.absent(),
    this.locationLat = const Value.absent(),
    this.locationLng = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.isAllDay = const Value.absent(),
    this.content = const Value.absent(),
  }) : eventDate = Value(eventDate),
       createdAt = Value(createdAt);
  static Insertable<EventTableData> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? eventDate,
    Expression<String>? createdAt,
    Expression<bool>? alarmEnabled,
    Expression<String>? alarmTime,
    Expression<int>? alarmDaysBefore,
    Expression<bool>? isCompleted,
    Expression<int>? priority,
    Expression<String>? googleEventId,
    Expression<String>? locationName,
    Expression<double>? locationLat,
    Expression<double>? locationLng,
    Expression<String>? startDate,
    Expression<String>? endDate,
    Expression<String>? startTime,
    Expression<String>? endTime,
    Expression<bool>? isAllDay,
    Expression<String>? content,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (eventDate != null) 'event_date': eventDate,
      if (createdAt != null) 'created_at': createdAt,
      if (alarmEnabled != null) 'alarm_enabled': alarmEnabled,
      if (alarmTime != null) 'alarm_time': alarmTime,
      if (alarmDaysBefore != null) 'alarm_days_before': alarmDaysBefore,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (priority != null) 'priority': priority,
      if (googleEventId != null) 'google_event_id': googleEventId,
      if (locationName != null) 'location_name': locationName,
      if (locationLat != null) 'location_lat': locationLat,
      if (locationLng != null) 'location_lng': locationLng,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (isAllDay != null) 'is_all_day': isAllDay,
      if (content != null) 'content': content,
    });
  }

  EventTableCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? eventDate,
    Value<String>? createdAt,
    Value<bool>? alarmEnabled,
    Value<String>? alarmTime,
    Value<int>? alarmDaysBefore,
    Value<bool>? isCompleted,
    Value<int>? priority,
    Value<String>? googleEventId,
    Value<String?>? locationName,
    Value<double?>? locationLat,
    Value<double?>? locationLng,
    Value<String?>? startDate,
    Value<String?>? endDate,
    Value<String?>? startTime,
    Value<String?>? endTime,
    Value<bool>? isAllDay,
    Value<String?>? content,
  }) {
    return EventTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      eventDate: eventDate ?? this.eventDate,
      createdAt: createdAt ?? this.createdAt,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      alarmTime: alarmTime ?? this.alarmTime,
      alarmDaysBefore: alarmDaysBefore ?? this.alarmDaysBefore,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      googleEventId: googleEventId ?? this.googleEventId,
      locationName: locationName ?? this.locationName,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      content: content ?? this.content,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (eventDate.present) {
      map['event_date'] = Variable<String>(eventDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (alarmEnabled.present) {
      map['alarm_enabled'] = Variable<bool>(alarmEnabled.value);
    }
    if (alarmTime.present) {
      map['alarm_time'] = Variable<String>(alarmTime.value);
    }
    if (alarmDaysBefore.present) {
      map['alarm_days_before'] = Variable<int>(alarmDaysBefore.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (googleEventId.present) {
      map['google_event_id'] = Variable<String>(googleEventId.value);
    }
    if (locationName.present) {
      map['location_name'] = Variable<String>(locationName.value);
    }
    if (locationLat.present) {
      map['location_lat'] = Variable<double>(locationLat.value);
    }
    if (locationLng.present) {
      map['location_lng'] = Variable<double>(locationLng.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<String>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<String>(endTime.value);
    }
    if (isAllDay.present) {
      map['is_all_day'] = Variable<bool>(isAllDay.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('eventDate: $eventDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('alarmEnabled: $alarmEnabled, ')
          ..write('alarmTime: $alarmTime, ')
          ..write('alarmDaysBefore: $alarmDaysBefore, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('priority: $priority, ')
          ..write('googleEventId: $googleEventId, ')
          ..write('locationName: $locationName, ')
          ..write('locationLat: $locationLat, ')
          ..write('locationLng: $locationLng, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('isAllDay: $isAllDay, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }
}

class $EventTagTableTable extends EventTagTable
    with TableInfo<$EventTagTableTable, EventTagTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventTagTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#4A90E2'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, color];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventTagTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventTagTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventTagTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
    );
  }

  @override
  $EventTagTableTable createAlias(String alias) {
    return $EventTagTableTable(attachedDatabase, alias);
  }
}

class EventTagTableData extends DataClass
    implements Insertable<EventTagTableData> {
  final int id;
  final String name;
  final String color;
  const EventTagTableData({
    required this.id,
    required this.name,
    required this.color,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    return map;
  }

  EventTagTableCompanion toCompanion(bool nullToAbsent) {
    return EventTagTableCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
    );
  }

  factory EventTagTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventTagTableData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String>(color),
    };
  }

  EventTagTableData copyWith({int? id, String? name, String? color}) =>
      EventTagTableData(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
      );
  EventTagTableData copyWithCompanion(EventTagTableCompanion data) {
    return EventTagTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventTagTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTagTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color);
}

class EventTagTableCompanion extends UpdateCompanion<EventTagTableData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> color;
  const EventTagTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
  });
  EventTagTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
  }) : name = Value(name);
  static Insertable<EventTagTableData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? color,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
    });
  }

  EventTagTableCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? color,
  }) {
    return EventTagTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventTagTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }
}

class $EventTagRelationTableTable extends EventTagRelationTable
    with TableInfo<$EventTagRelationTableTable, EventTagRelationTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventTagRelationTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES events (id)',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES event_tags (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [eventId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_tag_relations';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventTagRelationTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId, tagId};
  @override
  EventTagRelationTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventTagRelationTableData(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $EventTagRelationTableTable createAlias(String alias) {
    return $EventTagRelationTableTable(attachedDatabase, alias);
  }
}

class EventTagRelationTableData extends DataClass
    implements Insertable<EventTagRelationTableData> {
  final int eventId;
  final int tagId;
  const EventTagRelationTableData({required this.eventId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<int>(eventId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  EventTagRelationTableCompanion toCompanion(bool nullToAbsent) {
    return EventTagRelationTableCompanion(
      eventId: Value(eventId),
      tagId: Value(tagId),
    );
  }

  factory EventTagRelationTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventTagRelationTableData(
      eventId: serializer.fromJson<int>(json['eventId']),
      tagId: serializer.fromJson<int>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<int>(eventId),
      'tagId': serializer.toJson<int>(tagId),
    };
  }

  EventTagRelationTableData copyWith({int? eventId, int? tagId}) =>
      EventTagRelationTableData(
        eventId: eventId ?? this.eventId,
        tagId: tagId ?? this.tagId,
      );
  EventTagRelationTableData copyWithCompanion(
    EventTagRelationTableCompanion data,
  ) {
    return EventTagRelationTableData(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventTagRelationTableData(')
          ..write('eventId: $eventId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(eventId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTagRelationTableData &&
          other.eventId == this.eventId &&
          other.tagId == this.tagId);
}

class EventTagRelationTableCompanion
    extends UpdateCompanion<EventTagRelationTableData> {
  final Value<int> eventId;
  final Value<int> tagId;
  final Value<int> rowid;
  const EventTagRelationTableCompanion({
    this.eventId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventTagRelationTableCompanion.insert({
    required int eventId,
    required int tagId,
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       tagId = Value(tagId);
  static Insertable<EventTagRelationTableData> custom({
    Expression<int>? eventId,
    Expression<int>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventTagRelationTableCompanion copyWith({
    Value<int>? eventId,
    Value<int>? tagId,
    Value<int>? rowid,
  }) {
    return EventTagRelationTableCompanion(
      eventId: eventId ?? this.eventId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventTagRelationTableCompanion(')
          ..write('eventId: $eventId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FolderTableTable folderTable = $FolderTableTable(this);
  late final $NoteTableTable noteTable = $NoteTableTable(this);
  late final $TagTableTable tagTable = $TagTableTable(this);
  late final $NoteTagTableTable noteTagTable = $NoteTagTableTable(this);
  late final $AttachmentTableTable attachmentTable = $AttachmentTableTable(
    this,
  );
  late final $SettingTableTable settingTable = $SettingTableTable(this);
  late final $EventTableTable eventTable = $EventTableTable(this);
  late final $EventTagTableTable eventTagTable = $EventTagTableTable(this);
  late final $EventTagRelationTableTable eventTagRelationTable =
      $EventTagRelationTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    folderTable,
    noteTable,
    tagTable,
    noteTagTable,
    attachmentTable,
    settingTable,
    eventTable,
    eventTagTable,
    eventTagRelationTable,
  ];
}

typedef $$FolderTableTableCreateCompanionBuilder =
    FolderTableCompanion Function({
      Value<int> id,
      required String name,
      Value<int?> parentId,
      Value<double> sortOrder,
      required String createdAt,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<double> favoriteSortOrder,
    });
typedef $$FolderTableTableUpdateCompanionBuilder =
    FolderTableCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int?> parentId,
      Value<double> sortOrder,
      Value<String> createdAt,
      Value<bool> isPinned,
      Value<bool> isFavorite,
      Value<double> favoriteSortOrder,
    });

final class $$FolderTableTableReferences
    extends BaseReferences<_$AppDatabase, $FolderTableTable, FolderTableData> {
  $$FolderTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FolderTableTable _parentIdTable(_$AppDatabase db) =>
      db.folderTable.createAlias(
        $_aliasNameGenerator(db.folderTable.parentId, db.folderTable.id),
      );

  $$FolderTableTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<int>('parent_id');
    if ($_column == null) return null;
    final manager = $$FolderTableTableTableManager(
      $_db,
      $_db.folderTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$NoteTableTable, List<NoteTableData>>
  _noteTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.noteTable,
    aliasName: $_aliasNameGenerator(db.folderTable.id, db.noteTable.folderId),
  );

  $$NoteTableTableProcessedTableManager get noteTableRefs {
    final manager = $$NoteTableTableTableManager(
      $_db,
      $_db.noteTable,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FolderTableTableFilterComposer
    extends Composer<_$AppDatabase, $FolderTableTable> {
  $$FolderTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get favoriteSortOrder => $composableBuilder(
    column: $table.favoriteSortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$FolderTableTableFilterComposer get parentId {
    final $$FolderTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.folderTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderTableTableFilterComposer(
            $db: $db,
            $table: $db.folderTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> noteTableRefs(
    Expression<bool> Function($$NoteTableTableFilterComposer f) f,
  ) {
    final $$NoteTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableFilterComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FolderTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FolderTableTable> {
  $$FolderTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get favoriteSortOrder => $composableBuilder(
    column: $table.favoriteSortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$FolderTableTableOrderingComposer get parentId {
    final $$FolderTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.folderTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderTableTableOrderingComposer(
            $db: $db,
            $table: $db.folderTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FolderTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FolderTableTable> {
  $$FolderTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<double> get favoriteSortOrder => $composableBuilder(
    column: $table.favoriteSortOrder,
    builder: (column) => column,
  );

  $$FolderTableTableAnnotationComposer get parentId {
    final $$FolderTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.folderTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderTableTableAnnotationComposer(
            $db: $db,
            $table: $db.folderTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> noteTableRefs<T extends Object>(
    Expression<T> Function($$NoteTableTableAnnotationComposer a) f,
  ) {
    final $$NoteTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FolderTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FolderTableTable,
          FolderTableData,
          $$FolderTableTableFilterComposer,
          $$FolderTableTableOrderingComposer,
          $$FolderTableTableAnnotationComposer,
          $$FolderTableTableCreateCompanionBuilder,
          $$FolderTableTableUpdateCompanionBuilder,
          (FolderTableData, $$FolderTableTableReferences),
          FolderTableData,
          PrefetchHooks Function({bool parentId, bool noteTableRefs})
        > {
  $$FolderTableTableTableManager(_$AppDatabase db, $FolderTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FolderTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FolderTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FolderTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<double> favoriteSortOrder = const Value.absent(),
              }) => FolderTableCompanion(
                id: id,
                name: name,
                parentId: parentId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                isPinned: isPinned,
                isFavorite: isFavorite,
                favoriteSortOrder: favoriteSortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> parentId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                required String createdAt,
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<double> favoriteSortOrder = const Value.absent(),
              }) => FolderTableCompanion.insert(
                id: id,
                name: name,
                parentId: parentId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                isPinned: isPinned,
                isFavorite: isFavorite,
                favoriteSortOrder: favoriteSortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FolderTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({parentId = false, noteTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (noteTableRefs) db.noteTable],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (parentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.parentId,
                                referencedTable: $$FolderTableTableReferences
                                    ._parentIdTable(db),
                                referencedColumn: $$FolderTableTableReferences
                                    ._parentIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (noteTableRefs)
                    await $_getPrefetchedData<
                      FolderTableData,
                      $FolderTableTable,
                      NoteTableData
                    >(
                      currentTable: table,
                      referencedTable: $$FolderTableTableReferences
                          ._noteTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FolderTableTableReferences(
                            db,
                            table,
                            p0,
                          ).noteTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FolderTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FolderTableTable,
      FolderTableData,
      $$FolderTableTableFilterComposer,
      $$FolderTableTableOrderingComposer,
      $$FolderTableTableAnnotationComposer,
      $$FolderTableTableCreateCompanionBuilder,
      $$FolderTableTableUpdateCompanionBuilder,
      (FolderTableData, $$FolderTableTableReferences),
      FolderTableData,
      PrefetchHooks Function({bool parentId, bool noteTableRefs})
    >;
typedef $$NoteTableTableCreateCompanionBuilder =
    NoteTableCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> content,
      required String createdAt,
      required String updatedAt,
      Value<int?> folderId,
      Value<double> sortOrder,
      Value<String?> deletedAt,
      Value<bool> isPinned,
      Value<bool> isImportant,
      Value<bool> isFavorite,
      Value<double> favoriteSortOrder,
    });
typedef $$NoteTableTableUpdateCompanionBuilder =
    NoteTableCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> content,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int?> folderId,
      Value<double> sortOrder,
      Value<String?> deletedAt,
      Value<bool> isPinned,
      Value<bool> isImportant,
      Value<bool> isFavorite,
      Value<double> favoriteSortOrder,
    });

final class $$NoteTableTableReferences
    extends BaseReferences<_$AppDatabase, $NoteTableTable, NoteTableData> {
  $$NoteTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FolderTableTable _folderIdTable(_$AppDatabase db) =>
      db.folderTable.createAlias(
        $_aliasNameGenerator(db.noteTable.folderId, db.folderTable.id),
      );

  $$FolderTableTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<int>('folder_id');
    if ($_column == null) return null;
    final manager = $$FolderTableTableTableManager(
      $_db,
      $_db.folderTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$NoteTagTableTable, List<NoteTagTableData>>
  _noteTagTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.noteTagTable,
    aliasName: $_aliasNameGenerator(db.noteTable.id, db.noteTagTable.noteId),
  );

  $$NoteTagTableTableProcessedTableManager get noteTagTableRefs {
    final manager = $$NoteTagTableTableTableManager(
      $_db,
      $_db.noteTagTable,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteTagTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttachmentTableTable, List<AttachmentTableData>>
  _attachmentTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachmentTable,
    aliasName: $_aliasNameGenerator(db.noteTable.id, db.attachmentTable.noteId),
  );

  $$AttachmentTableTableProcessedTableManager get attachmentTableRefs {
    final manager = $$AttachmentTableTableTableManager(
      $_db,
      $_db.attachmentTable,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _attachmentTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NoteTableTableFilterComposer
    extends Composer<_$AppDatabase, $NoteTableTable> {
  $$NoteTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isImportant => $composableBuilder(
    column: $table.isImportant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get favoriteSortOrder => $composableBuilder(
    column: $table.favoriteSortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$FolderTableTableFilterComposer get folderId {
    final $$FolderTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folderTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderTableTableFilterComposer(
            $db: $db,
            $table: $db.folderTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> noteTagTableRefs(
    Expression<bool> Function($$NoteTagTableTableFilterComposer f) f,
  ) {
    final $$NoteTagTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTagTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagTableTableFilterComposer(
            $db: $db,
            $table: $db.noteTagTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attachmentTableRefs(
    Expression<bool> Function($$AttachmentTableTableFilterComposer f) f,
  ) {
    final $$AttachmentTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachmentTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentTableTableFilterComposer(
            $db: $db,
            $table: $db.attachmentTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NoteTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteTableTable> {
  $$NoteTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isImportant => $composableBuilder(
    column: $table.isImportant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get favoriteSortOrder => $composableBuilder(
    column: $table.favoriteSortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$FolderTableTableOrderingComposer get folderId {
    final $$FolderTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folderTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderTableTableOrderingComposer(
            $db: $db,
            $table: $db.folderTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteTableTable> {
  $$NoteTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<double> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isImportant => $composableBuilder(
    column: $table.isImportant,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<double> get favoriteSortOrder => $composableBuilder(
    column: $table.favoriteSortOrder,
    builder: (column) => column,
  );

  $$FolderTableTableAnnotationComposer get folderId {
    final $$FolderTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folderTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderTableTableAnnotationComposer(
            $db: $db,
            $table: $db.folderTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> noteTagTableRefs<T extends Object>(
    Expression<T> Function($$NoteTagTableTableAnnotationComposer a) f,
  ) {
    final $$NoteTagTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTagTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTagTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attachmentTableRefs<T extends Object>(
    Expression<T> Function($$AttachmentTableTableAnnotationComposer a) f,
  ) {
    final $$AttachmentTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachmentTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentTableTableAnnotationComposer(
            $db: $db,
            $table: $db.attachmentTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NoteTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteTableTable,
          NoteTableData,
          $$NoteTableTableFilterComposer,
          $$NoteTableTableOrderingComposer,
          $$NoteTableTableAnnotationComposer,
          $$NoteTableTableCreateCompanionBuilder,
          $$NoteTableTableUpdateCompanionBuilder,
          (NoteTableData, $$NoteTableTableReferences),
          NoteTableData,
          PrefetchHooks Function({
            bool folderId,
            bool noteTagTableRefs,
            bool attachmentTableRefs,
          })
        > {
  $$NoteTableTableTableManager(_$AppDatabase db, $NoteTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isImportant = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<double> favoriteSortOrder = const Value.absent(),
              }) => NoteTableCompanion(
                id: id,
                title: title,
                content: content,
                createdAt: createdAt,
                updatedAt: updatedAt,
                folderId: folderId,
                sortOrder: sortOrder,
                deletedAt: deletedAt,
                isPinned: isPinned,
                isImportant: isImportant,
                isFavorite: isFavorite,
                favoriteSortOrder: favoriteSortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int?> folderId = const Value.absent(),
                Value<double> sortOrder = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isImportant = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<double> favoriteSortOrder = const Value.absent(),
              }) => NoteTableCompanion.insert(
                id: id,
                title: title,
                content: content,
                createdAt: createdAt,
                updatedAt: updatedAt,
                folderId: folderId,
                sortOrder: sortOrder,
                deletedAt: deletedAt,
                isPinned: isPinned,
                isImportant: isImportant,
                isFavorite: isFavorite,
                favoriteSortOrder: favoriteSortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NoteTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                folderId = false,
                noteTagTableRefs = false,
                attachmentTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (noteTagTableRefs) db.noteTagTable,
                    if (attachmentTableRefs) db.attachmentTable,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (folderId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.folderId,
                                    referencedTable: $$NoteTableTableReferences
                                        ._folderIdTable(db),
                                    referencedColumn: $$NoteTableTableReferences
                                        ._folderIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (noteTagTableRefs)
                        await $_getPrefetchedData<
                          NoteTableData,
                          $NoteTableTable,
                          NoteTagTableData
                        >(
                          currentTable: table,
                          referencedTable: $$NoteTableTableReferences
                              ._noteTagTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NoteTableTableReferences(
                                db,
                                table,
                                p0,
                              ).noteTagTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.noteId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attachmentTableRefs)
                        await $_getPrefetchedData<
                          NoteTableData,
                          $NoteTableTable,
                          AttachmentTableData
                        >(
                          currentTable: table,
                          referencedTable: $$NoteTableTableReferences
                              ._attachmentTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NoteTableTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.noteId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$NoteTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteTableTable,
      NoteTableData,
      $$NoteTableTableFilterComposer,
      $$NoteTableTableOrderingComposer,
      $$NoteTableTableAnnotationComposer,
      $$NoteTableTableCreateCompanionBuilder,
      $$NoteTableTableUpdateCompanionBuilder,
      (NoteTableData, $$NoteTableTableReferences),
      NoteTableData,
      PrefetchHooks Function({
        bool folderId,
        bool noteTagTableRefs,
        bool attachmentTableRefs,
      })
    >;
typedef $$TagTableTableCreateCompanionBuilder =
    TagTableCompanion Function({Value<int> id, required String name});
typedef $$TagTableTableUpdateCompanionBuilder =
    TagTableCompanion Function({Value<int> id, Value<String> name});

final class $$TagTableTableReferences
    extends BaseReferences<_$AppDatabase, $TagTableTable, TagTableData> {
  $$TagTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NoteTagTableTable, List<NoteTagTableData>>
  _noteTagTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.noteTagTable,
    aliasName: $_aliasNameGenerator(db.tagTable.id, db.noteTagTable.tagId),
  );

  $$NoteTagTableTableProcessedTableManager get noteTagTableRefs {
    final manager = $$NoteTagTableTableTableManager(
      $_db,
      $_db.noteTagTable,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteTagTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagTableTableFilterComposer
    extends Composer<_$AppDatabase, $TagTableTable> {
  $$TagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> noteTagTableRefs(
    Expression<bool> Function($$NoteTagTableTableFilterComposer f) f,
  ) {
    final $$NoteTagTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTagTable,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagTableTableFilterComposer(
            $db: $db,
            $table: $db.noteTagTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TagTableTable> {
  $$TagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagTableTable> {
  $$TagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> noteTagTableRefs<T extends Object>(
    Expression<T> Function($$NoteTagTableTableAnnotationComposer a) f,
  ) {
    final $$NoteTagTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTagTable,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTagTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagTableTable,
          TagTableData,
          $$TagTableTableFilterComposer,
          $$TagTableTableOrderingComposer,
          $$TagTableTableAnnotationComposer,
          $$TagTableTableCreateCompanionBuilder,
          $$TagTableTableUpdateCompanionBuilder,
          (TagTableData, $$TagTableTableReferences),
          TagTableData,
          PrefetchHooks Function({bool noteTagTableRefs})
        > {
  $$TagTableTableTableManager(_$AppDatabase db, $TagTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => TagTableCompanion(id: id, name: name),
          createCompanionCallback:
              ({Value<int> id = const Value.absent(), required String name}) =>
                  TagTableCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TagTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteTagTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (noteTagTableRefs) db.noteTagTable],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (noteTagTableRefs)
                    await $_getPrefetchedData<
                      TagTableData,
                      $TagTableTable,
                      NoteTagTableData
                    >(
                      currentTable: table,
                      referencedTable: $$TagTableTableReferences
                          ._noteTagTableRefsTable(db),
                      managerFromTypedResult: (p0) => $$TagTableTableReferences(
                        db,
                        table,
                        p0,
                      ).noteTagTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagTableTable,
      TagTableData,
      $$TagTableTableFilterComposer,
      $$TagTableTableOrderingComposer,
      $$TagTableTableAnnotationComposer,
      $$TagTableTableCreateCompanionBuilder,
      $$TagTableTableUpdateCompanionBuilder,
      (TagTableData, $$TagTableTableReferences),
      TagTableData,
      PrefetchHooks Function({bool noteTagTableRefs})
    >;
typedef $$NoteTagTableTableCreateCompanionBuilder =
    NoteTagTableCompanion Function({
      required int noteId,
      required int tagId,
      Value<int> rowid,
    });
typedef $$NoteTagTableTableUpdateCompanionBuilder =
    NoteTagTableCompanion Function({
      Value<int> noteId,
      Value<int> tagId,
      Value<int> rowid,
    });

final class $$NoteTagTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $NoteTagTableTable, NoteTagTableData> {
  $$NoteTagTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NoteTableTable _noteIdTable(_$AppDatabase db) =>
      db.noteTable.createAlias(
        $_aliasNameGenerator(db.noteTagTable.noteId, db.noteTable.id),
      );

  $$NoteTableTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<int>('note_id')!;

    final manager = $$NoteTableTableTableManager(
      $_db,
      $_db.noteTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagTableTable _tagIdTable(_$AppDatabase db) => db.tagTable
      .createAlias($_aliasNameGenerator(db.noteTagTable.tagId, db.tagTable.id));

  $$TagTableTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$TagTableTableTableManager(
      $_db,
      $_db.tagTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NoteTagTableTableFilterComposer
    extends Composer<_$AppDatabase, $NoteTagTableTable> {
  $$NoteTagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NoteTableTableFilterComposer get noteId {
    final $$NoteTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableFilterComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagTableTableFilterComposer get tagId {
    final $$TagTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tagTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagTableTableFilterComposer(
            $db: $db,
            $table: $db.tagTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteTagTableTable> {
  $$NoteTagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NoteTableTableOrderingComposer get noteId {
    final $$NoteTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableOrderingComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagTableTableOrderingComposer get tagId {
    final $$TagTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tagTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagTableTableOrderingComposer(
            $db: $db,
            $table: $db.tagTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteTagTableTable> {
  $$NoteTagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$NoteTableTableAnnotationComposer get noteId {
    final $$NoteTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagTableTableAnnotationComposer get tagId {
    final $$TagTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tagTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagTableTableAnnotationComposer(
            $db: $db,
            $table: $db.tagTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteTagTableTable,
          NoteTagTableData,
          $$NoteTagTableTableFilterComposer,
          $$NoteTagTableTableOrderingComposer,
          $$NoteTagTableTableAnnotationComposer,
          $$NoteTagTableTableCreateCompanionBuilder,
          $$NoteTagTableTableUpdateCompanionBuilder,
          (NoteTagTableData, $$NoteTagTableTableReferences),
          NoteTagTableData,
          PrefetchHooks Function({bool noteId, bool tagId})
        > {
  $$NoteTagTableTableTableManager(_$AppDatabase db, $NoteTagTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTagTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> noteId = const Value.absent(),
                Value<int> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NoteTagTableCompanion(
                noteId: noteId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int noteId,
                required int tagId,
                Value<int> rowid = const Value.absent(),
              }) => NoteTagTableCompanion.insert(
                noteId: noteId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NoteTagTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (noteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.noteId,
                                referencedTable: $$NoteTagTableTableReferences
                                    ._noteIdTable(db),
                                referencedColumn: $$NoteTagTableTableReferences
                                    ._noteIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$NoteTagTableTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$NoteTagTableTableReferences
                                    ._tagIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NoteTagTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteTagTableTable,
      NoteTagTableData,
      $$NoteTagTableTableFilterComposer,
      $$NoteTagTableTableOrderingComposer,
      $$NoteTagTableTableAnnotationComposer,
      $$NoteTagTableTableCreateCompanionBuilder,
      $$NoteTagTableTableUpdateCompanionBuilder,
      (NoteTagTableData, $$NoteTagTableTableReferences),
      NoteTagTableData,
      PrefetchHooks Function({bool noteId, bool tagId})
    >;
typedef $$AttachmentTableTableCreateCompanionBuilder =
    AttachmentTableCompanion Function({
      Value<int> id,
      required int noteId,
      required String fileName,
      required String filePath,
      required String createdAt,
    });
typedef $$AttachmentTableTableUpdateCompanionBuilder =
    AttachmentTableCompanion Function({
      Value<int> id,
      Value<int> noteId,
      Value<String> fileName,
      Value<String> filePath,
      Value<String> createdAt,
    });

final class $$AttachmentTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AttachmentTableTable,
          AttachmentTableData
        > {
  $$AttachmentTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $NoteTableTable _noteIdTable(_$AppDatabase db) =>
      db.noteTable.createAlias(
        $_aliasNameGenerator(db.attachmentTable.noteId, db.noteTable.id),
      );

  $$NoteTableTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<int>('note_id')!;

    final manager = $$NoteTableTableTableManager(
      $_db,
      $_db.noteTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttachmentTableTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentTableTable> {
  $$AttachmentTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NoteTableTableFilterComposer get noteId {
    final $$NoteTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableFilterComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentTableTable> {
  $$AttachmentTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NoteTableTableOrderingComposer get noteId {
    final $$NoteTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableOrderingComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentTableTable> {
  $$AttachmentTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$NoteTableTableAnnotationComposer get noteId {
    final $$NoteTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentTableTable,
          AttachmentTableData,
          $$AttachmentTableTableFilterComposer,
          $$AttachmentTableTableOrderingComposer,
          $$AttachmentTableTableAnnotationComposer,
          $$AttachmentTableTableCreateCompanionBuilder,
          $$AttachmentTableTableUpdateCompanionBuilder,
          (AttachmentTableData, $$AttachmentTableTableReferences),
          AttachmentTableData,
          PrefetchHooks Function({bool noteId})
        > {
  $$AttachmentTableTableTableManager(
    _$AppDatabase db,
    $AttachmentTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> noteId = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
              }) => AttachmentTableCompanion(
                id: id,
                noteId: noteId,
                fileName: fileName,
                filePath: filePath,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int noteId,
                required String fileName,
                required String filePath,
                required String createdAt,
              }) => AttachmentTableCompanion.insert(
                id: id,
                noteId: noteId,
                fileName: fileName,
                filePath: filePath,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AttachmentTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (noteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.noteId,
                                referencedTable:
                                    $$AttachmentTableTableReferences
                                        ._noteIdTable(db),
                                referencedColumn:
                                    $$AttachmentTableTableReferences
                                        ._noteIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttachmentTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentTableTable,
      AttachmentTableData,
      $$AttachmentTableTableFilterComposer,
      $$AttachmentTableTableOrderingComposer,
      $$AttachmentTableTableAnnotationComposer,
      $$AttachmentTableTableCreateCompanionBuilder,
      $$AttachmentTableTableUpdateCompanionBuilder,
      (AttachmentTableData, $$AttachmentTableTableReferences),
      AttachmentTableData,
      PrefetchHooks Function({bool noteId})
    >;
typedef $$SettingTableTableCreateCompanionBuilder =
    SettingTableCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingTableTableUpdateCompanionBuilder =
    SettingTableCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingTableTableFilterComposer
    extends Composer<_$AppDatabase, $SettingTableTable> {
  $$SettingTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingTableTable> {
  $$SettingTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingTableTable> {
  $$SettingTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingTableTable,
          SettingTableData,
          $$SettingTableTableFilterComposer,
          $$SettingTableTableOrderingComposer,
          $$SettingTableTableAnnotationComposer,
          $$SettingTableTableCreateCompanionBuilder,
          $$SettingTableTableUpdateCompanionBuilder,
          (
            SettingTableData,
            BaseReferences<_$AppDatabase, $SettingTableTable, SettingTableData>,
          ),
          SettingTableData,
          PrefetchHooks Function()
        > {
  $$SettingTableTableTableManager(_$AppDatabase db, $SettingTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingTableCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingTableCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingTableTable,
      SettingTableData,
      $$SettingTableTableFilterComposer,
      $$SettingTableTableOrderingComposer,
      $$SettingTableTableAnnotationComposer,
      $$SettingTableTableCreateCompanionBuilder,
      $$SettingTableTableUpdateCompanionBuilder,
      (
        SettingTableData,
        BaseReferences<_$AppDatabase, $SettingTableTable, SettingTableData>,
      ),
      SettingTableData,
      PrefetchHooks Function()
    >;
typedef $$EventTableTableCreateCompanionBuilder =
    EventTableCompanion Function({
      Value<int> id,
      Value<String> title,
      required String eventDate,
      required String createdAt,
      Value<bool> alarmEnabled,
      Value<String> alarmTime,
      Value<int> alarmDaysBefore,
      Value<bool> isCompleted,
      Value<int> priority,
      Value<String> googleEventId,
      Value<String?> locationName,
      Value<double?> locationLat,
      Value<double?> locationLng,
      Value<String?> startDate,
      Value<String?> endDate,
      Value<String?> startTime,
      Value<String?> endTime,
      Value<bool> isAllDay,
      Value<String?> content,
    });
typedef $$EventTableTableUpdateCompanionBuilder =
    EventTableCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> eventDate,
      Value<String> createdAt,
      Value<bool> alarmEnabled,
      Value<String> alarmTime,
      Value<int> alarmDaysBefore,
      Value<bool> isCompleted,
      Value<int> priority,
      Value<String> googleEventId,
      Value<String?> locationName,
      Value<double?> locationLat,
      Value<double?> locationLng,
      Value<String?> startDate,
      Value<String?> endDate,
      Value<String?> startTime,
      Value<String?> endTime,
      Value<bool> isAllDay,
      Value<String?> content,
    });

final class $$EventTableTableReferences
    extends BaseReferences<_$AppDatabase, $EventTableTable, EventTableData> {
  $$EventTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $EventTagRelationTableTable,
    List<EventTagRelationTableData>
  >
  _eventTagRelationTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.eventTagRelationTable,
        aliasName: $_aliasNameGenerator(
          db.eventTable.id,
          db.eventTagRelationTable.eventId,
        ),
      );

  $$EventTagRelationTableTableProcessedTableManager
  get eventTagRelationTableRefs {
    final manager = $$EventTagRelationTableTableTableManager(
      $_db,
      $_db.eventTagRelationTable,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _eventTagRelationTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EventTableTableFilterComposer
    extends Composer<_$AppDatabase, $EventTableTable> {
  $$EventTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get alarmEnabled => $composableBuilder(
    column: $table.alarmEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alarmTime => $composableBuilder(
    column: $table.alarmTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get alarmDaysBefore => $composableBuilder(
    column: $table.alarmDaysBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get googleEventId => $composableBuilder(
    column: $table.googleEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get locationLat => $composableBuilder(
    column: $table.locationLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get locationLng => $composableBuilder(
    column: $table.locationLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAllDay => $composableBuilder(
    column: $table.isAllDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> eventTagRelationTableRefs(
    Expression<bool> Function($$EventTagRelationTableTableFilterComposer f) f,
  ) {
    final $$EventTagRelationTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.eventTagRelationTable,
          getReferencedColumn: (t) => t.eventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EventTagRelationTableTableFilterComposer(
                $db: $db,
                $table: $db.eventTagRelationTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$EventTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EventTableTable> {
  $$EventTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventDate => $composableBuilder(
    column: $table.eventDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get alarmEnabled => $composableBuilder(
    column: $table.alarmEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alarmTime => $composableBuilder(
    column: $table.alarmTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get alarmDaysBefore => $composableBuilder(
    column: $table.alarmDaysBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get googleEventId => $composableBuilder(
    column: $table.googleEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get locationLat => $composableBuilder(
    column: $table.locationLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get locationLng => $composableBuilder(
    column: $table.locationLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAllDay => $composableBuilder(
    column: $table.isAllDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventTableTable> {
  $$EventTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get eventDate =>
      $composableBuilder(column: $table.eventDate, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get alarmEnabled => $composableBuilder(
    column: $table.alarmEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alarmTime =>
      $composableBuilder(column: $table.alarmTime, builder: (column) => column);

  GeneratedColumn<int> get alarmDaysBefore => $composableBuilder(
    column: $table.alarmDaysBefore,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get googleEventId => $composableBuilder(
    column: $table.googleEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get locationLat => $composableBuilder(
    column: $table.locationLat,
    builder: (column) => column,
  );

  GeneratedColumn<double> get locationLng => $composableBuilder(
    column: $table.locationLng,
    builder: (column) => column,
  );

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<String> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<bool> get isAllDay =>
      $composableBuilder(column: $table.isAllDay, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  Expression<T> eventTagRelationTableRefs<T extends Object>(
    Expression<T> Function($$EventTagRelationTableTableAnnotationComposer a) f,
  ) {
    final $$EventTagRelationTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.eventTagRelationTable,
          getReferencedColumn: (t) => t.eventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EventTagRelationTableTableAnnotationComposer(
                $db: $db,
                $table: $db.eventTagRelationTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$EventTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventTableTable,
          EventTableData,
          $$EventTableTableFilterComposer,
          $$EventTableTableOrderingComposer,
          $$EventTableTableAnnotationComposer,
          $$EventTableTableCreateCompanionBuilder,
          $$EventTableTableUpdateCompanionBuilder,
          (EventTableData, $$EventTableTableReferences),
          EventTableData,
          PrefetchHooks Function({bool eventTagRelationTableRefs})
        > {
  $$EventTableTableTableManager(_$AppDatabase db, $EventTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> eventDate = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<bool> alarmEnabled = const Value.absent(),
                Value<String> alarmTime = const Value.absent(),
                Value<int> alarmDaysBefore = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> googleEventId = const Value.absent(),
                Value<String?> locationName = const Value.absent(),
                Value<double?> locationLat = const Value.absent(),
                Value<double?> locationLng = const Value.absent(),
                Value<String?> startDate = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<String?> startTime = const Value.absent(),
                Value<String?> endTime = const Value.absent(),
                Value<bool> isAllDay = const Value.absent(),
                Value<String?> content = const Value.absent(),
              }) => EventTableCompanion(
                id: id,
                title: title,
                eventDate: eventDate,
                createdAt: createdAt,
                alarmEnabled: alarmEnabled,
                alarmTime: alarmTime,
                alarmDaysBefore: alarmDaysBefore,
                isCompleted: isCompleted,
                priority: priority,
                googleEventId: googleEventId,
                locationName: locationName,
                locationLat: locationLat,
                locationLng: locationLng,
                startDate: startDate,
                endDate: endDate,
                startTime: startTime,
                endTime: endTime,
                isAllDay: isAllDay,
                content: content,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                required String eventDate,
                required String createdAt,
                Value<bool> alarmEnabled = const Value.absent(),
                Value<String> alarmTime = const Value.absent(),
                Value<int> alarmDaysBefore = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> googleEventId = const Value.absent(),
                Value<String?> locationName = const Value.absent(),
                Value<double?> locationLat = const Value.absent(),
                Value<double?> locationLng = const Value.absent(),
                Value<String?> startDate = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<String?> startTime = const Value.absent(),
                Value<String?> endTime = const Value.absent(),
                Value<bool> isAllDay = const Value.absent(),
                Value<String?> content = const Value.absent(),
              }) => EventTableCompanion.insert(
                id: id,
                title: title,
                eventDate: eventDate,
                createdAt: createdAt,
                alarmEnabled: alarmEnabled,
                alarmTime: alarmTime,
                alarmDaysBefore: alarmDaysBefore,
                isCompleted: isCompleted,
                priority: priority,
                googleEventId: googleEventId,
                locationName: locationName,
                locationLat: locationLat,
                locationLng: locationLng,
                startDate: startDate,
                endDate: endDate,
                startTime: startTime,
                endTime: endTime,
                isAllDay: isAllDay,
                content: content,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EventTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventTagRelationTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (eventTagRelationTableRefs) db.eventTagRelationTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (eventTagRelationTableRefs)
                    await $_getPrefetchedData<
                      EventTableData,
                      $EventTableTable,
                      EventTagRelationTableData
                    >(
                      currentTable: table,
                      referencedTable: $$EventTableTableReferences
                          ._eventTagRelationTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$EventTableTableReferences(
                            db,
                            table,
                            p0,
                          ).eventTagRelationTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.eventId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$EventTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventTableTable,
      EventTableData,
      $$EventTableTableFilterComposer,
      $$EventTableTableOrderingComposer,
      $$EventTableTableAnnotationComposer,
      $$EventTableTableCreateCompanionBuilder,
      $$EventTableTableUpdateCompanionBuilder,
      (EventTableData, $$EventTableTableReferences),
      EventTableData,
      PrefetchHooks Function({bool eventTagRelationTableRefs})
    >;
typedef $$EventTagTableTableCreateCompanionBuilder =
    EventTagTableCompanion Function({
      Value<int> id,
      required String name,
      Value<String> color,
    });
typedef $$EventTagTableTableUpdateCompanionBuilder =
    EventTagTableCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> color,
    });

final class $$EventTagTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $EventTagTableTable, EventTagTableData> {
  $$EventTagTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $EventTagRelationTableTable,
    List<EventTagRelationTableData>
  >
  _eventTagRelationTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.eventTagRelationTable,
        aliasName: $_aliasNameGenerator(
          db.eventTagTable.id,
          db.eventTagRelationTable.tagId,
        ),
      );

  $$EventTagRelationTableTableProcessedTableManager
  get eventTagRelationTableRefs {
    final manager = $$EventTagRelationTableTableTableManager(
      $_db,
      $_db.eventTagRelationTable,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _eventTagRelationTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EventTagTableTableFilterComposer
    extends Composer<_$AppDatabase, $EventTagTableTable> {
  $$EventTagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> eventTagRelationTableRefs(
    Expression<bool> Function($$EventTagRelationTableTableFilterComposer f) f,
  ) {
    final $$EventTagRelationTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.eventTagRelationTable,
          getReferencedColumn: (t) => t.tagId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EventTagRelationTableTableFilterComposer(
                $db: $db,
                $table: $db.eventTagRelationTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$EventTagTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EventTagTableTable> {
  $$EventTagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventTagTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventTagTableTable> {
  $$EventTagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  Expression<T> eventTagRelationTableRefs<T extends Object>(
    Expression<T> Function($$EventTagRelationTableTableAnnotationComposer a) f,
  ) {
    final $$EventTagRelationTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.eventTagRelationTable,
          getReferencedColumn: (t) => t.tagId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EventTagRelationTableTableAnnotationComposer(
                $db: $db,
                $table: $db.eventTagRelationTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$EventTagTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventTagTableTable,
          EventTagTableData,
          $$EventTagTableTableFilterComposer,
          $$EventTagTableTableOrderingComposer,
          $$EventTagTableTableAnnotationComposer,
          $$EventTagTableTableCreateCompanionBuilder,
          $$EventTagTableTableUpdateCompanionBuilder,
          (EventTagTableData, $$EventTagTableTableReferences),
          EventTagTableData,
          PrefetchHooks Function({bool eventTagRelationTableRefs})
        > {
  $$EventTagTableTableTableManager(_$AppDatabase db, $EventTagTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventTagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventTagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventTagTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> color = const Value.absent(),
              }) => EventTagTableCompanion(id: id, name: name, color: color),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> color = const Value.absent(),
              }) => EventTagTableCompanion.insert(
                id: id,
                name: name,
                color: color,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EventTagTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventTagRelationTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (eventTagRelationTableRefs) db.eventTagRelationTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (eventTagRelationTableRefs)
                    await $_getPrefetchedData<
                      EventTagTableData,
                      $EventTagTableTable,
                      EventTagRelationTableData
                    >(
                      currentTable: table,
                      referencedTable: $$EventTagTableTableReferences
                          ._eventTagRelationTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$EventTagTableTableReferences(
                            db,
                            table,
                            p0,
                          ).eventTagRelationTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$EventTagTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventTagTableTable,
      EventTagTableData,
      $$EventTagTableTableFilterComposer,
      $$EventTagTableTableOrderingComposer,
      $$EventTagTableTableAnnotationComposer,
      $$EventTagTableTableCreateCompanionBuilder,
      $$EventTagTableTableUpdateCompanionBuilder,
      (EventTagTableData, $$EventTagTableTableReferences),
      EventTagTableData,
      PrefetchHooks Function({bool eventTagRelationTableRefs})
    >;
typedef $$EventTagRelationTableTableCreateCompanionBuilder =
    EventTagRelationTableCompanion Function({
      required int eventId,
      required int tagId,
      Value<int> rowid,
    });
typedef $$EventTagRelationTableTableUpdateCompanionBuilder =
    EventTagRelationTableCompanion Function({
      Value<int> eventId,
      Value<int> tagId,
      Value<int> rowid,
    });

final class $$EventTagRelationTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $EventTagRelationTableTable,
          EventTagRelationTableData
        > {
  $$EventTagRelationTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EventTableTable _eventIdTable(_$AppDatabase db) =>
      db.eventTable.createAlias(
        $_aliasNameGenerator(
          db.eventTagRelationTable.eventId,
          db.eventTable.id,
        ),
      );

  $$EventTableTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<int>('event_id')!;

    final manager = $$EventTableTableTableManager(
      $_db,
      $_db.eventTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EventTagTableTable _tagIdTable(_$AppDatabase db) =>
      db.eventTagTable.createAlias(
        $_aliasNameGenerator(
          db.eventTagRelationTable.tagId,
          db.eventTagTable.id,
        ),
      );

  $$EventTagTableTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$EventTagTableTableTableManager(
      $_db,
      $_db.eventTagTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EventTagRelationTableTableFilterComposer
    extends Composer<_$AppDatabase, $EventTagRelationTableTable> {
  $$EventTagRelationTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$EventTableTableFilterComposer get eventId {
    final $$EventTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.eventTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventTableTableFilterComposer(
            $db: $db,
            $table: $db.eventTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EventTagTableTableFilterComposer get tagId {
    final $$EventTagTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.eventTagTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventTagTableTableFilterComposer(
            $db: $db,
            $table: $db.eventTagTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EventTagRelationTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EventTagRelationTableTable> {
  $$EventTagRelationTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$EventTableTableOrderingComposer get eventId {
    final $$EventTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.eventTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventTableTableOrderingComposer(
            $db: $db,
            $table: $db.eventTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EventTagTableTableOrderingComposer get tagId {
    final $$EventTagTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.eventTagTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventTagTableTableOrderingComposer(
            $db: $db,
            $table: $db.eventTagTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EventTagRelationTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventTagRelationTableTable> {
  $$EventTagRelationTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$EventTableTableAnnotationComposer get eventId {
    final $$EventTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.eventTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventTableTableAnnotationComposer(
            $db: $db,
            $table: $db.eventTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EventTagTableTableAnnotationComposer get tagId {
    final $$EventTagTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.eventTagTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventTagTableTableAnnotationComposer(
            $db: $db,
            $table: $db.eventTagTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EventTagRelationTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventTagRelationTableTable,
          EventTagRelationTableData,
          $$EventTagRelationTableTableFilterComposer,
          $$EventTagRelationTableTableOrderingComposer,
          $$EventTagRelationTableTableAnnotationComposer,
          $$EventTagRelationTableTableCreateCompanionBuilder,
          $$EventTagRelationTableTableUpdateCompanionBuilder,
          (EventTagRelationTableData, $$EventTagRelationTableTableReferences),
          EventTagRelationTableData,
          PrefetchHooks Function({bool eventId, bool tagId})
        > {
  $$EventTagRelationTableTableTableManager(
    _$AppDatabase db,
    $EventTagRelationTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventTagRelationTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$EventTagRelationTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EventTagRelationTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> eventId = const Value.absent(),
                Value<int> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventTagRelationTableCompanion(
                eventId: eventId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int eventId,
                required int tagId,
                Value<int> rowid = const Value.absent(),
              }) => EventTagRelationTableCompanion.insert(
                eventId: eventId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EventTagRelationTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (eventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.eventId,
                                referencedTable:
                                    $$EventTagRelationTableTableReferences
                                        ._eventIdTable(db),
                                referencedColumn:
                                    $$EventTagRelationTableTableReferences
                                        ._eventIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable:
                                    $$EventTagRelationTableTableReferences
                                        ._tagIdTable(db),
                                referencedColumn:
                                    $$EventTagRelationTableTableReferences
                                        ._tagIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EventTagRelationTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventTagRelationTableTable,
      EventTagRelationTableData,
      $$EventTagRelationTableTableFilterComposer,
      $$EventTagRelationTableTableOrderingComposer,
      $$EventTagRelationTableTableAnnotationComposer,
      $$EventTagRelationTableTableCreateCompanionBuilder,
      $$EventTagRelationTableTableUpdateCompanionBuilder,
      (EventTagRelationTableData, $$EventTagRelationTableTableReferences),
      EventTagRelationTableData,
      PrefetchHooks Function({bool eventId, bool tagId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FolderTableTableTableManager get folderTable =>
      $$FolderTableTableTableManager(_db, _db.folderTable);
  $$NoteTableTableTableManager get noteTable =>
      $$NoteTableTableTableManager(_db, _db.noteTable);
  $$TagTableTableTableManager get tagTable =>
      $$TagTableTableTableManager(_db, _db.tagTable);
  $$NoteTagTableTableTableManager get noteTagTable =>
      $$NoteTagTableTableTableManager(_db, _db.noteTagTable);
  $$AttachmentTableTableTableManager get attachmentTable =>
      $$AttachmentTableTableTableManager(_db, _db.attachmentTable);
  $$SettingTableTableTableManager get settingTable =>
      $$SettingTableTableTableManager(_db, _db.settingTable);
  $$EventTableTableTableManager get eventTable =>
      $$EventTableTableTableManager(_db, _db.eventTable);
  $$EventTagTableTableTableManager get eventTagTable =>
      $$EventTagTableTableTableManager(_db, _db.eventTagTable);
  $$EventTagRelationTableTableTableManager get eventTagRelationTable =>
      $$EventTagRelationTableTableTableManager(_db, _db.eventTagRelationTable);
}
