// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MessageRole, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MessageRole>($MessagesTable.$converterrole);
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gitCommitMeta = const VerificationMeta(
    'gitCommit',
  );
  @override
  late final GeneratedColumn<String> gitCommit = GeneratedColumn<String>(
    'git_commit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    role,
    authorId,
    content,
    gitCommit,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('git_commit')) {
      context.handle(
        _gitCommitMeta,
        gitCommit.isAcceptableOrUnknown(data['git_commit']!, _gitCommitMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      role: $MessagesTable.$converterrole.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        )!,
      ),
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      gitCommit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}git_commit'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MessageRole, String, String> $converterrole =
      const EnumNameConverter<MessageRole>(MessageRole.values);
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  final String id;
  final MessageRole role;
  final String? authorId;
  final String content;
  final String? gitCommit;
  final DateTime? createdAt;
  const MessageRow({
    required this.id,
    required this.role,
    this.authorId,
    required this.content,
    this.gitCommit,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['role'] = Variable<String>($MessagesTable.$converterrole.toSql(role));
    }
    if (!nullToAbsent || authorId != null) {
      map['author_id'] = Variable<String>(authorId);
    }
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || gitCommit != null) {
      map['git_commit'] = Variable<String>(gitCommit);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      role: Value(role),
      authorId: authorId == null && nullToAbsent
          ? const Value.absent()
          : Value(authorId),
      content: Value(content),
      gitCommit: gitCommit == null && nullToAbsent
          ? const Value.absent()
          : Value(gitCommit),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory MessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      id: serializer.fromJson<String>(json['id']),
      role: $MessagesTable.$converterrole.fromJson(
        serializer.fromJson<String>(json['role']),
      ),
      authorId: serializer.fromJson<String?>(json['authorId']),
      content: serializer.fromJson<String>(json['content']),
      gitCommit: serializer.fromJson<String?>(json['gitCommit']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'role': serializer.toJson<String>(
        $MessagesTable.$converterrole.toJson(role),
      ),
      'authorId': serializer.toJson<String?>(authorId),
      'content': serializer.toJson<String>(content),
      'gitCommit': serializer.toJson<String?>(gitCommit),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
    };
  }

  MessageRow copyWith({
    String? id,
    MessageRole? role,
    Value<String?> authorId = const Value.absent(),
    String? content,
    Value<String?> gitCommit = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
  }) => MessageRow(
    id: id ?? this.id,
    role: role ?? this.role,
    authorId: authorId.present ? authorId.value : this.authorId,
    content: content ?? this.content,
    gitCommit: gitCommit.present ? gitCommit.value : this.gitCommit,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  MessageRow copyWithCompanion(MessagesCompanion data) {
    return MessageRow(
      id: data.id.present ? data.id.value : this.id,
      role: data.role.present ? data.role.value : this.role,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      content: data.content.present ? data.content.value : this.content,
      gitCommit: data.gitCommit.present ? data.gitCommit.value : this.gitCommit,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('authorId: $authorId, ')
          ..write('content: $content, ')
          ..write('gitCommit: $gitCommit, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, role, authorId, content, gitCommit, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.id == this.id &&
          other.role == this.role &&
          other.authorId == this.authorId &&
          other.content == this.content &&
          other.gitCommit == this.gitCommit &&
          other.createdAt == this.createdAt);
}

class MessagesCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> id;
  final Value<MessageRole> role;
  final Value<String?> authorId;
  final Value<String> content;
  final Value<String?> gitCommit;
  final Value<DateTime?> createdAt;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.role = const Value.absent(),
    this.authorId = const Value.absent(),
    this.content = const Value.absent(),
    this.gitCommit = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required MessageRole role,
    this.authorId = const Value.absent(),
    required String content,
    this.gitCommit = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       role = Value(role),
       content = Value(content);
  static Insertable<MessageRow> custom({
    Expression<String>? id,
    Expression<String>? role,
    Expression<String>? authorId,
    Expression<String>? content,
    Expression<String>? gitCommit,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (role != null) 'role': role,
      if (authorId != null) 'author_id': authorId,
      if (content != null) 'content': content,
      if (gitCommit != null) 'git_commit': gitCommit,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<MessageRole>? role,
    Value<String?>? authorId,
    Value<String>? content,
    Value<String?>? gitCommit,
    Value<DateTime?>? createdAt,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      role: role ?? this.role,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      gitCommit: gitCommit ?? this.gitCommit,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $MessagesTable.$converterrole.toSql(role.value),
      );
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (gitCommit.present) {
      map['git_commit'] = Variable<String>(gitCommit.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('authorId: $authorId, ')
          ..write('content: $content, ')
          ..write('gitCommit: $gitCommit, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReplyEdgesTable extends ReplyEdges
    with TableInfo<$ReplyEdgesTable, ReplyEdge> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReplyEdgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES messages (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<String> childId = GeneratedColumn<String>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES messages (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [parentId, childId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reply_edges';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReplyEdge> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_parentIdMeta);
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {childId};
  @override
  ReplyEdge map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReplyEdge(
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_id'],
      )!,
    );
  }

  @override
  $ReplyEdgesTable createAlias(String alias) {
    return $ReplyEdgesTable(attachedDatabase, alias);
  }
}

class ReplyEdge extends DataClass implements Insertable<ReplyEdge> {
  final String parentId;
  final String childId;
  const ReplyEdge({required this.parentId, required this.childId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['parent_id'] = Variable<String>(parentId);
    map['child_id'] = Variable<String>(childId);
    return map;
  }

  ReplyEdgesCompanion toCompanion(bool nullToAbsent) {
    return ReplyEdgesCompanion(
      parentId: Value(parentId),
      childId: Value(childId),
    );
  }

  factory ReplyEdge.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReplyEdge(
      parentId: serializer.fromJson<String>(json['parentId']),
      childId: serializer.fromJson<String>(json['childId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'parentId': serializer.toJson<String>(parentId),
      'childId': serializer.toJson<String>(childId),
    };
  }

  ReplyEdge copyWith({String? parentId, String? childId}) => ReplyEdge(
    parentId: parentId ?? this.parentId,
    childId: childId ?? this.childId,
  );
  ReplyEdge copyWithCompanion(ReplyEdgesCompanion data) {
    return ReplyEdge(
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      childId: data.childId.present ? data.childId.value : this.childId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReplyEdge(')
          ..write('parentId: $parentId, ')
          ..write('childId: $childId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(parentId, childId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReplyEdge &&
          other.parentId == this.parentId &&
          other.childId == this.childId);
}

class ReplyEdgesCompanion extends UpdateCompanion<ReplyEdge> {
  final Value<String> parentId;
  final Value<String> childId;
  final Value<int> rowid;
  const ReplyEdgesCompanion({
    this.parentId = const Value.absent(),
    this.childId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReplyEdgesCompanion.insert({
    required String parentId,
    required String childId,
    this.rowid = const Value.absent(),
  }) : parentId = Value(parentId),
       childId = Value(childId);
  static Insertable<ReplyEdge> custom({
    Expression<String>? parentId,
    Expression<String>? childId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (parentId != null) 'parent_id': parentId,
      if (childId != null) 'child_id': childId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReplyEdgesCompanion copyWith({
    Value<String>? parentId,
    Value<String>? childId,
    Value<int>? rowid,
  }) {
    return ReplyEdgesCompanion(
      parentId: parentId ?? this.parentId,
      childId: childId ?? this.childId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<String>(childId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReplyEdgesCompanion(')
          ..write('parentId: $parentId, ')
          ..write('childId: $childId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StitchEdgesTable extends StitchEdges
    with TableInfo<$StitchEdgesTable, StitchEdge> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StitchEdgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fromIdMeta = const VerificationMeta('fromId');
  @override
  late final GeneratedColumn<String> fromId = GeneratedColumn<String>(
    'from_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES messages (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _toIdMeta = const VerificationMeta('toId');
  @override
  late final GeneratedColumn<String> toId = GeneratedColumn<String>(
    'to_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES messages (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _createdByAuthorIdMeta = const VerificationMeta(
    'createdByAuthorId',
  );
  @override
  late final GeneratedColumn<String> createdByAuthorId =
      GeneratedColumn<String>(
        'created_by_author_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    fromId,
    toId,
    createdByAuthorId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stitch_edges';
  @override
  VerificationContext validateIntegrity(
    Insertable<StitchEdge> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('from_id')) {
      context.handle(
        _fromIdMeta,
        fromId.isAcceptableOrUnknown(data['from_id']!, _fromIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fromIdMeta);
    }
    if (data.containsKey('to_id')) {
      context.handle(
        _toIdMeta,
        toId.isAcceptableOrUnknown(data['to_id']!, _toIdMeta),
      );
    } else if (isInserting) {
      context.missing(_toIdMeta);
    }
    if (data.containsKey('created_by_author_id')) {
      context.handle(
        _createdByAuthorIdMeta,
        createdByAuthorId.isAcceptableOrUnknown(
          data['created_by_author_id']!,
          _createdByAuthorIdMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fromId, toId};
  @override
  StitchEdge map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StitchEdge(
      fromId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_id'],
      )!,
      toId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_id'],
      )!,
      createdByAuthorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_author_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StitchEdgesTable createAlias(String alias) {
    return $StitchEdgesTable(attachedDatabase, alias);
  }
}

class StitchEdge extends DataClass implements Insertable<StitchEdge> {
  final String fromId;
  final String toId;
  final String? createdByAuthorId;
  final DateTime createdAt;
  const StitchEdge({
    required this.fromId,
    required this.toId,
    this.createdByAuthorId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['from_id'] = Variable<String>(fromId);
    map['to_id'] = Variable<String>(toId);
    if (!nullToAbsent || createdByAuthorId != null) {
      map['created_by_author_id'] = Variable<String>(createdByAuthorId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StitchEdgesCompanion toCompanion(bool nullToAbsent) {
    return StitchEdgesCompanion(
      fromId: Value(fromId),
      toId: Value(toId),
      createdByAuthorId: createdByAuthorId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdByAuthorId),
      createdAt: Value(createdAt),
    );
  }

  factory StitchEdge.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StitchEdge(
      fromId: serializer.fromJson<String>(json['fromId']),
      toId: serializer.fromJson<String>(json['toId']),
      createdByAuthorId: serializer.fromJson<String?>(
        json['createdByAuthorId'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fromId': serializer.toJson<String>(fromId),
      'toId': serializer.toJson<String>(toId),
      'createdByAuthorId': serializer.toJson<String?>(createdByAuthorId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StitchEdge copyWith({
    String? fromId,
    String? toId,
    Value<String?> createdByAuthorId = const Value.absent(),
    DateTime? createdAt,
  }) => StitchEdge(
    fromId: fromId ?? this.fromId,
    toId: toId ?? this.toId,
    createdByAuthorId: createdByAuthorId.present
        ? createdByAuthorId.value
        : this.createdByAuthorId,
    createdAt: createdAt ?? this.createdAt,
  );
  StitchEdge copyWithCompanion(StitchEdgesCompanion data) {
    return StitchEdge(
      fromId: data.fromId.present ? data.fromId.value : this.fromId,
      toId: data.toId.present ? data.toId.value : this.toId,
      createdByAuthorId: data.createdByAuthorId.present
          ? data.createdByAuthorId.value
          : this.createdByAuthorId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StitchEdge(')
          ..write('fromId: $fromId, ')
          ..write('toId: $toId, ')
          ..write('createdByAuthorId: $createdByAuthorId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(fromId, toId, createdByAuthorId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StitchEdge &&
          other.fromId == this.fromId &&
          other.toId == this.toId &&
          other.createdByAuthorId == this.createdByAuthorId &&
          other.createdAt == this.createdAt);
}

class StitchEdgesCompanion extends UpdateCompanion<StitchEdge> {
  final Value<String> fromId;
  final Value<String> toId;
  final Value<String?> createdByAuthorId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const StitchEdgesCompanion({
    this.fromId = const Value.absent(),
    this.toId = const Value.absent(),
    this.createdByAuthorId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StitchEdgesCompanion.insert({
    required String fromId,
    required String toId,
    this.createdByAuthorId = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : fromId = Value(fromId),
       toId = Value(toId),
       createdAt = Value(createdAt);
  static Insertable<StitchEdge> custom({
    Expression<String>? fromId,
    Expression<String>? toId,
    Expression<String>? createdByAuthorId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fromId != null) 'from_id': fromId,
      if (toId != null) 'to_id': toId,
      if (createdByAuthorId != null) 'created_by_author_id': createdByAuthorId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StitchEdgesCompanion copyWith({
    Value<String>? fromId,
    Value<String>? toId,
    Value<String?>? createdByAuthorId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return StitchEdgesCompanion(
      fromId: fromId ?? this.fromId,
      toId: toId ?? this.toId,
      createdByAuthorId: createdByAuthorId ?? this.createdByAuthorId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fromId.present) {
      map['from_id'] = Variable<String>(fromId.value);
    }
    if (toId.present) {
      map['to_id'] = Variable<String>(toId.value);
    }
    if (createdByAuthorId.present) {
      map['created_by_author_id'] = Variable<String>(createdByAuthorId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StitchEdgesCompanion(')
          ..write('fromId: $fromId, ')
          ..write('toId: $toId, ')
          ..write('createdByAuthorId: $createdByAuthorId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipientEdgesTable extends RecipientEdges
    with TableInfo<$RecipientEdgesTable, RecipientEdge> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipientEdgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES messages (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _recipientIdMeta = const VerificationMeta(
    'recipientId',
  );
  @override
  late final GeneratedColumn<String> recipientId = GeneratedColumn<String>(
    'recipient_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RecipientKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RecipientKind>($RecipientEdgesTable.$converterkind);
  @override
  List<GeneratedColumn> get $columns => [messageId, recipientId, kind];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipient_edges';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecipientEdge> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('recipient_id')) {
      context.handle(
        _recipientIdMeta,
        recipientId.isAcceptableOrUnknown(
          data['recipient_id']!,
          _recipientIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, recipientId};
  @override
  RecipientEdge map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipientEdge(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      recipientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_id'],
      )!,
      kind: $RecipientEdgesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
    );
  }

  @override
  $RecipientEdgesTable createAlias(String alias) {
    return $RecipientEdgesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RecipientKind, String, String> $converterkind =
      const EnumNameConverter<RecipientKind>(RecipientKind.values);
}

class RecipientEdge extends DataClass implements Insertable<RecipientEdge> {
  final String messageId;
  final String recipientId;
  final RecipientKind kind;
  const RecipientEdge({
    required this.messageId,
    required this.recipientId,
    required this.kind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['recipient_id'] = Variable<String>(recipientId);
    {
      map['kind'] = Variable<String>(
        $RecipientEdgesTable.$converterkind.toSql(kind),
      );
    }
    return map;
  }

  RecipientEdgesCompanion toCompanion(bool nullToAbsent) {
    return RecipientEdgesCompanion(
      messageId: Value(messageId),
      recipientId: Value(recipientId),
      kind: Value(kind),
    );
  }

  factory RecipientEdge.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipientEdge(
      messageId: serializer.fromJson<String>(json['messageId']),
      recipientId: serializer.fromJson<String>(json['recipientId']),
      kind: $RecipientEdgesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'recipientId': serializer.toJson<String>(recipientId),
      'kind': serializer.toJson<String>(
        $RecipientEdgesTable.$converterkind.toJson(kind),
      ),
    };
  }

  RecipientEdge copyWith({
    String? messageId,
    String? recipientId,
    RecipientKind? kind,
  }) => RecipientEdge(
    messageId: messageId ?? this.messageId,
    recipientId: recipientId ?? this.recipientId,
    kind: kind ?? this.kind,
  );
  RecipientEdge copyWithCompanion(RecipientEdgesCompanion data) {
    return RecipientEdge(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      recipientId: data.recipientId.present
          ? data.recipientId.value
          : this.recipientId,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipientEdge(')
          ..write('messageId: $messageId, ')
          ..write('recipientId: $recipientId, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(messageId, recipientId, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipientEdge &&
          other.messageId == this.messageId &&
          other.recipientId == this.recipientId &&
          other.kind == this.kind);
}

class RecipientEdgesCompanion extends UpdateCompanion<RecipientEdge> {
  final Value<String> messageId;
  final Value<String> recipientId;
  final Value<RecipientKind> kind;
  final Value<int> rowid;
  const RecipientEdgesCompanion({
    this.messageId = const Value.absent(),
    this.recipientId = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipientEdgesCompanion.insert({
    required String messageId,
    required String recipientId,
    required RecipientKind kind,
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       recipientId = Value(recipientId),
       kind = Value(kind);
  static Insertable<RecipientEdge> custom({
    Expression<String>? messageId,
    Expression<String>? recipientId,
    Expression<String>? kind,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (recipientId != null) 'recipient_id': recipientId,
      if (kind != null) 'kind': kind,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipientEdgesCompanion copyWith({
    Value<String>? messageId,
    Value<String>? recipientId,
    Value<RecipientKind>? kind,
    Value<int>? rowid,
  }) {
    return RecipientEdgesCompanion(
      messageId: messageId ?? this.messageId,
      recipientId: recipientId ?? this.recipientId,
      kind: kind ?? this.kind,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (recipientId.present) {
      map['recipient_id'] = Variable<String>(recipientId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $RecipientEdgesTable.$converterkind.toSql(kind.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipientEdgesCompanion(')
          ..write('messageId: $messageId, ')
          ..write('recipientId: $recipientId, ')
          ..write('kind: $kind, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ColumnsTable extends Columns with TableInfo<$ColumnsTable, ColumnRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ColumnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _anchorMessageIdMeta = const VerificationMeta(
    'anchorMessageId',
  );
  @override
  late final GeneratedColumn<String> anchorMessageId = GeneratedColumn<String>(
    'anchor_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES messages (id)',
    ),
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scrollOffsetMeta = const VerificationMeta(
    'scrollOffset',
  );
  @override
  late final GeneratedColumn<double> scrollOffset = GeneratedColumn<double>(
    'scroll_offset',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    anchorMessageId,
    width,
    scrollOffset,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'columns';
  @override
  VerificationContext validateIntegrity(
    Insertable<ColumnRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('anchor_message_id')) {
      context.handle(
        _anchorMessageIdMeta,
        anchorMessageId.isAcceptableOrUnknown(
          data['anchor_message_id']!,
          _anchorMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('scroll_offset')) {
      context.handle(
        _scrollOffsetMeta,
        scrollOffset.isAcceptableOrUnknown(
          data['scroll_offset']!,
          _scrollOffsetMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ColumnRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ColumnRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      anchorMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anchor_message_id'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      ),
      scrollOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}scroll_offset'],
      ),
    );
  }

  @override
  $ColumnsTable createAlias(String alias) {
    return $ColumnsTable(attachedDatabase, alias);
  }
}

class ColumnRow extends DataClass implements Insertable<ColumnRow> {
  final String id;
  final String? anchorMessageId;
  final double? width;
  final double? scrollOffset;
  const ColumnRow({
    required this.id,
    this.anchorMessageId,
    this.width,
    this.scrollOffset,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || anchorMessageId != null) {
      map['anchor_message_id'] = Variable<String>(anchorMessageId);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<double>(width);
    }
    if (!nullToAbsent || scrollOffset != null) {
      map['scroll_offset'] = Variable<double>(scrollOffset);
    }
    return map;
  }

  ColumnsCompanion toCompanion(bool nullToAbsent) {
    return ColumnsCompanion(
      id: Value(id),
      anchorMessageId: anchorMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(anchorMessageId),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      scrollOffset: scrollOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(scrollOffset),
    );
  }

  factory ColumnRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ColumnRow(
      id: serializer.fromJson<String>(json['id']),
      anchorMessageId: serializer.fromJson<String?>(json['anchorMessageId']),
      width: serializer.fromJson<double?>(json['width']),
      scrollOffset: serializer.fromJson<double?>(json['scrollOffset']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'anchorMessageId': serializer.toJson<String?>(anchorMessageId),
      'width': serializer.toJson<double?>(width),
      'scrollOffset': serializer.toJson<double?>(scrollOffset),
    };
  }

  ColumnRow copyWith({
    String? id,
    Value<String?> anchorMessageId = const Value.absent(),
    Value<double?> width = const Value.absent(),
    Value<double?> scrollOffset = const Value.absent(),
  }) => ColumnRow(
    id: id ?? this.id,
    anchorMessageId: anchorMessageId.present
        ? anchorMessageId.value
        : this.anchorMessageId,
    width: width.present ? width.value : this.width,
    scrollOffset: scrollOffset.present ? scrollOffset.value : this.scrollOffset,
  );
  ColumnRow copyWithCompanion(ColumnsCompanion data) {
    return ColumnRow(
      id: data.id.present ? data.id.value : this.id,
      anchorMessageId: data.anchorMessageId.present
          ? data.anchorMessageId.value
          : this.anchorMessageId,
      width: data.width.present ? data.width.value : this.width,
      scrollOffset: data.scrollOffset.present
          ? data.scrollOffset.value
          : this.scrollOffset,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ColumnRow(')
          ..write('id: $id, ')
          ..write('anchorMessageId: $anchorMessageId, ')
          ..write('width: $width, ')
          ..write('scrollOffset: $scrollOffset')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, anchorMessageId, width, scrollOffset);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ColumnRow &&
          other.id == this.id &&
          other.anchorMessageId == this.anchorMessageId &&
          other.width == this.width &&
          other.scrollOffset == this.scrollOffset);
}

class ColumnsCompanion extends UpdateCompanion<ColumnRow> {
  final Value<String> id;
  final Value<String?> anchorMessageId;
  final Value<double?> width;
  final Value<double?> scrollOffset;
  final Value<int> rowid;
  const ColumnsCompanion({
    this.id = const Value.absent(),
    this.anchorMessageId = const Value.absent(),
    this.width = const Value.absent(),
    this.scrollOffset = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ColumnsCompanion.insert({
    required String id,
    this.anchorMessageId = const Value.absent(),
    this.width = const Value.absent(),
    this.scrollOffset = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<ColumnRow> custom({
    Expression<String>? id,
    Expression<String>? anchorMessageId,
    Expression<double>? width,
    Expression<double>? scrollOffset,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (anchorMessageId != null) 'anchor_message_id': anchorMessageId,
      if (width != null) 'width': width,
      if (scrollOffset != null) 'scroll_offset': scrollOffset,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ColumnsCompanion copyWith({
    Value<String>? id,
    Value<String?>? anchorMessageId,
    Value<double?>? width,
    Value<double?>? scrollOffset,
    Value<int>? rowid,
  }) {
    return ColumnsCompanion(
      id: id ?? this.id,
      anchorMessageId: anchorMessageId ?? this.anchorMessageId,
      width: width ?? this.width,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (anchorMessageId.present) {
      map['anchor_message_id'] = Variable<String>(anchorMessageId.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (scrollOffset.present) {
      map['scroll_offset'] = Variable<double>(scrollOffset.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ColumnsCompanion(')
          ..write('id: $id, ')
          ..write('anchorMessageId: $anchorMessageId, ')
          ..write('width: $width, ')
          ..write('scrollOffset: $scrollOffset, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ColumnBranchPointersTable extends ColumnBranchPointers
    with TableInfo<$ColumnBranchPointersTable, ColumnBranchPointer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ColumnBranchPointersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _columnIdMeta = const VerificationMeta(
    'columnId',
  );
  @override
  late final GeneratedColumn<String> columnId = GeneratedColumn<String>(
    'column_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES columns (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES messages (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<String> childId = GeneratedColumn<String>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES messages (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [columnId, parentId, childId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'column_branch_pointers';
  @override
  VerificationContext validateIntegrity(
    Insertable<ColumnBranchPointer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('column_id')) {
      context.handle(
        _columnIdMeta,
        columnId.isAcceptableOrUnknown(data['column_id']!, _columnIdMeta),
      );
    } else if (isInserting) {
      context.missing(_columnIdMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_parentIdMeta);
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {columnId, parentId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {columnId, childId},
  ];
  @override
  ColumnBranchPointer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ColumnBranchPointer(
      columnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}column_id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_id'],
      )!,
    );
  }

  @override
  $ColumnBranchPointersTable createAlias(String alias) {
    return $ColumnBranchPointersTable(attachedDatabase, alias);
  }
}

class ColumnBranchPointer extends DataClass
    implements Insertable<ColumnBranchPointer> {
  final String columnId;
  final String parentId;
  final String childId;
  const ColumnBranchPointer({
    required this.columnId,
    required this.parentId,
    required this.childId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['column_id'] = Variable<String>(columnId);
    map['parent_id'] = Variable<String>(parentId);
    map['child_id'] = Variable<String>(childId);
    return map;
  }

  ColumnBranchPointersCompanion toCompanion(bool nullToAbsent) {
    return ColumnBranchPointersCompanion(
      columnId: Value(columnId),
      parentId: Value(parentId),
      childId: Value(childId),
    );
  }

  factory ColumnBranchPointer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ColumnBranchPointer(
      columnId: serializer.fromJson<String>(json['columnId']),
      parentId: serializer.fromJson<String>(json['parentId']),
      childId: serializer.fromJson<String>(json['childId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'columnId': serializer.toJson<String>(columnId),
      'parentId': serializer.toJson<String>(parentId),
      'childId': serializer.toJson<String>(childId),
    };
  }

  ColumnBranchPointer copyWith({
    String? columnId,
    String? parentId,
    String? childId,
  }) => ColumnBranchPointer(
    columnId: columnId ?? this.columnId,
    parentId: parentId ?? this.parentId,
    childId: childId ?? this.childId,
  );
  ColumnBranchPointer copyWithCompanion(ColumnBranchPointersCompanion data) {
    return ColumnBranchPointer(
      columnId: data.columnId.present ? data.columnId.value : this.columnId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      childId: data.childId.present ? data.childId.value : this.childId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ColumnBranchPointer(')
          ..write('columnId: $columnId, ')
          ..write('parentId: $parentId, ')
          ..write('childId: $childId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(columnId, parentId, childId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ColumnBranchPointer &&
          other.columnId == this.columnId &&
          other.parentId == this.parentId &&
          other.childId == this.childId);
}

class ColumnBranchPointersCompanion
    extends UpdateCompanion<ColumnBranchPointer> {
  final Value<String> columnId;
  final Value<String> parentId;
  final Value<String> childId;
  final Value<int> rowid;
  const ColumnBranchPointersCompanion({
    this.columnId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.childId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ColumnBranchPointersCompanion.insert({
    required String columnId,
    required String parentId,
    required String childId,
    this.rowid = const Value.absent(),
  }) : columnId = Value(columnId),
       parentId = Value(parentId),
       childId = Value(childId);
  static Insertable<ColumnBranchPointer> custom({
    Expression<String>? columnId,
    Expression<String>? parentId,
    Expression<String>? childId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (columnId != null) 'column_id': columnId,
      if (parentId != null) 'parent_id': parentId,
      if (childId != null) 'child_id': childId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ColumnBranchPointersCompanion copyWith({
    Value<String>? columnId,
    Value<String>? parentId,
    Value<String>? childId,
    Value<int>? rowid,
  }) {
    return ColumnBranchPointersCompanion(
      columnId: columnId ?? this.columnId,
      parentId: parentId ?? this.parentId,
      childId: childId ?? this.childId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (columnId.present) {
      map['column_id'] = Variable<String>(columnId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<String>(childId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ColumnBranchPointersCompanion(')
          ..write('columnId: $columnId, ')
          ..write('parentId: $parentId, ')
          ..write('childId: $childId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $ReplyEdgesTable replyEdges = $ReplyEdgesTable(this);
  late final $StitchEdgesTable stitchEdges = $StitchEdgesTable(this);
  late final $RecipientEdgesTable recipientEdges = $RecipientEdgesTable(this);
  late final $ColumnsTable columns = $ColumnsTable(this);
  late final $ColumnBranchPointersTable columnBranchPointers =
      $ColumnBranchPointersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    messages,
    replyEdges,
    stitchEdges,
    recipientEdges,
    columns,
    columnBranchPointers,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reply_edges', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reply_edges', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stitch_edges', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stitch_edges', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('recipient_edges', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'columns',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('column_branch_pointers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('column_branch_pointers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('column_branch_pointers', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required MessageRole role,
      Value<String?> authorId,
      required String content,
      Value<String?> gitCommit,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<MessageRole> role,
      Value<String?> authorId,
      Value<String> content,
      Value<String?> gitCommit,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });

final class $$MessagesTableReferences
    extends BaseReferences<_$AppDatabase, $MessagesTable, MessageRow> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ReplyEdgesTable, List<ReplyEdge>>
  _replyEdgesAsParentTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.replyEdges,
    aliasName: 'messages__id__reply_edges__parent_id',
  );

  $$ReplyEdgesTableProcessedTableManager get replyEdgesAsParent {
    final manager = $$ReplyEdgesTableTableManager(
      $_db,
      $_db.replyEdges,
    ).filter((f) => f.parentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_replyEdgesAsParentTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReplyEdgesTable, List<ReplyEdge>>
  _replyEdgesAsChildTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.replyEdges,
    aliasName: 'messages__id__reply_edges__child_id',
  );

  $$ReplyEdgesTableProcessedTableManager get replyEdgesAsChild {
    final manager = $$ReplyEdgesTableTableManager(
      $_db,
      $_db.replyEdges,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_replyEdgesAsChildTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StitchEdgesTable, List<StitchEdge>>
  _stitchEdgesAsFromTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stitchEdges,
    aliasName: 'messages__id__stitch_edges__from_id',
  );

  $$StitchEdgesTableProcessedTableManager get stitchEdgesAsFrom {
    final manager = $$StitchEdgesTableTableManager(
      $_db,
      $_db.stitchEdges,
    ).filter((f) => f.fromId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stitchEdgesAsFromTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StitchEdgesTable, List<StitchEdge>>
  _stitchEdgesAsToTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stitchEdges,
    aliasName: 'messages__id__stitch_edges__to_id',
  );

  $$StitchEdgesTableProcessedTableManager get stitchEdgesAsTo {
    final manager = $$StitchEdgesTableTableManager(
      $_db,
      $_db.stitchEdges,
    ).filter((f) => f.toId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stitchEdgesAsToTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecipientEdgesTable, List<RecipientEdge>>
  _recipientEdgesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recipientEdges,
    aliasName: 'messages__id__recipient_edges__message_id',
  );

  $$RecipientEdgesTableProcessedTableManager get recipientEdgesRefs {
    final manager = $$RecipientEdgesTableTableManager(
      $_db,
      $_db.recipientEdges,
    ).filter((f) => f.messageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recipientEdgesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ColumnsTable, List<ColumnRow>> _columnsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.columns,
    aliasName: 'messages__id__columns__anchor_message_id',
  );

  $$ColumnsTableProcessedTableManager get columnsRefs {
    final manager = $$ColumnsTableTableManager($_db, $_db.columns).filter(
      (f) => f.anchorMessageId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_columnsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ColumnBranchPointersTable,
    List<ColumnBranchPointer>
  >
  _branchPointersAsParentTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.columnBranchPointers,
        aliasName: 'messages__id__column_branch_pointers__parent_id',
      );

  $$ColumnBranchPointersTableProcessedTableManager get branchPointersAsParent {
    final manager = $$ColumnBranchPointersTableTableManager(
      $_db,
      $_db.columnBranchPointers,
    ).filter((f) => f.parentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _branchPointersAsParentTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ColumnBranchPointersTable,
    List<ColumnBranchPointer>
  >
  _branchPointersAsChildTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.columnBranchPointers,
        aliasName: 'messages__id__column_branch_pointers__child_id',
      );

  $$ColumnBranchPointersTableProcessedTableManager get branchPointersAsChild {
    final manager = $$ColumnBranchPointersTableTableManager(
      $_db,
      $_db.columnBranchPointers,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _branchPointersAsChildTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MessageRole, MessageRole, String> get role =>
      $composableBuilder(
        column: $table.role,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gitCommit => $composableBuilder(
    column: $table.gitCommit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> replyEdgesAsParent(
    Expression<bool> Function($$ReplyEdgesTableFilterComposer f) f,
  ) {
    final $$ReplyEdgesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.replyEdges,
      getReferencedColumn: (t) => t.parentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReplyEdgesTableFilterComposer(
            $db: $db,
            $table: $db.replyEdges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> replyEdgesAsChild(
    Expression<bool> Function($$ReplyEdgesTableFilterComposer f) f,
  ) {
    final $$ReplyEdgesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.replyEdges,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReplyEdgesTableFilterComposer(
            $db: $db,
            $table: $db.replyEdges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stitchEdgesAsFrom(
    Expression<bool> Function($$StitchEdgesTableFilterComposer f) f,
  ) {
    final $$StitchEdgesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stitchEdges,
      getReferencedColumn: (t) => t.fromId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StitchEdgesTableFilterComposer(
            $db: $db,
            $table: $db.stitchEdges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stitchEdgesAsTo(
    Expression<bool> Function($$StitchEdgesTableFilterComposer f) f,
  ) {
    final $$StitchEdgesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stitchEdges,
      getReferencedColumn: (t) => t.toId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StitchEdgesTableFilterComposer(
            $db: $db,
            $table: $db.stitchEdges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recipientEdgesRefs(
    Expression<bool> Function($$RecipientEdgesTableFilterComposer f) f,
  ) {
    final $$RecipientEdgesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipientEdges,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipientEdgesTableFilterComposer(
            $db: $db,
            $table: $db.recipientEdges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> columnsRefs(
    Expression<bool> Function($$ColumnsTableFilterComposer f) f,
  ) {
    final $$ColumnsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.columns,
      getReferencedColumn: (t) => t.anchorMessageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ColumnsTableFilterComposer(
            $db: $db,
            $table: $db.columns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> branchPointersAsParent(
    Expression<bool> Function($$ColumnBranchPointersTableFilterComposer f) f,
  ) {
    final $$ColumnBranchPointersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.columnBranchPointers,
      getReferencedColumn: (t) => t.parentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ColumnBranchPointersTableFilterComposer(
            $db: $db,
            $table: $db.columnBranchPointers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> branchPointersAsChild(
    Expression<bool> Function($$ColumnBranchPointersTableFilterComposer f) f,
  ) {
    final $$ColumnBranchPointersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.columnBranchPointers,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ColumnBranchPointersTableFilterComposer(
            $db: $db,
            $table: $db.columnBranchPointers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gitCommit => $composableBuilder(
    column: $table.gitCommit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MessageRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get gitCommit =>
      $composableBuilder(column: $table.gitCommit, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> replyEdgesAsParent<T extends Object>(
    Expression<T> Function($$ReplyEdgesTableAnnotationComposer a) f,
  ) {
    final $$ReplyEdgesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.replyEdges,
      getReferencedColumn: (t) => t.parentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReplyEdgesTableAnnotationComposer(
            $db: $db,
            $table: $db.replyEdges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> replyEdgesAsChild<T extends Object>(
    Expression<T> Function($$ReplyEdgesTableAnnotationComposer a) f,
  ) {
    final $$ReplyEdgesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.replyEdges,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReplyEdgesTableAnnotationComposer(
            $db: $db,
            $table: $db.replyEdges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stitchEdgesAsFrom<T extends Object>(
    Expression<T> Function($$StitchEdgesTableAnnotationComposer a) f,
  ) {
    final $$StitchEdgesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stitchEdges,
      getReferencedColumn: (t) => t.fromId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StitchEdgesTableAnnotationComposer(
            $db: $db,
            $table: $db.stitchEdges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stitchEdgesAsTo<T extends Object>(
    Expression<T> Function($$StitchEdgesTableAnnotationComposer a) f,
  ) {
    final $$StitchEdgesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stitchEdges,
      getReferencedColumn: (t) => t.toId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StitchEdgesTableAnnotationComposer(
            $db: $db,
            $table: $db.stitchEdges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recipientEdgesRefs<T extends Object>(
    Expression<T> Function($$RecipientEdgesTableAnnotationComposer a) f,
  ) {
    final $$RecipientEdgesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipientEdges,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipientEdgesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipientEdges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> columnsRefs<T extends Object>(
    Expression<T> Function($$ColumnsTableAnnotationComposer a) f,
  ) {
    final $$ColumnsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.columns,
      getReferencedColumn: (t) => t.anchorMessageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ColumnsTableAnnotationComposer(
            $db: $db,
            $table: $db.columns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> branchPointersAsParent<T extends Object>(
    Expression<T> Function($$ColumnBranchPointersTableAnnotationComposer a) f,
  ) {
    final $$ColumnBranchPointersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.columnBranchPointers,
          getReferencedColumn: (t) => t.parentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ColumnBranchPointersTableAnnotationComposer(
                $db: $db,
                $table: $db.columnBranchPointers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> branchPointersAsChild<T extends Object>(
    Expression<T> Function($$ColumnBranchPointersTableAnnotationComposer a) f,
  ) {
    final $$ColumnBranchPointersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.columnBranchPointers,
          getReferencedColumn: (t) => t.childId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ColumnBranchPointersTableAnnotationComposer(
                $db: $db,
                $table: $db.columnBranchPointers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          MessageRow,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (MessageRow, $$MessagesTableReferences),
          MessageRow,
          PrefetchHooks Function({
            bool replyEdgesAsParent,
            bool replyEdgesAsChild,
            bool stitchEdgesAsFrom,
            bool stitchEdgesAsTo,
            bool recipientEdgesRefs,
            bool columnsRefs,
            bool branchPointersAsParent,
            bool branchPointersAsChild,
          })
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<MessageRole> role = const Value.absent(),
                Value<String?> authorId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> gitCommit = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                role: role,
                authorId: authorId,
                content: content,
                gitCommit: gitCommit,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required MessageRole role,
                Value<String?> authorId = const Value.absent(),
                required String content,
                Value<String?> gitCommit = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                role: role,
                authorId: authorId,
                content: content,
                gitCommit: gitCommit,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                replyEdgesAsParent = false,
                replyEdgesAsChild = false,
                stitchEdgesAsFrom = false,
                stitchEdgesAsTo = false,
                recipientEdgesRefs = false,
                columnsRefs = false,
                branchPointersAsParent = false,
                branchPointersAsChild = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (replyEdgesAsParent) db.replyEdges,
                    if (replyEdgesAsChild) db.replyEdges,
                    if (stitchEdgesAsFrom) db.stitchEdges,
                    if (stitchEdgesAsTo) db.stitchEdges,
                    if (recipientEdgesRefs) db.recipientEdges,
                    if (columnsRefs) db.columns,
                    if (branchPointersAsParent) db.columnBranchPointers,
                    if (branchPointersAsChild) db.columnBranchPointers,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (replyEdgesAsParent)
                        await $_getPrefetchedData<
                          MessageRow,
                          $MessagesTable,
                          ReplyEdge
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._replyEdgesAsParentTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).replyEdgesAsParent,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.parentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (replyEdgesAsChild)
                        await $_getPrefetchedData<
                          MessageRow,
                          $MessagesTable,
                          ReplyEdge
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._replyEdgesAsChildTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).replyEdgesAsChild,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.childId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stitchEdgesAsFrom)
                        await $_getPrefetchedData<
                          MessageRow,
                          $MessagesTable,
                          StitchEdge
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._stitchEdgesAsFromTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).stitchEdgesAsFrom,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.fromId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stitchEdgesAsTo)
                        await $_getPrefetchedData<
                          MessageRow,
                          $MessagesTable,
                          StitchEdge
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._stitchEdgesAsToTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).stitchEdgesAsTo,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.toId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (recipientEdgesRefs)
                        await $_getPrefetchedData<
                          MessageRow,
                          $MessagesTable,
                          RecipientEdge
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._recipientEdgesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).recipientEdgesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.messageId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (columnsRefs)
                        await $_getPrefetchedData<
                          MessageRow,
                          $MessagesTable,
                          ColumnRow
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._columnsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).columnsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.anchorMessageId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (branchPointersAsParent)
                        await $_getPrefetchedData<
                          MessageRow,
                          $MessagesTable,
                          ColumnBranchPointer
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._branchPointersAsParentTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).branchPointersAsParent,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.parentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (branchPointersAsChild)
                        await $_getPrefetchedData<
                          MessageRow,
                          $MessagesTable,
                          ColumnBranchPointer
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._branchPointersAsChildTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).branchPointersAsChild,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.childId == item.id,
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

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      MessageRow,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (MessageRow, $$MessagesTableReferences),
      MessageRow,
      PrefetchHooks Function({
        bool replyEdgesAsParent,
        bool replyEdgesAsChild,
        bool stitchEdgesAsFrom,
        bool stitchEdgesAsTo,
        bool recipientEdgesRefs,
        bool columnsRefs,
        bool branchPointersAsParent,
        bool branchPointersAsChild,
      })
    >;
typedef $$ReplyEdgesTableCreateCompanionBuilder =
    ReplyEdgesCompanion Function({
      required String parentId,
      required String childId,
      Value<int> rowid,
    });
typedef $$ReplyEdgesTableUpdateCompanionBuilder =
    ReplyEdgesCompanion Function({
      Value<String> parentId,
      Value<String> childId,
      Value<int> rowid,
    });

final class $$ReplyEdgesTableReferences
    extends BaseReferences<_$AppDatabase, $ReplyEdgesTable, ReplyEdge> {
  $$ReplyEdgesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MessagesTable _parentIdTable(_$AppDatabase db) =>
      db.messages.createAlias('reply_edges__parent_id__messages__id');

  $$MessagesTableProcessedTableManager get parentId {
    final $_column = $_itemColumn<String>('parent_id')!;

    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MessagesTable _childIdTable(_$AppDatabase db) =>
      db.messages.createAlias('reply_edges__child_id__messages__id');

  $$MessagesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<String>('child_id')!;

    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReplyEdgesTableFilterComposer
    extends Composer<_$AppDatabase, $ReplyEdgesTable> {
  $$ReplyEdgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MessagesTableFilterComposer get parentId {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MessagesTableFilterComposer get childId {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReplyEdgesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReplyEdgesTable> {
  $$ReplyEdgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MessagesTableOrderingComposer get parentId {
    final $$MessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MessagesTableOrderingComposer get childId {
    final $$MessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReplyEdgesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReplyEdgesTable> {
  $$ReplyEdgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MessagesTableAnnotationComposer get parentId {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MessagesTableAnnotationComposer get childId {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReplyEdgesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReplyEdgesTable,
          ReplyEdge,
          $$ReplyEdgesTableFilterComposer,
          $$ReplyEdgesTableOrderingComposer,
          $$ReplyEdgesTableAnnotationComposer,
          $$ReplyEdgesTableCreateCompanionBuilder,
          $$ReplyEdgesTableUpdateCompanionBuilder,
          (ReplyEdge, $$ReplyEdgesTableReferences),
          ReplyEdge,
          PrefetchHooks Function({bool parentId, bool childId})
        > {
  $$ReplyEdgesTableTableManager(_$AppDatabase db, $ReplyEdgesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReplyEdgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReplyEdgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReplyEdgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> parentId = const Value.absent(),
                Value<String> childId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReplyEdgesCompanion(
                parentId: parentId,
                childId: childId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String parentId,
                required String childId,
                Value<int> rowid = const Value.absent(),
              }) => ReplyEdgesCompanion.insert(
                parentId: parentId,
                childId: childId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReplyEdgesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({parentId = false, childId = false}) {
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
                    if (parentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.parentId,
                                referencedTable: $$ReplyEdgesTableReferences
                                    ._parentIdTable(db),
                                referencedColumn: $$ReplyEdgesTableReferences
                                    ._parentIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (childId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.childId,
                                referencedTable: $$ReplyEdgesTableReferences
                                    ._childIdTable(db),
                                referencedColumn: $$ReplyEdgesTableReferences
                                    ._childIdTable(db)
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

typedef $$ReplyEdgesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReplyEdgesTable,
      ReplyEdge,
      $$ReplyEdgesTableFilterComposer,
      $$ReplyEdgesTableOrderingComposer,
      $$ReplyEdgesTableAnnotationComposer,
      $$ReplyEdgesTableCreateCompanionBuilder,
      $$ReplyEdgesTableUpdateCompanionBuilder,
      (ReplyEdge, $$ReplyEdgesTableReferences),
      ReplyEdge,
      PrefetchHooks Function({bool parentId, bool childId})
    >;
typedef $$StitchEdgesTableCreateCompanionBuilder =
    StitchEdgesCompanion Function({
      required String fromId,
      required String toId,
      Value<String?> createdByAuthorId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$StitchEdgesTableUpdateCompanionBuilder =
    StitchEdgesCompanion Function({
      Value<String> fromId,
      Value<String> toId,
      Value<String?> createdByAuthorId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$StitchEdgesTableReferences
    extends BaseReferences<_$AppDatabase, $StitchEdgesTable, StitchEdge> {
  $$StitchEdgesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MessagesTable _fromIdTable(_$AppDatabase db) =>
      db.messages.createAlias('stitch_edges__from_id__messages__id');

  $$MessagesTableProcessedTableManager get fromId {
    final $_column = $_itemColumn<String>('from_id')!;

    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fromIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MessagesTable _toIdTable(_$AppDatabase db) =>
      db.messages.createAlias('stitch_edges__to_id__messages__id');

  $$MessagesTableProcessedTableManager get toId {
    final $_column = $_itemColumn<String>('to_id')!;

    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_toIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StitchEdgesTableFilterComposer
    extends Composer<_$AppDatabase, $StitchEdgesTable> {
  $$StitchEdgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get createdByAuthorId => $composableBuilder(
    column: $table.createdByAuthorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MessagesTableFilterComposer get fromId {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MessagesTableFilterComposer get toId {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StitchEdgesTableOrderingComposer
    extends Composer<_$AppDatabase, $StitchEdgesTable> {
  $$StitchEdgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get createdByAuthorId => $composableBuilder(
    column: $table.createdByAuthorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MessagesTableOrderingComposer get fromId {
    final $$MessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MessagesTableOrderingComposer get toId {
    final $$MessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StitchEdgesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StitchEdgesTable> {
  $$StitchEdgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get createdByAuthorId => $composableBuilder(
    column: $table.createdByAuthorId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MessagesTableAnnotationComposer get fromId {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MessagesTableAnnotationComposer get toId {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StitchEdgesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StitchEdgesTable,
          StitchEdge,
          $$StitchEdgesTableFilterComposer,
          $$StitchEdgesTableOrderingComposer,
          $$StitchEdgesTableAnnotationComposer,
          $$StitchEdgesTableCreateCompanionBuilder,
          $$StitchEdgesTableUpdateCompanionBuilder,
          (StitchEdge, $$StitchEdgesTableReferences),
          StitchEdge,
          PrefetchHooks Function({bool fromId, bool toId})
        > {
  $$StitchEdgesTableTableManager(_$AppDatabase db, $StitchEdgesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StitchEdgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StitchEdgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StitchEdgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fromId = const Value.absent(),
                Value<String> toId = const Value.absent(),
                Value<String?> createdByAuthorId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StitchEdgesCompanion(
                fromId: fromId,
                toId: toId,
                createdByAuthorId: createdByAuthorId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fromId,
                required String toId,
                Value<String?> createdByAuthorId = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => StitchEdgesCompanion.insert(
                fromId: fromId,
                toId: toId,
                createdByAuthorId: createdByAuthorId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StitchEdgesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({fromId = false, toId = false}) {
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
                    if (fromId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.fromId,
                                referencedTable: $$StitchEdgesTableReferences
                                    ._fromIdTable(db),
                                referencedColumn: $$StitchEdgesTableReferences
                                    ._fromIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (toId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.toId,
                                referencedTable: $$StitchEdgesTableReferences
                                    ._toIdTable(db),
                                referencedColumn: $$StitchEdgesTableReferences
                                    ._toIdTable(db)
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

typedef $$StitchEdgesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StitchEdgesTable,
      StitchEdge,
      $$StitchEdgesTableFilterComposer,
      $$StitchEdgesTableOrderingComposer,
      $$StitchEdgesTableAnnotationComposer,
      $$StitchEdgesTableCreateCompanionBuilder,
      $$StitchEdgesTableUpdateCompanionBuilder,
      (StitchEdge, $$StitchEdgesTableReferences),
      StitchEdge,
      PrefetchHooks Function({bool fromId, bool toId})
    >;
typedef $$RecipientEdgesTableCreateCompanionBuilder =
    RecipientEdgesCompanion Function({
      required String messageId,
      required String recipientId,
      required RecipientKind kind,
      Value<int> rowid,
    });
typedef $$RecipientEdgesTableUpdateCompanionBuilder =
    RecipientEdgesCompanion Function({
      Value<String> messageId,
      Value<String> recipientId,
      Value<RecipientKind> kind,
      Value<int> rowid,
    });

final class $$RecipientEdgesTableReferences
    extends BaseReferences<_$AppDatabase, $RecipientEdgesTable, RecipientEdge> {
  $$RecipientEdgesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MessagesTable _messageIdTable(_$AppDatabase db) =>
      db.messages.createAlias('recipient_edges__message_id__messages__id');

  $$MessagesTableProcessedTableManager get messageId {
    final $_column = $_itemColumn<String>('message_id')!;

    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_messageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecipientEdgesTableFilterComposer
    extends Composer<_$AppDatabase, $RecipientEdgesTable> {
  $$RecipientEdgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recipientId => $composableBuilder(
    column: $table.recipientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RecipientKind, RecipientKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  $$MessagesTableFilterComposer get messageId {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipientEdgesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipientEdgesTable> {
  $$RecipientEdgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recipientId => $composableBuilder(
    column: $table.recipientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  $$MessagesTableOrderingComposer get messageId {
    final $$MessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipientEdgesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipientEdgesTable> {
  $$RecipientEdgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recipientId => $composableBuilder(
    column: $table.recipientId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<RecipientKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  $$MessagesTableAnnotationComposer get messageId {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipientEdgesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipientEdgesTable,
          RecipientEdge,
          $$RecipientEdgesTableFilterComposer,
          $$RecipientEdgesTableOrderingComposer,
          $$RecipientEdgesTableAnnotationComposer,
          $$RecipientEdgesTableCreateCompanionBuilder,
          $$RecipientEdgesTableUpdateCompanionBuilder,
          (RecipientEdge, $$RecipientEdgesTableReferences),
          RecipientEdge,
          PrefetchHooks Function({bool messageId})
        > {
  $$RecipientEdgesTableTableManager(
    _$AppDatabase db,
    $RecipientEdgesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipientEdgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipientEdgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipientEdgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> recipientId = const Value.absent(),
                Value<RecipientKind> kind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipientEdgesCompanion(
                messageId: messageId,
                recipientId: recipientId,
                kind: kind,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String recipientId,
                required RecipientKind kind,
                Value<int> rowid = const Value.absent(),
              }) => RecipientEdgesCompanion.insert(
                messageId: messageId,
                recipientId: recipientId,
                kind: kind,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecipientEdgesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({messageId = false}) {
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
                    if (messageId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.messageId,
                                referencedTable: $$RecipientEdgesTableReferences
                                    ._messageIdTable(db),
                                referencedColumn:
                                    $$RecipientEdgesTableReferences
                                        ._messageIdTable(db)
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

typedef $$RecipientEdgesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipientEdgesTable,
      RecipientEdge,
      $$RecipientEdgesTableFilterComposer,
      $$RecipientEdgesTableOrderingComposer,
      $$RecipientEdgesTableAnnotationComposer,
      $$RecipientEdgesTableCreateCompanionBuilder,
      $$RecipientEdgesTableUpdateCompanionBuilder,
      (RecipientEdge, $$RecipientEdgesTableReferences),
      RecipientEdge,
      PrefetchHooks Function({bool messageId})
    >;
typedef $$ColumnsTableCreateCompanionBuilder =
    ColumnsCompanion Function({
      required String id,
      Value<String?> anchorMessageId,
      Value<double?> width,
      Value<double?> scrollOffset,
      Value<int> rowid,
    });
typedef $$ColumnsTableUpdateCompanionBuilder =
    ColumnsCompanion Function({
      Value<String> id,
      Value<String?> anchorMessageId,
      Value<double?> width,
      Value<double?> scrollOffset,
      Value<int> rowid,
    });

final class $$ColumnsTableReferences
    extends BaseReferences<_$AppDatabase, $ColumnsTable, ColumnRow> {
  $$ColumnsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MessagesTable _anchorMessageIdTable(_$AppDatabase db) =>
      db.messages.createAlias('columns__anchor_message_id__messages__id');

  $$MessagesTableProcessedTableManager? get anchorMessageId {
    final $_column = $_itemColumn<String>('anchor_message_id');
    if ($_column == null) return null;
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_anchorMessageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $ColumnBranchPointersTable,
    List<ColumnBranchPointer>
  >
  _columnBranchPointersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.columnBranchPointers,
        aliasName: 'columns__id__column_branch_pointers__column_id',
      );

  $$ColumnBranchPointersTableProcessedTableManager
  get columnBranchPointersRefs {
    final manager = $$ColumnBranchPointersTableTableManager(
      $_db,
      $_db.columnBranchPointers,
    ).filter((f) => f.columnId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _columnBranchPointersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ColumnsTableFilterComposer
    extends Composer<_$AppDatabase, $ColumnsTable> {
  $$ColumnsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get scrollOffset => $composableBuilder(
    column: $table.scrollOffset,
    builder: (column) => ColumnFilters(column),
  );

  $$MessagesTableFilterComposer get anchorMessageId {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.anchorMessageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> columnBranchPointersRefs(
    Expression<bool> Function($$ColumnBranchPointersTableFilterComposer f) f,
  ) {
    final $$ColumnBranchPointersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.columnBranchPointers,
      getReferencedColumn: (t) => t.columnId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ColumnBranchPointersTableFilterComposer(
            $db: $db,
            $table: $db.columnBranchPointers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ColumnsTableOrderingComposer
    extends Composer<_$AppDatabase, $ColumnsTable> {
  $$ColumnsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get scrollOffset => $composableBuilder(
    column: $table.scrollOffset,
    builder: (column) => ColumnOrderings(column),
  );

  $$MessagesTableOrderingComposer get anchorMessageId {
    final $$MessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.anchorMessageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ColumnsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ColumnsTable> {
  $$ColumnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<double> get scrollOffset => $composableBuilder(
    column: $table.scrollOffset,
    builder: (column) => column,
  );

  $$MessagesTableAnnotationComposer get anchorMessageId {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.anchorMessageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> columnBranchPointersRefs<T extends Object>(
    Expression<T> Function($$ColumnBranchPointersTableAnnotationComposer a) f,
  ) {
    final $$ColumnBranchPointersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.columnBranchPointers,
          getReferencedColumn: (t) => t.columnId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ColumnBranchPointersTableAnnotationComposer(
                $db: $db,
                $table: $db.columnBranchPointers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ColumnsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ColumnsTable,
          ColumnRow,
          $$ColumnsTableFilterComposer,
          $$ColumnsTableOrderingComposer,
          $$ColumnsTableAnnotationComposer,
          $$ColumnsTableCreateCompanionBuilder,
          $$ColumnsTableUpdateCompanionBuilder,
          (ColumnRow, $$ColumnsTableReferences),
          ColumnRow,
          PrefetchHooks Function({
            bool anchorMessageId,
            bool columnBranchPointersRefs,
          })
        > {
  $$ColumnsTableTableManager(_$AppDatabase db, $ColumnsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ColumnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ColumnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ColumnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> anchorMessageId = const Value.absent(),
                Value<double?> width = const Value.absent(),
                Value<double?> scrollOffset = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ColumnsCompanion(
                id: id,
                anchorMessageId: anchorMessageId,
                width: width,
                scrollOffset: scrollOffset,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> anchorMessageId = const Value.absent(),
                Value<double?> width = const Value.absent(),
                Value<double?> scrollOffset = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ColumnsCompanion.insert(
                id: id,
                anchorMessageId: anchorMessageId,
                width: width,
                scrollOffset: scrollOffset,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ColumnsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({anchorMessageId = false, columnBranchPointersRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (columnBranchPointersRefs) db.columnBranchPointers,
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
                        if (anchorMessageId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.anchorMessageId,
                                    referencedTable: $$ColumnsTableReferences
                                        ._anchorMessageIdTable(db),
                                    referencedColumn: $$ColumnsTableReferences
                                        ._anchorMessageIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (columnBranchPointersRefs)
                        await $_getPrefetchedData<
                          ColumnRow,
                          $ColumnsTable,
                          ColumnBranchPointer
                        >(
                          currentTable: table,
                          referencedTable: $$ColumnsTableReferences
                              ._columnBranchPointersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ColumnsTableReferences(
                                db,
                                table,
                                p0,
                              ).columnBranchPointersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.columnId == item.id,
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

typedef $$ColumnsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ColumnsTable,
      ColumnRow,
      $$ColumnsTableFilterComposer,
      $$ColumnsTableOrderingComposer,
      $$ColumnsTableAnnotationComposer,
      $$ColumnsTableCreateCompanionBuilder,
      $$ColumnsTableUpdateCompanionBuilder,
      (ColumnRow, $$ColumnsTableReferences),
      ColumnRow,
      PrefetchHooks Function({
        bool anchorMessageId,
        bool columnBranchPointersRefs,
      })
    >;
typedef $$ColumnBranchPointersTableCreateCompanionBuilder =
    ColumnBranchPointersCompanion Function({
      required String columnId,
      required String parentId,
      required String childId,
      Value<int> rowid,
    });
typedef $$ColumnBranchPointersTableUpdateCompanionBuilder =
    ColumnBranchPointersCompanion Function({
      Value<String> columnId,
      Value<String> parentId,
      Value<String> childId,
      Value<int> rowid,
    });

final class $$ColumnBranchPointersTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ColumnBranchPointersTable,
          ColumnBranchPointer
        > {
  $$ColumnBranchPointersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ColumnsTable _columnIdTable(_$AppDatabase db) =>
      db.columns.createAlias('column_branch_pointers__column_id__columns__id');

  $$ColumnsTableProcessedTableManager get columnId {
    final $_column = $_itemColumn<String>('column_id')!;

    final manager = $$ColumnsTableTableManager(
      $_db,
      $_db.columns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_columnIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MessagesTable _parentIdTable(_$AppDatabase db) => db.messages
      .createAlias('column_branch_pointers__parent_id__messages__id');

  $$MessagesTableProcessedTableManager get parentId {
    final $_column = $_itemColumn<String>('parent_id')!;

    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MessagesTable _childIdTable(_$AppDatabase db) =>
      db.messages.createAlias('column_branch_pointers__child_id__messages__id');

  $$MessagesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<String>('child_id')!;

    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ColumnBranchPointersTableFilterComposer
    extends Composer<_$AppDatabase, $ColumnBranchPointersTable> {
  $$ColumnBranchPointersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ColumnsTableFilterComposer get columnId {
    final $$ColumnsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.columnId,
      referencedTable: $db.columns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ColumnsTableFilterComposer(
            $db: $db,
            $table: $db.columns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MessagesTableFilterComposer get parentId {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MessagesTableFilterComposer get childId {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ColumnBranchPointersTableOrderingComposer
    extends Composer<_$AppDatabase, $ColumnBranchPointersTable> {
  $$ColumnBranchPointersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ColumnsTableOrderingComposer get columnId {
    final $$ColumnsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.columnId,
      referencedTable: $db.columns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ColumnsTableOrderingComposer(
            $db: $db,
            $table: $db.columns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MessagesTableOrderingComposer get parentId {
    final $$MessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MessagesTableOrderingComposer get childId {
    final $$MessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ColumnBranchPointersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ColumnBranchPointersTable> {
  $$ColumnBranchPointersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ColumnsTableAnnotationComposer get columnId {
    final $$ColumnsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.columnId,
      referencedTable: $db.columns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ColumnsTableAnnotationComposer(
            $db: $db,
            $table: $db.columns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MessagesTableAnnotationComposer get parentId {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MessagesTableAnnotationComposer get childId {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ColumnBranchPointersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ColumnBranchPointersTable,
          ColumnBranchPointer,
          $$ColumnBranchPointersTableFilterComposer,
          $$ColumnBranchPointersTableOrderingComposer,
          $$ColumnBranchPointersTableAnnotationComposer,
          $$ColumnBranchPointersTableCreateCompanionBuilder,
          $$ColumnBranchPointersTableUpdateCompanionBuilder,
          (ColumnBranchPointer, $$ColumnBranchPointersTableReferences),
          ColumnBranchPointer,
          PrefetchHooks Function({bool columnId, bool parentId, bool childId})
        > {
  $$ColumnBranchPointersTableTableManager(
    _$AppDatabase db,
    $ColumnBranchPointersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ColumnBranchPointersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ColumnBranchPointersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ColumnBranchPointersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> columnId = const Value.absent(),
                Value<String> parentId = const Value.absent(),
                Value<String> childId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ColumnBranchPointersCompanion(
                columnId: columnId,
                parentId: parentId,
                childId: childId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String columnId,
                required String parentId,
                required String childId,
                Value<int> rowid = const Value.absent(),
              }) => ColumnBranchPointersCompanion.insert(
                columnId: columnId,
                parentId: parentId,
                childId: childId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ColumnBranchPointersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({columnId = false, parentId = false, childId = false}) {
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
                        if (columnId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.columnId,
                                    referencedTable:
                                        $$ColumnBranchPointersTableReferences
                                            ._columnIdTable(db),
                                    referencedColumn:
                                        $$ColumnBranchPointersTableReferences
                                            ._columnIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (parentId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentId,
                                    referencedTable:
                                        $$ColumnBranchPointersTableReferences
                                            ._parentIdTable(db),
                                    referencedColumn:
                                        $$ColumnBranchPointersTableReferences
                                            ._parentIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (childId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.childId,
                                    referencedTable:
                                        $$ColumnBranchPointersTableReferences
                                            ._childIdTable(db),
                                    referencedColumn:
                                        $$ColumnBranchPointersTableReferences
                                            ._childIdTable(db)
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

typedef $$ColumnBranchPointersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ColumnBranchPointersTable,
      ColumnBranchPointer,
      $$ColumnBranchPointersTableFilterComposer,
      $$ColumnBranchPointersTableOrderingComposer,
      $$ColumnBranchPointersTableAnnotationComposer,
      $$ColumnBranchPointersTableCreateCompanionBuilder,
      $$ColumnBranchPointersTableUpdateCompanionBuilder,
      (ColumnBranchPointer, $$ColumnBranchPointersTableReferences),
      ColumnBranchPointer,
      PrefetchHooks Function({bool columnId, bool parentId, bool childId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$ReplyEdgesTableTableManager get replyEdges =>
      $$ReplyEdgesTableTableManager(_db, _db.replyEdges);
  $$StitchEdgesTableTableManager get stitchEdges =>
      $$StitchEdgesTableTableManager(_db, _db.stitchEdges);
  $$RecipientEdgesTableTableManager get recipientEdges =>
      $$RecipientEdgesTableTableManager(_db, _db.recipientEdges);
  $$ColumnsTableTableManager get columns =>
      $$ColumnsTableTableManager(_db, _db.columns);
  $$ColumnBranchPointersTableTableManager get columnBranchPointers =>
      $$ColumnBranchPointersTableTableManager(_db, _db.columnBranchPointers);
}
