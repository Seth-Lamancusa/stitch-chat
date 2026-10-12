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
  static const VerificationMeta _cloudMessageIdMeta = const VerificationMeta(
    'cloudMessageId',
  );
  @override
  late final GeneratedColumn<String> cloudMessageId = GeneratedColumn<String>(
    'cloud_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CloudSyncStatus, String>
  syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  ).withConverter<CloudSyncStatus>($MessagesTable.$convertersyncStatus);
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    cloudMessageId,
    syncStatus,
    syncError,
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
    if (data.containsKey('cloud_message_id')) {
      context.handle(
        _cloudMessageIdMeta,
        cloudMessageId.isAcceptableOrUnknown(
          data['cloud_message_id']!,
          _cloudMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
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
      cloudMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_message_id'],
      ),
      syncStatus: $MessagesTable.$convertersyncStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sync_status'],
        )!,
      ),
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      ),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MessageRole, String, String> $converterrole =
      const EnumNameConverter<MessageRole>(MessageRole.values);
  static JsonTypeConverter2<CloudSyncStatus, String, String>
  $convertersyncStatus = const EnumNameConverter<CloudSyncStatus>(
    CloudSyncStatus.values,
  );
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  final String id;
  final MessageRole role;
  final String? authorId;
  final String content;
  final String? gitCommit;
  final DateTime? createdAt;
  final String? cloudMessageId;
  final CloudSyncStatus syncStatus;
  final String? syncError;
  const MessageRow({
    required this.id,
    required this.role,
    this.authorId,
    required this.content,
    this.gitCommit,
    this.createdAt,
    this.cloudMessageId,
    required this.syncStatus,
    this.syncError,
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
    if (!nullToAbsent || cloudMessageId != null) {
      map['cloud_message_id'] = Variable<String>(cloudMessageId);
    }
    {
      map['sync_status'] = Variable<String>(
        $MessagesTable.$convertersyncStatus.toSql(syncStatus),
      );
    }
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
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
      cloudMessageId: cloudMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudMessageId),
      syncStatus: Value(syncStatus),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
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
      cloudMessageId: serializer.fromJson<String?>(json['cloudMessageId']),
      syncStatus: $MessagesTable.$convertersyncStatus.fromJson(
        serializer.fromJson<String>(json['syncStatus']),
      ),
      syncError: serializer.fromJson<String?>(json['syncError']),
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
      'cloudMessageId': serializer.toJson<String?>(cloudMessageId),
      'syncStatus': serializer.toJson<String>(
        $MessagesTable.$convertersyncStatus.toJson(syncStatus),
      ),
      'syncError': serializer.toJson<String?>(syncError),
    };
  }

  MessageRow copyWith({
    String? id,
    MessageRole? role,
    Value<String?> authorId = const Value.absent(),
    String? content,
    Value<String?> gitCommit = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<String?> cloudMessageId = const Value.absent(),
    CloudSyncStatus? syncStatus,
    Value<String?> syncError = const Value.absent(),
  }) => MessageRow(
    id: id ?? this.id,
    role: role ?? this.role,
    authorId: authorId.present ? authorId.value : this.authorId,
    content: content ?? this.content,
    gitCommit: gitCommit.present ? gitCommit.value : this.gitCommit,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    cloudMessageId: cloudMessageId.present
        ? cloudMessageId.value
        : this.cloudMessageId,
    syncStatus: syncStatus ?? this.syncStatus,
    syncError: syncError.present ? syncError.value : this.syncError,
  );
  MessageRow copyWithCompanion(MessagesCompanion data) {
    return MessageRow(
      id: data.id.present ? data.id.value : this.id,
      role: data.role.present ? data.role.value : this.role,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      content: data.content.present ? data.content.value : this.content,
      gitCommit: data.gitCommit.present ? data.gitCommit.value : this.gitCommit,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      cloudMessageId: data.cloudMessageId.present
          ? data.cloudMessageId.value
          : this.cloudMessageId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
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
          ..write('createdAt: $createdAt, ')
          ..write('cloudMessageId: $cloudMessageId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    role,
    authorId,
    content,
    gitCommit,
    createdAt,
    cloudMessageId,
    syncStatus,
    syncError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.id == this.id &&
          other.role == this.role &&
          other.authorId == this.authorId &&
          other.content == this.content &&
          other.gitCommit == this.gitCommit &&
          other.createdAt == this.createdAt &&
          other.cloudMessageId == this.cloudMessageId &&
          other.syncStatus == this.syncStatus &&
          other.syncError == this.syncError);
}

class MessagesCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> id;
  final Value<MessageRole> role;
  final Value<String?> authorId;
  final Value<String> content;
  final Value<String?> gitCommit;
  final Value<DateTime?> createdAt;
  final Value<String?> cloudMessageId;
  final Value<CloudSyncStatus> syncStatus;
  final Value<String?> syncError;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.role = const Value.absent(),
    this.authorId = const Value.absent(),
    this.content = const Value.absent(),
    this.gitCommit = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.cloudMessageId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required MessageRole role,
    this.authorId = const Value.absent(),
    required String content,
    this.gitCommit = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.cloudMessageId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncError = const Value.absent(),
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
    Expression<String>? cloudMessageId,
    Expression<String>? syncStatus,
    Expression<String>? syncError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (role != null) 'role': role,
      if (authorId != null) 'author_id': authorId,
      if (content != null) 'content': content,
      if (gitCommit != null) 'git_commit': gitCommit,
      if (createdAt != null) 'created_at': createdAt,
      if (cloudMessageId != null) 'cloud_message_id': cloudMessageId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncError != null) 'sync_error': syncError,
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
    Value<String?>? cloudMessageId,
    Value<CloudSyncStatus>? syncStatus,
    Value<String?>? syncError,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      role: role ?? this.role,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      gitCommit: gitCommit ?? this.gitCommit,
      createdAt: createdAt ?? this.createdAt,
      cloudMessageId: cloudMessageId ?? this.cloudMessageId,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
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
    if (cloudMessageId.present) {
      map['cloud_message_id'] = Variable<String>(cloudMessageId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(
        $MessagesTable.$convertersyncStatus.toSql(syncStatus.value),
      );
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
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
          ..write('cloudMessageId: $cloudMessageId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncError: $syncError, ')
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
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [parentId, childId, hidden];
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
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
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
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
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

  /// When true, default path walks skip this hop; UI must explicitly reveal
  /// (AdaptiveMarker / sibling nav). Stays true after reveal — visibility is
  /// column pointer state, not a cleared flag.
  final bool hidden;
  const ReplyEdge({
    required this.parentId,
    required this.childId,
    required this.hidden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['parent_id'] = Variable<String>(parentId);
    map['child_id'] = Variable<String>(childId);
    map['hidden'] = Variable<bool>(hidden);
    return map;
  }

  ReplyEdgesCompanion toCompanion(bool nullToAbsent) {
    return ReplyEdgesCompanion(
      parentId: Value(parentId),
      childId: Value(childId),
      hidden: Value(hidden),
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
      hidden: serializer.fromJson<bool>(json['hidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'parentId': serializer.toJson<String>(parentId),
      'childId': serializer.toJson<String>(childId),
      'hidden': serializer.toJson<bool>(hidden),
    };
  }

  ReplyEdge copyWith({String? parentId, String? childId, bool? hidden}) =>
      ReplyEdge(
        parentId: parentId ?? this.parentId,
        childId: childId ?? this.childId,
        hidden: hidden ?? this.hidden,
      );
  ReplyEdge copyWithCompanion(ReplyEdgesCompanion data) {
    return ReplyEdge(
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      childId: data.childId.present ? data.childId.value : this.childId,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReplyEdge(')
          ..write('parentId: $parentId, ')
          ..write('childId: $childId, ')
          ..write('hidden: $hidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(parentId, childId, hidden);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReplyEdge &&
          other.parentId == this.parentId &&
          other.childId == this.childId &&
          other.hidden == this.hidden);
}

class ReplyEdgesCompanion extends UpdateCompanion<ReplyEdge> {
  final Value<String> parentId;
  final Value<String> childId;
  final Value<bool> hidden;
  final Value<int> rowid;
  const ReplyEdgesCompanion({
    this.parentId = const Value.absent(),
    this.childId = const Value.absent(),
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReplyEdgesCompanion.insert({
    required String parentId,
    required String childId,
    this.hidden = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : parentId = Value(parentId),
       childId = Value(childId);
  static Insertable<ReplyEdge> custom({
    Expression<String>? parentId,
    Expression<String>? childId,
    Expression<bool>? hidden,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (parentId != null) 'parent_id': parentId,
      if (childId != null) 'child_id': childId,
      if (hidden != null) 'hidden': hidden,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReplyEdgesCompanion copyWith({
    Value<String>? parentId,
    Value<String>? childId,
    Value<bool>? hidden,
    Value<int>? rowid,
  }) {
    return ReplyEdgesCompanion(
      parentId: parentId ?? this.parentId,
      childId: childId ?? this.childId,
      hidden: hidden ?? this.hidden,
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
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
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
          ..write('hidden: $hidden, ')
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
  static const VerificationMeta _isCloudBotMeta = const VerificationMeta(
    'isCloudBot',
  );
  @override
  late final GeneratedColumn<bool> isCloudBot = GeneratedColumn<bool>(
    'is_cloud_bot',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_cloud_bot" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPublicMeta = const VerificationMeta(
    'isPublic',
  );
  @override
  late final GeneratedColumn<bool> isPublic = GeneratedColumn<bool>(
    'is_public',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_public" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _notifyMeta = const VerificationMeta('notify');
  @override
  late final GeneratedColumn<bool> notify = GeneratedColumn<bool>(
    'notify',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notify" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _addedByMeta = const VerificationMeta(
    'addedBy',
  );
  @override
  late final GeneratedColumn<String> addedBy = GeneratedColumn<String>(
    'added_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    recipientId,
    kind,
    isCloudBot,
    isPublic,
    notify,
    addedBy,
    addedAt,
  ];
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
    if (data.containsKey('is_cloud_bot')) {
      context.handle(
        _isCloudBotMeta,
        isCloudBot.isAcceptableOrUnknown(
          data['is_cloud_bot']!,
          _isCloudBotMeta,
        ),
      );
    }
    if (data.containsKey('is_public')) {
      context.handle(
        _isPublicMeta,
        isPublic.isAcceptableOrUnknown(data['is_public']!, _isPublicMeta),
      );
    }
    if (data.containsKey('notify')) {
      context.handle(
        _notifyMeta,
        notify.isAcceptableOrUnknown(data['notify']!, _notifyMeta),
      );
    }
    if (data.containsKey('added_by')) {
      context.handle(
        _addedByMeta,
        addedBy.isAcceptableOrUnknown(data['added_by']!, _addedByMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
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
      isCloudBot: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_cloud_bot'],
      )!,
      isPublic: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_public'],
      )!,
      notify: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notify'],
      )!,
      addedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_by'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
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
  final bool isCloudBot;
  final bool isPublic;
  final bool notify;
  final String? addedBy;
  final DateTime? addedAt;
  const RecipientEdge({
    required this.messageId,
    required this.recipientId,
    required this.kind,
    required this.isCloudBot,
    required this.isPublic,
    required this.notify,
    this.addedBy,
    this.addedAt,
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
    map['is_cloud_bot'] = Variable<bool>(isCloudBot);
    map['is_public'] = Variable<bool>(isPublic);
    map['notify'] = Variable<bool>(notify);
    if (!nullToAbsent || addedBy != null) {
      map['added_by'] = Variable<String>(addedBy);
    }
    if (!nullToAbsent || addedAt != null) {
      map['added_at'] = Variable<DateTime>(addedAt);
    }
    return map;
  }

  RecipientEdgesCompanion toCompanion(bool nullToAbsent) {
    return RecipientEdgesCompanion(
      messageId: Value(messageId),
      recipientId: Value(recipientId),
      kind: Value(kind),
      isCloudBot: Value(isCloudBot),
      isPublic: Value(isPublic),
      notify: Value(notify),
      addedBy: addedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(addedBy),
      addedAt: addedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(addedAt),
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
      isCloudBot: serializer.fromJson<bool>(json['isCloudBot']),
      isPublic: serializer.fromJson<bool>(json['isPublic']),
      notify: serializer.fromJson<bool>(json['notify']),
      addedBy: serializer.fromJson<String?>(json['addedBy']),
      addedAt: serializer.fromJson<DateTime?>(json['addedAt']),
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
      'isCloudBot': serializer.toJson<bool>(isCloudBot),
      'isPublic': serializer.toJson<bool>(isPublic),
      'notify': serializer.toJson<bool>(notify),
      'addedBy': serializer.toJson<String?>(addedBy),
      'addedAt': serializer.toJson<DateTime?>(addedAt),
    };
  }

  RecipientEdge copyWith({
    String? messageId,
    String? recipientId,
    RecipientKind? kind,
    bool? isCloudBot,
    bool? isPublic,
    bool? notify,
    Value<String?> addedBy = const Value.absent(),
    Value<DateTime?> addedAt = const Value.absent(),
  }) => RecipientEdge(
    messageId: messageId ?? this.messageId,
    recipientId: recipientId ?? this.recipientId,
    kind: kind ?? this.kind,
    isCloudBot: isCloudBot ?? this.isCloudBot,
    isPublic: isPublic ?? this.isPublic,
    notify: notify ?? this.notify,
    addedBy: addedBy.present ? addedBy.value : this.addedBy,
    addedAt: addedAt.present ? addedAt.value : this.addedAt,
  );
  RecipientEdge copyWithCompanion(RecipientEdgesCompanion data) {
    return RecipientEdge(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      recipientId: data.recipientId.present
          ? data.recipientId.value
          : this.recipientId,
      kind: data.kind.present ? data.kind.value : this.kind,
      isCloudBot: data.isCloudBot.present
          ? data.isCloudBot.value
          : this.isCloudBot,
      isPublic: data.isPublic.present ? data.isPublic.value : this.isPublic,
      notify: data.notify.present ? data.notify.value : this.notify,
      addedBy: data.addedBy.present ? data.addedBy.value : this.addedBy,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipientEdge(')
          ..write('messageId: $messageId, ')
          ..write('recipientId: $recipientId, ')
          ..write('kind: $kind, ')
          ..write('isCloudBot: $isCloudBot, ')
          ..write('isPublic: $isPublic, ')
          ..write('notify: $notify, ')
          ..write('addedBy: $addedBy, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    messageId,
    recipientId,
    kind,
    isCloudBot,
    isPublic,
    notify,
    addedBy,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipientEdge &&
          other.messageId == this.messageId &&
          other.recipientId == this.recipientId &&
          other.kind == this.kind &&
          other.isCloudBot == this.isCloudBot &&
          other.isPublic == this.isPublic &&
          other.notify == this.notify &&
          other.addedBy == this.addedBy &&
          other.addedAt == this.addedAt);
}

class RecipientEdgesCompanion extends UpdateCompanion<RecipientEdge> {
  final Value<String> messageId;
  final Value<String> recipientId;
  final Value<RecipientKind> kind;
  final Value<bool> isCloudBot;
  final Value<bool> isPublic;
  final Value<bool> notify;
  final Value<String?> addedBy;
  final Value<DateTime?> addedAt;
  final Value<int> rowid;
  const RecipientEdgesCompanion({
    this.messageId = const Value.absent(),
    this.recipientId = const Value.absent(),
    this.kind = const Value.absent(),
    this.isCloudBot = const Value.absent(),
    this.isPublic = const Value.absent(),
    this.notify = const Value.absent(),
    this.addedBy = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipientEdgesCompanion.insert({
    required String messageId,
    required String recipientId,
    required RecipientKind kind,
    this.isCloudBot = const Value.absent(),
    this.isPublic = const Value.absent(),
    this.notify = const Value.absent(),
    this.addedBy = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       recipientId = Value(recipientId),
       kind = Value(kind);
  static Insertable<RecipientEdge> custom({
    Expression<String>? messageId,
    Expression<String>? recipientId,
    Expression<String>? kind,
    Expression<bool>? isCloudBot,
    Expression<bool>? isPublic,
    Expression<bool>? notify,
    Expression<String>? addedBy,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (recipientId != null) 'recipient_id': recipientId,
      if (kind != null) 'kind': kind,
      if (isCloudBot != null) 'is_cloud_bot': isCloudBot,
      if (isPublic != null) 'is_public': isPublic,
      if (notify != null) 'notify': notify,
      if (addedBy != null) 'added_by': addedBy,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipientEdgesCompanion copyWith({
    Value<String>? messageId,
    Value<String>? recipientId,
    Value<RecipientKind>? kind,
    Value<bool>? isCloudBot,
    Value<bool>? isPublic,
    Value<bool>? notify,
    Value<String?>? addedBy,
    Value<DateTime?>? addedAt,
    Value<int>? rowid,
  }) {
    return RecipientEdgesCompanion(
      messageId: messageId ?? this.messageId,
      recipientId: recipientId ?? this.recipientId,
      kind: kind ?? this.kind,
      isCloudBot: isCloudBot ?? this.isCloudBot,
      isPublic: isPublic ?? this.isPublic,
      notify: notify ?? this.notify,
      addedBy: addedBy ?? this.addedBy,
      addedAt: addedAt ?? this.addedAt,
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
    if (isCloudBot.present) {
      map['is_cloud_bot'] = Variable<bool>(isCloudBot.value);
    }
    if (isPublic.present) {
      map['is_public'] = Variable<bool>(isPublic.value);
    }
    if (notify.present) {
      map['notify'] = Variable<bool>(notify.value);
    }
    if (addedBy.present) {
      map['added_by'] = Variable<String>(addedBy.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
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
          ..write('isCloudBot: $isCloudBot, ')
          ..write('isPublic: $isPublic, ')
          ..write('notify: $notify, ')
          ..write('addedBy: $addedBy, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageTagsTable extends MessageTags
    with TableInfo<$MessageTagsTable, MessageTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageTagsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _addedByMeta = const VerificationMeta(
    'addedBy',
  );
  @override
  late final GeneratedColumn<String> addedBy = GeneratedColumn<String>(
    'added_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedByTagMeta = const VerificationMeta(
    'addedByTag',
  );
  @override
  late final GeneratedColumn<String> addedByTag = GeneratedColumn<String>(
    'added_by_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    name,
    createdAt,
    addedBy,
    addedByTag,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageTagRow> instance, {
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('added_by')) {
      context.handle(
        _addedByMeta,
        addedBy.isAcceptableOrUnknown(data['added_by']!, _addedByMeta),
      );
    }
    if (data.containsKey('added_by_tag')) {
      context.handle(
        _addedByTagMeta,
        addedByTag.isAcceptableOrUnknown(
          data['added_by_tag']!,
          _addedByTagMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, name};
  @override
  MessageTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageTagRow(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      addedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_by'],
      ),
      addedByTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_by_tag'],
      ),
    );
  }

  @override
  $MessageTagsTable createAlias(String alias) {
    return $MessageTagsTable(attachedDatabase, alias);
  }
}

class MessageTagRow extends DataClass implements Insertable<MessageTagRow> {
  final String messageId;
  final String name;
  final DateTime? createdAt;
  final String? addedBy;
  final String? addedByTag;
  const MessageTagRow({
    required this.messageId,
    required this.name,
    this.createdAt,
    this.addedBy,
    this.addedByTag,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || addedBy != null) {
      map['added_by'] = Variable<String>(addedBy);
    }
    if (!nullToAbsent || addedByTag != null) {
      map['added_by_tag'] = Variable<String>(addedByTag);
    }
    return map;
  }

  MessageTagsCompanion toCompanion(bool nullToAbsent) {
    return MessageTagsCompanion(
      messageId: Value(messageId),
      name: Value(name),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      addedBy: addedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(addedBy),
      addedByTag: addedByTag == null && nullToAbsent
          ? const Value.absent()
          : Value(addedByTag),
    );
  }

  factory MessageTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageTagRow(
      messageId: serializer.fromJson<String>(json['messageId']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      addedBy: serializer.fromJson<String?>(json['addedBy']),
      addedByTag: serializer.fromJson<String?>(json['addedByTag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'addedBy': serializer.toJson<String?>(addedBy),
      'addedByTag': serializer.toJson<String?>(addedByTag),
    };
  }

  MessageTagRow copyWith({
    String? messageId,
    String? name,
    Value<DateTime?> createdAt = const Value.absent(),
    Value<String?> addedBy = const Value.absent(),
    Value<String?> addedByTag = const Value.absent(),
  }) => MessageTagRow(
    messageId: messageId ?? this.messageId,
    name: name ?? this.name,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    addedBy: addedBy.present ? addedBy.value : this.addedBy,
    addedByTag: addedByTag.present ? addedByTag.value : this.addedByTag,
  );
  MessageTagRow copyWithCompanion(MessageTagsCompanion data) {
    return MessageTagRow(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      addedBy: data.addedBy.present ? data.addedBy.value : this.addedBy,
      addedByTag: data.addedByTag.present
          ? data.addedByTag.value
          : this.addedByTag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageTagRow(')
          ..write('messageId: $messageId, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('addedBy: $addedBy, ')
          ..write('addedByTag: $addedByTag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(messageId, name, createdAt, addedBy, addedByTag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageTagRow &&
          other.messageId == this.messageId &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.addedBy == this.addedBy &&
          other.addedByTag == this.addedByTag);
}

class MessageTagsCompanion extends UpdateCompanion<MessageTagRow> {
  final Value<String> messageId;
  final Value<String> name;
  final Value<DateTime?> createdAt;
  final Value<String?> addedBy;
  final Value<String?> addedByTag;
  final Value<int> rowid;
  const MessageTagsCompanion({
    this.messageId = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.addedBy = const Value.absent(),
    this.addedByTag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageTagsCompanion.insert({
    required String messageId,
    required String name,
    this.createdAt = const Value.absent(),
    this.addedBy = const Value.absent(),
    this.addedByTag = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       name = Value(name);
  static Insertable<MessageTagRow> custom({
    Expression<String>? messageId,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<String>? addedBy,
    Expression<String>? addedByTag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (addedBy != null) 'added_by': addedBy,
      if (addedByTag != null) 'added_by_tag': addedByTag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageTagsCompanion copyWith({
    Value<String>? messageId,
    Value<String>? name,
    Value<DateTime?>? createdAt,
    Value<String?>? addedBy,
    Value<String?>? addedByTag,
    Value<int>? rowid,
  }) {
    return MessageTagsCompanion(
      messageId: messageId ?? this.messageId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      addedBy: addedBy ?? this.addedBy,
      addedByTag: addedByTag ?? this.addedByTag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (addedBy.present) {
      map['added_by'] = Variable<String>(addedBy.value);
    }
    if (addedByTag.present) {
      map['added_by_tag'] = Variable<String>(addedByTag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageTagsCompanion(')
          ..write('messageId: $messageId, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('addedBy: $addedBy, ')
          ..write('addedByTag: $addedByTag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ParticipantProfilesTable extends ParticipantProfiles
    with TableInfo<$ParticipantProfilesTable, ParticipantProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParticipantProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userTagMeta = const VerificationMeta(
    'userTag',
  );
  @override
  late final GeneratedColumn<String> userTag = GeneratedColumn<String>(
    'user_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isBotMeta = const VerificationMeta('isBot');
  @override
  late final GeneratedColumn<bool> isBot = GeneratedColumn<bool>(
    'is_bot',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_bot" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [uid, userTag, displayName, isBot];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'participant_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ParticipantProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('user_tag')) {
      context.handle(
        _userTagMeta,
        userTag.isAcceptableOrUnknown(data['user_tag']!, _userTagMeta),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('is_bot')) {
      context.handle(
        _isBotMeta,
        isBot.isAcceptableOrUnknown(data['is_bot']!, _isBotMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uid};
  @override
  ParticipantProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParticipantProfileRow(
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      userTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_tag'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      isBot: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_bot'],
      )!,
    );
  }

  @override
  $ParticipantProfilesTable createAlias(String alias) {
    return $ParticipantProfilesTable(attachedDatabase, alias);
  }
}

class ParticipantProfileRow extends DataClass
    implements Insertable<ParticipantProfileRow> {
  final String uid;
  final String? userTag;
  final String? displayName;
  final bool isBot;
  const ParticipantProfileRow({
    required this.uid,
    this.userTag,
    this.displayName,
    required this.isBot,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uid'] = Variable<String>(uid);
    if (!nullToAbsent || userTag != null) {
      map['user_tag'] = Variable<String>(userTag);
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['is_bot'] = Variable<bool>(isBot);
    return map;
  }

  ParticipantProfilesCompanion toCompanion(bool nullToAbsent) {
    return ParticipantProfilesCompanion(
      uid: Value(uid),
      userTag: userTag == null && nullToAbsent
          ? const Value.absent()
          : Value(userTag),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      isBot: Value(isBot),
    );
  }

  factory ParticipantProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParticipantProfileRow(
      uid: serializer.fromJson<String>(json['uid']),
      userTag: serializer.fromJson<String?>(json['userTag']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      isBot: serializer.fromJson<bool>(json['isBot']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uid': serializer.toJson<String>(uid),
      'userTag': serializer.toJson<String?>(userTag),
      'displayName': serializer.toJson<String?>(displayName),
      'isBot': serializer.toJson<bool>(isBot),
    };
  }

  ParticipantProfileRow copyWith({
    String? uid,
    Value<String?> userTag = const Value.absent(),
    Value<String?> displayName = const Value.absent(),
    bool? isBot,
  }) => ParticipantProfileRow(
    uid: uid ?? this.uid,
    userTag: userTag.present ? userTag.value : this.userTag,
    displayName: displayName.present ? displayName.value : this.displayName,
    isBot: isBot ?? this.isBot,
  );
  ParticipantProfileRow copyWithCompanion(ParticipantProfilesCompanion data) {
    return ParticipantProfileRow(
      uid: data.uid.present ? data.uid.value : this.uid,
      userTag: data.userTag.present ? data.userTag.value : this.userTag,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      isBot: data.isBot.present ? data.isBot.value : this.isBot,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParticipantProfileRow(')
          ..write('uid: $uid, ')
          ..write('userTag: $userTag, ')
          ..write('displayName: $displayName, ')
          ..write('isBot: $isBot')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uid, userTag, displayName, isBot);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParticipantProfileRow &&
          other.uid == this.uid &&
          other.userTag == this.userTag &&
          other.displayName == this.displayName &&
          other.isBot == this.isBot);
}

class ParticipantProfilesCompanion
    extends UpdateCompanion<ParticipantProfileRow> {
  final Value<String> uid;
  final Value<String?> userTag;
  final Value<String?> displayName;
  final Value<bool> isBot;
  final Value<int> rowid;
  const ParticipantProfilesCompanion({
    this.uid = const Value.absent(),
    this.userTag = const Value.absent(),
    this.displayName = const Value.absent(),
    this.isBot = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ParticipantProfilesCompanion.insert({
    required String uid,
    this.userTag = const Value.absent(),
    this.displayName = const Value.absent(),
    this.isBot = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uid = Value(uid);
  static Insertable<ParticipantProfileRow> custom({
    Expression<String>? uid,
    Expression<String>? userTag,
    Expression<String>? displayName,
    Expression<bool>? isBot,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uid != null) 'uid': uid,
      if (userTag != null) 'user_tag': userTag,
      if (displayName != null) 'display_name': displayName,
      if (isBot != null) 'is_bot': isBot,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ParticipantProfilesCompanion copyWith({
    Value<String>? uid,
    Value<String?>? userTag,
    Value<String?>? displayName,
    Value<bool>? isBot,
    Value<int>? rowid,
  }) {
    return ParticipantProfilesCompanion(
      uid: uid ?? this.uid,
      userTag: userTag ?? this.userTag,
      displayName: displayName ?? this.displayName,
      isBot: isBot ?? this.isBot,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (userTag.present) {
      map['user_tag'] = Variable<String>(userTag.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (isBot.present) {
      map['is_bot'] = Variable<bool>(isBot.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParticipantProfilesCompanion(')
          ..write('uid: $uid, ')
          ..write('userTag: $userTag, ')
          ..write('displayName: $displayName, ')
          ..write('isBot: $isBot, ')
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
  static const VerificationMeta _cwdMeta = const VerificationMeta('cwd');
  @override
  late final GeneratedColumn<String> cwd = GeneratedColumn<String>(
    'cwd',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    anchorMessageId,
    width,
    scrollOffset,
    cwd,
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
    if (data.containsKey('cwd')) {
      context.handle(
        _cwdMeta,
        cwd.isAcceptableOrUnknown(data['cwd']!, _cwdMeta),
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
      cwd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cwd'],
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

  /// Working-directory tag for adapters that bind a cwd (e.g. Cursor local).
  /// Not message state — passed on each bot invoke for this column.
  final String? cwd;
  const ColumnRow({
    required this.id,
    this.anchorMessageId,
    this.width,
    this.scrollOffset,
    this.cwd,
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
    if (!nullToAbsent || cwd != null) {
      map['cwd'] = Variable<String>(cwd);
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
      cwd: cwd == null && nullToAbsent ? const Value.absent() : Value(cwd),
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
      cwd: serializer.fromJson<String?>(json['cwd']),
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
      'cwd': serializer.toJson<String?>(cwd),
    };
  }

  ColumnRow copyWith({
    String? id,
    Value<String?> anchorMessageId = const Value.absent(),
    Value<double?> width = const Value.absent(),
    Value<double?> scrollOffset = const Value.absent(),
    Value<String?> cwd = const Value.absent(),
  }) => ColumnRow(
    id: id ?? this.id,
    anchorMessageId: anchorMessageId.present
        ? anchorMessageId.value
        : this.anchorMessageId,
    width: width.present ? width.value : this.width,
    scrollOffset: scrollOffset.present ? scrollOffset.value : this.scrollOffset,
    cwd: cwd.present ? cwd.value : this.cwd,
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
      cwd: data.cwd.present ? data.cwd.value : this.cwd,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ColumnRow(')
          ..write('id: $id, ')
          ..write('anchorMessageId: $anchorMessageId, ')
          ..write('width: $width, ')
          ..write('scrollOffset: $scrollOffset, ')
          ..write('cwd: $cwd')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, anchorMessageId, width, scrollOffset, cwd);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ColumnRow &&
          other.id == this.id &&
          other.anchorMessageId == this.anchorMessageId &&
          other.width == this.width &&
          other.scrollOffset == this.scrollOffset &&
          other.cwd == this.cwd);
}

class ColumnsCompanion extends UpdateCompanion<ColumnRow> {
  final Value<String> id;
  final Value<String?> anchorMessageId;
  final Value<double?> width;
  final Value<double?> scrollOffset;
  final Value<String?> cwd;
  final Value<int> rowid;
  const ColumnsCompanion({
    this.id = const Value.absent(),
    this.anchorMessageId = const Value.absent(),
    this.width = const Value.absent(),
    this.scrollOffset = const Value.absent(),
    this.cwd = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ColumnsCompanion.insert({
    required String id,
    this.anchorMessageId = const Value.absent(),
    this.width = const Value.absent(),
    this.scrollOffset = const Value.absent(),
    this.cwd = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<ColumnRow> custom({
    Expression<String>? id,
    Expression<String>? anchorMessageId,
    Expression<double>? width,
    Expression<double>? scrollOffset,
    Expression<String>? cwd,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (anchorMessageId != null) 'anchor_message_id': anchorMessageId,
      if (width != null) 'width': width,
      if (scrollOffset != null) 'scroll_offset': scrollOffset,
      if (cwd != null) 'cwd': cwd,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ColumnsCompanion copyWith({
    Value<String>? id,
    Value<String?>? anchorMessageId,
    Value<double?>? width,
    Value<double?>? scrollOffset,
    Value<String?>? cwd,
    Value<int>? rowid,
  }) {
    return ColumnsCompanion(
      id: id ?? this.id,
      anchorMessageId: anchorMessageId ?? this.anchorMessageId,
      width: width ?? this.width,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      cwd: cwd ?? this.cwd,
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
    if (cwd.present) {
      map['cwd'] = Variable<String>(cwd.value);
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
          ..write('cwd: $cwd, ')
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
  late final $MessageTagsTable messageTags = $MessageTagsTable(this);
  late final $ParticipantProfilesTable participantProfiles =
      $ParticipantProfilesTable(this);
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
    messageTags,
    participantProfiles,
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
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('message_tags', kind: UpdateKind.delete)],
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
      Value<String?> cloudMessageId,
      Value<CloudSyncStatus> syncStatus,
      Value<String?> syncError,
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
      Value<String?> cloudMessageId,
      Value<CloudSyncStatus> syncStatus,
      Value<String?> syncError,
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

  static MultiTypedResultKey<$MessageTagsTable, List<MessageTagRow>>
  _messageTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.messageTags,
    aliasName: 'messages__id__message_tags__message_id',
  );

  $$MessageTagsTableProcessedTableManager get messageTagsRefs {
    final manager = $$MessageTagsTableTableManager(
      $_db,
      $_db.messageTags,
    ).filter((f) => f.messageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messageTagsRefsTable($_db));
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

  ColumnFilters<String> get cloudMessageId => $composableBuilder(
    column: $table.cloudMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CloudSyncStatus, CloudSyncStatus, String>
  get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
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

  Expression<bool> messageTagsRefs(
    Expression<bool> Function($$MessageTagsTableFilterComposer f) f,
  ) {
    final $$MessageTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messageTags,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageTagsTableFilterComposer(
            $db: $db,
            $table: $db.messageTags,
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

  ColumnOrderings<String> get cloudMessageId => $composableBuilder(
    column: $table.cloudMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
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

  GeneratedColumn<String> get cloudMessageId => $composableBuilder(
    column: $table.cloudMessageId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<CloudSyncStatus, String> get syncStatus =>
      $composableBuilder(
        column: $table.syncStatus,
        builder: (column) => column,
      );

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

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

  Expression<T> messageTagsRefs<T extends Object>(
    Expression<T> Function($$MessageTagsTableAnnotationComposer a) f,
  ) {
    final $$MessageTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messageTags,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.messageTags,
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
            bool messageTagsRefs,
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
                Value<String?> cloudMessageId = const Value.absent(),
                Value<CloudSyncStatus> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                role: role,
                authorId: authorId,
                content: content,
                gitCommit: gitCommit,
                createdAt: createdAt,
                cloudMessageId: cloudMessageId,
                syncStatus: syncStatus,
                syncError: syncError,
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
                Value<String?> cloudMessageId = const Value.absent(),
                Value<CloudSyncStatus> syncStatus = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                role: role,
                authorId: authorId,
                content: content,
                gitCommit: gitCommit,
                createdAt: createdAt,
                cloudMessageId: cloudMessageId,
                syncStatus: syncStatus,
                syncError: syncError,
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
                messageTagsRefs = false,
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
                    if (messageTagsRefs) db.messageTags,
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
                      if (messageTagsRefs)
                        await $_getPrefetchedData<
                          MessageRow,
                          $MessagesTable,
                          MessageTagRow
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._messageTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).messageTagsRefs,
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
        bool messageTagsRefs,
        bool columnsRefs,
        bool branchPointersAsParent,
        bool branchPointersAsChild,
      })
    >;
typedef $$ReplyEdgesTableCreateCompanionBuilder =
    ReplyEdgesCompanion Function({
      required String parentId,
      required String childId,
      Value<bool> hidden,
      Value<int> rowid,
    });
typedef $$ReplyEdgesTableUpdateCompanionBuilder =
    ReplyEdgesCompanion Function({
      Value<String> parentId,
      Value<String> childId,
      Value<bool> hidden,
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
  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

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
  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

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
  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

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
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReplyEdgesCompanion(
                parentId: parentId,
                childId: childId,
                hidden: hidden,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String parentId,
                required String childId,
                Value<bool> hidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReplyEdgesCompanion.insert(
                parentId: parentId,
                childId: childId,
                hidden: hidden,
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
      Value<bool> isCloudBot,
      Value<bool> isPublic,
      Value<bool> notify,
      Value<String?> addedBy,
      Value<DateTime?> addedAt,
      Value<int> rowid,
    });
typedef $$RecipientEdgesTableUpdateCompanionBuilder =
    RecipientEdgesCompanion Function({
      Value<String> messageId,
      Value<String> recipientId,
      Value<RecipientKind> kind,
      Value<bool> isCloudBot,
      Value<bool> isPublic,
      Value<bool> notify,
      Value<String?> addedBy,
      Value<DateTime?> addedAt,
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

  ColumnFilters<bool> get isCloudBot => $composableBuilder(
    column: $table.isCloudBot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPublic => $composableBuilder(
    column: $table.isPublic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notify => $composableBuilder(
    column: $table.notify,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedBy => $composableBuilder(
    column: $table.addedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
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

  ColumnOrderings<bool> get isCloudBot => $composableBuilder(
    column: $table.isCloudBot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPublic => $composableBuilder(
    column: $table.isPublic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notify => $composableBuilder(
    column: $table.notify,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedBy => $composableBuilder(
    column: $table.addedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
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

  GeneratedColumn<bool> get isCloudBot => $composableBuilder(
    column: $table.isCloudBot,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPublic =>
      $composableBuilder(column: $table.isPublic, builder: (column) => column);

  GeneratedColumn<bool> get notify =>
      $composableBuilder(column: $table.notify, builder: (column) => column);

  GeneratedColumn<String> get addedBy =>
      $composableBuilder(column: $table.addedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

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
                Value<bool> isCloudBot = const Value.absent(),
                Value<bool> isPublic = const Value.absent(),
                Value<bool> notify = const Value.absent(),
                Value<String?> addedBy = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipientEdgesCompanion(
                messageId: messageId,
                recipientId: recipientId,
                kind: kind,
                isCloudBot: isCloudBot,
                isPublic: isPublic,
                notify: notify,
                addedBy: addedBy,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String recipientId,
                required RecipientKind kind,
                Value<bool> isCloudBot = const Value.absent(),
                Value<bool> isPublic = const Value.absent(),
                Value<bool> notify = const Value.absent(),
                Value<String?> addedBy = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipientEdgesCompanion.insert(
                messageId: messageId,
                recipientId: recipientId,
                kind: kind,
                isCloudBot: isCloudBot,
                isPublic: isPublic,
                notify: notify,
                addedBy: addedBy,
                addedAt: addedAt,
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
typedef $$MessageTagsTableCreateCompanionBuilder =
    MessageTagsCompanion Function({
      required String messageId,
      required String name,
      Value<DateTime?> createdAt,
      Value<String?> addedBy,
      Value<String?> addedByTag,
      Value<int> rowid,
    });
typedef $$MessageTagsTableUpdateCompanionBuilder =
    MessageTagsCompanion Function({
      Value<String> messageId,
      Value<String> name,
      Value<DateTime?> createdAt,
      Value<String?> addedBy,
      Value<String?> addedByTag,
      Value<int> rowid,
    });

final class $$MessageTagsTableReferences
    extends BaseReferences<_$AppDatabase, $MessageTagsTable, MessageTagRow> {
  $$MessageTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MessagesTable _messageIdTable(_$AppDatabase db) =>
      db.messages.createAlias('message_tags__message_id__messages__id');

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

class $$MessageTagsTableFilterComposer
    extends Composer<_$AppDatabase, $MessageTagsTable> {
  $$MessageTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedBy => $composableBuilder(
    column: $table.addedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedByTag => $composableBuilder(
    column: $table.addedByTag,
    builder: (column) => ColumnFilters(column),
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

class $$MessageTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageTagsTable> {
  $$MessageTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedBy => $composableBuilder(
    column: $table.addedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedByTag => $composableBuilder(
    column: $table.addedByTag,
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

class $$MessageTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageTagsTable> {
  $$MessageTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get addedBy =>
      $composableBuilder(column: $table.addedBy, builder: (column) => column);

  GeneratedColumn<String> get addedByTag => $composableBuilder(
    column: $table.addedByTag,
    builder: (column) => column,
  );

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

class $$MessageTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageTagsTable,
          MessageTagRow,
          $$MessageTagsTableFilterComposer,
          $$MessageTagsTableOrderingComposer,
          $$MessageTagsTableAnnotationComposer,
          $$MessageTagsTableCreateCompanionBuilder,
          $$MessageTagsTableUpdateCompanionBuilder,
          (MessageTagRow, $$MessageTagsTableReferences),
          MessageTagRow,
          PrefetchHooks Function({bool messageId})
        > {
  $$MessageTagsTableTableManager(_$AppDatabase db, $MessageTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<String?> addedBy = const Value.absent(),
                Value<String?> addedByTag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageTagsCompanion(
                messageId: messageId,
                name: name,
                createdAt: createdAt,
                addedBy: addedBy,
                addedByTag: addedByTag,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String name,
                Value<DateTime?> createdAt = const Value.absent(),
                Value<String?> addedBy = const Value.absent(),
                Value<String?> addedByTag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageTagsCompanion.insert(
                messageId: messageId,
                name: name,
                createdAt: createdAt,
                addedBy: addedBy,
                addedByTag: addedByTag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessageTagsTableReferences(db, table, e),
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
                                referencedTable: $$MessageTagsTableReferences
                                    ._messageIdTable(db),
                                referencedColumn: $$MessageTagsTableReferences
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

typedef $$MessageTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageTagsTable,
      MessageTagRow,
      $$MessageTagsTableFilterComposer,
      $$MessageTagsTableOrderingComposer,
      $$MessageTagsTableAnnotationComposer,
      $$MessageTagsTableCreateCompanionBuilder,
      $$MessageTagsTableUpdateCompanionBuilder,
      (MessageTagRow, $$MessageTagsTableReferences),
      MessageTagRow,
      PrefetchHooks Function({bool messageId})
    >;
typedef $$ParticipantProfilesTableCreateCompanionBuilder =
    ParticipantProfilesCompanion Function({
      required String uid,
      Value<String?> userTag,
      Value<String?> displayName,
      Value<bool> isBot,
      Value<int> rowid,
    });
typedef $$ParticipantProfilesTableUpdateCompanionBuilder =
    ParticipantProfilesCompanion Function({
      Value<String> uid,
      Value<String?> userTag,
      Value<String?> displayName,
      Value<bool> isBot,
      Value<int> rowid,
    });

class $$ParticipantProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ParticipantProfilesTable> {
  $$ParticipantProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userTag => $composableBuilder(
    column: $table.userTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBot => $composableBuilder(
    column: $table.isBot,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ParticipantProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ParticipantProfilesTable> {
  $$ParticipantProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userTag => $composableBuilder(
    column: $table.userTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBot => $composableBuilder(
    column: $table.isBot,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ParticipantProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParticipantProfilesTable> {
  $$ParticipantProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get userTag =>
      $composableBuilder(column: $table.userTag, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBot =>
      $composableBuilder(column: $table.isBot, builder: (column) => column);
}

class $$ParticipantProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParticipantProfilesTable,
          ParticipantProfileRow,
          $$ParticipantProfilesTableFilterComposer,
          $$ParticipantProfilesTableOrderingComposer,
          $$ParticipantProfilesTableAnnotationComposer,
          $$ParticipantProfilesTableCreateCompanionBuilder,
          $$ParticipantProfilesTableUpdateCompanionBuilder,
          (
            ParticipantProfileRow,
            BaseReferences<
              _$AppDatabase,
              $ParticipantProfilesTable,
              ParticipantProfileRow
            >,
          ),
          ParticipantProfileRow,
          PrefetchHooks Function()
        > {
  $$ParticipantProfilesTableTableManager(
    _$AppDatabase db,
    $ParticipantProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParticipantProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParticipantProfilesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ParticipantProfilesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> uid = const Value.absent(),
                Value<String?> userTag = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<bool> isBot = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ParticipantProfilesCompanion(
                uid: uid,
                userTag: userTag,
                displayName: displayName,
                isBot: isBot,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uid,
                Value<String?> userTag = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<bool> isBot = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ParticipantProfilesCompanion.insert(
                uid: uid,
                userTag: userTag,
                displayName: displayName,
                isBot: isBot,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ParticipantProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParticipantProfilesTable,
      ParticipantProfileRow,
      $$ParticipantProfilesTableFilterComposer,
      $$ParticipantProfilesTableOrderingComposer,
      $$ParticipantProfilesTableAnnotationComposer,
      $$ParticipantProfilesTableCreateCompanionBuilder,
      $$ParticipantProfilesTableUpdateCompanionBuilder,
      (
        ParticipantProfileRow,
        BaseReferences<
          _$AppDatabase,
          $ParticipantProfilesTable,
          ParticipantProfileRow
        >,
      ),
      ParticipantProfileRow,
      PrefetchHooks Function()
    >;
typedef $$ColumnsTableCreateCompanionBuilder =
    ColumnsCompanion Function({
      required String id,
      Value<String?> anchorMessageId,
      Value<double?> width,
      Value<double?> scrollOffset,
      Value<String?> cwd,
      Value<int> rowid,
    });
typedef $$ColumnsTableUpdateCompanionBuilder =
    ColumnsCompanion Function({
      Value<String> id,
      Value<String?> anchorMessageId,
      Value<double?> width,
      Value<double?> scrollOffset,
      Value<String?> cwd,
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

  ColumnFilters<String> get cwd => $composableBuilder(
    column: $table.cwd,
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

  ColumnOrderings<String> get cwd => $composableBuilder(
    column: $table.cwd,
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

  GeneratedColumn<String> get cwd =>
      $composableBuilder(column: $table.cwd, builder: (column) => column);

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
                Value<String?> cwd = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ColumnsCompanion(
                id: id,
                anchorMessageId: anchorMessageId,
                width: width,
                scrollOffset: scrollOffset,
                cwd: cwd,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> anchorMessageId = const Value.absent(),
                Value<double?> width = const Value.absent(),
                Value<double?> scrollOffset = const Value.absent(),
                Value<String?> cwd = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ColumnsCompanion.insert(
                id: id,
                anchorMessageId: anchorMessageId,
                width: width,
                scrollOffset: scrollOffset,
                cwd: cwd,
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
  $$MessageTagsTableTableManager get messageTags =>
      $$MessageTagsTableTableManager(_db, _db.messageTags);
  $$ParticipantProfilesTableTableManager get participantProfiles =>
      $$ParticipantProfilesTableTableManager(_db, _db.participantProfiles);
  $$ColumnsTableTableManager get columns =>
      $$ColumnsTableTableManager(_db, _db.columns);
  $$ColumnBranchPointersTableTableManager get columnBranchPointers =>
      $$ColumnBranchPointersTableTableManager(_db, _db.columnBranchPointers);
}
