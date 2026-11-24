// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts
    with TableInfo<$AccountsTable, AccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _institutionMeta = const VerificationMeta(
    'institution',
  );
  @override
  late final GeneratedColumn<String> institution = GeneratedColumn<String>(
    'institution',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _last4Meta = const VerificationMeta('last4');
  @override
  late final GeneratedColumn<String> last4 = GeneratedColumn<String>(
    'last4',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('AED'),
  );
  static const VerificationMeta _creditLimitMinorMeta = const VerificationMeta(
    'creditLimitMinor',
  );
  @override
  late final GeneratedColumn<int> creditLimitMinor = GeneratedColumn<int>(
    'credit_limit_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statementDayMeta = const VerificationMeta(
    'statementDay',
  );
  @override
  late final GeneratedColumn<int> statementDay = GeneratedColumn<int>(
    'statement_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDayMeta = const VerificationMeta('dueDay');
  @override
  late final GeneratedColumn<int> dueDay = GeneratedColumn<int>(
    'due_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _balanceAnchorMinorMeta =
      const VerificationMeta('balanceAnchorMinor');
  @override
  late final GeneratedColumn<int> balanceAnchorMinor = GeneratedColumn<int>(
    'balance_anchor_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _balanceAnchorAtMeta = const VerificationMeta(
    'balanceAnchorAt',
  );
  @override
  late final GeneratedColumn<DateTime> balanceAnchorAt =
      GeneratedColumn<DateTime>(
        'balance_anchor_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    name,
    institution,
    last4,
    currency,
    creditLimitMinor,
    statementDay,
    dueDay,
    balanceAnchorMinor,
    balanceAnchorAt,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('institution')) {
      context.handle(
        _institutionMeta,
        institution.isAcceptableOrUnknown(
          data['institution']!,
          _institutionMeta,
        ),
      );
    }
    if (data.containsKey('last4')) {
      context.handle(
        _last4Meta,
        last4.isAcceptableOrUnknown(data['last4']!, _last4Meta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('credit_limit_minor')) {
      context.handle(
        _creditLimitMinorMeta,
        creditLimitMinor.isAcceptableOrUnknown(
          data['credit_limit_minor']!,
          _creditLimitMinorMeta,
        ),
      );
    }
    if (data.containsKey('statement_day')) {
      context.handle(
        _statementDayMeta,
        statementDay.isAcceptableOrUnknown(
          data['statement_day']!,
          _statementDayMeta,
        ),
      );
    }
    if (data.containsKey('due_day')) {
      context.handle(
        _dueDayMeta,
        dueDay.isAcceptableOrUnknown(data['due_day']!, _dueDayMeta),
      );
    }
    if (data.containsKey('balance_anchor_minor')) {
      context.handle(
        _balanceAnchorMinorMeta,
        balanceAnchorMinor.isAcceptableOrUnknown(
          data['balance_anchor_minor']!,
          _balanceAnchorMinorMeta,
        ),
      );
    }
    if (data.containsKey('balance_anchor_at')) {
      context.handle(
        _balanceAnchorAtMeta,
        balanceAnchorAt.isAcceptableOrUnknown(
          data['balance_anchor_at']!,
          _balanceAnchorAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      institution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution'],
      ),
      last4: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last4'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      creditLimitMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credit_limit_minor'],
      ),
      statementDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}statement_day'],
      ),
      dueDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_day'],
      ),
      balanceAnchorMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance_anchor_minor'],
      ),
      balanceAnchorAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}balance_anchor_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class AccountRow extends DataClass implements Insertable<AccountRow> {
  final String id;

  /// bank | credit_card | wallet | cash
  final String type;
  final String name;
  final String? institution;
  final String? last4;
  final String currency;
  final int? creditLimitMinor;
  final int? statementDay;
  final int? dueDay;

  /// A balance the user (or a statement) vouches for; the live balance is
  /// this plus the transactions after it. For cards it is the amount owed.
  final int? balanceAnchorMinor;
  final DateTime? balanceAnchorAt;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const AccountRow({
    required this.id,
    required this.type,
    required this.name,
    this.institution,
    this.last4,
    required this.currency,
    this.creditLimitMinor,
    this.statementDay,
    this.dueDay,
    this.balanceAnchorMinor,
    this.balanceAnchorAt,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || institution != null) {
      map['institution'] = Variable<String>(institution);
    }
    if (!nullToAbsent || last4 != null) {
      map['last4'] = Variable<String>(last4);
    }
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || creditLimitMinor != null) {
      map['credit_limit_minor'] = Variable<int>(creditLimitMinor);
    }
    if (!nullToAbsent || statementDay != null) {
      map['statement_day'] = Variable<int>(statementDay);
    }
    if (!nullToAbsent || dueDay != null) {
      map['due_day'] = Variable<int>(dueDay);
    }
    if (!nullToAbsent || balanceAnchorMinor != null) {
      map['balance_anchor_minor'] = Variable<int>(balanceAnchorMinor);
    }
    if (!nullToAbsent || balanceAnchorAt != null) {
      map['balance_anchor_at'] = Variable<DateTime>(balanceAnchorAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      type: Value(type),
      name: Value(name),
      institution: institution == null && nullToAbsent
          ? const Value.absent()
          : Value(institution),
      last4: last4 == null && nullToAbsent
          ? const Value.absent()
          : Value(last4),
      currency: Value(currency),
      creditLimitMinor: creditLimitMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(creditLimitMinor),
      statementDay: statementDay == null && nullToAbsent
          ? const Value.absent()
          : Value(statementDay),
      dueDay: dueDay == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDay),
      balanceAnchorMinor: balanceAnchorMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(balanceAnchorMinor),
      balanceAnchorAt: balanceAnchorAt == null && nullToAbsent
          ? const Value.absent()
          : Value(balanceAnchorAt),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory AccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountRow(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      name: serializer.fromJson<String>(json['name']),
      institution: serializer.fromJson<String?>(json['institution']),
      last4: serializer.fromJson<String?>(json['last4']),
      currency: serializer.fromJson<String>(json['currency']),
      creditLimitMinor: serializer.fromJson<int?>(json['creditLimitMinor']),
      statementDay: serializer.fromJson<int?>(json['statementDay']),
      dueDay: serializer.fromJson<int?>(json['dueDay']),
      balanceAnchorMinor: serializer.fromJson<int?>(json['balanceAnchorMinor']),
      balanceAnchorAt: serializer.fromJson<DateTime?>(json['balanceAnchorAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'name': serializer.toJson<String>(name),
      'institution': serializer.toJson<String?>(institution),
      'last4': serializer.toJson<String?>(last4),
      'currency': serializer.toJson<String>(currency),
      'creditLimitMinor': serializer.toJson<int?>(creditLimitMinor),
      'statementDay': serializer.toJson<int?>(statementDay),
      'dueDay': serializer.toJson<int?>(dueDay),
      'balanceAnchorMinor': serializer.toJson<int?>(balanceAnchorMinor),
      'balanceAnchorAt': serializer.toJson<DateTime?>(balanceAnchorAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  AccountRow copyWith({
    String? id,
    String? type,
    String? name,
    Value<String?> institution = const Value.absent(),
    Value<String?> last4 = const Value.absent(),
    String? currency,
    Value<int?> creditLimitMinor = const Value.absent(),
    Value<int?> statementDay = const Value.absent(),
    Value<int?> dueDay = const Value.absent(),
    Value<int?> balanceAnchorMinor = const Value.absent(),
    Value<DateTime?> balanceAnchorAt = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => AccountRow(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name ?? this.name,
    institution: institution.present ? institution.value : this.institution,
    last4: last4.present ? last4.value : this.last4,
    currency: currency ?? this.currency,
    creditLimitMinor: creditLimitMinor.present
        ? creditLimitMinor.value
        : this.creditLimitMinor,
    statementDay: statementDay.present ? statementDay.value : this.statementDay,
    dueDay: dueDay.present ? dueDay.value : this.dueDay,
    balanceAnchorMinor: balanceAnchorMinor.present
        ? balanceAnchorMinor.value
        : this.balanceAnchorMinor,
    balanceAnchorAt: balanceAnchorAt.present
        ? balanceAnchorAt.value
        : this.balanceAnchorAt,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  AccountRow copyWithCompanion(AccountsCompanion data) {
    return AccountRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      institution: data.institution.present
          ? data.institution.value
          : this.institution,
      last4: data.last4.present ? data.last4.value : this.last4,
      currency: data.currency.present ? data.currency.value : this.currency,
      creditLimitMinor: data.creditLimitMinor.present
          ? data.creditLimitMinor.value
          : this.creditLimitMinor,
      statementDay: data.statementDay.present
          ? data.statementDay.value
          : this.statementDay,
      dueDay: data.dueDay.present ? data.dueDay.value : this.dueDay,
      balanceAnchorMinor: data.balanceAnchorMinor.present
          ? data.balanceAnchorMinor.value
          : this.balanceAnchorMinor,
      balanceAnchorAt: data.balanceAnchorAt.present
          ? data.balanceAnchorAt.value
          : this.balanceAnchorAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('institution: $institution, ')
          ..write('last4: $last4, ')
          ..write('currency: $currency, ')
          ..write('creditLimitMinor: $creditLimitMinor, ')
          ..write('statementDay: $statementDay, ')
          ..write('dueDay: $dueDay, ')
          ..write('balanceAnchorMinor: $balanceAnchorMinor, ')
          ..write('balanceAnchorAt: $balanceAnchorAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    name,
    institution,
    last4,
    currency,
    creditLimitMinor,
    statementDay,
    dueDay,
    balanceAnchorMinor,
    balanceAnchorAt,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.institution == this.institution &&
          other.last4 == this.last4 &&
          other.currency == this.currency &&
          other.creditLimitMinor == this.creditLimitMinor &&
          other.statementDay == this.statementDay &&
          other.dueDay == this.dueDay &&
          other.balanceAnchorMinor == this.balanceAnchorMinor &&
          other.balanceAnchorAt == this.balanceAnchorAt &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class AccountsCompanion extends UpdateCompanion<AccountRow> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> name;
  final Value<String?> institution;
  final Value<String?> last4;
  final Value<String> currency;
  final Value<int?> creditLimitMinor;
  final Value<int?> statementDay;
  final Value<int?> dueDay;
  final Value<int?> balanceAnchorMinor;
  final Value<DateTime?> balanceAnchorAt;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.institution = const Value.absent(),
    this.last4 = const Value.absent(),
    this.currency = const Value.absent(),
    this.creditLimitMinor = const Value.absent(),
    this.statementDay = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.balanceAnchorMinor = const Value.absent(),
    this.balanceAnchorAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required String type,
    required String name,
    this.institution = const Value.absent(),
    this.last4 = const Value.absent(),
    this.currency = const Value.absent(),
    this.creditLimitMinor = const Value.absent(),
    this.statementDay = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.balanceAnchorMinor = const Value.absent(),
    this.balanceAnchorAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       name = Value(name);
  static Insertable<AccountRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? name,
    Expression<String>? institution,
    Expression<String>? last4,
    Expression<String>? currency,
    Expression<int>? creditLimitMinor,
    Expression<int>? statementDay,
    Expression<int>? dueDay,
    Expression<int>? balanceAnchorMinor,
    Expression<DateTime>? balanceAnchorAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (institution != null) 'institution': institution,
      if (last4 != null) 'last4': last4,
      if (currency != null) 'currency': currency,
      if (creditLimitMinor != null) 'credit_limit_minor': creditLimitMinor,
      if (statementDay != null) 'statement_day': statementDay,
      if (dueDay != null) 'due_day': dueDay,
      if (balanceAnchorMinor != null)
        'balance_anchor_minor': balanceAnchorMinor,
      if (balanceAnchorAt != null) 'balance_anchor_at': balanceAnchorAt,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? name,
    Value<String?>? institution,
    Value<String?>? last4,
    Value<String>? currency,
    Value<int?>? creditLimitMinor,
    Value<int?>? statementDay,
    Value<int?>? dueDay,
    Value<int?>? balanceAnchorMinor,
    Value<DateTime?>? balanceAnchorAt,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      institution: institution ?? this.institution,
      last4: last4 ?? this.last4,
      currency: currency ?? this.currency,
      creditLimitMinor: creditLimitMinor ?? this.creditLimitMinor,
      statementDay: statementDay ?? this.statementDay,
      dueDay: dueDay ?? this.dueDay,
      balanceAnchorMinor: balanceAnchorMinor ?? this.balanceAnchorMinor,
      balanceAnchorAt: balanceAnchorAt ?? this.balanceAnchorAt,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (institution.present) {
      map['institution'] = Variable<String>(institution.value);
    }
    if (last4.present) {
      map['last4'] = Variable<String>(last4.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (creditLimitMinor.present) {
      map['credit_limit_minor'] = Variable<int>(creditLimitMinor.value);
    }
    if (statementDay.present) {
      map['statement_day'] = Variable<int>(statementDay.value);
    }
    if (dueDay.present) {
      map['due_day'] = Variable<int>(dueDay.value);
    }
    if (balanceAnchorMinor.present) {
      map['balance_anchor_minor'] = Variable<int>(balanceAnchorMinor.value);
    }
    if (balanceAnchorAt.present) {
      map['balance_anchor_at'] = Variable<DateTime>(balanceAnchorAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('institution: $institution, ')
          ..write('last4: $last4, ')
          ..write('currency: $currency, ')
          ..write('creditLimitMinor: $creditLimitMinor, ')
          ..write('statementDay: $statementDay, ')
          ..write('dueDay: $dueDay, ')
          ..write('balanceAnchorMinor: $balanceAnchorMinor, ')
          ..write('balanceAnchorAt: $balanceAnchorAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogCardsTable extends CatalogCards
    with TableInfo<$CatalogCardsTable, CatalogCardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _issuerMeta = const VerificationMeta('issuer');
  @override
  late final GeneratedColumn<String> issuer = GeneratedColumn<String>(
    'issuer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _networkMeta = const VerificationMeta(
    'network',
  );
  @override
  late final GeneratedColumn<String> network = GeneratedColumn<String>(
    'network',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annualFeeMinorMeta = const VerificationMeta(
    'annualFeeMinor',
  );
  @override
  late final GeneratedColumn<int> annualFeeMinor = GeneratedColumn<int>(
    'annual_fee_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _minSalaryMinorMeta = const VerificationMeta(
    'minSalaryMinor',
  );
  @override
  late final GeneratedColumn<int> minSalaryMinor = GeneratedColumn<int>(
    'min_salary_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rewardStructureMeta = const VerificationMeta(
    'rewardStructure',
  );
  @override
  late final GeneratedColumn<String> rewardStructure = GeneratedColumn<String>(
    'reward_structure',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _perksMeta = const VerificationMeta('perks');
  @override
  late final GeneratedColumn<String> perks = GeneratedColumn<String>(
    'perks',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _verifiedOnMeta = const VerificationMeta(
    'verifiedOn',
  );
  @override
  late final GeneratedColumn<String> verifiedOn = GeneratedColumn<String>(
    'verified_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _catalogVersionMeta = const VerificationMeta(
    'catalogVersion',
  );
  @override
  late final GeneratedColumn<int> catalogVersion = GeneratedColumn<int>(
    'catalog_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    issuer,
    name,
    network,
    annualFeeMinor,
    minSalaryMinor,
    rewardStructure,
    perks,
    verifiedOn,
    source,
    catalogVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogCardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('issuer')) {
      context.handle(
        _issuerMeta,
        issuer.isAcceptableOrUnknown(data['issuer']!, _issuerMeta),
      );
    } else if (isInserting) {
      context.missing(_issuerMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('network')) {
      context.handle(
        _networkMeta,
        network.isAcceptableOrUnknown(data['network']!, _networkMeta),
      );
    }
    if (data.containsKey('annual_fee_minor')) {
      context.handle(
        _annualFeeMinorMeta,
        annualFeeMinor.isAcceptableOrUnknown(
          data['annual_fee_minor']!,
          _annualFeeMinorMeta,
        ),
      );
    }
    if (data.containsKey('min_salary_minor')) {
      context.handle(
        _minSalaryMinorMeta,
        minSalaryMinor.isAcceptableOrUnknown(
          data['min_salary_minor']!,
          _minSalaryMinorMeta,
        ),
      );
    }
    if (data.containsKey('reward_structure')) {
      context.handle(
        _rewardStructureMeta,
        rewardStructure.isAcceptableOrUnknown(
          data['reward_structure']!,
          _rewardStructureMeta,
        ),
      );
    }
    if (data.containsKey('perks')) {
      context.handle(
        _perksMeta,
        perks.isAcceptableOrUnknown(data['perks']!, _perksMeta),
      );
    }
    if (data.containsKey('verified_on')) {
      context.handle(
        _verifiedOnMeta,
        verifiedOn.isAcceptableOrUnknown(data['verified_on']!, _verifiedOnMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('catalog_version')) {
      context.handle(
        _catalogVersionMeta,
        catalogVersion.isAcceptableOrUnknown(
          data['catalog_version']!,
          _catalogVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatalogCardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogCardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      issuer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issuer'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      network: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}network'],
      ),
      annualFeeMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}annual_fee_minor'],
      )!,
      minSalaryMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_salary_minor'],
      ),
      rewardStructure: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reward_structure'],
      )!,
      perks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}perks'],
      )!,
      verifiedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verified_on'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      catalogVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}catalog_version'],
      )!,
    );
  }

  @override
  $CatalogCardsTable createAlias(String alias) {
    return $CatalogCardsTable(attachedDatabase, alias);
  }
}

class CatalogCardRow extends DataClass implements Insertable<CatalogCardRow> {
  final String id;
  final String issuer;
  final String name;
  final String? network;
  final int annualFeeMinor;
  final int? minSalaryMinor;

  /// JSON, see `core/engine/rewards.dart`.
  final String rewardStructure;
  final String perks;

  /// Null = unverified.
  final String? verifiedOn;
  final String? source;
  final int catalogVersion;
  const CatalogCardRow({
    required this.id,
    required this.issuer,
    required this.name,
    this.network,
    required this.annualFeeMinor,
    this.minSalaryMinor,
    required this.rewardStructure,
    required this.perks,
    this.verifiedOn,
    this.source,
    required this.catalogVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['issuer'] = Variable<String>(issuer);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || network != null) {
      map['network'] = Variable<String>(network);
    }
    map['annual_fee_minor'] = Variable<int>(annualFeeMinor);
    if (!nullToAbsent || minSalaryMinor != null) {
      map['min_salary_minor'] = Variable<int>(minSalaryMinor);
    }
    map['reward_structure'] = Variable<String>(rewardStructure);
    map['perks'] = Variable<String>(perks);
    if (!nullToAbsent || verifiedOn != null) {
      map['verified_on'] = Variable<String>(verifiedOn);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    map['catalog_version'] = Variable<int>(catalogVersion);
    return map;
  }

  CatalogCardsCompanion toCompanion(bool nullToAbsent) {
    return CatalogCardsCompanion(
      id: Value(id),
      issuer: Value(issuer),
      name: Value(name),
      network: network == null && nullToAbsent
          ? const Value.absent()
          : Value(network),
      annualFeeMinor: Value(annualFeeMinor),
      minSalaryMinor: minSalaryMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(minSalaryMinor),
      rewardStructure: Value(rewardStructure),
      perks: Value(perks),
      verifiedOn: verifiedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(verifiedOn),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      catalogVersion: Value(catalogVersion),
    );
  }

  factory CatalogCardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogCardRow(
      id: serializer.fromJson<String>(json['id']),
      issuer: serializer.fromJson<String>(json['issuer']),
      name: serializer.fromJson<String>(json['name']),
      network: serializer.fromJson<String?>(json['network']),
      annualFeeMinor: serializer.fromJson<int>(json['annualFeeMinor']),
      minSalaryMinor: serializer.fromJson<int?>(json['minSalaryMinor']),
      rewardStructure: serializer.fromJson<String>(json['rewardStructure']),
      perks: serializer.fromJson<String>(json['perks']),
      verifiedOn: serializer.fromJson<String?>(json['verifiedOn']),
      source: serializer.fromJson<String?>(json['source']),
      catalogVersion: serializer.fromJson<int>(json['catalogVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'issuer': serializer.toJson<String>(issuer),
      'name': serializer.toJson<String>(name),
      'network': serializer.toJson<String?>(network),
      'annualFeeMinor': serializer.toJson<int>(annualFeeMinor),
      'minSalaryMinor': serializer.toJson<int?>(minSalaryMinor),
      'rewardStructure': serializer.toJson<String>(rewardStructure),
      'perks': serializer.toJson<String>(perks),
      'verifiedOn': serializer.toJson<String?>(verifiedOn),
      'source': serializer.toJson<String?>(source),
      'catalogVersion': serializer.toJson<int>(catalogVersion),
    };
  }

  CatalogCardRow copyWith({
    String? id,
    String? issuer,
    String? name,
    Value<String?> network = const Value.absent(),
    int? annualFeeMinor,
    Value<int?> minSalaryMinor = const Value.absent(),
    String? rewardStructure,
    String? perks,
    Value<String?> verifiedOn = const Value.absent(),
    Value<String?> source = const Value.absent(),
    int? catalogVersion,
  }) => CatalogCardRow(
    id: id ?? this.id,
    issuer: issuer ?? this.issuer,
    name: name ?? this.name,
    network: network.present ? network.value : this.network,
    annualFeeMinor: annualFeeMinor ?? this.annualFeeMinor,
    minSalaryMinor: minSalaryMinor.present
        ? minSalaryMinor.value
        : this.minSalaryMinor,
    rewardStructure: rewardStructure ?? this.rewardStructure,
    perks: perks ?? this.perks,
    verifiedOn: verifiedOn.present ? verifiedOn.value : this.verifiedOn,
    source: source.present ? source.value : this.source,
    catalogVersion: catalogVersion ?? this.catalogVersion,
  );
  CatalogCardRow copyWithCompanion(CatalogCardsCompanion data) {
    return CatalogCardRow(
      id: data.id.present ? data.id.value : this.id,
      issuer: data.issuer.present ? data.issuer.value : this.issuer,
      name: data.name.present ? data.name.value : this.name,
      network: data.network.present ? data.network.value : this.network,
      annualFeeMinor: data.annualFeeMinor.present
          ? data.annualFeeMinor.value
          : this.annualFeeMinor,
      minSalaryMinor: data.minSalaryMinor.present
          ? data.minSalaryMinor.value
          : this.minSalaryMinor,
      rewardStructure: data.rewardStructure.present
          ? data.rewardStructure.value
          : this.rewardStructure,
      perks: data.perks.present ? data.perks.value : this.perks,
      verifiedOn: data.verifiedOn.present
          ? data.verifiedOn.value
          : this.verifiedOn,
      source: data.source.present ? data.source.value : this.source,
      catalogVersion: data.catalogVersion.present
          ? data.catalogVersion.value
          : this.catalogVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogCardRow(')
          ..write('id: $id, ')
          ..write('issuer: $issuer, ')
          ..write('name: $name, ')
          ..write('network: $network, ')
          ..write('annualFeeMinor: $annualFeeMinor, ')
          ..write('minSalaryMinor: $minSalaryMinor, ')
          ..write('rewardStructure: $rewardStructure, ')
          ..write('perks: $perks, ')
          ..write('verifiedOn: $verifiedOn, ')
          ..write('source: $source, ')
          ..write('catalogVersion: $catalogVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    issuer,
    name,
    network,
    annualFeeMinor,
    minSalaryMinor,
    rewardStructure,
    perks,
    verifiedOn,
    source,
    catalogVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogCardRow &&
          other.id == this.id &&
          other.issuer == this.issuer &&
          other.name == this.name &&
          other.network == this.network &&
          other.annualFeeMinor == this.annualFeeMinor &&
          other.minSalaryMinor == this.minSalaryMinor &&
          other.rewardStructure == this.rewardStructure &&
          other.perks == this.perks &&
          other.verifiedOn == this.verifiedOn &&
          other.source == this.source &&
          other.catalogVersion == this.catalogVersion);
}

class CatalogCardsCompanion extends UpdateCompanion<CatalogCardRow> {
  final Value<String> id;
  final Value<String> issuer;
  final Value<String> name;
  final Value<String?> network;
  final Value<int> annualFeeMinor;
  final Value<int?> minSalaryMinor;
  final Value<String> rewardStructure;
  final Value<String> perks;
  final Value<String?> verifiedOn;
  final Value<String?> source;
  final Value<int> catalogVersion;
  final Value<int> rowid;
  const CatalogCardsCompanion({
    this.id = const Value.absent(),
    this.issuer = const Value.absent(),
    this.name = const Value.absent(),
    this.network = const Value.absent(),
    this.annualFeeMinor = const Value.absent(),
    this.minSalaryMinor = const Value.absent(),
    this.rewardStructure = const Value.absent(),
    this.perks = const Value.absent(),
    this.verifiedOn = const Value.absent(),
    this.source = const Value.absent(),
    this.catalogVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogCardsCompanion.insert({
    required String id,
    required String issuer,
    required String name,
    this.network = const Value.absent(),
    this.annualFeeMinor = const Value.absent(),
    this.minSalaryMinor = const Value.absent(),
    this.rewardStructure = const Value.absent(),
    this.perks = const Value.absent(),
    this.verifiedOn = const Value.absent(),
    this.source = const Value.absent(),
    this.catalogVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       issuer = Value(issuer),
       name = Value(name);
  static Insertable<CatalogCardRow> custom({
    Expression<String>? id,
    Expression<String>? issuer,
    Expression<String>? name,
    Expression<String>? network,
    Expression<int>? annualFeeMinor,
    Expression<int>? minSalaryMinor,
    Expression<String>? rewardStructure,
    Expression<String>? perks,
    Expression<String>? verifiedOn,
    Expression<String>? source,
    Expression<int>? catalogVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (issuer != null) 'issuer': issuer,
      if (name != null) 'name': name,
      if (network != null) 'network': network,
      if (annualFeeMinor != null) 'annual_fee_minor': annualFeeMinor,
      if (minSalaryMinor != null) 'min_salary_minor': minSalaryMinor,
      if (rewardStructure != null) 'reward_structure': rewardStructure,
      if (perks != null) 'perks': perks,
      if (verifiedOn != null) 'verified_on': verifiedOn,
      if (source != null) 'source': source,
      if (catalogVersion != null) 'catalog_version': catalogVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogCardsCompanion copyWith({
    Value<String>? id,
    Value<String>? issuer,
    Value<String>? name,
    Value<String?>? network,
    Value<int>? annualFeeMinor,
    Value<int?>? minSalaryMinor,
    Value<String>? rewardStructure,
    Value<String>? perks,
    Value<String?>? verifiedOn,
    Value<String?>? source,
    Value<int>? catalogVersion,
    Value<int>? rowid,
  }) {
    return CatalogCardsCompanion(
      id: id ?? this.id,
      issuer: issuer ?? this.issuer,
      name: name ?? this.name,
      network: network ?? this.network,
      annualFeeMinor: annualFeeMinor ?? this.annualFeeMinor,
      minSalaryMinor: minSalaryMinor ?? this.minSalaryMinor,
      rewardStructure: rewardStructure ?? this.rewardStructure,
      perks: perks ?? this.perks,
      verifiedOn: verifiedOn ?? this.verifiedOn,
      source: source ?? this.source,
      catalogVersion: catalogVersion ?? this.catalogVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (issuer.present) {
      map['issuer'] = Variable<String>(issuer.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (network.present) {
      map['network'] = Variable<String>(network.value);
    }
    if (annualFeeMinor.present) {
      map['annual_fee_minor'] = Variable<int>(annualFeeMinor.value);
    }
    if (minSalaryMinor.present) {
      map['min_salary_minor'] = Variable<int>(minSalaryMinor.value);
    }
    if (rewardStructure.present) {
      map['reward_structure'] = Variable<String>(rewardStructure.value);
    }
    if (perks.present) {
      map['perks'] = Variable<String>(perks.value);
    }
    if (verifiedOn.present) {
      map['verified_on'] = Variable<String>(verifiedOn.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (catalogVersion.present) {
      map['catalog_version'] = Variable<int>(catalogVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogCardsCompanion(')
          ..write('id: $id, ')
          ..write('issuer: $issuer, ')
          ..write('name: $name, ')
          ..write('network: $network, ')
          ..write('annualFeeMinor: $annualFeeMinor, ')
          ..write('minSalaryMinor: $minSalaryMinor, ')
          ..write('rewardStructure: $rewardStructure, ')
          ..write('perks: $perks, ')
          ..write('verifiedOn: $verifiedOn, ')
          ..write('source: $source, ')
          ..write('catalogVersion: $catalogVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserCardsTable extends UserCards
    with TableInfo<$UserCardsTable, UserCardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _catalogCardIdMeta = const VerificationMeta(
    'catalogCardId',
  );
  @override
  late final GeneratedColumn<String> catalogCardId = GeneratedColumn<String>(
    'catalog_card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catalog_cards (id)',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    catalogCardId,
    accountId,
    nickname,
    colorIndex,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserCardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('catalog_card_id')) {
      context.handle(
        _catalogCardIdMeta,
        catalogCardId.isAcceptableOrUnknown(
          data['catalog_card_id']!,
          _catalogCardIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_catalogCardIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserCardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserCardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      catalogCardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catalog_card_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      ),
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $UserCardsTable createAlias(String alias) {
    return $UserCardsTable(attachedDatabase, alias);
  }
}

class UserCardRow extends DataClass implements Insertable<UserCardRow> {
  final String id;
  final String catalogCardId;
  final String? accountId;
  final String? nickname;
  final int colorIndex;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const UserCardRow({
    required this.id,
    required this.catalogCardId,
    this.accountId,
    this.nickname,
    required this.colorIndex,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['catalog_card_id'] = Variable<String>(catalogCardId);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || nickname != null) {
      map['nickname'] = Variable<String>(nickname);
    }
    map['color_index'] = Variable<int>(colorIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  UserCardsCompanion toCompanion(bool nullToAbsent) {
    return UserCardsCompanion(
      id: Value(id),
      catalogCardId: Value(catalogCardId),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      nickname: nickname == null && nullToAbsent
          ? const Value.absent()
          : Value(nickname),
      colorIndex: Value(colorIndex),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory UserCardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserCardRow(
      id: serializer.fromJson<String>(json['id']),
      catalogCardId: serializer.fromJson<String>(json['catalogCardId']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      nickname: serializer.fromJson<String?>(json['nickname']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'catalogCardId': serializer.toJson<String>(catalogCardId),
      'accountId': serializer.toJson<String?>(accountId),
      'nickname': serializer.toJson<String?>(nickname),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  UserCardRow copyWith({
    String? id,
    String? catalogCardId,
    Value<String?> accountId = const Value.absent(),
    Value<String?> nickname = const Value.absent(),
    int? colorIndex,
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => UserCardRow(
    id: id ?? this.id,
    catalogCardId: catalogCardId ?? this.catalogCardId,
    accountId: accountId.present ? accountId.value : this.accountId,
    nickname: nickname.present ? nickname.value : this.nickname,
    colorIndex: colorIndex ?? this.colorIndex,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  UserCardRow copyWithCompanion(UserCardsCompanion data) {
    return UserCardRow(
      id: data.id.present ? data.id.value : this.id,
      catalogCardId: data.catalogCardId.present
          ? data.catalogCardId.value
          : this.catalogCardId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserCardRow(')
          ..write('id: $id, ')
          ..write('catalogCardId: $catalogCardId, ')
          ..write('accountId: $accountId, ')
          ..write('nickname: $nickname, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    catalogCardId,
    accountId,
    nickname,
    colorIndex,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserCardRow &&
          other.id == this.id &&
          other.catalogCardId == this.catalogCardId &&
          other.accountId == this.accountId &&
          other.nickname == this.nickname &&
          other.colorIndex == this.colorIndex &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class UserCardsCompanion extends UpdateCompanion<UserCardRow> {
  final Value<String> id;
  final Value<String> catalogCardId;
  final Value<String?> accountId;
  final Value<String?> nickname;
  final Value<int> colorIndex;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const UserCardsCompanion({
    this.id = const Value.absent(),
    this.catalogCardId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.nickname = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserCardsCompanion.insert({
    required String id,
    required String catalogCardId,
    this.accountId = const Value.absent(),
    this.nickname = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       catalogCardId = Value(catalogCardId);
  static Insertable<UserCardRow> custom({
    Expression<String>? id,
    Expression<String>? catalogCardId,
    Expression<String>? accountId,
    Expression<String>? nickname,
    Expression<int>? colorIndex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (catalogCardId != null) 'catalog_card_id': catalogCardId,
      if (accountId != null) 'account_id': accountId,
      if (nickname != null) 'nickname': nickname,
      if (colorIndex != null) 'color_index': colorIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserCardsCompanion copyWith({
    Value<String>? id,
    Value<String>? catalogCardId,
    Value<String?>? accountId,
    Value<String?>? nickname,
    Value<int>? colorIndex,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return UserCardsCompanion(
      id: id ?? this.id,
      catalogCardId: catalogCardId ?? this.catalogCardId,
      accountId: accountId ?? this.accountId,
      nickname: nickname ?? this.nickname,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (catalogCardId.present) {
      map['catalog_card_id'] = Variable<String>(catalogCardId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserCardsCompanion(')
          ..write('id: $id, ')
          ..write('catalogCardId: $catalogCardId, ')
          ..write('accountId: $accountId, ')
          ..write('nickname: $nickname, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
    'slug',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('expense'),
  );
  static const VerificationMeta _isFixedMeta = const VerificationMeta(
    'isFixed',
  );
  @override
  late final GeneratedColumn<bool> isFixed = GeneratedColumn<bool>(
    'is_fixed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_fixed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isHiddenMeta = const VerificationMeta(
    'isHidden',
  );
  @override
  late final GeneratedColumn<bool> isHidden = GeneratedColumn<bool>(
    'is_hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    slug,
    name,
    kind,
    isFixed,
    icon,
    color,
    sortOrder,
    parentId,
    isCustom,
    isHidden,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('slug')) {
      context.handle(
        _slugMeta,
        slug.isAcceptableOrUnknown(data['slug']!, _slugMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('is_fixed')) {
      context.handle(
        _isFixedMeta,
        isFixed.isAcceptableOrUnknown(data['is_fixed']!, _isFixedMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('is_hidden')) {
      context.handle(
        _isHiddenMeta,
        isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      slug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      isFixed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_fixed'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      isHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_hidden'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  /// The slug for default categories, `c_<random>` for custom ones.
  final String id;
  final String? slug;
  final String name;

  /// expense | income | transfer
  final String kind;
  final bool isFixed;
  final String? icon;
  final String? color;
  final int sortOrder;
  final String? parentId;
  final bool isCustom;
  final bool isHidden;
  const CategoryRow({
    required this.id,
    this.slug,
    required this.name,
    required this.kind,
    required this.isFixed,
    this.icon,
    this.color,
    required this.sortOrder,
    this.parentId,
    required this.isCustom,
    required this.isHidden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || slug != null) {
      map['slug'] = Variable<String>(slug);
    }
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['is_fixed'] = Variable<bool>(isFixed);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['is_custom'] = Variable<bool>(isCustom);
    map['is_hidden'] = Variable<bool>(isHidden);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      slug: slug == null && nullToAbsent ? const Value.absent() : Value(slug),
      name: Value(name),
      kind: Value(kind),
      isFixed: Value(isFixed),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      sortOrder: Value(sortOrder),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      isCustom: Value(isCustom),
      isHidden: Value(isHidden),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<String>(json['id']),
      slug: serializer.fromJson<String?>(json['slug']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      isFixed: serializer.fromJson<bool>(json['isFixed']),
      icon: serializer.fromJson<String?>(json['icon']),
      color: serializer.fromJson<String?>(json['color']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      isHidden: serializer.fromJson<bool>(json['isHidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'slug': serializer.toJson<String?>(slug),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'isFixed': serializer.toJson<bool>(isFixed),
      'icon': serializer.toJson<String?>(icon),
      'color': serializer.toJson<String?>(color),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'parentId': serializer.toJson<String?>(parentId),
      'isCustom': serializer.toJson<bool>(isCustom),
      'isHidden': serializer.toJson<bool>(isHidden),
    };
  }

  CategoryRow copyWith({
    String? id,
    Value<String?> slug = const Value.absent(),
    String? name,
    String? kind,
    bool? isFixed,
    Value<String?> icon = const Value.absent(),
    Value<String?> color = const Value.absent(),
    int? sortOrder,
    Value<String?> parentId = const Value.absent(),
    bool? isCustom,
    bool? isHidden,
  }) => CategoryRow(
    id: id ?? this.id,
    slug: slug.present ? slug.value : this.slug,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    isFixed: isFixed ?? this.isFixed,
    icon: icon.present ? icon.value : this.icon,
    color: color.present ? color.value : this.color,
    sortOrder: sortOrder ?? this.sortOrder,
    parentId: parentId.present ? parentId.value : this.parentId,
    isCustom: isCustom ?? this.isCustom,
    isHidden: isHidden ?? this.isHidden,
  );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      slug: data.slug.present ? data.slug.value : this.slug,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      isFixed: data.isFixed.present ? data.isFixed.value : this.isFixed,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      isHidden: data.isHidden.present ? data.isHidden.value : this.isHidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('slug: $slug, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('isFixed: $isFixed, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('parentId: $parentId, ')
          ..write('isCustom: $isCustom, ')
          ..write('isHidden: $isHidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    slug,
    name,
    kind,
    isFixed,
    icon,
    color,
    sortOrder,
    parentId,
    isCustom,
    isHidden,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.slug == this.slug &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.isFixed == this.isFixed &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.sortOrder == this.sortOrder &&
          other.parentId == this.parentId &&
          other.isCustom == this.isCustom &&
          other.isHidden == this.isHidden);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> id;
  final Value<String?> slug;
  final Value<String> name;
  final Value<String> kind;
  final Value<bool> isFixed;
  final Value<String?> icon;
  final Value<String?> color;
  final Value<int> sortOrder;
  final Value<String?> parentId;
  final Value<bool> isCustom;
  final Value<bool> isHidden;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.slug = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.isFixed = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.parentId = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    this.slug = const Value.absent(),
    required String name,
    this.kind = const Value.absent(),
    this.isFixed = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.parentId = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<CategoryRow> custom({
    Expression<String>? id,
    Expression<String>? slug,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<bool>? isFixed,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<int>? sortOrder,
    Expression<String>? parentId,
    Expression<bool>? isCustom,
    Expression<bool>? isHidden,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (slug != null) 'slug': slug,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (isFixed != null) 'is_fixed': isFixed,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (parentId != null) 'parent_id': parentId,
      if (isCustom != null) 'is_custom': isCustom,
      if (isHidden != null) 'is_hidden': isHidden,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String?>? slug,
    Value<String>? name,
    Value<String>? kind,
    Value<bool>? isFixed,
    Value<String?>? icon,
    Value<String?>? color,
    Value<int>? sortOrder,
    Value<String?>? parentId,
    Value<bool>? isCustom,
    Value<bool>? isHidden,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      isFixed: isFixed ?? this.isFixed,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      parentId: parentId ?? this.parentId,
      isCustom: isCustom ?? this.isCustom,
      isHidden: isHidden ?? this.isHidden,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (isFixed.present) {
      map['is_fixed'] = Variable<bool>(isFixed.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (isHidden.present) {
      map['is_hidden'] = Variable<bool>(isHidden.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('slug: $slug, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('isFixed: $isFixed, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('parentId: $parentId, ')
          ..write('isCustom: $isCustom, ')
          ..write('isHidden: $isHidden, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, TxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _statementIdMeta = const VerificationMeta(
    'statementId',
  );
  @override
  late final GeneratedColumn<String> statementId = GeneratedColumn<String>(
    'statement_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('AED'),
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _merchantRawMeta = const VerificationMeta(
    'merchantRaw',
  );
  @override
  late final GeneratedColumn<String> merchantRaw = GeneratedColumn<String>(
    'merchant_raw',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _merchantNormalizedMeta =
      const VerificationMeta('merchantNormalized');
  @override
  late final GeneratedColumn<String> merchantNormalized =
      GeneratedColumn<String>(
        'merchant_normalized',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _postedAtMeta = const VerificationMeta(
    'postedAt',
  );
  @override
  late final GeneratedColumn<DateTime> postedAt = GeneratedColumn<DateTime>(
    'posted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalHashMeta = const VerificationMeta(
    'externalHash',
  );
  @override
  late final GeneratedColumn<String> externalHash = GeneratedColumn<String>(
    'external_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _excludeFromBudgetMeta = const VerificationMeta(
    'excludeFromBudget',
  );
  @override
  late final GeneratedColumn<bool> excludeFromBudget = GeneratedColumn<bool>(
    'exclude_from_budget',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("exclude_from_budget" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _sourcesMeta = const VerificationMeta(
    'sources',
  );
  @override
  late final GeneratedColumn<String> sources = GeneratedColumn<String>(
    'sources',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _statementLockedMeta = const VerificationMeta(
    'statementLocked',
  );
  @override
  late final GeneratedColumn<bool> statementLocked = GeneratedColumn<bool>(
    'statement_locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("statement_locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _appliedRuleIdMeta = const VerificationMeta(
    'appliedRuleId',
  );
  @override
  late final GeneratedColumn<String> appliedRuleId = GeneratedColumn<String>(
    'applied_rule_id',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    statementId,
    categoryId,
    amountMinor,
    currency,
    direction,
    merchantRaw,
    merchantNormalized,
    notes,
    postedAt,
    source,
    externalHash,
    excludeFromBudget,
    tags,
    sources,
    statementLocked,
    appliedRuleId,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('statement_id')) {
      context.handle(
        _statementIdMeta,
        statementId.isAcceptableOrUnknown(
          data['statement_id']!,
          _statementIdMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('merchant_raw')) {
      context.handle(
        _merchantRawMeta,
        merchantRaw.isAcceptableOrUnknown(
          data['merchant_raw']!,
          _merchantRawMeta,
        ),
      );
    }
    if (data.containsKey('merchant_normalized')) {
      context.handle(
        _merchantNormalizedMeta,
        merchantNormalized.isAcceptableOrUnknown(
          data['merchant_normalized']!,
          _merchantNormalizedMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('posted_at')) {
      context.handle(
        _postedAtMeta,
        postedAt.isAcceptableOrUnknown(data['posted_at']!, _postedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_postedAtMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('external_hash')) {
      context.handle(
        _externalHashMeta,
        externalHash.isAcceptableOrUnknown(
          data['external_hash']!,
          _externalHashMeta,
        ),
      );
    }
    if (data.containsKey('exclude_from_budget')) {
      context.handle(
        _excludeFromBudgetMeta,
        excludeFromBudget.isAcceptableOrUnknown(
          data['exclude_from_budget']!,
          _excludeFromBudgetMeta,
        ),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('sources')) {
      context.handle(
        _sourcesMeta,
        sources.isAcceptableOrUnknown(data['sources']!, _sourcesMeta),
      );
    }
    if (data.containsKey('statement_locked')) {
      context.handle(
        _statementLockedMeta,
        statementLocked.isAcceptableOrUnknown(
          data['statement_locked']!,
          _statementLockedMeta,
        ),
      );
    }
    if (data.containsKey('applied_rule_id')) {
      context.handle(
        _appliedRuleIdMeta,
        appliedRuleId.isAcceptableOrUnknown(
          data['applied_rule_id']!,
          _appliedRuleIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      statementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statement_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      merchantRaw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_raw'],
      ),
      merchantNormalized: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_normalized'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      postedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}posted_at'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      externalHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_hash'],
      ),
      excludeFromBudget: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}exclude_from_budget'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      sources: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sources'],
      )!,
      statementLocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}statement_locked'],
      )!,
      appliedRuleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}applied_rule_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class TxRow extends DataClass implements Insertable<TxRow> {
  final String id;
  final String accountId;
  final String? statementId;
  final String? categoryId;

  /// Always positive; [direction] carries the sign.
  final int amountMinor;
  final String currency;

  /// debit | credit
  final String direction;
  final String? merchantRaw;
  final String? merchantNormalized;
  final String? notes;
  final DateTime postedAt;

  /// statement | sms | notification | apple_shortcut | google_wallet |
  /// samsung_wallet | manual
  final String source;

  /// Dedupe key of the message this came from; unique when present.
  final String? externalHash;
  final bool excludeFromBudget;

  /// JSON list of free-form labels.
  final String tags;

  /// JSON list of every channel that saw this purchase: one purchase, one row.
  final String sources;

  /// A statement line confirmed it: amount/date are the bank's, final.
  final bool statementLocked;
  final String? appliedRuleId;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const TxRow({
    required this.id,
    required this.accountId,
    this.statementId,
    this.categoryId,
    required this.amountMinor,
    required this.currency,
    required this.direction,
    this.merchantRaw,
    this.merchantNormalized,
    this.notes,
    required this.postedAt,
    required this.source,
    this.externalHash,
    required this.excludeFromBudget,
    required this.tags,
    required this.sources,
    required this.statementLocked,
    this.appliedRuleId,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || statementId != null) {
      map['statement_id'] = Variable<String>(statementId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency'] = Variable<String>(currency);
    map['direction'] = Variable<String>(direction);
    if (!nullToAbsent || merchantRaw != null) {
      map['merchant_raw'] = Variable<String>(merchantRaw);
    }
    if (!nullToAbsent || merchantNormalized != null) {
      map['merchant_normalized'] = Variable<String>(merchantNormalized);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['posted_at'] = Variable<DateTime>(postedAt);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || externalHash != null) {
      map['external_hash'] = Variable<String>(externalHash);
    }
    map['exclude_from_budget'] = Variable<bool>(excludeFromBudget);
    map['tags'] = Variable<String>(tags);
    map['sources'] = Variable<String>(sources);
    map['statement_locked'] = Variable<bool>(statementLocked);
    if (!nullToAbsent || appliedRuleId != null) {
      map['applied_rule_id'] = Variable<String>(appliedRuleId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      statementId: statementId == null && nullToAbsent
          ? const Value.absent()
          : Value(statementId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      direction: Value(direction),
      merchantRaw: merchantRaw == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantRaw),
      merchantNormalized: merchantNormalized == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantNormalized),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      postedAt: Value(postedAt),
      source: Value(source),
      externalHash: externalHash == null && nullToAbsent
          ? const Value.absent()
          : Value(externalHash),
      excludeFromBudget: Value(excludeFromBudget),
      tags: Value(tags),
      sources: Value(sources),
      statementLocked: Value(statementLocked),
      appliedRuleId: appliedRuleId == null && nullToAbsent
          ? const Value.absent()
          : Value(appliedRuleId),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory TxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TxRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      statementId: serializer.fromJson<String?>(json['statementId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      direction: serializer.fromJson<String>(json['direction']),
      merchantRaw: serializer.fromJson<String?>(json['merchantRaw']),
      merchantNormalized: serializer.fromJson<String?>(
        json['merchantNormalized'],
      ),
      notes: serializer.fromJson<String?>(json['notes']),
      postedAt: serializer.fromJson<DateTime>(json['postedAt']),
      source: serializer.fromJson<String>(json['source']),
      externalHash: serializer.fromJson<String?>(json['externalHash']),
      excludeFromBudget: serializer.fromJson<bool>(json['excludeFromBudget']),
      tags: serializer.fromJson<String>(json['tags']),
      sources: serializer.fromJson<String>(json['sources']),
      statementLocked: serializer.fromJson<bool>(json['statementLocked']),
      appliedRuleId: serializer.fromJson<String?>(json['appliedRuleId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'statementId': serializer.toJson<String?>(statementId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<String>(currency),
      'direction': serializer.toJson<String>(direction),
      'merchantRaw': serializer.toJson<String?>(merchantRaw),
      'merchantNormalized': serializer.toJson<String?>(merchantNormalized),
      'notes': serializer.toJson<String?>(notes),
      'postedAt': serializer.toJson<DateTime>(postedAt),
      'source': serializer.toJson<String>(source),
      'externalHash': serializer.toJson<String?>(externalHash),
      'excludeFromBudget': serializer.toJson<bool>(excludeFromBudget),
      'tags': serializer.toJson<String>(tags),
      'sources': serializer.toJson<String>(sources),
      'statementLocked': serializer.toJson<bool>(statementLocked),
      'appliedRuleId': serializer.toJson<String?>(appliedRuleId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  TxRow copyWith({
    String? id,
    String? accountId,
    Value<String?> statementId = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    int? amountMinor,
    String? currency,
    String? direction,
    Value<String?> merchantRaw = const Value.absent(),
    Value<String?> merchantNormalized = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? postedAt,
    String? source,
    Value<String?> externalHash = const Value.absent(),
    bool? excludeFromBudget,
    String? tags,
    String? sources,
    bool? statementLocked,
    Value<String?> appliedRuleId = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => TxRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    statementId: statementId.present ? statementId.value : this.statementId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    amountMinor: amountMinor ?? this.amountMinor,
    currency: currency ?? this.currency,
    direction: direction ?? this.direction,
    merchantRaw: merchantRaw.present ? merchantRaw.value : this.merchantRaw,
    merchantNormalized: merchantNormalized.present
        ? merchantNormalized.value
        : this.merchantNormalized,
    notes: notes.present ? notes.value : this.notes,
    postedAt: postedAt ?? this.postedAt,
    source: source ?? this.source,
    externalHash: externalHash.present ? externalHash.value : this.externalHash,
    excludeFromBudget: excludeFromBudget ?? this.excludeFromBudget,
    tags: tags ?? this.tags,
    sources: sources ?? this.sources,
    statementLocked: statementLocked ?? this.statementLocked,
    appliedRuleId: appliedRuleId.present
        ? appliedRuleId.value
        : this.appliedRuleId,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  TxRow copyWithCompanion(TransactionsCompanion data) {
    return TxRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      statementId: data.statementId.present
          ? data.statementId.value
          : this.statementId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      direction: data.direction.present ? data.direction.value : this.direction,
      merchantRaw: data.merchantRaw.present
          ? data.merchantRaw.value
          : this.merchantRaw,
      merchantNormalized: data.merchantNormalized.present
          ? data.merchantNormalized.value
          : this.merchantNormalized,
      notes: data.notes.present ? data.notes.value : this.notes,
      postedAt: data.postedAt.present ? data.postedAt.value : this.postedAt,
      source: data.source.present ? data.source.value : this.source,
      externalHash: data.externalHash.present
          ? data.externalHash.value
          : this.externalHash,
      excludeFromBudget: data.excludeFromBudget.present
          ? data.excludeFromBudget.value
          : this.excludeFromBudget,
      tags: data.tags.present ? data.tags.value : this.tags,
      sources: data.sources.present ? data.sources.value : this.sources,
      statementLocked: data.statementLocked.present
          ? data.statementLocked.value
          : this.statementLocked,
      appliedRuleId: data.appliedRuleId.present
          ? data.appliedRuleId.value
          : this.appliedRuleId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TxRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('statementId: $statementId, ')
          ..write('categoryId: $categoryId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('direction: $direction, ')
          ..write('merchantRaw: $merchantRaw, ')
          ..write('merchantNormalized: $merchantNormalized, ')
          ..write('notes: $notes, ')
          ..write('postedAt: $postedAt, ')
          ..write('source: $source, ')
          ..write('externalHash: $externalHash, ')
          ..write('excludeFromBudget: $excludeFromBudget, ')
          ..write('tags: $tags, ')
          ..write('sources: $sources, ')
          ..write('statementLocked: $statementLocked, ')
          ..write('appliedRuleId: $appliedRuleId, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    statementId,
    categoryId,
    amountMinor,
    currency,
    direction,
    merchantRaw,
    merchantNormalized,
    notes,
    postedAt,
    source,
    externalHash,
    excludeFromBudget,
    tags,
    sources,
    statementLocked,
    appliedRuleId,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TxRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.statementId == this.statementId &&
          other.categoryId == this.categoryId &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.direction == this.direction &&
          other.merchantRaw == this.merchantRaw &&
          other.merchantNormalized == this.merchantNormalized &&
          other.notes == this.notes &&
          other.postedAt == this.postedAt &&
          other.source == this.source &&
          other.externalHash == this.externalHash &&
          other.excludeFromBudget == this.excludeFromBudget &&
          other.tags == this.tags &&
          other.sources == this.sources &&
          other.statementLocked == this.statementLocked &&
          other.appliedRuleId == this.appliedRuleId &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class TransactionsCompanion extends UpdateCompanion<TxRow> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String?> statementId;
  final Value<String?> categoryId;
  final Value<int> amountMinor;
  final Value<String> currency;
  final Value<String> direction;
  final Value<String?> merchantRaw;
  final Value<String?> merchantNormalized;
  final Value<String?> notes;
  final Value<DateTime> postedAt;
  final Value<String> source;
  final Value<String?> externalHash;
  final Value<bool> excludeFromBudget;
  final Value<String> tags;
  final Value<String> sources;
  final Value<bool> statementLocked;
  final Value<String?> appliedRuleId;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.statementId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.direction = const Value.absent(),
    this.merchantRaw = const Value.absent(),
    this.merchantNormalized = const Value.absent(),
    this.notes = const Value.absent(),
    this.postedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.externalHash = const Value.absent(),
    this.excludeFromBudget = const Value.absent(),
    this.tags = const Value.absent(),
    this.sources = const Value.absent(),
    this.statementLocked = const Value.absent(),
    this.appliedRuleId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required String accountId,
    this.statementId = const Value.absent(),
    this.categoryId = const Value.absent(),
    required int amountMinor,
    this.currency = const Value.absent(),
    required String direction,
    this.merchantRaw = const Value.absent(),
    this.merchantNormalized = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime postedAt,
    required String source,
    this.externalHash = const Value.absent(),
    this.excludeFromBudget = const Value.absent(),
    this.tags = const Value.absent(),
    this.sources = const Value.absent(),
    this.statementLocked = const Value.absent(),
    this.appliedRuleId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       amountMinor = Value(amountMinor),
       direction = Value(direction),
       postedAt = Value(postedAt),
       source = Value(source);
  static Insertable<TxRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? statementId,
    Expression<String>? categoryId,
    Expression<int>? amountMinor,
    Expression<String>? currency,
    Expression<String>? direction,
    Expression<String>? merchantRaw,
    Expression<String>? merchantNormalized,
    Expression<String>? notes,
    Expression<DateTime>? postedAt,
    Expression<String>? source,
    Expression<String>? externalHash,
    Expression<bool>? excludeFromBudget,
    Expression<String>? tags,
    Expression<String>? sources,
    Expression<bool>? statementLocked,
    Expression<String>? appliedRuleId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (statementId != null) 'statement_id': statementId,
      if (categoryId != null) 'category_id': categoryId,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (direction != null) 'direction': direction,
      if (merchantRaw != null) 'merchant_raw': merchantRaw,
      if (merchantNormalized != null) 'merchant_normalized': merchantNormalized,
      if (notes != null) 'notes': notes,
      if (postedAt != null) 'posted_at': postedAt,
      if (source != null) 'source': source,
      if (externalHash != null) 'external_hash': externalHash,
      if (excludeFromBudget != null) 'exclude_from_budget': excludeFromBudget,
      if (tags != null) 'tags': tags,
      if (sources != null) 'sources': sources,
      if (statementLocked != null) 'statement_locked': statementLocked,
      if (appliedRuleId != null) 'applied_rule_id': appliedRuleId,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String?>? statementId,
    Value<String?>? categoryId,
    Value<int>? amountMinor,
    Value<String>? currency,
    Value<String>? direction,
    Value<String?>? merchantRaw,
    Value<String?>? merchantNormalized,
    Value<String?>? notes,
    Value<DateTime>? postedAt,
    Value<String>? source,
    Value<String?>? externalHash,
    Value<bool>? excludeFromBudget,
    Value<String>? tags,
    Value<String>? sources,
    Value<bool>? statementLocked,
    Value<String?>? appliedRuleId,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      statementId: statementId ?? this.statementId,
      categoryId: categoryId ?? this.categoryId,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      direction: direction ?? this.direction,
      merchantRaw: merchantRaw ?? this.merchantRaw,
      merchantNormalized: merchantNormalized ?? this.merchantNormalized,
      notes: notes ?? this.notes,
      postedAt: postedAt ?? this.postedAt,
      source: source ?? this.source,
      externalHash: externalHash ?? this.externalHash,
      excludeFromBudget: excludeFromBudget ?? this.excludeFromBudget,
      tags: tags ?? this.tags,
      sources: sources ?? this.sources,
      statementLocked: statementLocked ?? this.statementLocked,
      appliedRuleId: appliedRuleId ?? this.appliedRuleId,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (statementId.present) {
      map['statement_id'] = Variable<String>(statementId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (merchantRaw.present) {
      map['merchant_raw'] = Variable<String>(merchantRaw.value);
    }
    if (merchantNormalized.present) {
      map['merchant_normalized'] = Variable<String>(merchantNormalized.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (postedAt.present) {
      map['posted_at'] = Variable<DateTime>(postedAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (externalHash.present) {
      map['external_hash'] = Variable<String>(externalHash.value);
    }
    if (excludeFromBudget.present) {
      map['exclude_from_budget'] = Variable<bool>(excludeFromBudget.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (sources.present) {
      map['sources'] = Variable<String>(sources.value);
    }
    if (statementLocked.present) {
      map['statement_locked'] = Variable<bool>(statementLocked.value);
    }
    if (appliedRuleId.present) {
      map['applied_rule_id'] = Variable<String>(appliedRuleId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('statementId: $statementId, ')
          ..write('categoryId: $categoryId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('direction: $direction, ')
          ..write('merchantRaw: $merchantRaw, ')
          ..write('merchantNormalized: $merchantNormalized, ')
          ..write('notes: $notes, ')
          ..write('postedAt: $postedAt, ')
          ..write('source: $source, ')
          ..write('externalHash: $externalHash, ')
          ..write('excludeFromBudget: $excludeFromBudget, ')
          ..write('tags: $tags, ')
          ..write('sources: $sources, ')
          ..write('statementLocked: $statementLocked, ')
          ..write('appliedRuleId: $appliedRuleId, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, BudgetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _limitMinorMeta = const VerificationMeta(
    'limitMinor',
  );
  @override
  late final GeneratedColumn<int> limitMinor = GeneratedColumn<int>(
    'limit_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('AED'),
  );
  static const VerificationMeta _rolloverMeta = const VerificationMeta(
    'rollover',
  );
  @override
  late final GeneratedColumn<bool> rollover = GeneratedColumn<bool>(
    'rollover',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("rollover" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    categoryId,
    month,
    limitMinor,
    currency,
    rollover,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('limit_minor')) {
      context.handle(
        _limitMinorMeta,
        limitMinor.isAcceptableOrUnknown(data['limit_minor']!, _limitMinorMeta),
      );
    } else if (isInserting) {
      context.missing(_limitMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('rollover')) {
      context.handle(
        _rolloverMeta,
        rollover.isAcceptableOrUnknown(data['rollover']!, _rolloverMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {categoryId, month},
  ];
  @override
  BudgetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      limitMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}limit_minor'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      rollover: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}rollover'],
      )!,
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class BudgetRow extends DataClass implements Insertable<BudgetRow> {
  final String id;
  final String categoryId;

  /// First day of the month, `YYYY-MM-01`.
  final String month;
  final int limitMinor;
  final String currency;
  final bool rollover;
  const BudgetRow({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.limitMinor,
    required this.currency,
    required this.rollover,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category_id'] = Variable<String>(categoryId);
    map['month'] = Variable<String>(month);
    map['limit_minor'] = Variable<int>(limitMinor);
    map['currency'] = Variable<String>(currency);
    map['rollover'] = Variable<bool>(rollover);
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      month: Value(month),
      limitMinor: Value(limitMinor),
      currency: Value(currency),
      rollover: Value(rollover),
    );
  }

  factory BudgetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetRow(
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      month: serializer.fromJson<String>(json['month']),
      limitMinor: serializer.fromJson<int>(json['limitMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      rollover: serializer.fromJson<bool>(json['rollover']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoryId': serializer.toJson<String>(categoryId),
      'month': serializer.toJson<String>(month),
      'limitMinor': serializer.toJson<int>(limitMinor),
      'currency': serializer.toJson<String>(currency),
      'rollover': serializer.toJson<bool>(rollover),
    };
  }

  BudgetRow copyWith({
    String? id,
    String? categoryId,
    String? month,
    int? limitMinor,
    String? currency,
    bool? rollover,
  }) => BudgetRow(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    month: month ?? this.month,
    limitMinor: limitMinor ?? this.limitMinor,
    currency: currency ?? this.currency,
    rollover: rollover ?? this.rollover,
  );
  BudgetRow copyWithCompanion(BudgetsCompanion data) {
    return BudgetRow(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      month: data.month.present ? data.month.value : this.month,
      limitMinor: data.limitMinor.present
          ? data.limitMinor.value
          : this.limitMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      rollover: data.rollover.present ? data.rollover.value : this.rollover,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetRow(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('month: $month, ')
          ..write('limitMinor: $limitMinor, ')
          ..write('currency: $currency, ')
          ..write('rollover: $rollover')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, categoryId, month, limitMinor, currency, rollover);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetRow &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.month == this.month &&
          other.limitMinor == this.limitMinor &&
          other.currency == this.currency &&
          other.rollover == this.rollover);
}

class BudgetsCompanion extends UpdateCompanion<BudgetRow> {
  final Value<String> id;
  final Value<String> categoryId;
  final Value<String> month;
  final Value<int> limitMinor;
  final Value<String> currency;
  final Value<bool> rollover;
  final Value<int> rowid;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.month = const Value.absent(),
    this.limitMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.rollover = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetsCompanion.insert({
    required String id,
    required String categoryId,
    required String month,
    required int limitMinor,
    this.currency = const Value.absent(),
    this.rollover = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       categoryId = Value(categoryId),
       month = Value(month),
       limitMinor = Value(limitMinor);
  static Insertable<BudgetRow> custom({
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? month,
    Expression<int>? limitMinor,
    Expression<String>? currency,
    Expression<bool>? rollover,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (month != null) 'month': month,
      if (limitMinor != null) 'limit_minor': limitMinor,
      if (currency != null) 'currency': currency,
      if (rollover != null) 'rollover': rollover,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetsCompanion copyWith({
    Value<String>? id,
    Value<String>? categoryId,
    Value<String>? month,
    Value<int>? limitMinor,
    Value<String>? currency,
    Value<bool>? rollover,
    Value<int>? rowid,
  }) {
    return BudgetsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      month: month ?? this.month,
      limitMinor: limitMinor ?? this.limitMinor,
      currency: currency ?? this.currency,
      rollover: rollover ?? this.rollover,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (limitMinor.present) {
      map['limit_minor'] = Variable<int>(limitMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (rollover.present) {
      map['rollover'] = Variable<bool>(rollover.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('month: $month, ')
          ..write('limitMinor: $limitMinor, ')
          ..write('currency: $currency, ')
          ..write('rollover: $rollover, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MerchantRulesTable extends MerchantRules
    with TableInfo<$MerchantRulesTable, RuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MerchantRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _merchantKeyMeta = const VerificationMeta(
    'merchantKey',
  );
  @override
  late final GeneratedColumn<String> merchantKey = GeneratedColumn<String>(
    'merchant_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _conditionsMeta = const VerificationMeta(
    'conditions',
  );
  @override
  late final GeneratedColumn<String> conditions = GeneratedColumn<String>(
    'conditions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _renameMerchantMeta = const VerificationMeta(
    'renameMerchant',
  );
  @override
  late final GeneratedColumn<String> renameMerchant = GeneratedColumn<String>(
    'rename_merchant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _markTransferMeta = const VerificationMeta(
    'markTransfer',
  );
  @override
  late final GeneratedColumn<bool> markTransfer = GeneratedColumn<bool>(
    'mark_transfer',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mark_transfer" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _excludeFromBudgetMeta = const VerificationMeta(
    'excludeFromBudget',
  );
  @override
  late final GeneratedColumn<bool> excludeFromBudget = GeneratedColumn<bool>(
    'exclude_from_budget',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("exclude_from_budget" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    merchantKey,
    name,
    priority,
    isActive,
    conditions,
    categoryId,
    renameMerchant,
    markTransfer,
    excludeFromBudget,
    tags,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'merchant_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('merchant_key')) {
      context.handle(
        _merchantKeyMeta,
        merchantKey.isAcceptableOrUnknown(
          data['merchant_key']!,
          _merchantKeyMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('conditions')) {
      context.handle(
        _conditionsMeta,
        conditions.isAcceptableOrUnknown(data['conditions']!, _conditionsMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('rename_merchant')) {
      context.handle(
        _renameMerchantMeta,
        renameMerchant.isAcceptableOrUnknown(
          data['rename_merchant']!,
          _renameMerchantMeta,
        ),
      );
    }
    if (data.containsKey('mark_transfer')) {
      context.handle(
        _markTransferMeta,
        markTransfer.isAcceptableOrUnknown(
          data['mark_transfer']!,
          _markTransferMeta,
        ),
      );
    }
    if (data.containsKey('exclude_from_budget')) {
      context.handle(
        _excludeFromBudgetMeta,
        excludeFromBudget.isAcceptableOrUnknown(
          data['exclude_from_budget']!,
          _excludeFromBudgetMeta,
        ),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
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
  RuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      merchantKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_key'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      conditions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conditions'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      renameMerchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rename_merchant'],
      ),
      markTransfer: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mark_transfer'],
      )!,
      excludeFromBudget: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}exclude_from_budget'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MerchantRulesTable createAlias(String alias) {
    return $MerchantRulesTable(attachedDatabase, alias);
  }
}

class RuleRow extends DataClass implements Insertable<RuleRow> {
  final String id;

  /// Upsert key of the learnt "always categorise X as Y" shortcut.
  final String? merchantKey;
  final String? name;

  /// Lower runs first.
  final int priority;
  final bool isActive;

  /// JSON list of conditions, see `core/engine/rule_engine.dart`.
  final String conditions;
  final String? categoryId;
  final String? renameMerchant;
  final bool markTransfer;
  final bool excludeFromBudget;
  final String tags;
  final DateTime createdAt;
  const RuleRow({
    required this.id,
    this.merchantKey,
    this.name,
    required this.priority,
    required this.isActive,
    required this.conditions,
    this.categoryId,
    this.renameMerchant,
    required this.markTransfer,
    required this.excludeFromBudget,
    required this.tags,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || merchantKey != null) {
      map['merchant_key'] = Variable<String>(merchantKey);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['priority'] = Variable<int>(priority);
    map['is_active'] = Variable<bool>(isActive);
    map['conditions'] = Variable<String>(conditions);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || renameMerchant != null) {
      map['rename_merchant'] = Variable<String>(renameMerchant);
    }
    map['mark_transfer'] = Variable<bool>(markTransfer);
    map['exclude_from_budget'] = Variable<bool>(excludeFromBudget);
    map['tags'] = Variable<String>(tags);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MerchantRulesCompanion toCompanion(bool nullToAbsent) {
    return MerchantRulesCompanion(
      id: Value(id),
      merchantKey: merchantKey == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantKey),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      priority: Value(priority),
      isActive: Value(isActive),
      conditions: Value(conditions),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      renameMerchant: renameMerchant == null && nullToAbsent
          ? const Value.absent()
          : Value(renameMerchant),
      markTransfer: Value(markTransfer),
      excludeFromBudget: Value(excludeFromBudget),
      tags: Value(tags),
      createdAt: Value(createdAt),
    );
  }

  factory RuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuleRow(
      id: serializer.fromJson<String>(json['id']),
      merchantKey: serializer.fromJson<String?>(json['merchantKey']),
      name: serializer.fromJson<String?>(json['name']),
      priority: serializer.fromJson<int>(json['priority']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      conditions: serializer.fromJson<String>(json['conditions']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      renameMerchant: serializer.fromJson<String?>(json['renameMerchant']),
      markTransfer: serializer.fromJson<bool>(json['markTransfer']),
      excludeFromBudget: serializer.fromJson<bool>(json['excludeFromBudget']),
      tags: serializer.fromJson<String>(json['tags']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'merchantKey': serializer.toJson<String?>(merchantKey),
      'name': serializer.toJson<String?>(name),
      'priority': serializer.toJson<int>(priority),
      'isActive': serializer.toJson<bool>(isActive),
      'conditions': serializer.toJson<String>(conditions),
      'categoryId': serializer.toJson<String?>(categoryId),
      'renameMerchant': serializer.toJson<String?>(renameMerchant),
      'markTransfer': serializer.toJson<bool>(markTransfer),
      'excludeFromBudget': serializer.toJson<bool>(excludeFromBudget),
      'tags': serializer.toJson<String>(tags),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RuleRow copyWith({
    String? id,
    Value<String?> merchantKey = const Value.absent(),
    Value<String?> name = const Value.absent(),
    int? priority,
    bool? isActive,
    String? conditions,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> renameMerchant = const Value.absent(),
    bool? markTransfer,
    bool? excludeFromBudget,
    String? tags,
    DateTime? createdAt,
  }) => RuleRow(
    id: id ?? this.id,
    merchantKey: merchantKey.present ? merchantKey.value : this.merchantKey,
    name: name.present ? name.value : this.name,
    priority: priority ?? this.priority,
    isActive: isActive ?? this.isActive,
    conditions: conditions ?? this.conditions,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    renameMerchant: renameMerchant.present
        ? renameMerchant.value
        : this.renameMerchant,
    markTransfer: markTransfer ?? this.markTransfer,
    excludeFromBudget: excludeFromBudget ?? this.excludeFromBudget,
    tags: tags ?? this.tags,
    createdAt: createdAt ?? this.createdAt,
  );
  RuleRow copyWithCompanion(MerchantRulesCompanion data) {
    return RuleRow(
      id: data.id.present ? data.id.value : this.id,
      merchantKey: data.merchantKey.present
          ? data.merchantKey.value
          : this.merchantKey,
      name: data.name.present ? data.name.value : this.name,
      priority: data.priority.present ? data.priority.value : this.priority,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      conditions: data.conditions.present
          ? data.conditions.value
          : this.conditions,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      renameMerchant: data.renameMerchant.present
          ? data.renameMerchant.value
          : this.renameMerchant,
      markTransfer: data.markTransfer.present
          ? data.markTransfer.value
          : this.markTransfer,
      excludeFromBudget: data.excludeFromBudget.present
          ? data.excludeFromBudget.value
          : this.excludeFromBudget,
      tags: data.tags.present ? data.tags.value : this.tags,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuleRow(')
          ..write('id: $id, ')
          ..write('merchantKey: $merchantKey, ')
          ..write('name: $name, ')
          ..write('priority: $priority, ')
          ..write('isActive: $isActive, ')
          ..write('conditions: $conditions, ')
          ..write('categoryId: $categoryId, ')
          ..write('renameMerchant: $renameMerchant, ')
          ..write('markTransfer: $markTransfer, ')
          ..write('excludeFromBudget: $excludeFromBudget, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    merchantKey,
    name,
    priority,
    isActive,
    conditions,
    categoryId,
    renameMerchant,
    markTransfer,
    excludeFromBudget,
    tags,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuleRow &&
          other.id == this.id &&
          other.merchantKey == this.merchantKey &&
          other.name == this.name &&
          other.priority == this.priority &&
          other.isActive == this.isActive &&
          other.conditions == this.conditions &&
          other.categoryId == this.categoryId &&
          other.renameMerchant == this.renameMerchant &&
          other.markTransfer == this.markTransfer &&
          other.excludeFromBudget == this.excludeFromBudget &&
          other.tags == this.tags &&
          other.createdAt == this.createdAt);
}

class MerchantRulesCompanion extends UpdateCompanion<RuleRow> {
  final Value<String> id;
  final Value<String?> merchantKey;
  final Value<String?> name;
  final Value<int> priority;
  final Value<bool> isActive;
  final Value<String> conditions;
  final Value<String?> categoryId;
  final Value<String?> renameMerchant;
  final Value<bool> markTransfer;
  final Value<bool> excludeFromBudget;
  final Value<String> tags;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MerchantRulesCompanion({
    this.id = const Value.absent(),
    this.merchantKey = const Value.absent(),
    this.name = const Value.absent(),
    this.priority = const Value.absent(),
    this.isActive = const Value.absent(),
    this.conditions = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.renameMerchant = const Value.absent(),
    this.markTransfer = const Value.absent(),
    this.excludeFromBudget = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MerchantRulesCompanion.insert({
    required String id,
    this.merchantKey = const Value.absent(),
    this.name = const Value.absent(),
    this.priority = const Value.absent(),
    this.isActive = const Value.absent(),
    this.conditions = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.renameMerchant = const Value.absent(),
    this.markTransfer = const Value.absent(),
    this.excludeFromBudget = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<RuleRow> custom({
    Expression<String>? id,
    Expression<String>? merchantKey,
    Expression<String>? name,
    Expression<int>? priority,
    Expression<bool>? isActive,
    Expression<String>? conditions,
    Expression<String>? categoryId,
    Expression<String>? renameMerchant,
    Expression<bool>? markTransfer,
    Expression<bool>? excludeFromBudget,
    Expression<String>? tags,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (merchantKey != null) 'merchant_key': merchantKey,
      if (name != null) 'name': name,
      if (priority != null) 'priority': priority,
      if (isActive != null) 'is_active': isActive,
      if (conditions != null) 'conditions': conditions,
      if (categoryId != null) 'category_id': categoryId,
      if (renameMerchant != null) 'rename_merchant': renameMerchant,
      if (markTransfer != null) 'mark_transfer': markTransfer,
      if (excludeFromBudget != null) 'exclude_from_budget': excludeFromBudget,
      if (tags != null) 'tags': tags,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MerchantRulesCompanion copyWith({
    Value<String>? id,
    Value<String?>? merchantKey,
    Value<String?>? name,
    Value<int>? priority,
    Value<bool>? isActive,
    Value<String>? conditions,
    Value<String?>? categoryId,
    Value<String?>? renameMerchant,
    Value<bool>? markTransfer,
    Value<bool>? excludeFromBudget,
    Value<String>? tags,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MerchantRulesCompanion(
      id: id ?? this.id,
      merchantKey: merchantKey ?? this.merchantKey,
      name: name ?? this.name,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      conditions: conditions ?? this.conditions,
      categoryId: categoryId ?? this.categoryId,
      renameMerchant: renameMerchant ?? this.renameMerchant,
      markTransfer: markTransfer ?? this.markTransfer,
      excludeFromBudget: excludeFromBudget ?? this.excludeFromBudget,
      tags: tags ?? this.tags,
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
    if (merchantKey.present) {
      map['merchant_key'] = Variable<String>(merchantKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (conditions.present) {
      map['conditions'] = Variable<String>(conditions.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (renameMerchant.present) {
      map['rename_merchant'] = Variable<String>(renameMerchant.value);
    }
    if (markTransfer.present) {
      map['mark_transfer'] = Variable<bool>(markTransfer.value);
    }
    if (excludeFromBudget.present) {
      map['exclude_from_budget'] = Variable<bool>(excludeFromBudget.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
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
    return (StringBuffer('MerchantRulesCompanion(')
          ..write('id: $id, ')
          ..write('merchantKey: $merchantKey, ')
          ..write('name: $name, ')
          ..write('priority: $priority, ')
          ..write('isActive: $isActive, ')
          ..write('conditions: $conditions, ')
          ..write('categoryId: $categoryId, ')
          ..write('renameMerchant: $renameMerchant, ')
          ..write('markTransfer: $markTransfer, ')
          ..write('excludeFromBudget: $excludeFromBudget, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StatementsTable extends Statements
    with TableInfo<$StatementsTable, StatementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StatementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _periodStartMeta = const VerificationMeta(
    'periodStart',
  );
  @override
  late final GeneratedColumn<String> periodStart = GeneratedColumn<String>(
    'period_start',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _periodEndMeta = const VerificationMeta(
    'periodEnd',
  );
  @override
  late final GeneratedColumn<String> periodEnd = GeneratedColumn<String>(
    'period_end',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('AED'),
  );
  static const VerificationMeta _openingBalanceMinorMeta =
      const VerificationMeta('openingBalanceMinor');
  @override
  late final GeneratedColumn<int> openingBalanceMinor = GeneratedColumn<int>(
    'opening_balance_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closingBalanceMinorMeta =
      const VerificationMeta('closingBalanceMinor');
  @override
  late final GeneratedColumn<int> closingBalanceMinor = GeneratedColumn<int>(
    'closing_balance_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parseStatusMeta = const VerificationMeta(
    'parseStatus',
  );
  @override
  late final GeneratedColumn<String> parseStatus = GeneratedColumn<String>(
    'parse_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _reconciliationStatusMeta =
      const VerificationMeta('reconciliationStatus');
  @override
  late final GeneratedColumn<String> reconciliationStatus =
      GeneratedColumn<String>(
        'reconciliation_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('pending'),
      );
  static const VerificationMeta _diffMinorMeta = const VerificationMeta(
    'diffMinor',
  );
  @override
  late final GeneratedColumn<int> diffMinor = GeneratedColumn<int>(
    'diff_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _institutionMeta = const VerificationMeta(
    'institution',
  );
  @override
  late final GeneratedColumn<String> institution = GeneratedColumn<String>(
    'institution',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('upload'),
  );
  static const VerificationMeta _fileSha256Meta = const VerificationMeta(
    'fileSha256',
  );
  @override
  late final GeneratedColumn<String> fileSha256 = GeneratedColumn<String>(
    'file_sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalFilenameMeta = const VerificationMeta(
    'originalFilename',
  );
  @override
  late final GeneratedColumn<String> originalFilename = GeneratedColumn<String>(
    'original_filename',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parseErrorMeta = const VerificationMeta(
    'parseError',
  );
  @override
  late final GeneratedColumn<String> parseError = GeneratedColumn<String>(
    'parse_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    periodStart,
    periodEnd,
    currency,
    openingBalanceMinor,
    closingBalanceMinor,
    parseStatus,
    reconciliationStatus,
    diffMinor,
    institution,
    kind,
    source,
    fileSha256,
    originalFilename,
    parseError,
    summary,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'statements';
  @override
  VerificationContext validateIntegrity(
    Insertable<StatementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('period_start')) {
      context.handle(
        _periodStartMeta,
        periodStart.isAcceptableOrUnknown(
          data['period_start']!,
          _periodStartMeta,
        ),
      );
    }
    if (data.containsKey('period_end')) {
      context.handle(
        _periodEndMeta,
        periodEnd.isAcceptableOrUnknown(data['period_end']!, _periodEndMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('opening_balance_minor')) {
      context.handle(
        _openingBalanceMinorMeta,
        openingBalanceMinor.isAcceptableOrUnknown(
          data['opening_balance_minor']!,
          _openingBalanceMinorMeta,
        ),
      );
    }
    if (data.containsKey('closing_balance_minor')) {
      context.handle(
        _closingBalanceMinorMeta,
        closingBalanceMinor.isAcceptableOrUnknown(
          data['closing_balance_minor']!,
          _closingBalanceMinorMeta,
        ),
      );
    }
    if (data.containsKey('parse_status')) {
      context.handle(
        _parseStatusMeta,
        parseStatus.isAcceptableOrUnknown(
          data['parse_status']!,
          _parseStatusMeta,
        ),
      );
    }
    if (data.containsKey('reconciliation_status')) {
      context.handle(
        _reconciliationStatusMeta,
        reconciliationStatus.isAcceptableOrUnknown(
          data['reconciliation_status']!,
          _reconciliationStatusMeta,
        ),
      );
    }
    if (data.containsKey('diff_minor')) {
      context.handle(
        _diffMinorMeta,
        diffMinor.isAcceptableOrUnknown(data['diff_minor']!, _diffMinorMeta),
      );
    }
    if (data.containsKey('institution')) {
      context.handle(
        _institutionMeta,
        institution.isAcceptableOrUnknown(
          data['institution']!,
          _institutionMeta,
        ),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('file_sha256')) {
      context.handle(
        _fileSha256Meta,
        fileSha256.isAcceptableOrUnknown(data['file_sha256']!, _fileSha256Meta),
      );
    }
    if (data.containsKey('original_filename')) {
      context.handle(
        _originalFilenameMeta,
        originalFilename.isAcceptableOrUnknown(
          data['original_filename']!,
          _originalFilenameMeta,
        ),
      );
    }
    if (data.containsKey('parse_error')) {
      context.handle(
        _parseErrorMeta,
        parseError.isAcceptableOrUnknown(data['parse_error']!, _parseErrorMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StatementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StatementRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      periodStart: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_start'],
      ),
      periodEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_end'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      openingBalanceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opening_balance_minor'],
      ),
      closingBalanceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}closing_balance_minor'],
      ),
      parseStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parse_status'],
      )!,
      reconciliationStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reconciliation_status'],
      )!,
      diffMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}diff_minor'],
      ),
      institution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      fileSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_sha256'],
      ),
      originalFilename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_filename'],
      ),
      parseError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parse_error'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $StatementsTable createAlias(String alias) {
    return $StatementsTable(attachedDatabase, alias);
  }
}

class StatementRow extends DataClass implements Insertable<StatementRow> {
  final String id;
  final String? accountId;
  final String? periodStart;
  final String? periodEnd;
  final String currency;
  final int? openingBalanceMinor;
  final int? closingBalanceMinor;
  final String parseStatus;
  final String reconciliationStatus;
  final int? diffMinor;
  final String? institution;

  /// credit_card | bank_account
  final String? kind;

  /// upload | gmail
  final String source;
  final String? fileSha256;
  final String? originalFilename;
  final String? parseError;

  /// JSON: min due, due date, statement date, totals, warnings...
  final String? summary;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const StatementRow({
    required this.id,
    this.accountId,
    this.periodStart,
    this.periodEnd,
    required this.currency,
    this.openingBalanceMinor,
    this.closingBalanceMinor,
    required this.parseStatus,
    required this.reconciliationStatus,
    this.diffMinor,
    this.institution,
    this.kind,
    required this.source,
    this.fileSha256,
    this.originalFilename,
    this.parseError,
    this.summary,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || periodStart != null) {
      map['period_start'] = Variable<String>(periodStart);
    }
    if (!nullToAbsent || periodEnd != null) {
      map['period_end'] = Variable<String>(periodEnd);
    }
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || openingBalanceMinor != null) {
      map['opening_balance_minor'] = Variable<int>(openingBalanceMinor);
    }
    if (!nullToAbsent || closingBalanceMinor != null) {
      map['closing_balance_minor'] = Variable<int>(closingBalanceMinor);
    }
    map['parse_status'] = Variable<String>(parseStatus);
    map['reconciliation_status'] = Variable<String>(reconciliationStatus);
    if (!nullToAbsent || diffMinor != null) {
      map['diff_minor'] = Variable<int>(diffMinor);
    }
    if (!nullToAbsent || institution != null) {
      map['institution'] = Variable<String>(institution);
    }
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || fileSha256 != null) {
      map['file_sha256'] = Variable<String>(fileSha256);
    }
    if (!nullToAbsent || originalFilename != null) {
      map['original_filename'] = Variable<String>(originalFilename);
    }
    if (!nullToAbsent || parseError != null) {
      map['parse_error'] = Variable<String>(parseError);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  StatementsCompanion toCompanion(bool nullToAbsent) {
    return StatementsCompanion(
      id: Value(id),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      periodStart: periodStart == null && nullToAbsent
          ? const Value.absent()
          : Value(periodStart),
      periodEnd: periodEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(periodEnd),
      currency: Value(currency),
      openingBalanceMinor: openingBalanceMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(openingBalanceMinor),
      closingBalanceMinor: closingBalanceMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(closingBalanceMinor),
      parseStatus: Value(parseStatus),
      reconciliationStatus: Value(reconciliationStatus),
      diffMinor: diffMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(diffMinor),
      institution: institution == null && nullToAbsent
          ? const Value.absent()
          : Value(institution),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      source: Value(source),
      fileSha256: fileSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSha256),
      originalFilename: originalFilename == null && nullToAbsent
          ? const Value.absent()
          : Value(originalFilename),
      parseError: parseError == null && nullToAbsent
          ? const Value.absent()
          : Value(parseError),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory StatementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StatementRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      periodStart: serializer.fromJson<String?>(json['periodStart']),
      periodEnd: serializer.fromJson<String?>(json['periodEnd']),
      currency: serializer.fromJson<String>(json['currency']),
      openingBalanceMinor: serializer.fromJson<int?>(
        json['openingBalanceMinor'],
      ),
      closingBalanceMinor: serializer.fromJson<int?>(
        json['closingBalanceMinor'],
      ),
      parseStatus: serializer.fromJson<String>(json['parseStatus']),
      reconciliationStatus: serializer.fromJson<String>(
        json['reconciliationStatus'],
      ),
      diffMinor: serializer.fromJson<int?>(json['diffMinor']),
      institution: serializer.fromJson<String?>(json['institution']),
      kind: serializer.fromJson<String?>(json['kind']),
      source: serializer.fromJson<String>(json['source']),
      fileSha256: serializer.fromJson<String?>(json['fileSha256']),
      originalFilename: serializer.fromJson<String?>(json['originalFilename']),
      parseError: serializer.fromJson<String?>(json['parseError']),
      summary: serializer.fromJson<String?>(json['summary']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String?>(accountId),
      'periodStart': serializer.toJson<String?>(periodStart),
      'periodEnd': serializer.toJson<String?>(periodEnd),
      'currency': serializer.toJson<String>(currency),
      'openingBalanceMinor': serializer.toJson<int?>(openingBalanceMinor),
      'closingBalanceMinor': serializer.toJson<int?>(closingBalanceMinor),
      'parseStatus': serializer.toJson<String>(parseStatus),
      'reconciliationStatus': serializer.toJson<String>(reconciliationStatus),
      'diffMinor': serializer.toJson<int?>(diffMinor),
      'institution': serializer.toJson<String?>(institution),
      'kind': serializer.toJson<String?>(kind),
      'source': serializer.toJson<String>(source),
      'fileSha256': serializer.toJson<String?>(fileSha256),
      'originalFilename': serializer.toJson<String?>(originalFilename),
      'parseError': serializer.toJson<String?>(parseError),
      'summary': serializer.toJson<String?>(summary),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  StatementRow copyWith({
    String? id,
    Value<String?> accountId = const Value.absent(),
    Value<String?> periodStart = const Value.absent(),
    Value<String?> periodEnd = const Value.absent(),
    String? currency,
    Value<int?> openingBalanceMinor = const Value.absent(),
    Value<int?> closingBalanceMinor = const Value.absent(),
    String? parseStatus,
    String? reconciliationStatus,
    Value<int?> diffMinor = const Value.absent(),
    Value<String?> institution = const Value.absent(),
    Value<String?> kind = const Value.absent(),
    String? source,
    Value<String?> fileSha256 = const Value.absent(),
    Value<String?> originalFilename = const Value.absent(),
    Value<String?> parseError = const Value.absent(),
    Value<String?> summary = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => StatementRow(
    id: id ?? this.id,
    accountId: accountId.present ? accountId.value : this.accountId,
    periodStart: periodStart.present ? periodStart.value : this.periodStart,
    periodEnd: periodEnd.present ? periodEnd.value : this.periodEnd,
    currency: currency ?? this.currency,
    openingBalanceMinor: openingBalanceMinor.present
        ? openingBalanceMinor.value
        : this.openingBalanceMinor,
    closingBalanceMinor: closingBalanceMinor.present
        ? closingBalanceMinor.value
        : this.closingBalanceMinor,
    parseStatus: parseStatus ?? this.parseStatus,
    reconciliationStatus: reconciliationStatus ?? this.reconciliationStatus,
    diffMinor: diffMinor.present ? diffMinor.value : this.diffMinor,
    institution: institution.present ? institution.value : this.institution,
    kind: kind.present ? kind.value : this.kind,
    source: source ?? this.source,
    fileSha256: fileSha256.present ? fileSha256.value : this.fileSha256,
    originalFilename: originalFilename.present
        ? originalFilename.value
        : this.originalFilename,
    parseError: parseError.present ? parseError.value : this.parseError,
    summary: summary.present ? summary.value : this.summary,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  StatementRow copyWithCompanion(StatementsCompanion data) {
    return StatementRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      periodStart: data.periodStart.present
          ? data.periodStart.value
          : this.periodStart,
      periodEnd: data.periodEnd.present ? data.periodEnd.value : this.periodEnd,
      currency: data.currency.present ? data.currency.value : this.currency,
      openingBalanceMinor: data.openingBalanceMinor.present
          ? data.openingBalanceMinor.value
          : this.openingBalanceMinor,
      closingBalanceMinor: data.closingBalanceMinor.present
          ? data.closingBalanceMinor.value
          : this.closingBalanceMinor,
      parseStatus: data.parseStatus.present
          ? data.parseStatus.value
          : this.parseStatus,
      reconciliationStatus: data.reconciliationStatus.present
          ? data.reconciliationStatus.value
          : this.reconciliationStatus,
      diffMinor: data.diffMinor.present ? data.diffMinor.value : this.diffMinor,
      institution: data.institution.present
          ? data.institution.value
          : this.institution,
      kind: data.kind.present ? data.kind.value : this.kind,
      source: data.source.present ? data.source.value : this.source,
      fileSha256: data.fileSha256.present
          ? data.fileSha256.value
          : this.fileSha256,
      originalFilename: data.originalFilename.present
          ? data.originalFilename.value
          : this.originalFilename,
      parseError: data.parseError.present
          ? data.parseError.value
          : this.parseError,
      summary: data.summary.present ? data.summary.value : this.summary,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StatementRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('periodStart: $periodStart, ')
          ..write('periodEnd: $periodEnd, ')
          ..write('currency: $currency, ')
          ..write('openingBalanceMinor: $openingBalanceMinor, ')
          ..write('closingBalanceMinor: $closingBalanceMinor, ')
          ..write('parseStatus: $parseStatus, ')
          ..write('reconciliationStatus: $reconciliationStatus, ')
          ..write('diffMinor: $diffMinor, ')
          ..write('institution: $institution, ')
          ..write('kind: $kind, ')
          ..write('source: $source, ')
          ..write('fileSha256: $fileSha256, ')
          ..write('originalFilename: $originalFilename, ')
          ..write('parseError: $parseError, ')
          ..write('summary: $summary, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    periodStart,
    periodEnd,
    currency,
    openingBalanceMinor,
    closingBalanceMinor,
    parseStatus,
    reconciliationStatus,
    diffMinor,
    institution,
    kind,
    source,
    fileSha256,
    originalFilename,
    parseError,
    summary,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StatementRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.periodStart == this.periodStart &&
          other.periodEnd == this.periodEnd &&
          other.currency == this.currency &&
          other.openingBalanceMinor == this.openingBalanceMinor &&
          other.closingBalanceMinor == this.closingBalanceMinor &&
          other.parseStatus == this.parseStatus &&
          other.reconciliationStatus == this.reconciliationStatus &&
          other.diffMinor == this.diffMinor &&
          other.institution == this.institution &&
          other.kind == this.kind &&
          other.source == this.source &&
          other.fileSha256 == this.fileSha256 &&
          other.originalFilename == this.originalFilename &&
          other.parseError == this.parseError &&
          other.summary == this.summary &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class StatementsCompanion extends UpdateCompanion<StatementRow> {
  final Value<String> id;
  final Value<String?> accountId;
  final Value<String?> periodStart;
  final Value<String?> periodEnd;
  final Value<String> currency;
  final Value<int?> openingBalanceMinor;
  final Value<int?> closingBalanceMinor;
  final Value<String> parseStatus;
  final Value<String> reconciliationStatus;
  final Value<int?> diffMinor;
  final Value<String?> institution;
  final Value<String?> kind;
  final Value<String> source;
  final Value<String?> fileSha256;
  final Value<String?> originalFilename;
  final Value<String?> parseError;
  final Value<String?> summary;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const StatementsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.periodStart = const Value.absent(),
    this.periodEnd = const Value.absent(),
    this.currency = const Value.absent(),
    this.openingBalanceMinor = const Value.absent(),
    this.closingBalanceMinor = const Value.absent(),
    this.parseStatus = const Value.absent(),
    this.reconciliationStatus = const Value.absent(),
    this.diffMinor = const Value.absent(),
    this.institution = const Value.absent(),
    this.kind = const Value.absent(),
    this.source = const Value.absent(),
    this.fileSha256 = const Value.absent(),
    this.originalFilename = const Value.absent(),
    this.parseError = const Value.absent(),
    this.summary = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StatementsCompanion.insert({
    required String id,
    this.accountId = const Value.absent(),
    this.periodStart = const Value.absent(),
    this.periodEnd = const Value.absent(),
    this.currency = const Value.absent(),
    this.openingBalanceMinor = const Value.absent(),
    this.closingBalanceMinor = const Value.absent(),
    this.parseStatus = const Value.absent(),
    this.reconciliationStatus = const Value.absent(),
    this.diffMinor = const Value.absent(),
    this.institution = const Value.absent(),
    this.kind = const Value.absent(),
    this.source = const Value.absent(),
    this.fileSha256 = const Value.absent(),
    this.originalFilename = const Value.absent(),
    this.parseError = const Value.absent(),
    this.summary = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<StatementRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? periodStart,
    Expression<String>? periodEnd,
    Expression<String>? currency,
    Expression<int>? openingBalanceMinor,
    Expression<int>? closingBalanceMinor,
    Expression<String>? parseStatus,
    Expression<String>? reconciliationStatus,
    Expression<int>? diffMinor,
    Expression<String>? institution,
    Expression<String>? kind,
    Expression<String>? source,
    Expression<String>? fileSha256,
    Expression<String>? originalFilename,
    Expression<String>? parseError,
    Expression<String>? summary,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (periodStart != null) 'period_start': periodStart,
      if (periodEnd != null) 'period_end': periodEnd,
      if (currency != null) 'currency': currency,
      if (openingBalanceMinor != null)
        'opening_balance_minor': openingBalanceMinor,
      if (closingBalanceMinor != null)
        'closing_balance_minor': closingBalanceMinor,
      if (parseStatus != null) 'parse_status': parseStatus,
      if (reconciliationStatus != null)
        'reconciliation_status': reconciliationStatus,
      if (diffMinor != null) 'diff_minor': diffMinor,
      if (institution != null) 'institution': institution,
      if (kind != null) 'kind': kind,
      if (source != null) 'source': source,
      if (fileSha256 != null) 'file_sha256': fileSha256,
      if (originalFilename != null) 'original_filename': originalFilename,
      if (parseError != null) 'parse_error': parseError,
      if (summary != null) 'summary': summary,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StatementsCompanion copyWith({
    Value<String>? id,
    Value<String?>? accountId,
    Value<String?>? periodStart,
    Value<String?>? periodEnd,
    Value<String>? currency,
    Value<int?>? openingBalanceMinor,
    Value<int?>? closingBalanceMinor,
    Value<String>? parseStatus,
    Value<String>? reconciliationStatus,
    Value<int?>? diffMinor,
    Value<String?>? institution,
    Value<String?>? kind,
    Value<String>? source,
    Value<String?>? fileSha256,
    Value<String?>? originalFilename,
    Value<String?>? parseError,
    Value<String?>? summary,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return StatementsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      currency: currency ?? this.currency,
      openingBalanceMinor: openingBalanceMinor ?? this.openingBalanceMinor,
      closingBalanceMinor: closingBalanceMinor ?? this.closingBalanceMinor,
      parseStatus: parseStatus ?? this.parseStatus,
      reconciliationStatus: reconciliationStatus ?? this.reconciliationStatus,
      diffMinor: diffMinor ?? this.diffMinor,
      institution: institution ?? this.institution,
      kind: kind ?? this.kind,
      source: source ?? this.source,
      fileSha256: fileSha256 ?? this.fileSha256,
      originalFilename: originalFilename ?? this.originalFilename,
      parseError: parseError ?? this.parseError,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (periodStart.present) {
      map['period_start'] = Variable<String>(periodStart.value);
    }
    if (periodEnd.present) {
      map['period_end'] = Variable<String>(periodEnd.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (openingBalanceMinor.present) {
      map['opening_balance_minor'] = Variable<int>(openingBalanceMinor.value);
    }
    if (closingBalanceMinor.present) {
      map['closing_balance_minor'] = Variable<int>(closingBalanceMinor.value);
    }
    if (parseStatus.present) {
      map['parse_status'] = Variable<String>(parseStatus.value);
    }
    if (reconciliationStatus.present) {
      map['reconciliation_status'] = Variable<String>(
        reconciliationStatus.value,
      );
    }
    if (diffMinor.present) {
      map['diff_minor'] = Variable<int>(diffMinor.value);
    }
    if (institution.present) {
      map['institution'] = Variable<String>(institution.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (fileSha256.present) {
      map['file_sha256'] = Variable<String>(fileSha256.value);
    }
    if (originalFilename.present) {
      map['original_filename'] = Variable<String>(originalFilename.value);
    }
    if (parseError.present) {
      map['parse_error'] = Variable<String>(parseError.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StatementsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('periodStart: $periodStart, ')
          ..write('periodEnd: $periodEnd, ')
          ..write('currency: $currency, ')
          ..write('openingBalanceMinor: $openingBalanceMinor, ')
          ..write('closingBalanceMinor: $closingBalanceMinor, ')
          ..write('parseStatus: $parseStatus, ')
          ..write('reconciliationStatus: $reconciliationStatus, ')
          ..write('diffMinor: $diffMinor, ')
          ..write('institution: $institution, ')
          ..write('kind: $kind, ')
          ..write('source: $source, ')
          ..write('fileSha256: $fileSha256, ')
          ..write('originalFilename: $originalFilename, ')
          ..write('parseError: $parseError, ')
          ..write('summary: $summary, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StatementLinesTable extends StatementLines
    with TableInfo<$StatementLinesTable, StatementLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StatementLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statementIdMeta = const VerificationMeta(
    'statementId',
  );
  @override
  late final GeneratedColumn<String> statementId = GeneratedColumn<String>(
    'statement_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES statements (id)',
    ),
  );
  static const VerificationMeta _lineNoMeta = const VerificationMeta('lineNo');
  @override
  late final GeneratedColumn<int> lineNo = GeneratedColumn<int>(
    'line_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _postedOnMeta = const VerificationMeta(
    'postedOn',
  );
  @override
  late final GeneratedColumn<String> postedOn = GeneratedColumn<String>(
    'posted_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('AED'),
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foreignAmountMinorMeta =
      const VerificationMeta('foreignAmountMinor');
  @override
  late final GeneratedColumn<int> foreignAmountMinor = GeneratedColumn<int>(
    'foreign_amount_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _foreignCurrencyMeta = const VerificationMeta(
    'foreignCurrency',
  );
  @override
  late final GeneratedColumn<String> foreignCurrency = GeneratedColumn<String>(
    'foreign_currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _balanceMinorMeta = const VerificationMeta(
    'balanceMinor',
  );
  @override
  late final GeneratedColumn<int> balanceMinor = GeneratedColumn<int>(
    'balance_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id)',
    ),
  );
  static const VerificationMeta _matchStatusMeta = const VerificationMeta(
    'matchStatus',
  );
  @override
  late final GeneratedColumn<String> matchStatus = GeneratedColumn<String>(
    'match_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unmatched'),
  );
  static const VerificationMeta _matchScoreMeta = const VerificationMeta(
    'matchScore',
  );
  @override
  late final GeneratedColumn<int> matchScore = GeneratedColumn<int>(
    'match_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    statementId,
    lineNo,
    postedOn,
    description,
    amountMinor,
    currency,
    direction,
    foreignAmountMinor,
    foreignCurrency,
    balanceMinor,
    transactionId,
    matchStatus,
    matchScore,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'statement_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<StatementLineRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('statement_id')) {
      context.handle(
        _statementIdMeta,
        statementId.isAcceptableOrUnknown(
          data['statement_id']!,
          _statementIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_statementIdMeta);
    }
    if (data.containsKey('line_no')) {
      context.handle(
        _lineNoMeta,
        lineNo.isAcceptableOrUnknown(data['line_no']!, _lineNoMeta),
      );
    } else if (isInserting) {
      context.missing(_lineNoMeta);
    }
    if (data.containsKey('posted_on')) {
      context.handle(
        _postedOnMeta,
        postedOn.isAcceptableOrUnknown(data['posted_on']!, _postedOnMeta),
      );
    } else if (isInserting) {
      context.missing(_postedOnMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('foreign_amount_minor')) {
      context.handle(
        _foreignAmountMinorMeta,
        foreignAmountMinor.isAcceptableOrUnknown(
          data['foreign_amount_minor']!,
          _foreignAmountMinorMeta,
        ),
      );
    }
    if (data.containsKey('foreign_currency')) {
      context.handle(
        _foreignCurrencyMeta,
        foreignCurrency.isAcceptableOrUnknown(
          data['foreign_currency']!,
          _foreignCurrencyMeta,
        ),
      );
    }
    if (data.containsKey('balance_minor')) {
      context.handle(
        _balanceMinorMeta,
        balanceMinor.isAcceptableOrUnknown(
          data['balance_minor']!,
          _balanceMinorMeta,
        ),
      );
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    }
    if (data.containsKey('match_status')) {
      context.handle(
        _matchStatusMeta,
        matchStatus.isAcceptableOrUnknown(
          data['match_status']!,
          _matchStatusMeta,
        ),
      );
    }
    if (data.containsKey('match_score')) {
      context.handle(
        _matchScoreMeta,
        matchScore.isAcceptableOrUnknown(data['match_score']!, _matchScoreMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {statementId, lineNo},
  ];
  @override
  StatementLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StatementLineRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      statementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statement_id'],
      )!,
      lineNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_no'],
      )!,
      postedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}posted_on'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      foreignAmountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}foreign_amount_minor'],
      ),
      foreignCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}foreign_currency'],
      ),
      balanceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance_minor'],
      ),
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      ),
      matchStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_status'],
      )!,
      matchScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}match_score'],
      ),
    );
  }

  @override
  $StatementLinesTable createAlias(String alias) {
    return $StatementLinesTable(attachedDatabase, alias);
  }
}

class StatementLineRow extends DataClass
    implements Insertable<StatementLineRow> {
  final String id;
  final String statementId;
  final int lineNo;
  final String postedOn;
  final String description;
  final int amountMinor;
  final String currency;
  final String direction;
  final int? foreignAmountMinor;
  final String? foreignCurrency;
  final int? balanceMinor;
  final String? transactionId;

  /// created | linked | unmatched
  final String matchStatus;
  final int? matchScore;
  const StatementLineRow({
    required this.id,
    required this.statementId,
    required this.lineNo,
    required this.postedOn,
    required this.description,
    required this.amountMinor,
    required this.currency,
    required this.direction,
    this.foreignAmountMinor,
    this.foreignCurrency,
    this.balanceMinor,
    this.transactionId,
    required this.matchStatus,
    this.matchScore,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['statement_id'] = Variable<String>(statementId);
    map['line_no'] = Variable<int>(lineNo);
    map['posted_on'] = Variable<String>(postedOn);
    map['description'] = Variable<String>(description);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency'] = Variable<String>(currency);
    map['direction'] = Variable<String>(direction);
    if (!nullToAbsent || foreignAmountMinor != null) {
      map['foreign_amount_minor'] = Variable<int>(foreignAmountMinor);
    }
    if (!nullToAbsent || foreignCurrency != null) {
      map['foreign_currency'] = Variable<String>(foreignCurrency);
    }
    if (!nullToAbsent || balanceMinor != null) {
      map['balance_minor'] = Variable<int>(balanceMinor);
    }
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<String>(transactionId);
    }
    map['match_status'] = Variable<String>(matchStatus);
    if (!nullToAbsent || matchScore != null) {
      map['match_score'] = Variable<int>(matchScore);
    }
    return map;
  }

  StatementLinesCompanion toCompanion(bool nullToAbsent) {
    return StatementLinesCompanion(
      id: Value(id),
      statementId: Value(statementId),
      lineNo: Value(lineNo),
      postedOn: Value(postedOn),
      description: Value(description),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      direction: Value(direction),
      foreignAmountMinor: foreignAmountMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(foreignAmountMinor),
      foreignCurrency: foreignCurrency == null && nullToAbsent
          ? const Value.absent()
          : Value(foreignCurrency),
      balanceMinor: balanceMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(balanceMinor),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      matchStatus: Value(matchStatus),
      matchScore: matchScore == null && nullToAbsent
          ? const Value.absent()
          : Value(matchScore),
    );
  }

  factory StatementLineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StatementLineRow(
      id: serializer.fromJson<String>(json['id']),
      statementId: serializer.fromJson<String>(json['statementId']),
      lineNo: serializer.fromJson<int>(json['lineNo']),
      postedOn: serializer.fromJson<String>(json['postedOn']),
      description: serializer.fromJson<String>(json['description']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      direction: serializer.fromJson<String>(json['direction']),
      foreignAmountMinor: serializer.fromJson<int?>(json['foreignAmountMinor']),
      foreignCurrency: serializer.fromJson<String?>(json['foreignCurrency']),
      balanceMinor: serializer.fromJson<int?>(json['balanceMinor']),
      transactionId: serializer.fromJson<String?>(json['transactionId']),
      matchStatus: serializer.fromJson<String>(json['matchStatus']),
      matchScore: serializer.fromJson<int?>(json['matchScore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'statementId': serializer.toJson<String>(statementId),
      'lineNo': serializer.toJson<int>(lineNo),
      'postedOn': serializer.toJson<String>(postedOn),
      'description': serializer.toJson<String>(description),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<String>(currency),
      'direction': serializer.toJson<String>(direction),
      'foreignAmountMinor': serializer.toJson<int?>(foreignAmountMinor),
      'foreignCurrency': serializer.toJson<String?>(foreignCurrency),
      'balanceMinor': serializer.toJson<int?>(balanceMinor),
      'transactionId': serializer.toJson<String?>(transactionId),
      'matchStatus': serializer.toJson<String>(matchStatus),
      'matchScore': serializer.toJson<int?>(matchScore),
    };
  }

  StatementLineRow copyWith({
    String? id,
    String? statementId,
    int? lineNo,
    String? postedOn,
    String? description,
    int? amountMinor,
    String? currency,
    String? direction,
    Value<int?> foreignAmountMinor = const Value.absent(),
    Value<String?> foreignCurrency = const Value.absent(),
    Value<int?> balanceMinor = const Value.absent(),
    Value<String?> transactionId = const Value.absent(),
    String? matchStatus,
    Value<int?> matchScore = const Value.absent(),
  }) => StatementLineRow(
    id: id ?? this.id,
    statementId: statementId ?? this.statementId,
    lineNo: lineNo ?? this.lineNo,
    postedOn: postedOn ?? this.postedOn,
    description: description ?? this.description,
    amountMinor: amountMinor ?? this.amountMinor,
    currency: currency ?? this.currency,
    direction: direction ?? this.direction,
    foreignAmountMinor: foreignAmountMinor.present
        ? foreignAmountMinor.value
        : this.foreignAmountMinor,
    foreignCurrency: foreignCurrency.present
        ? foreignCurrency.value
        : this.foreignCurrency,
    balanceMinor: balanceMinor.present ? balanceMinor.value : this.balanceMinor,
    transactionId: transactionId.present
        ? transactionId.value
        : this.transactionId,
    matchStatus: matchStatus ?? this.matchStatus,
    matchScore: matchScore.present ? matchScore.value : this.matchScore,
  );
  StatementLineRow copyWithCompanion(StatementLinesCompanion data) {
    return StatementLineRow(
      id: data.id.present ? data.id.value : this.id,
      statementId: data.statementId.present
          ? data.statementId.value
          : this.statementId,
      lineNo: data.lineNo.present ? data.lineNo.value : this.lineNo,
      postedOn: data.postedOn.present ? data.postedOn.value : this.postedOn,
      description: data.description.present
          ? data.description.value
          : this.description,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      direction: data.direction.present ? data.direction.value : this.direction,
      foreignAmountMinor: data.foreignAmountMinor.present
          ? data.foreignAmountMinor.value
          : this.foreignAmountMinor,
      foreignCurrency: data.foreignCurrency.present
          ? data.foreignCurrency.value
          : this.foreignCurrency,
      balanceMinor: data.balanceMinor.present
          ? data.balanceMinor.value
          : this.balanceMinor,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      matchStatus: data.matchStatus.present
          ? data.matchStatus.value
          : this.matchStatus,
      matchScore: data.matchScore.present
          ? data.matchScore.value
          : this.matchScore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StatementLineRow(')
          ..write('id: $id, ')
          ..write('statementId: $statementId, ')
          ..write('lineNo: $lineNo, ')
          ..write('postedOn: $postedOn, ')
          ..write('description: $description, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('direction: $direction, ')
          ..write('foreignAmountMinor: $foreignAmountMinor, ')
          ..write('foreignCurrency: $foreignCurrency, ')
          ..write('balanceMinor: $balanceMinor, ')
          ..write('transactionId: $transactionId, ')
          ..write('matchStatus: $matchStatus, ')
          ..write('matchScore: $matchScore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    statementId,
    lineNo,
    postedOn,
    description,
    amountMinor,
    currency,
    direction,
    foreignAmountMinor,
    foreignCurrency,
    balanceMinor,
    transactionId,
    matchStatus,
    matchScore,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StatementLineRow &&
          other.id == this.id &&
          other.statementId == this.statementId &&
          other.lineNo == this.lineNo &&
          other.postedOn == this.postedOn &&
          other.description == this.description &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.direction == this.direction &&
          other.foreignAmountMinor == this.foreignAmountMinor &&
          other.foreignCurrency == this.foreignCurrency &&
          other.balanceMinor == this.balanceMinor &&
          other.transactionId == this.transactionId &&
          other.matchStatus == this.matchStatus &&
          other.matchScore == this.matchScore);
}

class StatementLinesCompanion extends UpdateCompanion<StatementLineRow> {
  final Value<String> id;
  final Value<String> statementId;
  final Value<int> lineNo;
  final Value<String> postedOn;
  final Value<String> description;
  final Value<int> amountMinor;
  final Value<String> currency;
  final Value<String> direction;
  final Value<int?> foreignAmountMinor;
  final Value<String?> foreignCurrency;
  final Value<int?> balanceMinor;
  final Value<String?> transactionId;
  final Value<String> matchStatus;
  final Value<int?> matchScore;
  final Value<int> rowid;
  const StatementLinesCompanion({
    this.id = const Value.absent(),
    this.statementId = const Value.absent(),
    this.lineNo = const Value.absent(),
    this.postedOn = const Value.absent(),
    this.description = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.direction = const Value.absent(),
    this.foreignAmountMinor = const Value.absent(),
    this.foreignCurrency = const Value.absent(),
    this.balanceMinor = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.matchStatus = const Value.absent(),
    this.matchScore = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StatementLinesCompanion.insert({
    required String id,
    required String statementId,
    required int lineNo,
    required String postedOn,
    required String description,
    required int amountMinor,
    this.currency = const Value.absent(),
    required String direction,
    this.foreignAmountMinor = const Value.absent(),
    this.foreignCurrency = const Value.absent(),
    this.balanceMinor = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.matchStatus = const Value.absent(),
    this.matchScore = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       statementId = Value(statementId),
       lineNo = Value(lineNo),
       postedOn = Value(postedOn),
       description = Value(description),
       amountMinor = Value(amountMinor),
       direction = Value(direction);
  static Insertable<StatementLineRow> custom({
    Expression<String>? id,
    Expression<String>? statementId,
    Expression<int>? lineNo,
    Expression<String>? postedOn,
    Expression<String>? description,
    Expression<int>? amountMinor,
    Expression<String>? currency,
    Expression<String>? direction,
    Expression<int>? foreignAmountMinor,
    Expression<String>? foreignCurrency,
    Expression<int>? balanceMinor,
    Expression<String>? transactionId,
    Expression<String>? matchStatus,
    Expression<int>? matchScore,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (statementId != null) 'statement_id': statementId,
      if (lineNo != null) 'line_no': lineNo,
      if (postedOn != null) 'posted_on': postedOn,
      if (description != null) 'description': description,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (direction != null) 'direction': direction,
      if (foreignAmountMinor != null)
        'foreign_amount_minor': foreignAmountMinor,
      if (foreignCurrency != null) 'foreign_currency': foreignCurrency,
      if (balanceMinor != null) 'balance_minor': balanceMinor,
      if (transactionId != null) 'transaction_id': transactionId,
      if (matchStatus != null) 'match_status': matchStatus,
      if (matchScore != null) 'match_score': matchScore,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StatementLinesCompanion copyWith({
    Value<String>? id,
    Value<String>? statementId,
    Value<int>? lineNo,
    Value<String>? postedOn,
    Value<String>? description,
    Value<int>? amountMinor,
    Value<String>? currency,
    Value<String>? direction,
    Value<int?>? foreignAmountMinor,
    Value<String?>? foreignCurrency,
    Value<int?>? balanceMinor,
    Value<String?>? transactionId,
    Value<String>? matchStatus,
    Value<int?>? matchScore,
    Value<int>? rowid,
  }) {
    return StatementLinesCompanion(
      id: id ?? this.id,
      statementId: statementId ?? this.statementId,
      lineNo: lineNo ?? this.lineNo,
      postedOn: postedOn ?? this.postedOn,
      description: description ?? this.description,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      direction: direction ?? this.direction,
      foreignAmountMinor: foreignAmountMinor ?? this.foreignAmountMinor,
      foreignCurrency: foreignCurrency ?? this.foreignCurrency,
      balanceMinor: balanceMinor ?? this.balanceMinor,
      transactionId: transactionId ?? this.transactionId,
      matchStatus: matchStatus ?? this.matchStatus,
      matchScore: matchScore ?? this.matchScore,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (statementId.present) {
      map['statement_id'] = Variable<String>(statementId.value);
    }
    if (lineNo.present) {
      map['line_no'] = Variable<int>(lineNo.value);
    }
    if (postedOn.present) {
      map['posted_on'] = Variable<String>(postedOn.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (foreignAmountMinor.present) {
      map['foreign_amount_minor'] = Variable<int>(foreignAmountMinor.value);
    }
    if (foreignCurrency.present) {
      map['foreign_currency'] = Variable<String>(foreignCurrency.value);
    }
    if (balanceMinor.present) {
      map['balance_minor'] = Variable<int>(balanceMinor.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (matchStatus.present) {
      map['match_status'] = Variable<String>(matchStatus.value);
    }
    if (matchScore.present) {
      map['match_score'] = Variable<int>(matchScore.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StatementLinesCompanion(')
          ..write('id: $id, ')
          ..write('statementId: $statementId, ')
          ..write('lineNo: $lineNo, ')
          ..write('postedOn: $postedOn, ')
          ..write('description: $description, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('direction: $direction, ')
          ..write('foreignAmountMinor: $foreignAmountMinor, ')
          ..write('foreignCurrency: $foreignCurrency, ')
          ..write('balanceMinor: $balanceMinor, ')
          ..write('transactionId: $transactionId, ')
          ..write('matchStatus: $matchStatus, ')
          ..write('matchScore: $matchScore, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssetsTable extends Assets with TableInfo<$AssetsTable, AssetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('AED'),
  );
  static const VerificationMeta _costBasisMinorMeta = const VerificationMeta(
    'costBasisMinor',
  );
  @override
  late final GeneratedColumn<int> costBasisMinor = GeneratedColumn<int>(
    'cost_basis_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manualValueMinorMeta = const VerificationMeta(
    'manualValueMinor',
  );
  @override
  late final GeneratedColumn<int> manualValueMinor = GeneratedColumn<int>(
    'manual_value_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valuationSourceMeta = const VerificationMeta(
    'valuationSource',
  );
  @override
  late final GeneratedColumn<String> valuationSource = GeneratedColumn<String>(
    'valuation_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _valuedAtMeta = const VerificationMeta(
    'valuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> valuedAt = GeneratedColumn<DateTime>(
    'valued_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _acquiredOnMeta = const VerificationMeta(
    'acquiredOn',
  );
  @override
  late final GeneratedColumn<String> acquiredOn = GeneratedColumn<String>(
    'acquired_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _marketValueMinorMeta = const VerificationMeta(
    'marketValueMinor',
  );
  @override
  late final GeneratedColumn<int> marketValueMinor = GeneratedColumn<int>(
    'market_value_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _marketValuedAtMeta = const VerificationMeta(
    'marketValuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> marketValuedAt =
      GeneratedColumn<DateTime>(
        'market_valued_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _valuationNoteMeta = const VerificationMeta(
    'valuationNote',
  );
  @override
  late final GeneratedColumn<String> valuationNote = GeneratedColumn<String>(
    'valuation_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String> meta = GeneratedColumn<String>(
    'meta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    name,
    quantity,
    unit,
    currency,
    costBasisMinor,
    manualValueMinor,
    valuationSource,
    valuedAt,
    acquiredOn,
    marketValueMinor,
    marketValuedAt,
    valuationNote,
    meta,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('cost_basis_minor')) {
      context.handle(
        _costBasisMinorMeta,
        costBasisMinor.isAcceptableOrUnknown(
          data['cost_basis_minor']!,
          _costBasisMinorMeta,
        ),
      );
    }
    if (data.containsKey('manual_value_minor')) {
      context.handle(
        _manualValueMinorMeta,
        manualValueMinor.isAcceptableOrUnknown(
          data['manual_value_minor']!,
          _manualValueMinorMeta,
        ),
      );
    }
    if (data.containsKey('valuation_source')) {
      context.handle(
        _valuationSourceMeta,
        valuationSource.isAcceptableOrUnknown(
          data['valuation_source']!,
          _valuationSourceMeta,
        ),
      );
    }
    if (data.containsKey('valued_at')) {
      context.handle(
        _valuedAtMeta,
        valuedAt.isAcceptableOrUnknown(data['valued_at']!, _valuedAtMeta),
      );
    }
    if (data.containsKey('acquired_on')) {
      context.handle(
        _acquiredOnMeta,
        acquiredOn.isAcceptableOrUnknown(data['acquired_on']!, _acquiredOnMeta),
      );
    }
    if (data.containsKey('market_value_minor')) {
      context.handle(
        _marketValueMinorMeta,
        marketValueMinor.isAcceptableOrUnknown(
          data['market_value_minor']!,
          _marketValueMinorMeta,
        ),
      );
    }
    if (data.containsKey('market_valued_at')) {
      context.handle(
        _marketValuedAtMeta,
        marketValuedAt.isAcceptableOrUnknown(
          data['market_valued_at']!,
          _marketValuedAtMeta,
        ),
      );
    }
    if (data.containsKey('valuation_note')) {
      context.handle(
        _valuationNoteMeta,
        valuationNote.isAcceptableOrUnknown(
          data['valuation_note']!,
          _valuationNoteMeta,
        ),
      );
    }
    if (data.containsKey('meta')) {
      context.handle(
        _metaMeta,
        meta.isAcceptableOrUnknown(data['meta']!, _metaMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      costBasisMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_basis_minor'],
      ),
      manualValueMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manual_value_minor'],
      ),
      valuationSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valuation_source'],
      )!,
      valuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}valued_at'],
      ),
      acquiredOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}acquired_on'],
      ),
      marketValueMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}market_value_minor'],
      ),
      marketValuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}market_valued_at'],
      ),
      valuationNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valuation_note'],
      ),
      meta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $AssetsTable createAlias(String alias) {
    return $AssetsTable(attachedDatabase, alias);
  }
}

class AssetRow extends DataClass implements Insertable<AssetRow> {
  final String id;

  /// real_estate | fd | gold | stock | crypto | cash | vehicle |
  /// gold_jewellery | other
  final String kind;
  final String name;
  final double? quantity;
  final String? unit;
  final String currency;
  final int? costBasisMinor;
  final int? manualValueMinor;

  /// manual | market | estimate
  final String valuationSource;
  final DateTime? valuedAt;
  final String? acquiredOn;

  /// Latest automatic valuation (gold spot...); the manual value stays the
  /// fallback.
  final int? marketValueMinor;
  final DateTime? marketValuedAt;
  final String? valuationNote;
  final String meta;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const AssetRow({
    required this.id,
    required this.kind,
    required this.name,
    this.quantity,
    this.unit,
    required this.currency,
    this.costBasisMinor,
    this.manualValueMinor,
    required this.valuationSource,
    this.valuedAt,
    this.acquiredOn,
    this.marketValueMinor,
    this.marketValuedAt,
    this.valuationNote,
    required this.meta,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<double>(quantity);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || costBasisMinor != null) {
      map['cost_basis_minor'] = Variable<int>(costBasisMinor);
    }
    if (!nullToAbsent || manualValueMinor != null) {
      map['manual_value_minor'] = Variable<int>(manualValueMinor);
    }
    map['valuation_source'] = Variable<String>(valuationSource);
    if (!nullToAbsent || valuedAt != null) {
      map['valued_at'] = Variable<DateTime>(valuedAt);
    }
    if (!nullToAbsent || acquiredOn != null) {
      map['acquired_on'] = Variable<String>(acquiredOn);
    }
    if (!nullToAbsent || marketValueMinor != null) {
      map['market_value_minor'] = Variable<int>(marketValueMinor);
    }
    if (!nullToAbsent || marketValuedAt != null) {
      map['market_valued_at'] = Variable<DateTime>(marketValuedAt);
    }
    if (!nullToAbsent || valuationNote != null) {
      map['valuation_note'] = Variable<String>(valuationNote);
    }
    map['meta'] = Variable<String>(meta);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  AssetsCompanion toCompanion(bool nullToAbsent) {
    return AssetsCompanion(
      id: Value(id),
      kind: Value(kind),
      name: Value(name),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      currency: Value(currency),
      costBasisMinor: costBasisMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(costBasisMinor),
      manualValueMinor: manualValueMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(manualValueMinor),
      valuationSource: Value(valuationSource),
      valuedAt: valuedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(valuedAt),
      acquiredOn: acquiredOn == null && nullToAbsent
          ? const Value.absent()
          : Value(acquiredOn),
      marketValueMinor: marketValueMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(marketValueMinor),
      marketValuedAt: marketValuedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(marketValuedAt),
      valuationNote: valuationNote == null && nullToAbsent
          ? const Value.absent()
          : Value(valuationNote),
      meta: Value(meta),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory AssetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<double?>(json['quantity']),
      unit: serializer.fromJson<String?>(json['unit']),
      currency: serializer.fromJson<String>(json['currency']),
      costBasisMinor: serializer.fromJson<int?>(json['costBasisMinor']),
      manualValueMinor: serializer.fromJson<int?>(json['manualValueMinor']),
      valuationSource: serializer.fromJson<String>(json['valuationSource']),
      valuedAt: serializer.fromJson<DateTime?>(json['valuedAt']),
      acquiredOn: serializer.fromJson<String?>(json['acquiredOn']),
      marketValueMinor: serializer.fromJson<int?>(json['marketValueMinor']),
      marketValuedAt: serializer.fromJson<DateTime?>(json['marketValuedAt']),
      valuationNote: serializer.fromJson<String?>(json['valuationNote']),
      meta: serializer.fromJson<String>(json['meta']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<double?>(quantity),
      'unit': serializer.toJson<String?>(unit),
      'currency': serializer.toJson<String>(currency),
      'costBasisMinor': serializer.toJson<int?>(costBasisMinor),
      'manualValueMinor': serializer.toJson<int?>(manualValueMinor),
      'valuationSource': serializer.toJson<String>(valuationSource),
      'valuedAt': serializer.toJson<DateTime?>(valuedAt),
      'acquiredOn': serializer.toJson<String?>(acquiredOn),
      'marketValueMinor': serializer.toJson<int?>(marketValueMinor),
      'marketValuedAt': serializer.toJson<DateTime?>(marketValuedAt),
      'valuationNote': serializer.toJson<String?>(valuationNote),
      'meta': serializer.toJson<String>(meta),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  AssetRow copyWith({
    String? id,
    String? kind,
    String? name,
    Value<double?> quantity = const Value.absent(),
    Value<String?> unit = const Value.absent(),
    String? currency,
    Value<int?> costBasisMinor = const Value.absent(),
    Value<int?> manualValueMinor = const Value.absent(),
    String? valuationSource,
    Value<DateTime?> valuedAt = const Value.absent(),
    Value<String?> acquiredOn = const Value.absent(),
    Value<int?> marketValueMinor = const Value.absent(),
    Value<DateTime?> marketValuedAt = const Value.absent(),
    Value<String?> valuationNote = const Value.absent(),
    String? meta,
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => AssetRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    quantity: quantity.present ? quantity.value : this.quantity,
    unit: unit.present ? unit.value : this.unit,
    currency: currency ?? this.currency,
    costBasisMinor: costBasisMinor.present
        ? costBasisMinor.value
        : this.costBasisMinor,
    manualValueMinor: manualValueMinor.present
        ? manualValueMinor.value
        : this.manualValueMinor,
    valuationSource: valuationSource ?? this.valuationSource,
    valuedAt: valuedAt.present ? valuedAt.value : this.valuedAt,
    acquiredOn: acquiredOn.present ? acquiredOn.value : this.acquiredOn,
    marketValueMinor: marketValueMinor.present
        ? marketValueMinor.value
        : this.marketValueMinor,
    marketValuedAt: marketValuedAt.present
        ? marketValuedAt.value
        : this.marketValuedAt,
    valuationNote: valuationNote.present
        ? valuationNote.value
        : this.valuationNote,
    meta: meta ?? this.meta,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  AssetRow copyWithCompanion(AssetsCompanion data) {
    return AssetRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
      currency: data.currency.present ? data.currency.value : this.currency,
      costBasisMinor: data.costBasisMinor.present
          ? data.costBasisMinor.value
          : this.costBasisMinor,
      manualValueMinor: data.manualValueMinor.present
          ? data.manualValueMinor.value
          : this.manualValueMinor,
      valuationSource: data.valuationSource.present
          ? data.valuationSource.value
          : this.valuationSource,
      valuedAt: data.valuedAt.present ? data.valuedAt.value : this.valuedAt,
      acquiredOn: data.acquiredOn.present
          ? data.acquiredOn.value
          : this.acquiredOn,
      marketValueMinor: data.marketValueMinor.present
          ? data.marketValueMinor.value
          : this.marketValueMinor,
      marketValuedAt: data.marketValuedAt.present
          ? data.marketValuedAt.value
          : this.marketValuedAt,
      valuationNote: data.valuationNote.present
          ? data.valuationNote.value
          : this.valuationNote,
      meta: data.meta.present ? data.meta.value : this.meta,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('currency: $currency, ')
          ..write('costBasisMinor: $costBasisMinor, ')
          ..write('manualValueMinor: $manualValueMinor, ')
          ..write('valuationSource: $valuationSource, ')
          ..write('valuedAt: $valuedAt, ')
          ..write('acquiredOn: $acquiredOn, ')
          ..write('marketValueMinor: $marketValueMinor, ')
          ..write('marketValuedAt: $marketValuedAt, ')
          ..write('valuationNote: $valuationNote, ')
          ..write('meta: $meta, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    name,
    quantity,
    unit,
    currency,
    costBasisMinor,
    manualValueMinor,
    valuationSource,
    valuedAt,
    acquiredOn,
    marketValueMinor,
    marketValuedAt,
    valuationNote,
    meta,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.unit == this.unit &&
          other.currency == this.currency &&
          other.costBasisMinor == this.costBasisMinor &&
          other.manualValueMinor == this.manualValueMinor &&
          other.valuationSource == this.valuationSource &&
          other.valuedAt == this.valuedAt &&
          other.acquiredOn == this.acquiredOn &&
          other.marketValueMinor == this.marketValueMinor &&
          other.marketValuedAt == this.marketValuedAt &&
          other.valuationNote == this.valuationNote &&
          other.meta == this.meta &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class AssetsCompanion extends UpdateCompanion<AssetRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> name;
  final Value<double?> quantity;
  final Value<String?> unit;
  final Value<String> currency;
  final Value<int?> costBasisMinor;
  final Value<int?> manualValueMinor;
  final Value<String> valuationSource;
  final Value<DateTime?> valuedAt;
  final Value<String?> acquiredOn;
  final Value<int?> marketValueMinor;
  final Value<DateTime?> marketValuedAt;
  final Value<String?> valuationNote;
  final Value<String> meta;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const AssetsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.currency = const Value.absent(),
    this.costBasisMinor = const Value.absent(),
    this.manualValueMinor = const Value.absent(),
    this.valuationSource = const Value.absent(),
    this.valuedAt = const Value.absent(),
    this.acquiredOn = const Value.absent(),
    this.marketValueMinor = const Value.absent(),
    this.marketValuedAt = const Value.absent(),
    this.valuationNote = const Value.absent(),
    this.meta = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssetsCompanion.insert({
    required String id,
    required String kind,
    required String name,
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.currency = const Value.absent(),
    this.costBasisMinor = const Value.absent(),
    this.manualValueMinor = const Value.absent(),
    this.valuationSource = const Value.absent(),
    this.valuedAt = const Value.absent(),
    this.acquiredOn = const Value.absent(),
    this.marketValueMinor = const Value.absent(),
    this.marketValuedAt = const Value.absent(),
    this.valuationNote = const Value.absent(),
    this.meta = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       name = Value(name);
  static Insertable<AssetRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<double>? quantity,
    Expression<String>? unit,
    Expression<String>? currency,
    Expression<int>? costBasisMinor,
    Expression<int>? manualValueMinor,
    Expression<String>? valuationSource,
    Expression<DateTime>? valuedAt,
    Expression<String>? acquiredOn,
    Expression<int>? marketValueMinor,
    Expression<DateTime>? marketValuedAt,
    Expression<String>? valuationNote,
    Expression<String>? meta,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (currency != null) 'currency': currency,
      if (costBasisMinor != null) 'cost_basis_minor': costBasisMinor,
      if (manualValueMinor != null) 'manual_value_minor': manualValueMinor,
      if (valuationSource != null) 'valuation_source': valuationSource,
      if (valuedAt != null) 'valued_at': valuedAt,
      if (acquiredOn != null) 'acquired_on': acquiredOn,
      if (marketValueMinor != null) 'market_value_minor': marketValueMinor,
      if (marketValuedAt != null) 'market_valued_at': marketValuedAt,
      if (valuationNote != null) 'valuation_note': valuationNote,
      if (meta != null) 'meta': meta,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssetsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? name,
    Value<double?>? quantity,
    Value<String?>? unit,
    Value<String>? currency,
    Value<int?>? costBasisMinor,
    Value<int?>? manualValueMinor,
    Value<String>? valuationSource,
    Value<DateTime?>? valuedAt,
    Value<String?>? acquiredOn,
    Value<int?>? marketValueMinor,
    Value<DateTime?>? marketValuedAt,
    Value<String?>? valuationNote,
    Value<String>? meta,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return AssetsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      currency: currency ?? this.currency,
      costBasisMinor: costBasisMinor ?? this.costBasisMinor,
      manualValueMinor: manualValueMinor ?? this.manualValueMinor,
      valuationSource: valuationSource ?? this.valuationSource,
      valuedAt: valuedAt ?? this.valuedAt,
      acquiredOn: acquiredOn ?? this.acquiredOn,
      marketValueMinor: marketValueMinor ?? this.marketValueMinor,
      marketValuedAt: marketValuedAt ?? this.marketValuedAt,
      valuationNote: valuationNote ?? this.valuationNote,
      meta: meta ?? this.meta,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (costBasisMinor.present) {
      map['cost_basis_minor'] = Variable<int>(costBasisMinor.value);
    }
    if (manualValueMinor.present) {
      map['manual_value_minor'] = Variable<int>(manualValueMinor.value);
    }
    if (valuationSource.present) {
      map['valuation_source'] = Variable<String>(valuationSource.value);
    }
    if (valuedAt.present) {
      map['valued_at'] = Variable<DateTime>(valuedAt.value);
    }
    if (acquiredOn.present) {
      map['acquired_on'] = Variable<String>(acquiredOn.value);
    }
    if (marketValueMinor.present) {
      map['market_value_minor'] = Variable<int>(marketValueMinor.value);
    }
    if (marketValuedAt.present) {
      map['market_valued_at'] = Variable<DateTime>(marketValuedAt.value);
    }
    if (valuationNote.present) {
      map['valuation_note'] = Variable<String>(valuationNote.value);
    }
    if (meta.present) {
      map['meta'] = Variable<String>(meta.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('currency: $currency, ')
          ..write('costBasisMinor: $costBasisMinor, ')
          ..write('manualValueMinor: $manualValueMinor, ')
          ..write('valuationSource: $valuationSource, ')
          ..write('valuedAt: $valuedAt, ')
          ..write('acquiredOn: $acquiredOn, ')
          ..write('marketValueMinor: $marketValueMinor, ')
          ..write('marketValuedAt: $marketValuedAt, ')
          ..write('valuationNote: $valuationNote, ')
          ..write('meta: $meta, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LiabilitiesTable extends Liabilities
    with TableInfo<$LiabilitiesTable, LiabilityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LiabilitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _lenderMeta = const VerificationMeta('lender');
  @override
  late final GeneratedColumn<String> lender = GeneratedColumn<String>(
    'lender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('AED'),
  );
  static const VerificationMeta _principalMinorMeta = const VerificationMeta(
    'principalMinor',
  );
  @override
  late final GeneratedColumn<int> principalMinor = GeneratedColumn<int>(
    'principal_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outstandingMinorMeta = const VerificationMeta(
    'outstandingMinor',
  );
  @override
  late final GeneratedColumn<int> outstandingMinor = GeneratedColumn<int>(
    'outstanding_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _interestRateBpsMeta = const VerificationMeta(
    'interestRateBps',
  );
  @override
  late final GeneratedColumn<int> interestRateBps = GeneratedColumn<int>(
    'interest_rate_bps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emiMinorMeta = const VerificationMeta(
    'emiMinor',
  );
  @override
  late final GeneratedColumn<int> emiMinor = GeneratedColumn<int>(
    'emi_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextDueOnMeta = const VerificationMeta(
    'nextDueOn',
  );
  @override
  late final GeneratedColumn<String> nextDueOn = GeneratedColumn<String>(
    'next_due_on',
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    kind,
    name,
    lender,
    currency,
    principalMinor,
    outstandingMinor,
    interestRateBps,
    emiMinor,
    nextDueOn,
    endDate,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'liabilities';
  @override
  VerificationContext validateIntegrity(
    Insertable<LiabilityRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('lender')) {
      context.handle(
        _lenderMeta,
        lender.isAcceptableOrUnknown(data['lender']!, _lenderMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('principal_minor')) {
      context.handle(
        _principalMinorMeta,
        principalMinor.isAcceptableOrUnknown(
          data['principal_minor']!,
          _principalMinorMeta,
        ),
      );
    }
    if (data.containsKey('outstanding_minor')) {
      context.handle(
        _outstandingMinorMeta,
        outstandingMinor.isAcceptableOrUnknown(
          data['outstanding_minor']!,
          _outstandingMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outstandingMinorMeta);
    }
    if (data.containsKey('interest_rate_bps')) {
      context.handle(
        _interestRateBpsMeta,
        interestRateBps.isAcceptableOrUnknown(
          data['interest_rate_bps']!,
          _interestRateBpsMeta,
        ),
      );
    }
    if (data.containsKey('emi_minor')) {
      context.handle(
        _emiMinorMeta,
        emiMinor.isAcceptableOrUnknown(data['emi_minor']!, _emiMinorMeta),
      );
    }
    if (data.containsKey('next_due_on')) {
      context.handle(
        _nextDueOnMeta,
        nextDueOn.isAcceptableOrUnknown(data['next_due_on']!, _nextDueOnMeta),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LiabilityRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LiabilityRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lender'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      principalMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}principal_minor'],
      ),
      outstandingMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}outstanding_minor'],
      )!,
      interestRateBps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interest_rate_bps'],
      ),
      emiMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}emi_minor'],
      ),
      nextDueOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_due_on'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $LiabilitiesTable createAlias(String alias) {
    return $LiabilitiesTable(attachedDatabase, alias);
  }
}

class LiabilityRow extends DataClass implements Insertable<LiabilityRow> {
  final String id;
  final String? accountId;

  /// credit_card | personal_loan | auto_loan | mortgage | other
  final String kind;
  final String name;
  final String? lender;
  final String currency;
  final int? principalMinor;
  final int outstandingMinor;
  final int? interestRateBps;
  final int? emiMinor;
  final String? nextDueOn;
  final String? endDate;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const LiabilityRow({
    required this.id,
    this.accountId,
    required this.kind,
    required this.name,
    this.lender,
    required this.currency,
    this.principalMinor,
    required this.outstandingMinor,
    this.interestRateBps,
    this.emiMinor,
    this.nextDueOn,
    this.endDate,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || lender != null) {
      map['lender'] = Variable<String>(lender);
    }
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || principalMinor != null) {
      map['principal_minor'] = Variable<int>(principalMinor);
    }
    map['outstanding_minor'] = Variable<int>(outstandingMinor);
    if (!nullToAbsent || interestRateBps != null) {
      map['interest_rate_bps'] = Variable<int>(interestRateBps);
    }
    if (!nullToAbsent || emiMinor != null) {
      map['emi_minor'] = Variable<int>(emiMinor);
    }
    if (!nullToAbsent || nextDueOn != null) {
      map['next_due_on'] = Variable<String>(nextDueOn);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<String>(endDate);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LiabilitiesCompanion toCompanion(bool nullToAbsent) {
    return LiabilitiesCompanion(
      id: Value(id),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      kind: Value(kind),
      name: Value(name),
      lender: lender == null && nullToAbsent
          ? const Value.absent()
          : Value(lender),
      currency: Value(currency),
      principalMinor: principalMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(principalMinor),
      outstandingMinor: Value(outstandingMinor),
      interestRateBps: interestRateBps == null && nullToAbsent
          ? const Value.absent()
          : Value(interestRateBps),
      emiMinor: emiMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(emiMinor),
      nextDueOn: nextDueOn == null && nullToAbsent
          ? const Value.absent()
          : Value(nextDueOn),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LiabilityRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LiabilityRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      lender: serializer.fromJson<String?>(json['lender']),
      currency: serializer.fromJson<String>(json['currency']),
      principalMinor: serializer.fromJson<int?>(json['principalMinor']),
      outstandingMinor: serializer.fromJson<int>(json['outstandingMinor']),
      interestRateBps: serializer.fromJson<int?>(json['interestRateBps']),
      emiMinor: serializer.fromJson<int?>(json['emiMinor']),
      nextDueOn: serializer.fromJson<String?>(json['nextDueOn']),
      endDate: serializer.fromJson<String?>(json['endDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String?>(accountId),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'lender': serializer.toJson<String?>(lender),
      'currency': serializer.toJson<String>(currency),
      'principalMinor': serializer.toJson<int?>(principalMinor),
      'outstandingMinor': serializer.toJson<int>(outstandingMinor),
      'interestRateBps': serializer.toJson<int?>(interestRateBps),
      'emiMinor': serializer.toJson<int?>(emiMinor),
      'nextDueOn': serializer.toJson<String?>(nextDueOn),
      'endDate': serializer.toJson<String?>(endDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LiabilityRow copyWith({
    String? id,
    Value<String?> accountId = const Value.absent(),
    String? kind,
    String? name,
    Value<String?> lender = const Value.absent(),
    String? currency,
    Value<int?> principalMinor = const Value.absent(),
    int? outstandingMinor,
    Value<int?> interestRateBps = const Value.absent(),
    Value<int?> emiMinor = const Value.absent(),
    Value<String?> nextDueOn = const Value.absent(),
    Value<String?> endDate = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => LiabilityRow(
    id: id ?? this.id,
    accountId: accountId.present ? accountId.value : this.accountId,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    lender: lender.present ? lender.value : this.lender,
    currency: currency ?? this.currency,
    principalMinor: principalMinor.present
        ? principalMinor.value
        : this.principalMinor,
    outstandingMinor: outstandingMinor ?? this.outstandingMinor,
    interestRateBps: interestRateBps.present
        ? interestRateBps.value
        : this.interestRateBps,
    emiMinor: emiMinor.present ? emiMinor.value : this.emiMinor,
    nextDueOn: nextDueOn.present ? nextDueOn.value : this.nextDueOn,
    endDate: endDate.present ? endDate.value : this.endDate,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  LiabilityRow copyWithCompanion(LiabilitiesCompanion data) {
    return LiabilityRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      lender: data.lender.present ? data.lender.value : this.lender,
      currency: data.currency.present ? data.currency.value : this.currency,
      principalMinor: data.principalMinor.present
          ? data.principalMinor.value
          : this.principalMinor,
      outstandingMinor: data.outstandingMinor.present
          ? data.outstandingMinor.value
          : this.outstandingMinor,
      interestRateBps: data.interestRateBps.present
          ? data.interestRateBps.value
          : this.interestRateBps,
      emiMinor: data.emiMinor.present ? data.emiMinor.value : this.emiMinor,
      nextDueOn: data.nextDueOn.present ? data.nextDueOn.value : this.nextDueOn,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LiabilityRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('lender: $lender, ')
          ..write('currency: $currency, ')
          ..write('principalMinor: $principalMinor, ')
          ..write('outstandingMinor: $outstandingMinor, ')
          ..write('interestRateBps: $interestRateBps, ')
          ..write('emiMinor: $emiMinor, ')
          ..write('nextDueOn: $nextDueOn, ')
          ..write('endDate: $endDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    kind,
    name,
    lender,
    currency,
    principalMinor,
    outstandingMinor,
    interestRateBps,
    emiMinor,
    nextDueOn,
    endDate,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LiabilityRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.lender == this.lender &&
          other.currency == this.currency &&
          other.principalMinor == this.principalMinor &&
          other.outstandingMinor == this.outstandingMinor &&
          other.interestRateBps == this.interestRateBps &&
          other.emiMinor == this.emiMinor &&
          other.nextDueOn == this.nextDueOn &&
          other.endDate == this.endDate &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class LiabilitiesCompanion extends UpdateCompanion<LiabilityRow> {
  final Value<String> id;
  final Value<String?> accountId;
  final Value<String> kind;
  final Value<String> name;
  final Value<String?> lender;
  final Value<String> currency;
  final Value<int?> principalMinor;
  final Value<int> outstandingMinor;
  final Value<int?> interestRateBps;
  final Value<int?> emiMinor;
  final Value<String?> nextDueOn;
  final Value<String?> endDate;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const LiabilitiesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.lender = const Value.absent(),
    this.currency = const Value.absent(),
    this.principalMinor = const Value.absent(),
    this.outstandingMinor = const Value.absent(),
    this.interestRateBps = const Value.absent(),
    this.emiMinor = const Value.absent(),
    this.nextDueOn = const Value.absent(),
    this.endDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LiabilitiesCompanion.insert({
    required String id,
    this.accountId = const Value.absent(),
    required String kind,
    required String name,
    this.lender = const Value.absent(),
    this.currency = const Value.absent(),
    this.principalMinor = const Value.absent(),
    required int outstandingMinor,
    this.interestRateBps = const Value.absent(),
    this.emiMinor = const Value.absent(),
    this.nextDueOn = const Value.absent(),
    this.endDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       name = Value(name),
       outstandingMinor = Value(outstandingMinor);
  static Insertable<LiabilityRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? lender,
    Expression<String>? currency,
    Expression<int>? principalMinor,
    Expression<int>? outstandingMinor,
    Expression<int>? interestRateBps,
    Expression<int>? emiMinor,
    Expression<String>? nextDueOn,
    Expression<String>? endDate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (lender != null) 'lender': lender,
      if (currency != null) 'currency': currency,
      if (principalMinor != null) 'principal_minor': principalMinor,
      if (outstandingMinor != null) 'outstanding_minor': outstandingMinor,
      if (interestRateBps != null) 'interest_rate_bps': interestRateBps,
      if (emiMinor != null) 'emi_minor': emiMinor,
      if (nextDueOn != null) 'next_due_on': nextDueOn,
      if (endDate != null) 'end_date': endDate,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LiabilitiesCompanion copyWith({
    Value<String>? id,
    Value<String?>? accountId,
    Value<String>? kind,
    Value<String>? name,
    Value<String?>? lender,
    Value<String>? currency,
    Value<int?>? principalMinor,
    Value<int>? outstandingMinor,
    Value<int?>? interestRateBps,
    Value<int?>? emiMinor,
    Value<String?>? nextDueOn,
    Value<String?>? endDate,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return LiabilitiesCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      lender: lender ?? this.lender,
      currency: currency ?? this.currency,
      principalMinor: principalMinor ?? this.principalMinor,
      outstandingMinor: outstandingMinor ?? this.outstandingMinor,
      interestRateBps: interestRateBps ?? this.interestRateBps,
      emiMinor: emiMinor ?? this.emiMinor,
      nextDueOn: nextDueOn ?? this.nextDueOn,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lender.present) {
      map['lender'] = Variable<String>(lender.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (principalMinor.present) {
      map['principal_minor'] = Variable<int>(principalMinor.value);
    }
    if (outstandingMinor.present) {
      map['outstanding_minor'] = Variable<int>(outstandingMinor.value);
    }
    if (interestRateBps.present) {
      map['interest_rate_bps'] = Variable<int>(interestRateBps.value);
    }
    if (emiMinor.present) {
      map['emi_minor'] = Variable<int>(emiMinor.value);
    }
    if (nextDueOn.present) {
      map['next_due_on'] = Variable<String>(nextDueOn.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LiabilitiesCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('lender: $lender, ')
          ..write('currency: $currency, ')
          ..write('principalMinor: $principalMinor, ')
          ..write('outstandingMinor: $outstandingMinor, ')
          ..write('interestRateBps: $interestRateBps, ')
          ..write('emiMinor: $emiMinor, ')
          ..write('nextDueOn: $nextDueOn, ')
          ..write('endDate: $endDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SalaryRecordsTable extends SalaryRecords
    with TableInfo<$SalaryRecordsTable, SalaryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalaryRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _employerMeta = const VerificationMeta(
    'employer',
  );
  @override
  late final GeneratedColumn<String> employer = GeneratedColumn<String>(
    'employer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('AED'),
  );
  static const VerificationMeta _receivedOnMeta = const VerificationMeta(
    'receivedOn',
  );
  @override
  late final GeneratedColumn<String> receivedOn = GeneratedColumn<String>(
    'received_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES transactions (id)',
    ),
  );
  static const VerificationMeta _matchedByMeta = const VerificationMeta(
    'matchedBy',
  );
  @override
  late final GeneratedColumn<String> matchedBy = GeneratedColumn<String>(
    'matched_by',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    employer,
    amountMinor,
    currency,
    receivedOn,
    transactionId,
    matchedBy,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'salary_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<SalaryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('employer')) {
      context.handle(
        _employerMeta,
        employer.isAcceptableOrUnknown(data['employer']!, _employerMeta),
      );
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('received_on')) {
      context.handle(
        _receivedOnMeta,
        receivedOn.isAcceptableOrUnknown(data['received_on']!, _receivedOnMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedOnMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    }
    if (data.containsKey('matched_by')) {
      context.handle(
        _matchedByMeta,
        matchedBy.isAcceptableOrUnknown(data['matched_by']!, _matchedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SalaryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SalaryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      employer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employer'],
      ),
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      receivedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}received_on'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      ),
      matchedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}matched_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $SalaryRecordsTable createAlias(String alias) {
    return $SalaryRecordsTable(attachedDatabase, alias);
  }
}

class SalaryRow extends DataClass implements Insertable<SalaryRow> {
  final String id;
  final String? accountId;
  final String? employer;
  final int amountMinor;
  final String currency;
  final String receivedOn;

  /// One record per detected credit; a dismissed record keeps the link so a
  /// re-scan does not resurrect it.
  final String? transactionId;

  /// wps | payroll | salary
  final String? matchedBy;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const SalaryRow({
    required this.id,
    this.accountId,
    this.employer,
    required this.amountMinor,
    required this.currency,
    required this.receivedOn,
    this.transactionId,
    this.matchedBy,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || employer != null) {
      map['employer'] = Variable<String>(employer);
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency'] = Variable<String>(currency);
    map['received_on'] = Variable<String>(receivedOn);
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<String>(transactionId);
    }
    if (!nullToAbsent || matchedBy != null) {
      map['matched_by'] = Variable<String>(matchedBy);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  SalaryRecordsCompanion toCompanion(bool nullToAbsent) {
    return SalaryRecordsCompanion(
      id: Value(id),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      employer: employer == null && nullToAbsent
          ? const Value.absent()
          : Value(employer),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      receivedOn: Value(receivedOn),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      matchedBy: matchedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(matchedBy),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory SalaryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SalaryRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      employer: serializer.fromJson<String?>(json['employer']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      receivedOn: serializer.fromJson<String>(json['receivedOn']),
      transactionId: serializer.fromJson<String?>(json['transactionId']),
      matchedBy: serializer.fromJson<String?>(json['matchedBy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String?>(accountId),
      'employer': serializer.toJson<String?>(employer),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<String>(currency),
      'receivedOn': serializer.toJson<String>(receivedOn),
      'transactionId': serializer.toJson<String?>(transactionId),
      'matchedBy': serializer.toJson<String?>(matchedBy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  SalaryRow copyWith({
    String? id,
    Value<String?> accountId = const Value.absent(),
    Value<String?> employer = const Value.absent(),
    int? amountMinor,
    String? currency,
    String? receivedOn,
    Value<String?> transactionId = const Value.absent(),
    Value<String?> matchedBy = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => SalaryRow(
    id: id ?? this.id,
    accountId: accountId.present ? accountId.value : this.accountId,
    employer: employer.present ? employer.value : this.employer,
    amountMinor: amountMinor ?? this.amountMinor,
    currency: currency ?? this.currency,
    receivedOn: receivedOn ?? this.receivedOn,
    transactionId: transactionId.present
        ? transactionId.value
        : this.transactionId,
    matchedBy: matchedBy.present ? matchedBy.value : this.matchedBy,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  SalaryRow copyWithCompanion(SalaryRecordsCompanion data) {
    return SalaryRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      employer: data.employer.present ? data.employer.value : this.employer,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      receivedOn: data.receivedOn.present
          ? data.receivedOn.value
          : this.receivedOn,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      matchedBy: data.matchedBy.present ? data.matchedBy.value : this.matchedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SalaryRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('employer: $employer, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('receivedOn: $receivedOn, ')
          ..write('transactionId: $transactionId, ')
          ..write('matchedBy: $matchedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    employer,
    amountMinor,
    currency,
    receivedOn,
    transactionId,
    matchedBy,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SalaryRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.employer == this.employer &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.receivedOn == this.receivedOn &&
          other.transactionId == this.transactionId &&
          other.matchedBy == this.matchedBy &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class SalaryRecordsCompanion extends UpdateCompanion<SalaryRow> {
  final Value<String> id;
  final Value<String?> accountId;
  final Value<String?> employer;
  final Value<int> amountMinor;
  final Value<String> currency;
  final Value<String> receivedOn;
  final Value<String?> transactionId;
  final Value<String?> matchedBy;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const SalaryRecordsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.employer = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.receivedOn = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.matchedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SalaryRecordsCompanion.insert({
    required String id,
    this.accountId = const Value.absent(),
    this.employer = const Value.absent(),
    required int amountMinor,
    this.currency = const Value.absent(),
    required String receivedOn,
    this.transactionId = const Value.absent(),
    this.matchedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       amountMinor = Value(amountMinor),
       receivedOn = Value(receivedOn);
  static Insertable<SalaryRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? employer,
    Expression<int>? amountMinor,
    Expression<String>? currency,
    Expression<String>? receivedOn,
    Expression<String>? transactionId,
    Expression<String>? matchedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (employer != null) 'employer': employer,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (receivedOn != null) 'received_on': receivedOn,
      if (transactionId != null) 'transaction_id': transactionId,
      if (matchedBy != null) 'matched_by': matchedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SalaryRecordsCompanion copyWith({
    Value<String>? id,
    Value<String?>? accountId,
    Value<String?>? employer,
    Value<int>? amountMinor,
    Value<String>? currency,
    Value<String>? receivedOn,
    Value<String?>? transactionId,
    Value<String?>? matchedBy,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return SalaryRecordsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      employer: employer ?? this.employer,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      receivedOn: receivedOn ?? this.receivedOn,
      transactionId: transactionId ?? this.transactionId,
      matchedBy: matchedBy ?? this.matchedBy,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (employer.present) {
      map['employer'] = Variable<String>(employer.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (receivedOn.present) {
      map['received_on'] = Variable<String>(receivedOn.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (matchedBy.present) {
      map['matched_by'] = Variable<String>(matchedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalaryRecordsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('employer: $employer, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('receivedOn: $receivedOn, ')
          ..write('transactionId: $transactionId, ')
          ..write('matchedBy: $matchedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavingsGoalsTable extends SavingsGoals
    with TableInfo<$SavingsGoalsTable, GoalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavingsGoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _targetMinorMeta = const VerificationMeta(
    'targetMinor',
  );
  @override
  late final GeneratedColumn<int> targetMinor = GeneratedColumn<int>(
    'target_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedMinorMeta = const VerificationMeta(
    'savedMinor',
  );
  @override
  late final GeneratedColumn<int> savedMinor = GeneratedColumn<int>(
    'saved_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('AED'),
  );
  static const VerificationMeta _targetDateMeta = const VerificationMeta(
    'targetDate',
  );
  @override
  late final GeneratedColumn<String> targetDate = GeneratedColumn<String>(
    'target_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthlyContributionMinorMeta =
      const VerificationMeta('monthlyContributionMinor');
  @override
  late final GeneratedColumn<int> monthlyContributionMinor =
      GeneratedColumn<int>(
        'monthly_contribution_minor',
        aliasedName,
        true,
        type: DriftSqlType.int,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    targetMinor,
    savedMinor,
    currency,
    targetDate,
    monthlyContributionMinor,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'savings_goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('target_minor')) {
      context.handle(
        _targetMinorMeta,
        targetMinor.isAcceptableOrUnknown(
          data['target_minor']!,
          _targetMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetMinorMeta);
    }
    if (data.containsKey('saved_minor')) {
      context.handle(
        _savedMinorMeta,
        savedMinor.isAcceptableOrUnknown(data['saved_minor']!, _savedMinorMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('target_date')) {
      context.handle(
        _targetDateMeta,
        targetDate.isAcceptableOrUnknown(data['target_date']!, _targetDateMeta),
      );
    }
    if (data.containsKey('monthly_contribution_minor')) {
      context.handle(
        _monthlyContributionMinorMeta,
        monthlyContributionMinor.isAcceptableOrUnknown(
          data['monthly_contribution_minor']!,
          _monthlyContributionMinorMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      targetMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_minor'],
      )!,
      savedMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saved_minor'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      targetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_date'],
      ),
      monthlyContributionMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}monthly_contribution_minor'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $SavingsGoalsTable createAlias(String alias) {
    return $SavingsGoalsTable(attachedDatabase, alias);
  }
}

class GoalRow extends DataClass implements Insertable<GoalRow> {
  final String id;
  final String name;
  final int targetMinor;
  final int savedMinor;
  final String currency;
  final String? targetDate;
  final int? monthlyContributionMinor;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const GoalRow({
    required this.id,
    required this.name,
    required this.targetMinor,
    required this.savedMinor,
    required this.currency,
    this.targetDate,
    this.monthlyContributionMinor,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['target_minor'] = Variable<int>(targetMinor);
    map['saved_minor'] = Variable<int>(savedMinor);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<String>(targetDate);
    }
    if (!nullToAbsent || monthlyContributionMinor != null) {
      map['monthly_contribution_minor'] = Variable<int>(
        monthlyContributionMinor,
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  SavingsGoalsCompanion toCompanion(bool nullToAbsent) {
    return SavingsGoalsCompanion(
      id: Value(id),
      name: Value(name),
      targetMinor: Value(targetMinor),
      savedMinor: Value(savedMinor),
      currency: Value(currency),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
      monthlyContributionMinor: monthlyContributionMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(monthlyContributionMinor),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory GoalRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      targetMinor: serializer.fromJson<int>(json['targetMinor']),
      savedMinor: serializer.fromJson<int>(json['savedMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      targetDate: serializer.fromJson<String?>(json['targetDate']),
      monthlyContributionMinor: serializer.fromJson<int?>(
        json['monthlyContributionMinor'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'targetMinor': serializer.toJson<int>(targetMinor),
      'savedMinor': serializer.toJson<int>(savedMinor),
      'currency': serializer.toJson<String>(currency),
      'targetDate': serializer.toJson<String?>(targetDate),
      'monthlyContributionMinor': serializer.toJson<int?>(
        monthlyContributionMinor,
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  GoalRow copyWith({
    String? id,
    String? name,
    int? targetMinor,
    int? savedMinor,
    String? currency,
    Value<String?> targetDate = const Value.absent(),
    Value<int?> monthlyContributionMinor = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => GoalRow(
    id: id ?? this.id,
    name: name ?? this.name,
    targetMinor: targetMinor ?? this.targetMinor,
    savedMinor: savedMinor ?? this.savedMinor,
    currency: currency ?? this.currency,
    targetDate: targetDate.present ? targetDate.value : this.targetDate,
    monthlyContributionMinor: monthlyContributionMinor.present
        ? monthlyContributionMinor.value
        : this.monthlyContributionMinor,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  GoalRow copyWithCompanion(SavingsGoalsCompanion data) {
    return GoalRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      targetMinor: data.targetMinor.present
          ? data.targetMinor.value
          : this.targetMinor,
      savedMinor: data.savedMinor.present
          ? data.savedMinor.value
          : this.savedMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      targetDate: data.targetDate.present
          ? data.targetDate.value
          : this.targetDate,
      monthlyContributionMinor: data.monthlyContributionMinor.present
          ? data.monthlyContributionMinor.value
          : this.monthlyContributionMinor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('targetMinor: $targetMinor, ')
          ..write('savedMinor: $savedMinor, ')
          ..write('currency: $currency, ')
          ..write('targetDate: $targetDate, ')
          ..write('monthlyContributionMinor: $monthlyContributionMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    targetMinor,
    savedMinor,
    currency,
    targetDate,
    monthlyContributionMinor,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.targetMinor == this.targetMinor &&
          other.savedMinor == this.savedMinor &&
          other.currency == this.currency &&
          other.targetDate == this.targetDate &&
          other.monthlyContributionMinor == this.monthlyContributionMinor &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class SavingsGoalsCompanion extends UpdateCompanion<GoalRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> targetMinor;
  final Value<int> savedMinor;
  final Value<String> currency;
  final Value<String?> targetDate;
  final Value<int?> monthlyContributionMinor;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const SavingsGoalsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.targetMinor = const Value.absent(),
    this.savedMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.monthlyContributionMinor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavingsGoalsCompanion.insert({
    required String id,
    required String name,
    required int targetMinor,
    this.savedMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.monthlyContributionMinor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       targetMinor = Value(targetMinor);
  static Insertable<GoalRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? targetMinor,
    Expression<int>? savedMinor,
    Expression<String>? currency,
    Expression<String>? targetDate,
    Expression<int>? monthlyContributionMinor,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (targetMinor != null) 'target_minor': targetMinor,
      if (savedMinor != null) 'saved_minor': savedMinor,
      if (currency != null) 'currency': currency,
      if (targetDate != null) 'target_date': targetDate,
      if (monthlyContributionMinor != null)
        'monthly_contribution_minor': monthlyContributionMinor,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavingsGoalsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? targetMinor,
    Value<int>? savedMinor,
    Value<String>? currency,
    Value<String?>? targetDate,
    Value<int?>? monthlyContributionMinor,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return SavingsGoalsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      targetMinor: targetMinor ?? this.targetMinor,
      savedMinor: savedMinor ?? this.savedMinor,
      currency: currency ?? this.currency,
      targetDate: targetDate ?? this.targetDate,
      monthlyContributionMinor:
          monthlyContributionMinor ?? this.monthlyContributionMinor,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (targetMinor.present) {
      map['target_minor'] = Variable<int>(targetMinor.value);
    }
    if (savedMinor.present) {
      map['saved_minor'] = Variable<int>(savedMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<String>(targetDate.value);
    }
    if (monthlyContributionMinor.present) {
      map['monthly_contribution_minor'] = Variable<int>(
        monthlyContributionMinor.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavingsGoalsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('targetMinor: $targetMinor, ')
          ..write('savedMinor: $savedMinor, ')
          ..write('currency: $currency, ')
          ..write('targetDate: $targetDate, ')
          ..write('monthlyContributionMinor: $monthlyContributionMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RawIngestsTable extends RawIngests
    with TableInfo<$RawIngestsTable, RawIngestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RawIngestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelMeta = const VerificationMeta(
    'channel',
  );
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
    'channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalHashMeta = const VerificationMeta(
    'externalHash',
  );
  @override
  late final GeneratedColumn<String> externalHash = GeneratedColumn<String>(
    'external_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parseStatusMeta = const VerificationMeta(
    'parseStatus',
  );
  @override
  late final GeneratedColumn<String> parseStatus = GeneratedColumn<String>(
    'parse_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _parseResultMeta = const VerificationMeta(
    'parseResult',
  );
  @override
  late final GeneratedColumn<String> parseResult = GeneratedColumn<String>(
    'parse_result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id)',
    ),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    channel,
    externalHash,
    payload,
    parseStatus,
    parseResult,
    error,
    transactionId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'raw_ingests';
  @override
  VerificationContext validateIntegrity(
    Insertable<RawIngestRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    } else if (isInserting) {
      context.missing(_channelMeta);
    }
    if (data.containsKey('external_hash')) {
      context.handle(
        _externalHashMeta,
        externalHash.isAcceptableOrUnknown(
          data['external_hash']!,
          _externalHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_externalHashMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('parse_status')) {
      context.handle(
        _parseStatusMeta,
        parseStatus.isAcceptableOrUnknown(
          data['parse_status']!,
          _parseStatusMeta,
        ),
      );
    }
    if (data.containsKey('parse_result')) {
      context.handle(
        _parseResultMeta,
        parseResult.isAcceptableOrUnknown(
          data['parse_result']!,
          _parseResultMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
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
  RawIngestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RawIngestRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      channel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel'],
      )!,
      externalHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_hash'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      parseStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parse_status'],
      )!,
      parseResult: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parse_result'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RawIngestsTable createAlias(String alias) {
    return $RawIngestsTable(attachedDatabase, alias);
  }
}

class RawIngestRow extends DataClass implements Insertable<RawIngestRow> {
  final String id;
  final String channel;
  final String externalHash;
  final String payload;

  /// pending | parsed | failed | needs_review | skipped
  final String parseStatus;
  final String? parseResult;
  final String? error;
  final String? transactionId;
  final DateTime createdAt;
  const RawIngestRow({
    required this.id,
    required this.channel,
    required this.externalHash,
    required this.payload,
    required this.parseStatus,
    this.parseResult,
    this.error,
    this.transactionId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['channel'] = Variable<String>(channel);
    map['external_hash'] = Variable<String>(externalHash);
    map['payload'] = Variable<String>(payload);
    map['parse_status'] = Variable<String>(parseStatus);
    if (!nullToAbsent || parseResult != null) {
      map['parse_result'] = Variable<String>(parseResult);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<String>(transactionId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RawIngestsCompanion toCompanion(bool nullToAbsent) {
    return RawIngestsCompanion(
      id: Value(id),
      channel: Value(channel),
      externalHash: Value(externalHash),
      payload: Value(payload),
      parseStatus: Value(parseStatus),
      parseResult: parseResult == null && nullToAbsent
          ? const Value.absent()
          : Value(parseResult),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      createdAt: Value(createdAt),
    );
  }

  factory RawIngestRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RawIngestRow(
      id: serializer.fromJson<String>(json['id']),
      channel: serializer.fromJson<String>(json['channel']),
      externalHash: serializer.fromJson<String>(json['externalHash']),
      payload: serializer.fromJson<String>(json['payload']),
      parseStatus: serializer.fromJson<String>(json['parseStatus']),
      parseResult: serializer.fromJson<String?>(json['parseResult']),
      error: serializer.fromJson<String?>(json['error']),
      transactionId: serializer.fromJson<String?>(json['transactionId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'channel': serializer.toJson<String>(channel),
      'externalHash': serializer.toJson<String>(externalHash),
      'payload': serializer.toJson<String>(payload),
      'parseStatus': serializer.toJson<String>(parseStatus),
      'parseResult': serializer.toJson<String?>(parseResult),
      'error': serializer.toJson<String?>(error),
      'transactionId': serializer.toJson<String?>(transactionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RawIngestRow copyWith({
    String? id,
    String? channel,
    String? externalHash,
    String? payload,
    String? parseStatus,
    Value<String?> parseResult = const Value.absent(),
    Value<String?> error = const Value.absent(),
    Value<String?> transactionId = const Value.absent(),
    DateTime? createdAt,
  }) => RawIngestRow(
    id: id ?? this.id,
    channel: channel ?? this.channel,
    externalHash: externalHash ?? this.externalHash,
    payload: payload ?? this.payload,
    parseStatus: parseStatus ?? this.parseStatus,
    parseResult: parseResult.present ? parseResult.value : this.parseResult,
    error: error.present ? error.value : this.error,
    transactionId: transactionId.present
        ? transactionId.value
        : this.transactionId,
    createdAt: createdAt ?? this.createdAt,
  );
  RawIngestRow copyWithCompanion(RawIngestsCompanion data) {
    return RawIngestRow(
      id: data.id.present ? data.id.value : this.id,
      channel: data.channel.present ? data.channel.value : this.channel,
      externalHash: data.externalHash.present
          ? data.externalHash.value
          : this.externalHash,
      payload: data.payload.present ? data.payload.value : this.payload,
      parseStatus: data.parseStatus.present
          ? data.parseStatus.value
          : this.parseStatus,
      parseResult: data.parseResult.present
          ? data.parseResult.value
          : this.parseResult,
      error: data.error.present ? data.error.value : this.error,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RawIngestRow(')
          ..write('id: $id, ')
          ..write('channel: $channel, ')
          ..write('externalHash: $externalHash, ')
          ..write('payload: $payload, ')
          ..write('parseStatus: $parseStatus, ')
          ..write('parseResult: $parseResult, ')
          ..write('error: $error, ')
          ..write('transactionId: $transactionId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    channel,
    externalHash,
    payload,
    parseStatus,
    parseResult,
    error,
    transactionId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RawIngestRow &&
          other.id == this.id &&
          other.channel == this.channel &&
          other.externalHash == this.externalHash &&
          other.payload == this.payload &&
          other.parseStatus == this.parseStatus &&
          other.parseResult == this.parseResult &&
          other.error == this.error &&
          other.transactionId == this.transactionId &&
          other.createdAt == this.createdAt);
}

class RawIngestsCompanion extends UpdateCompanion<RawIngestRow> {
  final Value<String> id;
  final Value<String> channel;
  final Value<String> externalHash;
  final Value<String> payload;
  final Value<String> parseStatus;
  final Value<String?> parseResult;
  final Value<String?> error;
  final Value<String?> transactionId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RawIngestsCompanion({
    this.id = const Value.absent(),
    this.channel = const Value.absent(),
    this.externalHash = const Value.absent(),
    this.payload = const Value.absent(),
    this.parseStatus = const Value.absent(),
    this.parseResult = const Value.absent(),
    this.error = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RawIngestsCompanion.insert({
    required String id,
    required String channel,
    required String externalHash,
    required String payload,
    this.parseStatus = const Value.absent(),
    this.parseResult = const Value.absent(),
    this.error = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       channel = Value(channel),
       externalHash = Value(externalHash),
       payload = Value(payload);
  static Insertable<RawIngestRow> custom({
    Expression<String>? id,
    Expression<String>? channel,
    Expression<String>? externalHash,
    Expression<String>? payload,
    Expression<String>? parseStatus,
    Expression<String>? parseResult,
    Expression<String>? error,
    Expression<String>? transactionId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (channel != null) 'channel': channel,
      if (externalHash != null) 'external_hash': externalHash,
      if (payload != null) 'payload': payload,
      if (parseStatus != null) 'parse_status': parseStatus,
      if (parseResult != null) 'parse_result': parseResult,
      if (error != null) 'error': error,
      if (transactionId != null) 'transaction_id': transactionId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RawIngestsCompanion copyWith({
    Value<String>? id,
    Value<String>? channel,
    Value<String>? externalHash,
    Value<String>? payload,
    Value<String>? parseStatus,
    Value<String?>? parseResult,
    Value<String?>? error,
    Value<String?>? transactionId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return RawIngestsCompanion(
      id: id ?? this.id,
      channel: channel ?? this.channel,
      externalHash: externalHash ?? this.externalHash,
      payload: payload ?? this.payload,
      parseStatus: parseStatus ?? this.parseStatus,
      parseResult: parseResult ?? this.parseResult,
      error: error ?? this.error,
      transactionId: transactionId ?? this.transactionId,
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
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (externalHash.present) {
      map['external_hash'] = Variable<String>(externalHash.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (parseStatus.present) {
      map['parse_status'] = Variable<String>(parseStatus.value);
    }
    if (parseResult.present) {
      map['parse_result'] = Variable<String>(parseResult.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
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
    return (StringBuffer('RawIngestsCompanion(')
          ..write('id: $id, ')
          ..write('channel: $channel, ')
          ..write('externalHash: $externalHash, ')
          ..write('payload: $payload, ')
          ..write('parseStatus: $parseStatus, ')
          ..write('parseResult: $parseResult, ')
          ..write('error: $error, ')
          ..write('transactionId: $transactionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NetWorthSnapshotsTable extends NetWorthSnapshots
    with TableInfo<$NetWorthSnapshotsTable, SnapshotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NetWorthSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snapshotDateMeta = const VerificationMeta(
    'snapshotDate',
  );
  @override
  late final GeneratedColumn<String> snapshotDate = GeneratedColumn<String>(
    'snapshot_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _assetsMinorMeta = const VerificationMeta(
    'assetsMinor',
  );
  @override
  late final GeneratedColumn<int> assetsMinor = GeneratedColumn<int>(
    'assets_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _liabilitiesMinorMeta = const VerificationMeta(
    'liabilitiesMinor',
  );
  @override
  late final GeneratedColumn<int> liabilitiesMinor = GeneratedColumn<int>(
    'liabilities_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _netWorthMinorMeta = const VerificationMeta(
    'netWorthMinor',
  );
  @override
  late final GeneratedColumn<int> netWorthMinor = GeneratedColumn<int>(
    'net_worth_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _breakdownMeta = const VerificationMeta(
    'breakdown',
  );
  @override
  late final GeneratedColumn<String> breakdown = GeneratedColumn<String>(
    'breakdown',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    snapshotDate,
    assetsMinor,
    liabilitiesMinor,
    netWorthMinor,
    breakdown,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'net_worth_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('snapshot_date')) {
      context.handle(
        _snapshotDateMeta,
        snapshotDate.isAcceptableOrUnknown(
          data['snapshot_date']!,
          _snapshotDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotDateMeta);
    }
    if (data.containsKey('assets_minor')) {
      context.handle(
        _assetsMinorMeta,
        assetsMinor.isAcceptableOrUnknown(
          data['assets_minor']!,
          _assetsMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assetsMinorMeta);
    }
    if (data.containsKey('liabilities_minor')) {
      context.handle(
        _liabilitiesMinorMeta,
        liabilitiesMinor.isAcceptableOrUnknown(
          data['liabilities_minor']!,
          _liabilitiesMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_liabilitiesMinorMeta);
    }
    if (data.containsKey('net_worth_minor')) {
      context.handle(
        _netWorthMinorMeta,
        netWorthMinor.isAcceptableOrUnknown(
          data['net_worth_minor']!,
          _netWorthMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_netWorthMinorMeta);
    }
    if (data.containsKey('breakdown')) {
      context.handle(
        _breakdownMeta,
        breakdown.isAcceptableOrUnknown(data['breakdown']!, _breakdownMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SnapshotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnapshotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      snapshotDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_date'],
      )!,
      assetsMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}assets_minor'],
      )!,
      liabilitiesMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}liabilities_minor'],
      )!,
      netWorthMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}net_worth_minor'],
      )!,
      breakdown: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}breakdown'],
      )!,
    );
  }

  @override
  $NetWorthSnapshotsTable createAlias(String alias) {
    return $NetWorthSnapshotsTable(attachedDatabase, alias);
  }
}

class SnapshotRow extends DataClass implements Insertable<SnapshotRow> {
  final String id;
  final String snapshotDate;
  final int assetsMinor;
  final int liabilitiesMinor;
  final int netWorthMinor;
  final String breakdown;
  const SnapshotRow({
    required this.id,
    required this.snapshotDate,
    required this.assetsMinor,
    required this.liabilitiesMinor,
    required this.netWorthMinor,
    required this.breakdown,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['snapshot_date'] = Variable<String>(snapshotDate);
    map['assets_minor'] = Variable<int>(assetsMinor);
    map['liabilities_minor'] = Variable<int>(liabilitiesMinor);
    map['net_worth_minor'] = Variable<int>(netWorthMinor);
    map['breakdown'] = Variable<String>(breakdown);
    return map;
  }

  NetWorthSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return NetWorthSnapshotsCompanion(
      id: Value(id),
      snapshotDate: Value(snapshotDate),
      assetsMinor: Value(assetsMinor),
      liabilitiesMinor: Value(liabilitiesMinor),
      netWorthMinor: Value(netWorthMinor),
      breakdown: Value(breakdown),
    );
  }

  factory SnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnapshotRow(
      id: serializer.fromJson<String>(json['id']),
      snapshotDate: serializer.fromJson<String>(json['snapshotDate']),
      assetsMinor: serializer.fromJson<int>(json['assetsMinor']),
      liabilitiesMinor: serializer.fromJson<int>(json['liabilitiesMinor']),
      netWorthMinor: serializer.fromJson<int>(json['netWorthMinor']),
      breakdown: serializer.fromJson<String>(json['breakdown']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'snapshotDate': serializer.toJson<String>(snapshotDate),
      'assetsMinor': serializer.toJson<int>(assetsMinor),
      'liabilitiesMinor': serializer.toJson<int>(liabilitiesMinor),
      'netWorthMinor': serializer.toJson<int>(netWorthMinor),
      'breakdown': serializer.toJson<String>(breakdown),
    };
  }

  SnapshotRow copyWith({
    String? id,
    String? snapshotDate,
    int? assetsMinor,
    int? liabilitiesMinor,
    int? netWorthMinor,
    String? breakdown,
  }) => SnapshotRow(
    id: id ?? this.id,
    snapshotDate: snapshotDate ?? this.snapshotDate,
    assetsMinor: assetsMinor ?? this.assetsMinor,
    liabilitiesMinor: liabilitiesMinor ?? this.liabilitiesMinor,
    netWorthMinor: netWorthMinor ?? this.netWorthMinor,
    breakdown: breakdown ?? this.breakdown,
  );
  SnapshotRow copyWithCompanion(NetWorthSnapshotsCompanion data) {
    return SnapshotRow(
      id: data.id.present ? data.id.value : this.id,
      snapshotDate: data.snapshotDate.present
          ? data.snapshotDate.value
          : this.snapshotDate,
      assetsMinor: data.assetsMinor.present
          ? data.assetsMinor.value
          : this.assetsMinor,
      liabilitiesMinor: data.liabilitiesMinor.present
          ? data.liabilitiesMinor.value
          : this.liabilitiesMinor,
      netWorthMinor: data.netWorthMinor.present
          ? data.netWorthMinor.value
          : this.netWorthMinor,
      breakdown: data.breakdown.present ? data.breakdown.value : this.breakdown,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotRow(')
          ..write('id: $id, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('assetsMinor: $assetsMinor, ')
          ..write('liabilitiesMinor: $liabilitiesMinor, ')
          ..write('netWorthMinor: $netWorthMinor, ')
          ..write('breakdown: $breakdown')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    snapshotDate,
    assetsMinor,
    liabilitiesMinor,
    netWorthMinor,
    breakdown,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotRow &&
          other.id == this.id &&
          other.snapshotDate == this.snapshotDate &&
          other.assetsMinor == this.assetsMinor &&
          other.liabilitiesMinor == this.liabilitiesMinor &&
          other.netWorthMinor == this.netWorthMinor &&
          other.breakdown == this.breakdown);
}

class NetWorthSnapshotsCompanion extends UpdateCompanion<SnapshotRow> {
  final Value<String> id;
  final Value<String> snapshotDate;
  final Value<int> assetsMinor;
  final Value<int> liabilitiesMinor;
  final Value<int> netWorthMinor;
  final Value<String> breakdown;
  final Value<int> rowid;
  const NetWorthSnapshotsCompanion({
    this.id = const Value.absent(),
    this.snapshotDate = const Value.absent(),
    this.assetsMinor = const Value.absent(),
    this.liabilitiesMinor = const Value.absent(),
    this.netWorthMinor = const Value.absent(),
    this.breakdown = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NetWorthSnapshotsCompanion.insert({
    required String id,
    required String snapshotDate,
    required int assetsMinor,
    required int liabilitiesMinor,
    required int netWorthMinor,
    this.breakdown = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       snapshotDate = Value(snapshotDate),
       assetsMinor = Value(assetsMinor),
       liabilitiesMinor = Value(liabilitiesMinor),
       netWorthMinor = Value(netWorthMinor);
  static Insertable<SnapshotRow> custom({
    Expression<String>? id,
    Expression<String>? snapshotDate,
    Expression<int>? assetsMinor,
    Expression<int>? liabilitiesMinor,
    Expression<int>? netWorthMinor,
    Expression<String>? breakdown,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (snapshotDate != null) 'snapshot_date': snapshotDate,
      if (assetsMinor != null) 'assets_minor': assetsMinor,
      if (liabilitiesMinor != null) 'liabilities_minor': liabilitiesMinor,
      if (netWorthMinor != null) 'net_worth_minor': netWorthMinor,
      if (breakdown != null) 'breakdown': breakdown,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NetWorthSnapshotsCompanion copyWith({
    Value<String>? id,
    Value<String>? snapshotDate,
    Value<int>? assetsMinor,
    Value<int>? liabilitiesMinor,
    Value<int>? netWorthMinor,
    Value<String>? breakdown,
    Value<int>? rowid,
  }) {
    return NetWorthSnapshotsCompanion(
      id: id ?? this.id,
      snapshotDate: snapshotDate ?? this.snapshotDate,
      assetsMinor: assetsMinor ?? this.assetsMinor,
      liabilitiesMinor: liabilitiesMinor ?? this.liabilitiesMinor,
      netWorthMinor: netWorthMinor ?? this.netWorthMinor,
      breakdown: breakdown ?? this.breakdown,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (snapshotDate.present) {
      map['snapshot_date'] = Variable<String>(snapshotDate.value);
    }
    if (assetsMinor.present) {
      map['assets_minor'] = Variable<int>(assetsMinor.value);
    }
    if (liabilitiesMinor.present) {
      map['liabilities_minor'] = Variable<int>(liabilitiesMinor.value);
    }
    if (netWorthMinor.present) {
      map['net_worth_minor'] = Variable<int>(netWorthMinor.value);
    }
    if (breakdown.present) {
      map['breakdown'] = Variable<String>(breakdown.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NetWorthSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('assetsMinor: $assetsMinor, ')
          ..write('liabilitiesMinor: $liabilitiesMinor, ')
          ..write('netWorthMinor: $netWorthMinor, ')
          ..write('breakdown: $breakdown, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecurringReviewsTable extends RecurringReviews
    with TableInfo<$RecurringReviewsTable, ReviewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringReviewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seriesKeyMeta = const VerificationMeta(
    'seriesKey',
  );
  @override
  late final GeneratedColumn<String> seriesKey = GeneratedColumn<String>(
    'series_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [seriesKey, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_reviews';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('series_key')) {
      context.handle(
        _seriesKeyMeta,
        seriesKey.isAcceptableOrUnknown(data['series_key']!, _seriesKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesKeyMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seriesKey};
  @override
  ReviewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewRow(
      seriesKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_key'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $RecurringReviewsTable createAlias(String alias) {
    return $RecurringReviewsTable(attachedDatabase, alias);
  }
}

class ReviewRow extends DataClass implements Insertable<ReviewRow> {
  final String seriesKey;
  final String status;
  const ReviewRow({required this.seriesKey, required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['series_key'] = Variable<String>(seriesKey);
    map['status'] = Variable<String>(status);
    return map;
  }

  RecurringReviewsCompanion toCompanion(bool nullToAbsent) {
    return RecurringReviewsCompanion(
      seriesKey: Value(seriesKey),
      status: Value(status),
    );
  }

  factory ReviewRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewRow(
      seriesKey: serializer.fromJson<String>(json['seriesKey']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seriesKey': serializer.toJson<String>(seriesKey),
      'status': serializer.toJson<String>(status),
    };
  }

  ReviewRow copyWith({String? seriesKey, String? status}) => ReviewRow(
    seriesKey: seriesKey ?? this.seriesKey,
    status: status ?? this.status,
  );
  ReviewRow copyWithCompanion(RecurringReviewsCompanion data) {
    return ReviewRow(
      seriesKey: data.seriesKey.present ? data.seriesKey.value : this.seriesKey,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewRow(')
          ..write('seriesKey: $seriesKey, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(seriesKey, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewRow &&
          other.seriesKey == this.seriesKey &&
          other.status == this.status);
}

class RecurringReviewsCompanion extends UpdateCompanion<ReviewRow> {
  final Value<String> seriesKey;
  final Value<String> status;
  final Value<int> rowid;
  const RecurringReviewsCompanion({
    this.seriesKey = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecurringReviewsCompanion.insert({
    required String seriesKey,
    required String status,
    this.rowid = const Value.absent(),
  }) : seriesKey = Value(seriesKey),
       status = Value(status);
  static Insertable<ReviewRow> custom({
    Expression<String>? seriesKey,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (seriesKey != null) 'series_key': seriesKey,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecurringReviewsCompanion copyWith({
    Value<String>? seriesKey,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return RecurringReviewsCompanion(
      seriesKey: seriesKey ?? this.seriesKey,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seriesKey.present) {
      map['series_key'] = Variable<String>(seriesKey.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringReviewsCompanion(')
          ..write('seriesKey: $seriesKey, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
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
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
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
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
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

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(AppSettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
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
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
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

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
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
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PriceCacheTable extends PriceCache
    with TableInfo<$PriceCacheTable, PriceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PriceCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('AED'),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('live'),
  );
  static const VerificationMeta _quotedAtMeta = const VerificationMeta(
    'quotedAt',
  );
  @override
  late final GeneratedColumn<DateTime> quotedAt = GeneratedColumn<DateTime>(
    'quoted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    symbol,
    price,
    unit,
    source,
    status,
    quotedAt,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'price_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<PriceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('quoted_at')) {
      context.handle(
        _quotedAtMeta,
        quotedAt.isAcceptableOrUnknown(data['quoted_at']!, _quotedAtMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol};
  @override
  PriceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PriceRow(
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      quotedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}quoted_at'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $PriceCacheTable createAlias(String alias) {
    return $PriceCacheTable(attachedDatabase, alias);
  }
}

class PriceRow extends DataClass implements Insertable<PriceRow> {
  final String symbol;
  final double price;

  /// What [price] is quoted in (`AED`).
  final String unit;
  final String? source;

  /// live | stale | unavailable, as reported by the backend.
  final String status;

  /// When the source last quoted it (null when unknown).
  final DateTime? quotedAt;

  /// When this phone last fetched it.
  final DateTime fetchedAt;
  const PriceRow({
    required this.symbol,
    required this.price,
    required this.unit,
    this.source,
    required this.status,
    this.quotedAt,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['price'] = Variable<double>(price);
    map['unit'] = Variable<String>(unit);
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || quotedAt != null) {
      map['quoted_at'] = Variable<DateTime>(quotedAt);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  PriceCacheCompanion toCompanion(bool nullToAbsent) {
    return PriceCacheCompanion(
      symbol: Value(symbol),
      price: Value(price),
      unit: Value(unit),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      status: Value(status),
      quotedAt: quotedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(quotedAt),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory PriceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PriceRow(
      symbol: serializer.fromJson<String>(json['symbol']),
      price: serializer.fromJson<double>(json['price']),
      unit: serializer.fromJson<String>(json['unit']),
      source: serializer.fromJson<String?>(json['source']),
      status: serializer.fromJson<String>(json['status']),
      quotedAt: serializer.fromJson<DateTime?>(json['quotedAt']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'price': serializer.toJson<double>(price),
      'unit': serializer.toJson<String>(unit),
      'source': serializer.toJson<String?>(source),
      'status': serializer.toJson<String>(status),
      'quotedAt': serializer.toJson<DateTime?>(quotedAt),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  PriceRow copyWith({
    String? symbol,
    double? price,
    String? unit,
    Value<String?> source = const Value.absent(),
    String? status,
    Value<DateTime?> quotedAt = const Value.absent(),
    DateTime? fetchedAt,
  }) => PriceRow(
    symbol: symbol ?? this.symbol,
    price: price ?? this.price,
    unit: unit ?? this.unit,
    source: source.present ? source.value : this.source,
    status: status ?? this.status,
    quotedAt: quotedAt.present ? quotedAt.value : this.quotedAt,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  PriceRow copyWithCompanion(PriceCacheCompanion data) {
    return PriceRow(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      price: data.price.present ? data.price.value : this.price,
      unit: data.unit.present ? data.unit.value : this.unit,
      source: data.source.present ? data.source.value : this.source,
      status: data.status.present ? data.status.value : this.status,
      quotedAt: data.quotedAt.present ? data.quotedAt.value : this.quotedAt,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PriceRow(')
          ..write('symbol: $symbol, ')
          ..write('price: $price, ')
          ..write('unit: $unit, ')
          ..write('source: $source, ')
          ..write('status: $status, ')
          ..write('quotedAt: $quotedAt, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(symbol, price, unit, source, status, quotedAt, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PriceRow &&
          other.symbol == this.symbol &&
          other.price == this.price &&
          other.unit == this.unit &&
          other.source == this.source &&
          other.status == this.status &&
          other.quotedAt == this.quotedAt &&
          other.fetchedAt == this.fetchedAt);
}

class PriceCacheCompanion extends UpdateCompanion<PriceRow> {
  final Value<String> symbol;
  final Value<double> price;
  final Value<String> unit;
  final Value<String?> source;
  final Value<String> status;
  final Value<DateTime?> quotedAt;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const PriceCacheCompanion({
    this.symbol = const Value.absent(),
    this.price = const Value.absent(),
    this.unit = const Value.absent(),
    this.source = const Value.absent(),
    this.status = const Value.absent(),
    this.quotedAt = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PriceCacheCompanion.insert({
    required String symbol,
    required double price,
    this.unit = const Value.absent(),
    this.source = const Value.absent(),
    this.status = const Value.absent(),
    this.quotedAt = const Value.absent(),
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : symbol = Value(symbol),
       price = Value(price),
       fetchedAt = Value(fetchedAt);
  static Insertable<PriceRow> custom({
    Expression<String>? symbol,
    Expression<double>? price,
    Expression<String>? unit,
    Expression<String>? source,
    Expression<String>? status,
    Expression<DateTime>? quotedAt,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (price != null) 'price': price,
      if (unit != null) 'unit': unit,
      if (source != null) 'source': source,
      if (status != null) 'status': status,
      if (quotedAt != null) 'quoted_at': quotedAt,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PriceCacheCompanion copyWith({
    Value<String>? symbol,
    Value<double>? price,
    Value<String>? unit,
    Value<String?>? source,
    Value<String>? status,
    Value<DateTime?>? quotedAt,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return PriceCacheCompanion(
      symbol: symbol ?? this.symbol,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      source: source ?? this.source,
      status: status ?? this.status,
      quotedAt: quotedAt ?? this.quotedAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (quotedAt.present) {
      map['quoted_at'] = Variable<DateTime>(quotedAt.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PriceCacheCompanion(')
          ..write('symbol: $symbol, ')
          ..write('price: $price, ')
          ..write('unit: $unit, ')
          ..write('source: $source, ')
          ..write('status: $status, ')
          ..write('quotedAt: $quotedAt, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JewelleryItemsTable extends JewelleryItems
    with TableInfo<$JewelleryItemsTable, JewelleryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JewelleryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _weightGramsMeta = const VerificationMeta(
    'weightGrams',
  );
  @override
  late final GeneratedColumn<double> weightGrams = GeneratedColumn<double>(
    'weight_grams',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _karatMeta = const VerificationMeta('karat');
  @override
  late final GeneratedColumn<int> karat = GeneratedColumn<int>(
    'karat',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purityOverrideMeta = const VerificationMeta(
    'purityOverride',
  );
  @override
  late final GeneratedColumn<double> purityOverride = GeneratedColumn<double>(
    'purity_override',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _purchasePriceMinorMeta =
      const VerificationMeta('purchasePriceMinor');
  @override
  late final GeneratedColumn<int> purchasePriceMinor = GeneratedColumn<int>(
    'purchase_price_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _purchaseDateMeta = const VerificationMeta(
    'purchaseDate',
  );
  @override
  late final GeneratedColumn<String> purchaseDate = GeneratedColumn<String>(
    'purchase_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _makingChargesMinorMeta =
      const VerificationMeta('makingChargesMinor');
  @override
  late final GeneratedColumn<int> makingChargesMinor = GeneratedColumn<int>(
    'making_charges_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoPathsMeta = const VerificationMeta(
    'photoPaths',
  );
  @override
  late final GeneratedColumn<String> photoPaths = GeneratedColumn<String>(
    'photo_paths',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    weightGrams,
    karat,
    purityOverride,
    purchasePriceMinor,
    purchaseDate,
    makingChargesMinor,
    notes,
    photoPaths,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jewellery_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<JewelleryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('weight_grams')) {
      context.handle(
        _weightGramsMeta,
        weightGrams.isAcceptableOrUnknown(
          data['weight_grams']!,
          _weightGramsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_weightGramsMeta);
    }
    if (data.containsKey('karat')) {
      context.handle(
        _karatMeta,
        karat.isAcceptableOrUnknown(data['karat']!, _karatMeta),
      );
    } else if (isInserting) {
      context.missing(_karatMeta);
    }
    if (data.containsKey('purity_override')) {
      context.handle(
        _purityOverrideMeta,
        purityOverride.isAcceptableOrUnknown(
          data['purity_override']!,
          _purityOverrideMeta,
        ),
      );
    }
    if (data.containsKey('purchase_price_minor')) {
      context.handle(
        _purchasePriceMinorMeta,
        purchasePriceMinor.isAcceptableOrUnknown(
          data['purchase_price_minor']!,
          _purchasePriceMinorMeta,
        ),
      );
    }
    if (data.containsKey('purchase_date')) {
      context.handle(
        _purchaseDateMeta,
        purchaseDate.isAcceptableOrUnknown(
          data['purchase_date']!,
          _purchaseDateMeta,
        ),
      );
    }
    if (data.containsKey('making_charges_minor')) {
      context.handle(
        _makingChargesMinorMeta,
        makingChargesMinor.isAcceptableOrUnknown(
          data['making_charges_minor']!,
          _makingChargesMinorMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('photo_paths')) {
      context.handle(
        _photoPathsMeta,
        photoPaths.isAcceptableOrUnknown(data['photo_paths']!, _photoPathsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JewelleryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JewelleryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      weightGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_grams'],
      )!,
      karat: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}karat'],
      )!,
      purityOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}purity_override'],
      ),
      purchasePriceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}purchase_price_minor'],
      ),
      purchaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purchase_date'],
      ),
      makingChargesMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}making_charges_minor'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      photoPaths: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_paths'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $JewelleryItemsTable createAlias(String alias) {
    return $JewelleryItemsTable(attachedDatabase, alias);
  }
}

class JewelleryRow extends DataClass implements Insertable<JewelleryRow> {
  final String id;
  final String name;
  final double weightGrams;

  /// 24 | 22 | 21 | 18 (or 0 with a purity override).
  final int karat;

  /// Fineness 0..1 when it is not a plain karat (e.g. 0.875).
  final double? purityOverride;
  final int? purchasePriceMinor;
  final String? purchaseDate;
  final int? makingChargesMinor;
  final String? notes;

  /// JSON list of file paths inside the app-private attachments folder.
  final String photoPaths;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const JewelleryRow({
    required this.id,
    required this.name,
    required this.weightGrams,
    required this.karat,
    this.purityOverride,
    this.purchasePriceMinor,
    this.purchaseDate,
    this.makingChargesMinor,
    this.notes,
    required this.photoPaths,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['weight_grams'] = Variable<double>(weightGrams);
    map['karat'] = Variable<int>(karat);
    if (!nullToAbsent || purityOverride != null) {
      map['purity_override'] = Variable<double>(purityOverride);
    }
    if (!nullToAbsent || purchasePriceMinor != null) {
      map['purchase_price_minor'] = Variable<int>(purchasePriceMinor);
    }
    if (!nullToAbsent || purchaseDate != null) {
      map['purchase_date'] = Variable<String>(purchaseDate);
    }
    if (!nullToAbsent || makingChargesMinor != null) {
      map['making_charges_minor'] = Variable<int>(makingChargesMinor);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['photo_paths'] = Variable<String>(photoPaths);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  JewelleryItemsCompanion toCompanion(bool nullToAbsent) {
    return JewelleryItemsCompanion(
      id: Value(id),
      name: Value(name),
      weightGrams: Value(weightGrams),
      karat: Value(karat),
      purityOverride: purityOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(purityOverride),
      purchasePriceMinor: purchasePriceMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(purchasePriceMinor),
      purchaseDate: purchaseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(purchaseDate),
      makingChargesMinor: makingChargesMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(makingChargesMinor),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      photoPaths: Value(photoPaths),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory JewelleryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JewelleryRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      weightGrams: serializer.fromJson<double>(json['weightGrams']),
      karat: serializer.fromJson<int>(json['karat']),
      purityOverride: serializer.fromJson<double?>(json['purityOverride']),
      purchasePriceMinor: serializer.fromJson<int?>(json['purchasePriceMinor']),
      purchaseDate: serializer.fromJson<String?>(json['purchaseDate']),
      makingChargesMinor: serializer.fromJson<int?>(json['makingChargesMinor']),
      notes: serializer.fromJson<String?>(json['notes']),
      photoPaths: serializer.fromJson<String>(json['photoPaths']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'weightGrams': serializer.toJson<double>(weightGrams),
      'karat': serializer.toJson<int>(karat),
      'purityOverride': serializer.toJson<double?>(purityOverride),
      'purchasePriceMinor': serializer.toJson<int?>(purchasePriceMinor),
      'purchaseDate': serializer.toJson<String?>(purchaseDate),
      'makingChargesMinor': serializer.toJson<int?>(makingChargesMinor),
      'notes': serializer.toJson<String?>(notes),
      'photoPaths': serializer.toJson<String>(photoPaths),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  JewelleryRow copyWith({
    String? id,
    String? name,
    double? weightGrams,
    int? karat,
    Value<double?> purityOverride = const Value.absent(),
    Value<int?> purchasePriceMinor = const Value.absent(),
    Value<String?> purchaseDate = const Value.absent(),
    Value<int?> makingChargesMinor = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? photoPaths,
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => JewelleryRow(
    id: id ?? this.id,
    name: name ?? this.name,
    weightGrams: weightGrams ?? this.weightGrams,
    karat: karat ?? this.karat,
    purityOverride: purityOverride.present
        ? purityOverride.value
        : this.purityOverride,
    purchasePriceMinor: purchasePriceMinor.present
        ? purchasePriceMinor.value
        : this.purchasePriceMinor,
    purchaseDate: purchaseDate.present ? purchaseDate.value : this.purchaseDate,
    makingChargesMinor: makingChargesMinor.present
        ? makingChargesMinor.value
        : this.makingChargesMinor,
    notes: notes.present ? notes.value : this.notes,
    photoPaths: photoPaths ?? this.photoPaths,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  JewelleryRow copyWithCompanion(JewelleryItemsCompanion data) {
    return JewelleryRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      weightGrams: data.weightGrams.present
          ? data.weightGrams.value
          : this.weightGrams,
      karat: data.karat.present ? data.karat.value : this.karat,
      purityOverride: data.purityOverride.present
          ? data.purityOverride.value
          : this.purityOverride,
      purchasePriceMinor: data.purchasePriceMinor.present
          ? data.purchasePriceMinor.value
          : this.purchasePriceMinor,
      purchaseDate: data.purchaseDate.present
          ? data.purchaseDate.value
          : this.purchaseDate,
      makingChargesMinor: data.makingChargesMinor.present
          ? data.makingChargesMinor.value
          : this.makingChargesMinor,
      notes: data.notes.present ? data.notes.value : this.notes,
      photoPaths: data.photoPaths.present
          ? data.photoPaths.value
          : this.photoPaths,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JewelleryRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('weightGrams: $weightGrams, ')
          ..write('karat: $karat, ')
          ..write('purityOverride: $purityOverride, ')
          ..write('purchasePriceMinor: $purchasePriceMinor, ')
          ..write('purchaseDate: $purchaseDate, ')
          ..write('makingChargesMinor: $makingChargesMinor, ')
          ..write('notes: $notes, ')
          ..write('photoPaths: $photoPaths, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    weightGrams,
    karat,
    purityOverride,
    purchasePriceMinor,
    purchaseDate,
    makingChargesMinor,
    notes,
    photoPaths,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JewelleryRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.weightGrams == this.weightGrams &&
          other.karat == this.karat &&
          other.purityOverride == this.purityOverride &&
          other.purchasePriceMinor == this.purchasePriceMinor &&
          other.purchaseDate == this.purchaseDate &&
          other.makingChargesMinor == this.makingChargesMinor &&
          other.notes == this.notes &&
          other.photoPaths == this.photoPaths &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class JewelleryItemsCompanion extends UpdateCompanion<JewelleryRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> weightGrams;
  final Value<int> karat;
  final Value<double?> purityOverride;
  final Value<int?> purchasePriceMinor;
  final Value<String?> purchaseDate;
  final Value<int?> makingChargesMinor;
  final Value<String?> notes;
  final Value<String> photoPaths;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const JewelleryItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.weightGrams = const Value.absent(),
    this.karat = const Value.absent(),
    this.purityOverride = const Value.absent(),
    this.purchasePriceMinor = const Value.absent(),
    this.purchaseDate = const Value.absent(),
    this.makingChargesMinor = const Value.absent(),
    this.notes = const Value.absent(),
    this.photoPaths = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JewelleryItemsCompanion.insert({
    required String id,
    required String name,
    required double weightGrams,
    required int karat,
    this.purityOverride = const Value.absent(),
    this.purchasePriceMinor = const Value.absent(),
    this.purchaseDate = const Value.absent(),
    this.makingChargesMinor = const Value.absent(),
    this.notes = const Value.absent(),
    this.photoPaths = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       weightGrams = Value(weightGrams),
       karat = Value(karat);
  static Insertable<JewelleryRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? weightGrams,
    Expression<int>? karat,
    Expression<double>? purityOverride,
    Expression<int>? purchasePriceMinor,
    Expression<String>? purchaseDate,
    Expression<int>? makingChargesMinor,
    Expression<String>? notes,
    Expression<String>? photoPaths,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (weightGrams != null) 'weight_grams': weightGrams,
      if (karat != null) 'karat': karat,
      if (purityOverride != null) 'purity_override': purityOverride,
      if (purchasePriceMinor != null)
        'purchase_price_minor': purchasePriceMinor,
      if (purchaseDate != null) 'purchase_date': purchaseDate,
      if (makingChargesMinor != null)
        'making_charges_minor': makingChargesMinor,
      if (notes != null) 'notes': notes,
      if (photoPaths != null) 'photo_paths': photoPaths,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JewelleryItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<double>? weightGrams,
    Value<int>? karat,
    Value<double?>? purityOverride,
    Value<int?>? purchasePriceMinor,
    Value<String?>? purchaseDate,
    Value<int?>? makingChargesMinor,
    Value<String?>? notes,
    Value<String>? photoPaths,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return JewelleryItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      weightGrams: weightGrams ?? this.weightGrams,
      karat: karat ?? this.karat,
      purityOverride: purityOverride ?? this.purityOverride,
      purchasePriceMinor: purchasePriceMinor ?? this.purchasePriceMinor,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      makingChargesMinor: makingChargesMinor ?? this.makingChargesMinor,
      notes: notes ?? this.notes,
      photoPaths: photoPaths ?? this.photoPaths,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (weightGrams.present) {
      map['weight_grams'] = Variable<double>(weightGrams.value);
    }
    if (karat.present) {
      map['karat'] = Variable<int>(karat.value);
    }
    if (purityOverride.present) {
      map['purity_override'] = Variable<double>(purityOverride.value);
    }
    if (purchasePriceMinor.present) {
      map['purchase_price_minor'] = Variable<int>(purchasePriceMinor.value);
    }
    if (purchaseDate.present) {
      map['purchase_date'] = Variable<String>(purchaseDate.value);
    }
    if (makingChargesMinor.present) {
      map['making_charges_minor'] = Variable<int>(makingChargesMinor.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (photoPaths.present) {
      map['photo_paths'] = Variable<String>(photoPaths.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JewelleryItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('weightGrams: $weightGrams, ')
          ..write('karat: $karat, ')
          ..write('purityOverride: $purityOverride, ')
          ..write('purchasePriceMinor: $purchasePriceMinor, ')
          ..write('purchaseDate: $purchaseDate, ')
          ..write('makingChargesMinor: $makingChargesMinor, ')
          ..write('notes: $notes, ')
          ..write('photoPaths: $photoPaths, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentAttachmentsTable extends DocumentAttachments
    with TableInfo<$DocumentAttachmentsTable, DocumentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathsMeta = const VerificationMeta(
    'filePaths',
  );
  @override
  late final GeneratedColumn<String> filePaths = GeneratedColumn<String>(
    'file_paths',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _dueOnMeta = const VerificationMeta('dueOn');
  @override
  late final GeneratedColumn<String> dueOn = GeneratedColumn<String>(
    'due_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueKindMeta = const VerificationMeta(
    'dueKind',
  );
  @override
  late final GeneratedColumn<String> dueKind = GeneratedColumn<String>(
    'due_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('expiry'),
  );
  static const VerificationMeta _remindDaysBeforeMeta = const VerificationMeta(
    'remindDaysBefore',
  );
  @override
  late final GeneratedColumn<int> remindDaysBefore = GeneratedColumn<int>(
    'remind_days_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notificationIdMeta = const VerificationMeta(
    'notificationId',
  );
  @override
  late final GeneratedColumn<int> notificationId = GeneratedColumn<int>(
    'notification_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    category,
    notes,
    filePaths,
    dueOn,
    dueKind,
    remindDaysBefore,
    notificationId,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('file_paths')) {
      context.handle(
        _filePathsMeta,
        filePaths.isAcceptableOrUnknown(data['file_paths']!, _filePathsMeta),
      );
    }
    if (data.containsKey('due_on')) {
      context.handle(
        _dueOnMeta,
        dueOn.isAcceptableOrUnknown(data['due_on']!, _dueOnMeta),
      );
    }
    if (data.containsKey('due_kind')) {
      context.handle(
        _dueKindMeta,
        dueKind.isAcceptableOrUnknown(data['due_kind']!, _dueKindMeta),
      );
    }
    if (data.containsKey('remind_days_before')) {
      context.handle(
        _remindDaysBeforeMeta,
        remindDaysBefore.isAcceptableOrUnknown(
          data['remind_days_before']!,
          _remindDaysBeforeMeta,
        ),
      );
    }
    if (data.containsKey('notification_id')) {
      context.handle(
        _notificationIdMeta,
        notificationId.isAcceptableOrUnknown(
          data['notification_id']!,
          _notificationIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      filePaths: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_paths'],
      )!,
      dueOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_on'],
      ),
      dueKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_kind'],
      )!,
      remindDaysBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remind_days_before'],
      ),
      notificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $DocumentAttachmentsTable createAlias(String alias) {
    return $DocumentAttachmentsTable(attachedDatabase, alias);
  }
}

class DocumentRow extends DataClass implements Insertable<DocumentRow> {
  final String id;
  final String title;

  /// title_deed | fd_certificate | insurance | passport | emirates_id | other
  final String category;
  final String? notes;

  /// JSON list of file paths inside the app-private attachments folder.
  final String filePaths;

  /// ISO date (yyyy-mm-dd) of the expiry, maturity or renewal.
  final String? dueOn;

  /// expiry | maturity | renewal
  final String dueKind;

  /// Days before [dueOn] to notify; null = no reminder.
  final int? remindDaysBefore;

  /// Id of the scheduled local notification (stable per document).
  final int? notificationId;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const DocumentRow({
    required this.id,
    required this.title,
    required this.category,
    this.notes,
    required this.filePaths,
    this.dueOn,
    required this.dueKind,
    this.remindDaysBefore,
    this.notificationId,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['file_paths'] = Variable<String>(filePaths);
    if (!nullToAbsent || dueOn != null) {
      map['due_on'] = Variable<String>(dueOn);
    }
    map['due_kind'] = Variable<String>(dueKind);
    if (!nullToAbsent || remindDaysBefore != null) {
      map['remind_days_before'] = Variable<int>(remindDaysBefore);
    }
    if (!nullToAbsent || notificationId != null) {
      map['notification_id'] = Variable<int>(notificationId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  DocumentAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentAttachmentsCompanion(
      id: Value(id),
      title: Value(title),
      category: Value(category),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      filePaths: Value(filePaths),
      dueOn: dueOn == null && nullToAbsent
          ? const Value.absent()
          : Value(dueOn),
      dueKind: Value(dueKind),
      remindDaysBefore: remindDaysBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(remindDaysBefore),
      notificationId: notificationId == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationId),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory DocumentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      category: serializer.fromJson<String>(json['category']),
      notes: serializer.fromJson<String?>(json['notes']),
      filePaths: serializer.fromJson<String>(json['filePaths']),
      dueOn: serializer.fromJson<String?>(json['dueOn']),
      dueKind: serializer.fromJson<String>(json['dueKind']),
      remindDaysBefore: serializer.fromJson<int?>(json['remindDaysBefore']),
      notificationId: serializer.fromJson<int?>(json['notificationId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'category': serializer.toJson<String>(category),
      'notes': serializer.toJson<String?>(notes),
      'filePaths': serializer.toJson<String>(filePaths),
      'dueOn': serializer.toJson<String?>(dueOn),
      'dueKind': serializer.toJson<String>(dueKind),
      'remindDaysBefore': serializer.toJson<int?>(remindDaysBefore),
      'notificationId': serializer.toJson<int?>(notificationId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  DocumentRow copyWith({
    String? id,
    String? title,
    String? category,
    Value<String?> notes = const Value.absent(),
    String? filePaths,
    Value<String?> dueOn = const Value.absent(),
    String? dueKind,
    Value<int?> remindDaysBefore = const Value.absent(),
    Value<int?> notificationId = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => DocumentRow(
    id: id ?? this.id,
    title: title ?? this.title,
    category: category ?? this.category,
    notes: notes.present ? notes.value : this.notes,
    filePaths: filePaths ?? this.filePaths,
    dueOn: dueOn.present ? dueOn.value : this.dueOn,
    dueKind: dueKind ?? this.dueKind,
    remindDaysBefore: remindDaysBefore.present
        ? remindDaysBefore.value
        : this.remindDaysBefore,
    notificationId: notificationId.present
        ? notificationId.value
        : this.notificationId,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  DocumentRow copyWithCompanion(DocumentAttachmentsCompanion data) {
    return DocumentRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      category: data.category.present ? data.category.value : this.category,
      notes: data.notes.present ? data.notes.value : this.notes,
      filePaths: data.filePaths.present ? data.filePaths.value : this.filePaths,
      dueOn: data.dueOn.present ? data.dueOn.value : this.dueOn,
      dueKind: data.dueKind.present ? data.dueKind.value : this.dueKind,
      remindDaysBefore: data.remindDaysBefore.present
          ? data.remindDaysBefore.value
          : this.remindDaysBefore,
      notificationId: data.notificationId.present
          ? data.notificationId.value
          : this.notificationId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('notes: $notes, ')
          ..write('filePaths: $filePaths, ')
          ..write('dueOn: $dueOn, ')
          ..write('dueKind: $dueKind, ')
          ..write('remindDaysBefore: $remindDaysBefore, ')
          ..write('notificationId: $notificationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    category,
    notes,
    filePaths,
    dueOn,
    dueKind,
    remindDaysBefore,
    notificationId,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.category == this.category &&
          other.notes == this.notes &&
          other.filePaths == this.filePaths &&
          other.dueOn == this.dueOn &&
          other.dueKind == this.dueKind &&
          other.remindDaysBefore == this.remindDaysBefore &&
          other.notificationId == this.notificationId &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class DocumentAttachmentsCompanion extends UpdateCompanion<DocumentRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> category;
  final Value<String?> notes;
  final Value<String> filePaths;
  final Value<String?> dueOn;
  final Value<String> dueKind;
  final Value<int?> remindDaysBefore;
  final Value<int?> notificationId;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const DocumentAttachmentsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.notes = const Value.absent(),
    this.filePaths = const Value.absent(),
    this.dueOn = const Value.absent(),
    this.dueKind = const Value.absent(),
    this.remindDaysBefore = const Value.absent(),
    this.notificationId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentAttachmentsCompanion.insert({
    required String id,
    required String title,
    required String category,
    this.notes = const Value.absent(),
    this.filePaths = const Value.absent(),
    this.dueOn = const Value.absent(),
    this.dueKind = const Value.absent(),
    this.remindDaysBefore = const Value.absent(),
    this.notificationId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       category = Value(category);
  static Insertable<DocumentRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? category,
    Expression<String>? notes,
    Expression<String>? filePaths,
    Expression<String>? dueOn,
    Expression<String>? dueKind,
    Expression<int>? remindDaysBefore,
    Expression<int>? notificationId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (notes != null) 'notes': notes,
      if (filePaths != null) 'file_paths': filePaths,
      if (dueOn != null) 'due_on': dueOn,
      if (dueKind != null) 'due_kind': dueKind,
      if (remindDaysBefore != null) 'remind_days_before': remindDaysBefore,
      if (notificationId != null) 'notification_id': notificationId,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentAttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? category,
    Value<String?>? notes,
    Value<String>? filePaths,
    Value<String?>? dueOn,
    Value<String>? dueKind,
    Value<int?>? remindDaysBefore,
    Value<int?>? notificationId,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return DocumentAttachmentsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      filePaths: filePaths ?? this.filePaths,
      dueOn: dueOn ?? this.dueOn,
      dueKind: dueKind ?? this.dueKind,
      remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (filePaths.present) {
      map['file_paths'] = Variable<String>(filePaths.value);
    }
    if (dueOn.present) {
      map['due_on'] = Variable<String>(dueOn.value);
    }
    if (dueKind.present) {
      map['due_kind'] = Variable<String>(dueKind.value);
    }
    if (remindDaysBefore.present) {
      map['remind_days_before'] = Variable<int>(remindDaysBefore.value);
    }
    if (notificationId.present) {
      map['notification_id'] = Variable<int>(notificationId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentAttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('notes: $notes, ')
          ..write('filePaths: $filePaths, ')
          ..write('dueOn: $dueOn, ')
          ..write('dueKind: $dueKind, ')
          ..write('remindDaysBefore: $remindDaysBefore, ')
          ..write('notificationId: $notificationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FundHoldingsTable extends FundHoldings
    with TableInfo<$FundHoldingsTable, FundRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FundHoldingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemeCodeMeta = const VerificationMeta(
    'schemeCode',
  );
  @override
  late final GeneratedColumn<String> schemeCode = GeneratedColumn<String>(
    'scheme_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('INR'),
  );
  static const VerificationMeta _unitsMeta = const VerificationMeta('units');
  @override
  late final GeneratedColumn<double> units = GeneratedColumn<double>(
    'units',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avgCostNavMeta = const VerificationMeta(
    'avgCostNav',
  );
  @override
  late final GeneratedColumn<double> avgCostNav = GeneratedColumn<double>(
    'avg_cost_nav',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _navMeta = const VerificationMeta('nav');
  @override
  late final GeneratedColumn<double> nav = GeneratedColumn<double>(
    'nav',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _navDateMeta = const VerificationMeta(
    'navDate',
  );
  @override
  late final GeneratedColumn<String> navDate = GeneratedColumn<String>(
    'nav_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _navSourceMeta = const VerificationMeta(
    'navSource',
  );
  @override
  late final GeneratedColumn<String> navSource = GeneratedColumn<String>(
    'nav_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _navFetchedAtMeta = const VerificationMeta(
    'navFetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> navFetchedAt = GeneratedColumn<DateTime>(
    'nav_fetched_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sipAmountMinorMeta = const VerificationMeta(
    'sipAmountMinor',
  );
  @override
  late final GeneratedColumn<int> sipAmountMinor = GeneratedColumn<int>(
    'sip_amount_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sipDayMeta = const VerificationMeta('sipDay');
  @override
  late final GeneratedColumn<int> sipDay = GeneratedColumn<int>(
    'sip_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    schemeCode,
    name,
    currency,
    units,
    avgCostNav,
    nav,
    navDate,
    navSource,
    navFetchedAt,
    sipAmountMinor,
    sipDay,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fund_holdings';
  @override
  VerificationContext validateIntegrity(
    Insertable<FundRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('scheme_code')) {
      context.handle(
        _schemeCodeMeta,
        schemeCode.isAcceptableOrUnknown(data['scheme_code']!, _schemeCodeMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('units')) {
      context.handle(
        _unitsMeta,
        units.isAcceptableOrUnknown(data['units']!, _unitsMeta),
      );
    } else if (isInserting) {
      context.missing(_unitsMeta);
    }
    if (data.containsKey('avg_cost_nav')) {
      context.handle(
        _avgCostNavMeta,
        avgCostNav.isAcceptableOrUnknown(
          data['avg_cost_nav']!,
          _avgCostNavMeta,
        ),
      );
    }
    if (data.containsKey('nav')) {
      context.handle(
        _navMeta,
        nav.isAcceptableOrUnknown(data['nav']!, _navMeta),
      );
    } else if (isInserting) {
      context.missing(_navMeta);
    }
    if (data.containsKey('nav_date')) {
      context.handle(
        _navDateMeta,
        navDate.isAcceptableOrUnknown(data['nav_date']!, _navDateMeta),
      );
    }
    if (data.containsKey('nav_source')) {
      context.handle(
        _navSourceMeta,
        navSource.isAcceptableOrUnknown(data['nav_source']!, _navSourceMeta),
      );
    }
    if (data.containsKey('nav_fetched_at')) {
      context.handle(
        _navFetchedAtMeta,
        navFetchedAt.isAcceptableOrUnknown(
          data['nav_fetched_at']!,
          _navFetchedAtMeta,
        ),
      );
    }
    if (data.containsKey('sip_amount_minor')) {
      context.handle(
        _sipAmountMinorMeta,
        sipAmountMinor.isAcceptableOrUnknown(
          data['sip_amount_minor']!,
          _sipAmountMinorMeta,
        ),
      );
    }
    if (data.containsKey('sip_day')) {
      context.handle(
        _sipDayMeta,
        sipDay.isAcceptableOrUnknown(data['sip_day']!, _sipDayMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FundRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FundRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      schemeCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheme_code'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      units: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}units'],
      )!,
      avgCostNav: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_cost_nav'],
      ),
      nav: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}nav'],
      )!,
      navDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nav_date'],
      ),
      navSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nav_source'],
      )!,
      navFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}nav_fetched_at'],
      ),
      sipAmountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sip_amount_minor'],
      ),
      sipDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sip_day'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $FundHoldingsTable createAlias(String alias) {
    return $FundHoldingsTable(attachedDatabase, alias);
  }
}

class FundRow extends DataClass implements Insertable<FundRow> {
  final String id;

  /// india_mf | manual
  final String kind;
  final String? schemeCode;
  final String name;

  /// Currency of the NAV (INR for Indian funds, AED/USD for others).
  final String currency;
  final double units;

  /// Average cost per unit, in [currency].
  final double? avgCostNav;
  final double nav;
  final String? navDate;

  /// market | manual
  final String navSource;
  final DateTime? navFetchedAt;

  /// Monthly SIP amount in [currency] minor units, and the debit day.
  final int? sipAmountMinor;
  final int? sipDay;
  final DateTime createdAt;
  final DateTime? deletedAt;
  const FundRow({
    required this.id,
    required this.kind,
    this.schemeCode,
    required this.name,
    required this.currency,
    required this.units,
    this.avgCostNav,
    required this.nav,
    this.navDate,
    required this.navSource,
    this.navFetchedAt,
    this.sipAmountMinor,
    this.sipDay,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || schemeCode != null) {
      map['scheme_code'] = Variable<String>(schemeCode);
    }
    map['name'] = Variable<String>(name);
    map['currency'] = Variable<String>(currency);
    map['units'] = Variable<double>(units);
    if (!nullToAbsent || avgCostNav != null) {
      map['avg_cost_nav'] = Variable<double>(avgCostNav);
    }
    map['nav'] = Variable<double>(nav);
    if (!nullToAbsent || navDate != null) {
      map['nav_date'] = Variable<String>(navDate);
    }
    map['nav_source'] = Variable<String>(navSource);
    if (!nullToAbsent || navFetchedAt != null) {
      map['nav_fetched_at'] = Variable<DateTime>(navFetchedAt);
    }
    if (!nullToAbsent || sipAmountMinor != null) {
      map['sip_amount_minor'] = Variable<int>(sipAmountMinor);
    }
    if (!nullToAbsent || sipDay != null) {
      map['sip_day'] = Variable<int>(sipDay);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  FundHoldingsCompanion toCompanion(bool nullToAbsent) {
    return FundHoldingsCompanion(
      id: Value(id),
      kind: Value(kind),
      schemeCode: schemeCode == null && nullToAbsent
          ? const Value.absent()
          : Value(schemeCode),
      name: Value(name),
      currency: Value(currency),
      units: Value(units),
      avgCostNav: avgCostNav == null && nullToAbsent
          ? const Value.absent()
          : Value(avgCostNav),
      nav: Value(nav),
      navDate: navDate == null && nullToAbsent
          ? const Value.absent()
          : Value(navDate),
      navSource: Value(navSource),
      navFetchedAt: navFetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(navFetchedAt),
      sipAmountMinor: sipAmountMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(sipAmountMinor),
      sipDay: sipDay == null && nullToAbsent
          ? const Value.absent()
          : Value(sipDay),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory FundRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FundRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      schemeCode: serializer.fromJson<String?>(json['schemeCode']),
      name: serializer.fromJson<String>(json['name']),
      currency: serializer.fromJson<String>(json['currency']),
      units: serializer.fromJson<double>(json['units']),
      avgCostNav: serializer.fromJson<double?>(json['avgCostNav']),
      nav: serializer.fromJson<double>(json['nav']),
      navDate: serializer.fromJson<String?>(json['navDate']),
      navSource: serializer.fromJson<String>(json['navSource']),
      navFetchedAt: serializer.fromJson<DateTime?>(json['navFetchedAt']),
      sipAmountMinor: serializer.fromJson<int?>(json['sipAmountMinor']),
      sipDay: serializer.fromJson<int?>(json['sipDay']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'schemeCode': serializer.toJson<String?>(schemeCode),
      'name': serializer.toJson<String>(name),
      'currency': serializer.toJson<String>(currency),
      'units': serializer.toJson<double>(units),
      'avgCostNav': serializer.toJson<double?>(avgCostNav),
      'nav': serializer.toJson<double>(nav),
      'navDate': serializer.toJson<String?>(navDate),
      'navSource': serializer.toJson<String>(navSource),
      'navFetchedAt': serializer.toJson<DateTime?>(navFetchedAt),
      'sipAmountMinor': serializer.toJson<int?>(sipAmountMinor),
      'sipDay': serializer.toJson<int?>(sipDay),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  FundRow copyWith({
    String? id,
    String? kind,
    Value<String?> schemeCode = const Value.absent(),
    String? name,
    String? currency,
    double? units,
    Value<double?> avgCostNav = const Value.absent(),
    double? nav,
    Value<String?> navDate = const Value.absent(),
    String? navSource,
    Value<DateTime?> navFetchedAt = const Value.absent(),
    Value<int?> sipAmountMinor = const Value.absent(),
    Value<int?> sipDay = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => FundRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    schemeCode: schemeCode.present ? schemeCode.value : this.schemeCode,
    name: name ?? this.name,
    currency: currency ?? this.currency,
    units: units ?? this.units,
    avgCostNav: avgCostNav.present ? avgCostNav.value : this.avgCostNav,
    nav: nav ?? this.nav,
    navDate: navDate.present ? navDate.value : this.navDate,
    navSource: navSource ?? this.navSource,
    navFetchedAt: navFetchedAt.present ? navFetchedAt.value : this.navFetchedAt,
    sipAmountMinor: sipAmountMinor.present
        ? sipAmountMinor.value
        : this.sipAmountMinor,
    sipDay: sipDay.present ? sipDay.value : this.sipDay,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  FundRow copyWithCompanion(FundHoldingsCompanion data) {
    return FundRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      schemeCode: data.schemeCode.present
          ? data.schemeCode.value
          : this.schemeCode,
      name: data.name.present ? data.name.value : this.name,
      currency: data.currency.present ? data.currency.value : this.currency,
      units: data.units.present ? data.units.value : this.units,
      avgCostNav: data.avgCostNav.present
          ? data.avgCostNav.value
          : this.avgCostNav,
      nav: data.nav.present ? data.nav.value : this.nav,
      navDate: data.navDate.present ? data.navDate.value : this.navDate,
      navSource: data.navSource.present ? data.navSource.value : this.navSource,
      navFetchedAt: data.navFetchedAt.present
          ? data.navFetchedAt.value
          : this.navFetchedAt,
      sipAmountMinor: data.sipAmountMinor.present
          ? data.sipAmountMinor.value
          : this.sipAmountMinor,
      sipDay: data.sipDay.present ? data.sipDay.value : this.sipDay,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FundRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('schemeCode: $schemeCode, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('units: $units, ')
          ..write('avgCostNav: $avgCostNav, ')
          ..write('nav: $nav, ')
          ..write('navDate: $navDate, ')
          ..write('navSource: $navSource, ')
          ..write('navFetchedAt: $navFetchedAt, ')
          ..write('sipAmountMinor: $sipAmountMinor, ')
          ..write('sipDay: $sipDay, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    schemeCode,
    name,
    currency,
    units,
    avgCostNav,
    nav,
    navDate,
    navSource,
    navFetchedAt,
    sipAmountMinor,
    sipDay,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FundRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.schemeCode == this.schemeCode &&
          other.name == this.name &&
          other.currency == this.currency &&
          other.units == this.units &&
          other.avgCostNav == this.avgCostNav &&
          other.nav == this.nav &&
          other.navDate == this.navDate &&
          other.navSource == this.navSource &&
          other.navFetchedAt == this.navFetchedAt &&
          other.sipAmountMinor == this.sipAmountMinor &&
          other.sipDay == this.sipDay &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class FundHoldingsCompanion extends UpdateCompanion<FundRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String?> schemeCode;
  final Value<String> name;
  final Value<String> currency;
  final Value<double> units;
  final Value<double?> avgCostNav;
  final Value<double> nav;
  final Value<String?> navDate;
  final Value<String> navSource;
  final Value<DateTime?> navFetchedAt;
  final Value<int?> sipAmountMinor;
  final Value<int?> sipDay;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const FundHoldingsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.schemeCode = const Value.absent(),
    this.name = const Value.absent(),
    this.currency = const Value.absent(),
    this.units = const Value.absent(),
    this.avgCostNav = const Value.absent(),
    this.nav = const Value.absent(),
    this.navDate = const Value.absent(),
    this.navSource = const Value.absent(),
    this.navFetchedAt = const Value.absent(),
    this.sipAmountMinor = const Value.absent(),
    this.sipDay = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FundHoldingsCompanion.insert({
    required String id,
    required String kind,
    this.schemeCode = const Value.absent(),
    required String name,
    this.currency = const Value.absent(),
    required double units,
    this.avgCostNav = const Value.absent(),
    required double nav,
    this.navDate = const Value.absent(),
    this.navSource = const Value.absent(),
    this.navFetchedAt = const Value.absent(),
    this.sipAmountMinor = const Value.absent(),
    this.sipDay = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       name = Value(name),
       units = Value(units),
       nav = Value(nav);
  static Insertable<FundRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? schemeCode,
    Expression<String>? name,
    Expression<String>? currency,
    Expression<double>? units,
    Expression<double>? avgCostNav,
    Expression<double>? nav,
    Expression<String>? navDate,
    Expression<String>? navSource,
    Expression<DateTime>? navFetchedAt,
    Expression<int>? sipAmountMinor,
    Expression<int>? sipDay,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (schemeCode != null) 'scheme_code': schemeCode,
      if (name != null) 'name': name,
      if (currency != null) 'currency': currency,
      if (units != null) 'units': units,
      if (avgCostNav != null) 'avg_cost_nav': avgCostNav,
      if (nav != null) 'nav': nav,
      if (navDate != null) 'nav_date': navDate,
      if (navSource != null) 'nav_source': navSource,
      if (navFetchedAt != null) 'nav_fetched_at': navFetchedAt,
      if (sipAmountMinor != null) 'sip_amount_minor': sipAmountMinor,
      if (sipDay != null) 'sip_day': sipDay,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FundHoldingsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String?>? schemeCode,
    Value<String>? name,
    Value<String>? currency,
    Value<double>? units,
    Value<double?>? avgCostNav,
    Value<double>? nav,
    Value<String?>? navDate,
    Value<String>? navSource,
    Value<DateTime?>? navFetchedAt,
    Value<int?>? sipAmountMinor,
    Value<int?>? sipDay,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return FundHoldingsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      schemeCode: schemeCode ?? this.schemeCode,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      units: units ?? this.units,
      avgCostNav: avgCostNav ?? this.avgCostNav,
      nav: nav ?? this.nav,
      navDate: navDate ?? this.navDate,
      navSource: navSource ?? this.navSource,
      navFetchedAt: navFetchedAt ?? this.navFetchedAt,
      sipAmountMinor: sipAmountMinor ?? this.sipAmountMinor,
      sipDay: sipDay ?? this.sipDay,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (schemeCode.present) {
      map['scheme_code'] = Variable<String>(schemeCode.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (units.present) {
      map['units'] = Variable<double>(units.value);
    }
    if (avgCostNav.present) {
      map['avg_cost_nav'] = Variable<double>(avgCostNav.value);
    }
    if (nav.present) {
      map['nav'] = Variable<double>(nav.value);
    }
    if (navDate.present) {
      map['nav_date'] = Variable<String>(navDate.value);
    }
    if (navSource.present) {
      map['nav_source'] = Variable<String>(navSource.value);
    }
    if (navFetchedAt.present) {
      map['nav_fetched_at'] = Variable<DateTime>(navFetchedAt.value);
    }
    if (sipAmountMinor.present) {
      map['sip_amount_minor'] = Variable<int>(sipAmountMinor.value);
    }
    if (sipDay.present) {
      map['sip_day'] = Variable<int>(sipDay.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FundHoldingsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('schemeCode: $schemeCode, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('units: $units, ')
          ..write('avgCostNav: $avgCostNav, ')
          ..write('nav: $nav, ')
          ..write('navDate: $navDate, ')
          ..write('navSource: $navSource, ')
          ..write('navFetchedAt: $navFetchedAt, ')
          ..write('sipAmountMinor: $sipAmountMinor, ')
          ..write('sipDay: $sipDay, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ValuationSnapshotsTable extends ValuationSnapshots
    with TableInfo<$ValuationSnapshotsTable, ValuationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ValuationSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectKindMeta = const VerificationMeta(
    'subjectKind',
  );
  @override
  late final GeneratedColumn<String> subjectKind = GeneratedColumn<String>(
    'subject_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snapshotDateMeta = const VerificationMeta(
    'snapshotDate',
  );
  @override
  late final GeneratedColumn<String> snapshotDate = GeneratedColumn<String>(
    'snapshot_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMinorMeta = const VerificationMeta(
    'valueMinor',
  );
  @override
  late final GeneratedColumn<int> valueMinor = GeneratedColumn<int>(
    'value_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitPriceMeta = const VerificationMeta(
    'unitPrice',
  );
  @override
  late final GeneratedColumn<double> unitPrice = GeneratedColumn<double>(
    'unit_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectKind,
    subjectId,
    snapshotDate,
    valueMinor,
    unitPrice,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'valuation_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ValuationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('subject_kind')) {
      context.handle(
        _subjectKindMeta,
        subjectKind.isAcceptableOrUnknown(
          data['subject_kind']!,
          _subjectKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectKindMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('snapshot_date')) {
      context.handle(
        _snapshotDateMeta,
        snapshotDate.isAcceptableOrUnknown(
          data['snapshot_date']!,
          _snapshotDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotDateMeta);
    }
    if (data.containsKey('value_minor')) {
      context.handle(
        _valueMinorMeta,
        valueMinor.isAcceptableOrUnknown(data['value_minor']!, _valueMinorMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMinorMeta);
    }
    if (data.containsKey('unit_price')) {
      context.handle(
        _unitPriceMeta,
        unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {subjectKind, subjectId, snapshotDate},
  ];
  @override
  ValuationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ValuationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      subjectKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_kind'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      snapshotDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_date'],
      )!,
      valueMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value_minor'],
      )!,
      unitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_price'],
      ),
    );
  }

  @override
  $ValuationSnapshotsTable createAlias(String alias) {
    return $ValuationSnapshotsTable(attachedDatabase, alias);
  }
}

class ValuationRow extends DataClass implements Insertable<ValuationRow> {
  final String id;

  /// jewellery | fund
  final String subjectKind;
  final String subjectId;
  final String snapshotDate;
  final int valueMinor;

  /// The AED/g (or NAV) used, so the chart can be explained later.
  final double? unitPrice;
  const ValuationRow({
    required this.id,
    required this.subjectKind,
    required this.subjectId,
    required this.snapshotDate,
    required this.valueMinor,
    this.unitPrice,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['subject_kind'] = Variable<String>(subjectKind);
    map['subject_id'] = Variable<String>(subjectId);
    map['snapshot_date'] = Variable<String>(snapshotDate);
    map['value_minor'] = Variable<int>(valueMinor);
    if (!nullToAbsent || unitPrice != null) {
      map['unit_price'] = Variable<double>(unitPrice);
    }
    return map;
  }

  ValuationSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return ValuationSnapshotsCompanion(
      id: Value(id),
      subjectKind: Value(subjectKind),
      subjectId: Value(subjectId),
      snapshotDate: Value(snapshotDate),
      valueMinor: Value(valueMinor),
      unitPrice: unitPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(unitPrice),
    );
  }

  factory ValuationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ValuationRow(
      id: serializer.fromJson<String>(json['id']),
      subjectKind: serializer.fromJson<String>(json['subjectKind']),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      snapshotDate: serializer.fromJson<String>(json['snapshotDate']),
      valueMinor: serializer.fromJson<int>(json['valueMinor']),
      unitPrice: serializer.fromJson<double?>(json['unitPrice']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'subjectKind': serializer.toJson<String>(subjectKind),
      'subjectId': serializer.toJson<String>(subjectId),
      'snapshotDate': serializer.toJson<String>(snapshotDate),
      'valueMinor': serializer.toJson<int>(valueMinor),
      'unitPrice': serializer.toJson<double?>(unitPrice),
    };
  }

  ValuationRow copyWith({
    String? id,
    String? subjectKind,
    String? subjectId,
    String? snapshotDate,
    int? valueMinor,
    Value<double?> unitPrice = const Value.absent(),
  }) => ValuationRow(
    id: id ?? this.id,
    subjectKind: subjectKind ?? this.subjectKind,
    subjectId: subjectId ?? this.subjectId,
    snapshotDate: snapshotDate ?? this.snapshotDate,
    valueMinor: valueMinor ?? this.valueMinor,
    unitPrice: unitPrice.present ? unitPrice.value : this.unitPrice,
  );
  ValuationRow copyWithCompanion(ValuationSnapshotsCompanion data) {
    return ValuationRow(
      id: data.id.present ? data.id.value : this.id,
      subjectKind: data.subjectKind.present
          ? data.subjectKind.value
          : this.subjectKind,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      snapshotDate: data.snapshotDate.present
          ? data.snapshotDate.value
          : this.snapshotDate,
      valueMinor: data.valueMinor.present
          ? data.valueMinor.value
          : this.valueMinor,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ValuationRow(')
          ..write('id: $id, ')
          ..write('subjectKind: $subjectKind, ')
          ..write('subjectId: $subjectId, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('valueMinor: $valueMinor, ')
          ..write('unitPrice: $unitPrice')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subjectKind,
    subjectId,
    snapshotDate,
    valueMinor,
    unitPrice,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ValuationRow &&
          other.id == this.id &&
          other.subjectKind == this.subjectKind &&
          other.subjectId == this.subjectId &&
          other.snapshotDate == this.snapshotDate &&
          other.valueMinor == this.valueMinor &&
          other.unitPrice == this.unitPrice);
}

class ValuationSnapshotsCompanion extends UpdateCompanion<ValuationRow> {
  final Value<String> id;
  final Value<String> subjectKind;
  final Value<String> subjectId;
  final Value<String> snapshotDate;
  final Value<int> valueMinor;
  final Value<double?> unitPrice;
  final Value<int> rowid;
  const ValuationSnapshotsCompanion({
    this.id = const Value.absent(),
    this.subjectKind = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.snapshotDate = const Value.absent(),
    this.valueMinor = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ValuationSnapshotsCompanion.insert({
    required String id,
    required String subjectKind,
    required String subjectId,
    required String snapshotDate,
    required int valueMinor,
    this.unitPrice = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       subjectKind = Value(subjectKind),
       subjectId = Value(subjectId),
       snapshotDate = Value(snapshotDate),
       valueMinor = Value(valueMinor);
  static Insertable<ValuationRow> custom({
    Expression<String>? id,
    Expression<String>? subjectKind,
    Expression<String>? subjectId,
    Expression<String>? snapshotDate,
    Expression<int>? valueMinor,
    Expression<double>? unitPrice,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectKind != null) 'subject_kind': subjectKind,
      if (subjectId != null) 'subject_id': subjectId,
      if (snapshotDate != null) 'snapshot_date': snapshotDate,
      if (valueMinor != null) 'value_minor': valueMinor,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ValuationSnapshotsCompanion copyWith({
    Value<String>? id,
    Value<String>? subjectKind,
    Value<String>? subjectId,
    Value<String>? snapshotDate,
    Value<int>? valueMinor,
    Value<double?>? unitPrice,
    Value<int>? rowid,
  }) {
    return ValuationSnapshotsCompanion(
      id: id ?? this.id,
      subjectKind: subjectKind ?? this.subjectKind,
      subjectId: subjectId ?? this.subjectId,
      snapshotDate: snapshotDate ?? this.snapshotDate,
      valueMinor: valueMinor ?? this.valueMinor,
      unitPrice: unitPrice ?? this.unitPrice,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (subjectKind.present) {
      map['subject_kind'] = Variable<String>(subjectKind.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (snapshotDate.present) {
      map['snapshot_date'] = Variable<String>(snapshotDate.value);
    }
    if (valueMinor.present) {
      map['value_minor'] = Variable<int>(valueMinor.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<double>(unitPrice.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ValuationSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('subjectKind: $subjectKind, ')
          ..write('subjectId: $subjectId, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('valueMinor: $valueMinor, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$PulseDatabase extends GeneratedDatabase {
  _$PulseDatabase(QueryExecutor e) : super(e);
  $PulseDatabaseManager get managers => $PulseDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CatalogCardsTable catalogCards = $CatalogCardsTable(this);
  late final $UserCardsTable userCards = $UserCardsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $MerchantRulesTable merchantRules = $MerchantRulesTable(this);
  late final $StatementsTable statements = $StatementsTable(this);
  late final $StatementLinesTable statementLines = $StatementLinesTable(this);
  late final $AssetsTable assets = $AssetsTable(this);
  late final $LiabilitiesTable liabilities = $LiabilitiesTable(this);
  late final $SalaryRecordsTable salaryRecords = $SalaryRecordsTable(this);
  late final $SavingsGoalsTable savingsGoals = $SavingsGoalsTable(this);
  late final $RawIngestsTable rawIngests = $RawIngestsTable(this);
  late final $NetWorthSnapshotsTable netWorthSnapshots =
      $NetWorthSnapshotsTable(this);
  late final $RecurringReviewsTable recurringReviews = $RecurringReviewsTable(
    this,
  );
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $PriceCacheTable priceCache = $PriceCacheTable(this);
  late final $JewelleryItemsTable jewelleryItems = $JewelleryItemsTable(this);
  late final $DocumentAttachmentsTable documentAttachments =
      $DocumentAttachmentsTable(this);
  late final $FundHoldingsTable fundHoldings = $FundHoldingsTable(this);
  late final $ValuationSnapshotsTable valuationSnapshots =
      $ValuationSnapshotsTable(this);
  late final Index ixTransactionsPostedAt = Index(
    'ix_transactions_posted_at',
    'CREATE INDEX ix_transactions_posted_at ON transactions (posted_at)',
  );
  late final Index ixTransactionsAccountPosted = Index(
    'ix_transactions_account_posted',
    'CREATE INDEX ix_transactions_account_posted ON transactions (account_id, posted_at)',
  );
  late final Index ixTransactionsStatement = Index(
    'ix_transactions_statement',
    'CREATE INDEX ix_transactions_statement ON transactions (statement_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    catalogCards,
    userCards,
    categories,
    transactions,
    budgets,
    merchantRules,
    statements,
    statementLines,
    assets,
    liabilities,
    salaryRecords,
    savingsGoals,
    rawIngests,
    netWorthSnapshots,
    recurringReviews,
    appSettings,
    priceCache,
    jewelleryItems,
    documentAttachments,
    fundHoldings,
    valuationSnapshots,
    ixTransactionsPostedAt,
    ixTransactionsAccountPosted,
    ixTransactionsStatement,
  ];
}

typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  required String id,
  required String type,
  required String name,
  Value<String?> institution,
  Value<String?> last4,
  Value<String> currency,
  Value<int?> creditLimitMinor,
  Value<int?> statementDay,
  Value<int?> dueDay,
  Value<int?> balanceAnchorMinor,
  Value<DateTime?> balanceAnchorAt,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<String> id,
  Value<String> type,
  Value<String> name,
  Value<String?> institution,
  Value<String?> last4,
  Value<String> currency,
  Value<int?> creditLimitMinor,
  Value<int?> statementDay,
  Value<int?> dueDay,
  Value<int?> balanceAnchorMinor,
  Value<DateTime?> balanceAnchorAt,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$AccountsTableReferences
    extends BaseReferences<_$PulseDatabase, $AccountsTable, AccountRow> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$UserCardsTable, List<UserCardRow>>
  _userCardsRefsTable(_$PulseDatabase db) => MultiTypedResultKey.fromTable(
    db.userCards,
    aliasName: 'accounts__id__user_cards__account_id',
  );

  $$UserCardsTableProcessedTableManager get userCardsRefs {
    final manager = $$UserCardsTableTableManager(
      $_db,
      $_db.userCards,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_userCardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<TxRow>>
  _transactionsRefsTable(_$PulseDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'accounts__id__transactions__account_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StatementsTable, List<StatementRow>>
  _statementsRefsTable(_$PulseDatabase db) => MultiTypedResultKey.fromTable(
    db.statements,
    aliasName: 'accounts__id__statements__account_id',
  );

  $$StatementsTableProcessedTableManager get statementsRefs {
    final manager = $$StatementsTableTableManager(
      $_db,
      $_db.statements,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_statementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LiabilitiesTable, List<LiabilityRow>>
  _liabilitiesRefsTable(_$PulseDatabase db) => MultiTypedResultKey.fromTable(
    db.liabilities,
    aliasName: 'accounts__id__liabilities__account_id',
  );

  $$LiabilitiesTableProcessedTableManager get liabilitiesRefs {
    final manager = $$LiabilitiesTableTableManager(
      $_db,
      $_db.liabilities,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_liabilitiesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SalaryRecordsTable, List<SalaryRow>>
  _salaryRecordsRefsTable(_$PulseDatabase db) => MultiTypedResultKey.fromTable(
    db.salaryRecords,
    aliasName: 'accounts__id__salary_records__account_id',
  );

  $$SalaryRecordsTableProcessedTableManager get salaryRecordsRefs {
    final manager = $$SalaryRecordsTableTableManager(
      $_db,
      $_db.salaryRecords,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_salaryRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$PulseDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get last4 => $composableBuilder(
    column: $table.last4,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditLimitMinor => $composableBuilder(
    column: $table.creditLimitMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get statementDay => $composableBuilder(
    column: $table.statementDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get balanceAnchorMinor => $composableBuilder(
    column: $table.balanceAnchorMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get balanceAnchorAt => $composableBuilder(
    column: $table.balanceAnchorAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> userCardsRefs(
    Expression<bool> Function($$UserCardsTableFilterComposer f) f,
  ) {
    final $$UserCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userCards,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserCardsTableFilterComposer(
            $db: $db,
            $table: $db.userCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> statementsRefs(
    Expression<bool> Function($$StatementsTableFilterComposer f) f,
  ) {
    final $$StatementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.statements,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StatementsTableFilterComposer(
            $db: $db,
            $table: $db.statements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> liabilitiesRefs(
    Expression<bool> Function($$LiabilitiesTableFilterComposer f) f,
  ) {
    final $$LiabilitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.liabilities,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LiabilitiesTableFilterComposer(
            $db: $db,
            $table: $db.liabilities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> salaryRecordsRefs(
    Expression<bool> Function($$SalaryRecordsTableFilterComposer f) f,
  ) {
    final $$SalaryRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.salaryRecords,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalaryRecordsTableFilterComposer(
            $db: $db,
            $table: $db.salaryRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$PulseDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get last4 => $composableBuilder(
    column: $table.last4,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditLimitMinor => $composableBuilder(
    column: $table.creditLimitMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get statementDay => $composableBuilder(
    column: $table.statementDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get balanceAnchorMinor => $composableBuilder(
    column: $table.balanceAnchorMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get balanceAnchorAt => $composableBuilder(
    column: $table.balanceAnchorAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => column,
  );

  GeneratedColumn<String> get last4 =>
      $composableBuilder(column: $table.last4, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get creditLimitMinor => $composableBuilder(
    column: $table.creditLimitMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get statementDay => $composableBuilder(
    column: $table.statementDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueDay =>
      $composableBuilder(column: $table.dueDay, builder: (column) => column);

  GeneratedColumn<int> get balanceAnchorMinor => $composableBuilder(
    column: $table.balanceAnchorMinor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get balanceAnchorAt => $composableBuilder(
    column: $table.balanceAnchorAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> userCardsRefs<T extends Object>(
    Expression<T> Function($$UserCardsTableAnnotationComposer a) f,
  ) {
    final $$UserCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userCards,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.userCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> statementsRefs<T extends Object>(
    Expression<T> Function($$StatementsTableAnnotationComposer a) f,
  ) {
    final $$StatementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.statements,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StatementsTableAnnotationComposer(
            $db: $db,
            $table: $db.statements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> liabilitiesRefs<T extends Object>(
    Expression<T> Function($$LiabilitiesTableAnnotationComposer a) f,
  ) {
    final $$LiabilitiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.liabilities,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LiabilitiesTableAnnotationComposer(
            $db: $db,
            $table: $db.liabilities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> salaryRecordsRefs<T extends Object>(
    Expression<T> Function($$SalaryRecordsTableAnnotationComposer a) f,
  ) {
    final $$SalaryRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.salaryRecords,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalaryRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.salaryRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $AccountsTable,
          AccountRow,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (AccountRow, $$AccountsTableReferences),
          AccountRow,
          PrefetchHooks Function({
            bool userCardsRefs,
            bool transactionsRefs,
            bool statementsRefs,
            bool liabilitiesRefs,
            bool salaryRecordsRefs,
          })
        > {
  $$AccountsTableTableManager(_$PulseDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> institution = const Value.absent(),
                Value<String?> last4 = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int?> creditLimitMinor = const Value.absent(),
                Value<int?> statementDay = const Value.absent(),
                Value<int?> dueDay = const Value.absent(),
                Value<int?> balanceAnchorMinor = const Value.absent(),
                Value<DateTime?> balanceAnchorAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                type: type,
                name: name,
                institution: institution,
                last4: last4,
                currency: currency,
                creditLimitMinor: creditLimitMinor,
                statementDay: statementDay,
                dueDay: dueDay,
                balanceAnchorMinor: balanceAnchorMinor,
                balanceAnchorAt: balanceAnchorAt,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String name,
                Value<String?> institution = const Value.absent(),
                Value<String?> last4 = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int?> creditLimitMinor = const Value.absent(),
                Value<int?> statementDay = const Value.absent(),
                Value<int?> dueDay = const Value.absent(),
                Value<int?> balanceAnchorMinor = const Value.absent(),
                Value<DateTime?> balanceAnchorAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                type: type,
                name: name,
                institution: institution,
                last4: last4,
                currency: currency,
                creditLimitMinor: creditLimitMinor,
                statementDay: statementDay,
                dueDay: dueDay,
                balanceAnchorMinor: balanceAnchorMinor,
                balanceAnchorAt: balanceAnchorAt,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AccountsTable, AccountRow>(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                userCardsRefs = false,
                transactionsRefs = false,
                statementsRefs = false,
                liabilitiesRefs = false,
                salaryRecordsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (userCardsRefs) db.userCards,
                    if (transactionsRefs) db.transactions,
                    if (statementsRefs) db.statements,
                    if (liabilitiesRefs) db.liabilities,
                    if (salaryRecordsRefs) db.salaryRecords,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (userCardsRefs)
                        await $_getPrefetchedDataByColumns<
                          AccountRow,
                          $AccountsTable,
                          UserCardRow,
                          $UserCardsTable
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._userCardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).userCardsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'account_id',
                          typedResults: items,
                        ),
                      if (transactionsRefs)
                        await $_getPrefetchedDataByColumns<
                          AccountRow,
                          $AccountsTable,
                          TxRow,
                          $TransactionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'account_id',
                          typedResults: items,
                        ),
                      if (statementsRefs)
                        await $_getPrefetchedDataByColumns<
                          AccountRow,
                          $AccountsTable,
                          StatementRow,
                          $StatementsTable
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._statementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).statementsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'account_id',
                          typedResults: items,
                        ),
                      if (liabilitiesRefs)
                        await $_getPrefetchedDataByColumns<
                          AccountRow,
                          $AccountsTable,
                          LiabilityRow,
                          $LiabilitiesTable
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._liabilitiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).liabilitiesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'account_id',
                          typedResults: items,
                        ),
                      if (salaryRecordsRefs)
                        await $_getPrefetchedDataByColumns<
                          AccountRow,
                          $AccountsTable,
                          SalaryRow,
                          $SalaryRecordsTable
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._salaryRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).salaryRecordsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'account_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $AccountsTable,
      AccountRow,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (AccountRow, $$AccountsTableReferences),
      AccountRow,
      PrefetchHooks Function({
        bool userCardsRefs,
        bool transactionsRefs,
        bool statementsRefs,
        bool liabilitiesRefs,
        bool salaryRecordsRefs,
      })
    >;
typedef $$CatalogCardsTableCreateCompanionBuilder =
    CatalogCardsCompanion Function({
      required String id,
      required String issuer,
      required String name,
      Value<String?> network,
      Value<int> annualFeeMinor,
      Value<int?> minSalaryMinor,
      Value<String> rewardStructure,
      Value<String> perks,
      Value<String?> verifiedOn,
      Value<String?> source,
      Value<int> catalogVersion,
      Value<int> rowid,
    });
typedef $$CatalogCardsTableUpdateCompanionBuilder =
    CatalogCardsCompanion Function({
      Value<String> id,
      Value<String> issuer,
      Value<String> name,
      Value<String?> network,
      Value<int> annualFeeMinor,
      Value<int?> minSalaryMinor,
      Value<String> rewardStructure,
      Value<String> perks,
      Value<String?> verifiedOn,
      Value<String?> source,
      Value<int> catalogVersion,
      Value<int> rowid,
    });

final class $$CatalogCardsTableReferences
    extends
        BaseReferences<_$PulseDatabase, $CatalogCardsTable, CatalogCardRow> {
  $$CatalogCardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$UserCardsTable, List<UserCardRow>>
  _userCardsRefsTable(_$PulseDatabase db) => MultiTypedResultKey.fromTable(
    db.userCards,
    aliasName: 'catalog_cards__id__user_cards__catalog_card_id',
  );

  $$UserCardsTableProcessedTableManager get userCardsRefs {
    final manager = $$UserCardsTableTableManager(
      $_db,
      $_db.userCards,
    ).filter((f) => f.catalogCardId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_userCardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CatalogCardsTableFilterComposer
    extends Composer<_$PulseDatabase, $CatalogCardsTable> {
  $$CatalogCardsTableFilterComposer({
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

  ColumnFilters<String> get issuer => $composableBuilder(
    column: $table.issuer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get network => $composableBuilder(
    column: $table.network,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get annualFeeMinor => $composableBuilder(
    column: $table.annualFeeMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minSalaryMinor => $composableBuilder(
    column: $table.minSalaryMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rewardStructure => $composableBuilder(
    column: $table.rewardStructure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get perks => $composableBuilder(
    column: $table.perks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verifiedOn => $composableBuilder(
    column: $table.verifiedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get catalogVersion => $composableBuilder(
    column: $table.catalogVersion,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> userCardsRefs(
    Expression<bool> Function($$UserCardsTableFilterComposer f) f,
  ) {
    final $$UserCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userCards,
      getReferencedColumn: (t) => t.catalogCardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserCardsTableFilterComposer(
            $db: $db,
            $table: $db.userCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CatalogCardsTableOrderingComposer
    extends Composer<_$PulseDatabase, $CatalogCardsTable> {
  $$CatalogCardsTableOrderingComposer({
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

  ColumnOrderings<String> get issuer => $composableBuilder(
    column: $table.issuer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get network => $composableBuilder(
    column: $table.network,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get annualFeeMinor => $composableBuilder(
    column: $table.annualFeeMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minSalaryMinor => $composableBuilder(
    column: $table.minSalaryMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rewardStructure => $composableBuilder(
    column: $table.rewardStructure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get perks => $composableBuilder(
    column: $table.perks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verifiedOn => $composableBuilder(
    column: $table.verifiedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get catalogVersion => $composableBuilder(
    column: $table.catalogVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogCardsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $CatalogCardsTable> {
  $$CatalogCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get issuer =>
      $composableBuilder(column: $table.issuer, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get network =>
      $composableBuilder(column: $table.network, builder: (column) => column);

  GeneratedColumn<int> get annualFeeMinor => $composableBuilder(
    column: $table.annualFeeMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get minSalaryMinor => $composableBuilder(
    column: $table.minSalaryMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rewardStructure => $composableBuilder(
    column: $table.rewardStructure,
    builder: (column) => column,
  );

  GeneratedColumn<String> get perks =>
      $composableBuilder(column: $table.perks, builder: (column) => column);

  GeneratedColumn<String> get verifiedOn => $composableBuilder(
    column: $table.verifiedOn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get catalogVersion => $composableBuilder(
    column: $table.catalogVersion,
    builder: (column) => column,
  );

  Expression<T> userCardsRefs<T extends Object>(
    Expression<T> Function($$UserCardsTableAnnotationComposer a) f,
  ) {
    final $$UserCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userCards,
      getReferencedColumn: (t) => t.catalogCardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.userCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CatalogCardsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $CatalogCardsTable,
          CatalogCardRow,
          $$CatalogCardsTableFilterComposer,
          $$CatalogCardsTableOrderingComposer,
          $$CatalogCardsTableAnnotationComposer,
          $$CatalogCardsTableCreateCompanionBuilder,
          $$CatalogCardsTableUpdateCompanionBuilder,
          (CatalogCardRow, $$CatalogCardsTableReferences),
          CatalogCardRow,
          PrefetchHooks Function({bool userCardsRefs})
        > {
  $$CatalogCardsTableTableManager(_$PulseDatabase db, $CatalogCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> issuer = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> network = const Value.absent(),
                Value<int> annualFeeMinor = const Value.absent(),
                Value<int?> minSalaryMinor = const Value.absent(),
                Value<String> rewardStructure = const Value.absent(),
                Value<String> perks = const Value.absent(),
                Value<String?> verifiedOn = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<int> catalogVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogCardsCompanion(
                id: id,
                issuer: issuer,
                name: name,
                network: network,
                annualFeeMinor: annualFeeMinor,
                minSalaryMinor: minSalaryMinor,
                rewardStructure: rewardStructure,
                perks: perks,
                verifiedOn: verifiedOn,
                source: source,
                catalogVersion: catalogVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String issuer,
                required String name,
                Value<String?> network = const Value.absent(),
                Value<int> annualFeeMinor = const Value.absent(),
                Value<int?> minSalaryMinor = const Value.absent(),
                Value<String> rewardStructure = const Value.absent(),
                Value<String> perks = const Value.absent(),
                Value<String?> verifiedOn = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<int> catalogVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogCardsCompanion.insert(
                id: id,
                issuer: issuer,
                name: name,
                network: network,
                annualFeeMinor: annualFeeMinor,
                minSalaryMinor: minSalaryMinor,
                rewardStructure: rewardStructure,
                perks: perks,
                verifiedOn: verifiedOn,
                source: source,
                catalogVersion: catalogVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogCardsTable, CatalogCardRow>(table),
                  $$CatalogCardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userCardsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (userCardsRefs) db.userCards],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (userCardsRefs)
                    await $_getPrefetchedDataByColumns<
                      CatalogCardRow,
                      $CatalogCardsTable,
                      UserCardRow,
                      $UserCardsTable
                    >(
                      currentTable: table,
                      referencedTable: $$CatalogCardsTableReferences
                          ._userCardsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CatalogCardsTableReferences(
                            db,
                            table,
                            p0,
                          ).userCardsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'catalog_card_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CatalogCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $CatalogCardsTable,
      CatalogCardRow,
      $$CatalogCardsTableFilterComposer,
      $$CatalogCardsTableOrderingComposer,
      $$CatalogCardsTableAnnotationComposer,
      $$CatalogCardsTableCreateCompanionBuilder,
      $$CatalogCardsTableUpdateCompanionBuilder,
      (CatalogCardRow, $$CatalogCardsTableReferences),
      CatalogCardRow,
      PrefetchHooks Function({bool userCardsRefs})
    >;
typedef $$UserCardsTableCreateCompanionBuilder = UserCardsCompanion Function({
  required String id,
  required String catalogCardId,
  Value<String?> accountId,
  Value<String?> nickname,
  Value<int> colorIndex,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$UserCardsTableUpdateCompanionBuilder = UserCardsCompanion Function({
  Value<String> id,
  Value<String> catalogCardId,
  Value<String?> accountId,
  Value<String?> nickname,
  Value<int> colorIndex,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$UserCardsTableReferences
    extends BaseReferences<_$PulseDatabase, $UserCardsTable, UserCardRow> {
  $$UserCardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CatalogCardsTable _catalogCardIdTable(_$PulseDatabase db) => db
      .catalogCards
      .createAlias('user_cards__catalog_card_id__catalog_cards__id');

  $$CatalogCardsTableProcessedTableManager get catalogCardId {
    final $_column = $_itemColumn<String>('catalog_card_id')!;

    final manager = $$CatalogCardsTableTableManager(
      $_db,
      $_db.catalogCards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_catalogCardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _accountIdTable(_$PulseDatabase db) =>
      db.accounts.createAlias('user_cards__account_id__accounts__id');

  $$AccountsTableProcessedTableManager? get accountId {
    final $_column = $_itemColumn<String>('account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$UserCardsTableFilterComposer
    extends Composer<_$PulseDatabase, $UserCardsTable> {
  $$UserCardsTableFilterComposer({
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

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CatalogCardsTableFilterComposer get catalogCardId {
    final $$CatalogCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catalogCardId,
      referencedTable: $db.catalogCards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogCardsTableFilterComposer(
            $db: $db,
            $table: $db.catalogCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserCardsTableOrderingComposer
    extends Composer<_$PulseDatabase, $UserCardsTable> {
  $$UserCardsTableOrderingComposer({
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

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CatalogCardsTableOrderingComposer get catalogCardId {
    final $$CatalogCardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catalogCardId,
      referencedTable: $db.catalogCards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogCardsTableOrderingComposer(
            $db: $db,
            $table: $db.catalogCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserCardsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $UserCardsTable> {
  $$UserCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$CatalogCardsTableAnnotationComposer get catalogCardId {
    final $$CatalogCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catalogCardId,
      referencedTable: $db.catalogCards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatalogCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.catalogCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserCardsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $UserCardsTable,
          UserCardRow,
          $$UserCardsTableFilterComposer,
          $$UserCardsTableOrderingComposer,
          $$UserCardsTableAnnotationComposer,
          $$UserCardsTableCreateCompanionBuilder,
          $$UserCardsTableUpdateCompanionBuilder,
          (UserCardRow, $$UserCardsTableReferences),
          UserCardRow,
          PrefetchHooks Function({bool catalogCardId, bool accountId})
        > {
  $$UserCardsTableTableManager(_$PulseDatabase db, $UserCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> catalogCardId = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserCardsCompanion(
                id: id,
                catalogCardId: catalogCardId,
                accountId: accountId,
                nickname: nickname,
                colorIndex: colorIndex,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String catalogCardId,
                Value<String?> accountId = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserCardsCompanion.insert(
                id: id,
                catalogCardId: catalogCardId,
                accountId: accountId,
                nickname: nickname,
                colorIndex: colorIndex,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserCardsTable, UserCardRow>(table),
                  $$UserCardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({catalogCardId = false, accountId = false}) {
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
                    if (catalogCardId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.catalogCardId,
                        referencedTable: $$UserCardsTableReferences
                            ._catalogCardIdTable(db),
                        referencedColumn: $$UserCardsTableReferences
                            ._catalogCardIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$UserCardsTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$UserCardsTableReferences
                            ._accountIdTable(db)
                            .id,
                      ) as T;
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

typedef $$UserCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $UserCardsTable,
      UserCardRow,
      $$UserCardsTableFilterComposer,
      $$UserCardsTableOrderingComposer,
      $$UserCardsTableAnnotationComposer,
      $$UserCardsTableCreateCompanionBuilder,
      $$UserCardsTableUpdateCompanionBuilder,
      (UserCardRow, $$UserCardsTableReferences),
      UserCardRow,
      PrefetchHooks Function({bool catalogCardId, bool accountId})
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  Value<String?> slug,
  required String name,
  Value<String> kind,
  Value<bool> isFixed,
  Value<String?> icon,
  Value<String?> color,
  Value<int> sortOrder,
  Value<String?> parentId,
  Value<bool> isCustom,
  Value<bool> isHidden,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String?> slug,
  Value<String> name,
  Value<String> kind,
  Value<bool> isFixed,
  Value<String?> icon,
  Value<String?> color,
  Value<int> sortOrder,
  Value<String?> parentId,
  Value<bool> isCustom,
  Value<bool> isHidden,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$PulseDatabase, $CategoriesTable, CategoryRow> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionsTable, List<TxRow>>
  _transactionsRefsTable(_$PulseDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'categories__id__transactions__category_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BudgetsTable, List<BudgetRow>> _budgetsRefsTable(
    _$PulseDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.budgets,
    aliasName: 'categories__id__budgets__category_id',
  );

  $$BudgetsTableProcessedTableManager get budgetsRefs {
    final manager = $$BudgetsTableTableManager(
      $_db,
      $_db.budgets,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_budgetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MerchantRulesTable, List<RuleRow>>
  _merchantRulesRefsTable(_$PulseDatabase db) => MultiTypedResultKey.fromTable(
    db.merchantRules,
    aliasName: 'categories__id__merchant_rules__category_id',
  );

  $$MerchantRulesTableProcessedTableManager get merchantRulesRefs {
    final manager = $$MerchantRulesTableTableManager(
      $_db,
      $_db.merchantRules,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_merchantRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$PulseDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFixed => $composableBuilder(
    column: $table.isFixed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> budgetsRefs(
    Expression<bool> Function($$BudgetsTableFilterComposer f) f,
  ) {
    final $$BudgetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgets,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetsTableFilterComposer(
            $db: $db,
            $table: $db.budgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> merchantRulesRefs(
    Expression<bool> Function($$MerchantRulesTableFilterComposer f) f,
  ) {
    final $$MerchantRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.merchantRules,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantRulesTableFilterComposer(
            $db: $db,
            $table: $db.merchantRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$PulseDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFixed => $composableBuilder(
    column: $table.isFixed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$PulseDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<bool> get isFixed =>
      $composableBuilder(column: $table.isFixed, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<bool> get isHidden =>
      $composableBuilder(column: $table.isHidden, builder: (column) => column);

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> budgetsRefs<T extends Object>(
    Expression<T> Function($$BudgetsTableAnnotationComposer a) f,
  ) {
    final $$BudgetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgets,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetsTableAnnotationComposer(
            $db: $db,
            $table: $db.budgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> merchantRulesRefs<T extends Object>(
    Expression<T> Function($$MerchantRulesTableAnnotationComposer a) f,
  ) {
    final $$MerchantRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.merchantRules,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.merchantRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $CategoriesTable,
          CategoryRow,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (CategoryRow, $$CategoriesTableReferences),
          CategoryRow,
          PrefetchHooks Function({
            bool transactionsRefs,
            bool budgetsRefs,
            bool merchantRulesRefs,
          })
        > {
  $$CategoriesTableTableManager(_$PulseDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> slug = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<bool> isFixed = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                slug: slug,
                name: name,
                kind: kind,
                isFixed: isFixed,
                icon: icon,
                color: color,
                sortOrder: sortOrder,
                parentId: parentId,
                isCustom: isCustom,
                isHidden: isHidden,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> slug = const Value.absent(),
                required String name,
                Value<String> kind = const Value.absent(),
                Value<bool> isFixed = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                slug: slug,
                name: name,
                kind: kind,
                isFixed: isFixed,
                icon: icon,
                color: color,
                sortOrder: sortOrder,
                parentId: parentId,
                isCustom: isCustom,
                isHidden: isHidden,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, CategoryRow>(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                transactionsRefs = false,
                budgetsRefs = false,
                merchantRulesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionsRefs) db.transactions,
                    if (budgetsRefs) db.budgets,
                    if (merchantRulesRefs) db.merchantRules,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionsRefs)
                        await $_getPrefetchedDataByColumns<
                          CategoryRow,
                          $CategoriesTable,
                          TxRow,
                          $TransactionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'category_id',
                          typedResults: items,
                        ),
                      if (budgetsRefs)
                        await $_getPrefetchedDataByColumns<
                          CategoryRow,
                          $CategoriesTable,
                          BudgetRow,
                          $BudgetsTable
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._budgetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).budgetsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'category_id',
                          typedResults: items,
                        ),
                      if (merchantRulesRefs)
                        await $_getPrefetchedDataByColumns<
                          CategoryRow,
                          $CategoriesTable,
                          RuleRow,
                          $MerchantRulesTable
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._merchantRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).merchantRulesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'category_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $CategoriesTable,
      CategoryRow,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (CategoryRow, $$CategoriesTableReferences),
      CategoryRow,
      PrefetchHooks Function({
        bool transactionsRefs,
        bool budgetsRefs,
        bool merchantRulesRefs,
      })
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      required String accountId,
      Value<String?> statementId,
      Value<String?> categoryId,
      required int amountMinor,
      Value<String> currency,
      required String direction,
      Value<String?> merchantRaw,
      Value<String?> merchantNormalized,
      Value<String?> notes,
      required DateTime postedAt,
      required String source,
      Value<String?> externalHash,
      Value<bool> excludeFromBudget,
      Value<String> tags,
      Value<String> sources,
      Value<bool> statementLocked,
      Value<String?> appliedRuleId,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String?> statementId,
      Value<String?> categoryId,
      Value<int> amountMinor,
      Value<String> currency,
      Value<String> direction,
      Value<String?> merchantRaw,
      Value<String?> merchantNormalized,
      Value<String?> notes,
      Value<DateTime> postedAt,
      Value<String> source,
      Value<String?> externalHash,
      Value<bool> excludeFromBudget,
      Value<String> tags,
      Value<String> sources,
      Value<bool> statementLocked,
      Value<String?> appliedRuleId,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$TransactionsTableReferences
    extends BaseReferences<_$PulseDatabase, $TransactionsTable, TxRow> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$PulseDatabase db) =>
      db.accounts.createAlias('transactions__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$PulseDatabase db) =>
      db.categories.createAlias('transactions__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$StatementLinesTable, List<StatementLineRow>>
  _statementLinesRefsTable(_$PulseDatabase db) => MultiTypedResultKey.fromTable(
    db.statementLines,
    aliasName: 'transactions__id__statement_lines__transaction_id',
  );

  $$StatementLinesTableProcessedTableManager get statementLinesRefs {
    final manager = $$StatementLinesTableTableManager(
      $_db,
      $_db.statementLines,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_statementLinesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SalaryRecordsTable, List<SalaryRow>>
  _salaryRecordsRefsTable(_$PulseDatabase db) => MultiTypedResultKey.fromTable(
    db.salaryRecords,
    aliasName: 'transactions__id__salary_records__transaction_id',
  );

  $$SalaryRecordsTableProcessedTableManager get salaryRecordsRefs {
    final manager = $$SalaryRecordsTableTableManager(
      $_db,
      $_db.salaryRecords,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_salaryRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RawIngestsTable, List<RawIngestRow>>
  _rawIngestsRefsTable(_$PulseDatabase db) => MultiTypedResultKey.fromTable(
    db.rawIngests,
    aliasName: 'transactions__id__raw_ingests__transaction_id',
  );

  $$RawIngestsTableProcessedTableManager get rawIngestsRefs {
    final manager = $$RawIngestsTableTableManager(
      $_db,
      $_db.rawIngests,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_rawIngestsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$PulseDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
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

  ColumnFilters<String> get statementId => $composableBuilder(
    column: $table.statementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantRaw => $composableBuilder(
    column: $table.merchantRaw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantNormalized => $composableBuilder(
    column: $table.merchantNormalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get postedAt => $composableBuilder(
    column: $table.postedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalHash => $composableBuilder(
    column: $table.externalHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get excludeFromBudget => $composableBuilder(
    column: $table.excludeFromBudget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sources => $composableBuilder(
    column: $table.sources,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get statementLocked => $composableBuilder(
    column: $table.statementLocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appliedRuleId => $composableBuilder(
    column: $table.appliedRuleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> statementLinesRefs(
    Expression<bool> Function($$StatementLinesTableFilterComposer f) f,
  ) {
    final $$StatementLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.statementLines,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StatementLinesTableFilterComposer(
            $db: $db,
            $table: $db.statementLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> salaryRecordsRefs(
    Expression<bool> Function($$SalaryRecordsTableFilterComposer f) f,
  ) {
    final $$SalaryRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.salaryRecords,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalaryRecordsTableFilterComposer(
            $db: $db,
            $table: $db.salaryRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> rawIngestsRefs(
    Expression<bool> Function($$RawIngestsTableFilterComposer f) f,
  ) {
    final $$RawIngestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rawIngests,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RawIngestsTableFilterComposer(
            $db: $db,
            $table: $db.rawIngests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$PulseDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
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

  ColumnOrderings<String> get statementId => $composableBuilder(
    column: $table.statementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantRaw => $composableBuilder(
    column: $table.merchantRaw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantNormalized => $composableBuilder(
    column: $table.merchantNormalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get postedAt => $composableBuilder(
    column: $table.postedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalHash => $composableBuilder(
    column: $table.externalHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get excludeFromBudget => $composableBuilder(
    column: $table.excludeFromBudget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sources => $composableBuilder(
    column: $table.sources,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get statementLocked => $composableBuilder(
    column: $table.statementLocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appliedRuleId => $composableBuilder(
    column: $table.appliedRuleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get statementId => $composableBuilder(
    column: $table.statementId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get merchantRaw => $composableBuilder(
    column: $table.merchantRaw,
    builder: (column) => column,
  );

  GeneratedColumn<String> get merchantNormalized => $composableBuilder(
    column: $table.merchantNormalized,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get postedAt =>
      $composableBuilder(column: $table.postedAt, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get externalHash => $composableBuilder(
    column: $table.externalHash,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get excludeFromBudget => $composableBuilder(
    column: $table.excludeFromBudget,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get sources =>
      $composableBuilder(column: $table.sources, builder: (column) => column);

  GeneratedColumn<bool> get statementLocked => $composableBuilder(
    column: $table.statementLocked,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appliedRuleId => $composableBuilder(
    column: $table.appliedRuleId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> statementLinesRefs<T extends Object>(
    Expression<T> Function($$StatementLinesTableAnnotationComposer a) f,
  ) {
    final $$StatementLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.statementLines,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StatementLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.statementLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> salaryRecordsRefs<T extends Object>(
    Expression<T> Function($$SalaryRecordsTableAnnotationComposer a) f,
  ) {
    final $$SalaryRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.salaryRecords,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SalaryRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.salaryRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> rawIngestsRefs<T extends Object>(
    Expression<T> Function($$RawIngestsTableAnnotationComposer a) f,
  ) {
    final $$RawIngestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rawIngests,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RawIngestsTableAnnotationComposer(
            $db: $db,
            $table: $db.rawIngests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $TransactionsTable,
          TxRow,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (TxRow, $$TransactionsTableReferences),
          TxRow,
          PrefetchHooks Function({
            bool accountId,
            bool categoryId,
            bool statementLinesRefs,
            bool salaryRecordsRefs,
            bool rawIngestsRefs,
          })
        > {
  $$TransactionsTableTableManager(_$PulseDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> statementId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String?> merchantRaw = const Value.absent(),
                Value<String?> merchantNormalized = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> postedAt = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> externalHash = const Value.absent(),
                Value<bool> excludeFromBudget = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> sources = const Value.absent(),
                Value<bool> statementLocked = const Value.absent(),
                Value<String?> appliedRuleId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                accountId: accountId,
                statementId: statementId,
                categoryId: categoryId,
                amountMinor: amountMinor,
                currency: currency,
                direction: direction,
                merchantRaw: merchantRaw,
                merchantNormalized: merchantNormalized,
                notes: notes,
                postedAt: postedAt,
                source: source,
                externalHash: externalHash,
                excludeFromBudget: excludeFromBudget,
                tags: tags,
                sources: sources,
                statementLocked: statementLocked,
                appliedRuleId: appliedRuleId,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                Value<String?> statementId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                required int amountMinor,
                Value<String> currency = const Value.absent(),
                required String direction,
                Value<String?> merchantRaw = const Value.absent(),
                Value<String?> merchantNormalized = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime postedAt,
                required String source,
                Value<String?> externalHash = const Value.absent(),
                Value<bool> excludeFromBudget = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> sources = const Value.absent(),
                Value<bool> statementLocked = const Value.absent(),
                Value<String?> appliedRuleId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                accountId: accountId,
                statementId: statementId,
                categoryId: categoryId,
                amountMinor: amountMinor,
                currency: currency,
                direction: direction,
                merchantRaw: merchantRaw,
                merchantNormalized: merchantNormalized,
                notes: notes,
                postedAt: postedAt,
                source: source,
                externalHash: externalHash,
                excludeFromBudget: excludeFromBudget,
                tags: tags,
                sources: sources,
                statementLocked: statementLocked,
                appliedRuleId: appliedRuleId,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransactionsTable, TxRow>(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                categoryId = false,
                statementLinesRefs = false,
                salaryRecordsRefs = false,
                rawIngestsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (statementLinesRefs) db.statementLines,
                    if (salaryRecordsRefs) db.salaryRecords,
                    if (rawIngestsRefs) db.rawIngests,
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
                        if (accountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.accountId,
                            referencedTable: $$TransactionsTableReferences
                                ._accountIdTable(db),
                            referencedColumn: $$TransactionsTableReferences
                                ._accountIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$TransactionsTableReferences
                                ._categoryIdTable(db),
                            referencedColumn: $$TransactionsTableReferences
                                ._categoryIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (statementLinesRefs)
                        await $_getPrefetchedDataByColumns<
                          TxRow,
                          $TransactionsTable,
                          StatementLineRow,
                          $StatementLinesTable
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._statementLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).statementLinesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'transaction_id',
                          typedResults: items,
                        ),
                      if (salaryRecordsRefs)
                        await $_getPrefetchedDataByColumns<
                          TxRow,
                          $TransactionsTable,
                          SalaryRow,
                          $SalaryRecordsTable
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._salaryRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).salaryRecordsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'transaction_id',
                          typedResults: items,
                        ),
                      if (rawIngestsRefs)
                        await $_getPrefetchedDataByColumns<
                          TxRow,
                          $TransactionsTable,
                          RawIngestRow,
                          $RawIngestsTable
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._rawIngestsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).rawIngestsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'transaction_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $TransactionsTable,
      TxRow,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (TxRow, $$TransactionsTableReferences),
      TxRow,
      PrefetchHooks Function({
        bool accountId,
        bool categoryId,
        bool statementLinesRefs,
        bool salaryRecordsRefs,
        bool rawIngestsRefs,
      })
    >;
typedef $$BudgetsTableCreateCompanionBuilder = BudgetsCompanion Function({
  required String id,
  required String categoryId,
  required String month,
  required int limitMinor,
  Value<String> currency,
  Value<bool> rollover,
  Value<int> rowid,
});
typedef $$BudgetsTableUpdateCompanionBuilder = BudgetsCompanion Function({
  Value<String> id,
  Value<String> categoryId,
  Value<String> month,
  Value<int> limitMinor,
  Value<String> currency,
  Value<bool> rollover,
  Value<int> rowid,
});

final class $$BudgetsTableReferences
    extends BaseReferences<_$PulseDatabase, $BudgetsTable, BudgetRow> {
  $$BudgetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$PulseDatabase db) =>
      db.categories.createAlias('budgets__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BudgetsTableFilterComposer
    extends Composer<_$PulseDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
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

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get limitMinor => $composableBuilder(
    column: $table.limitMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get rollover => $composableBuilder(
    column: $table.rollover,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$PulseDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
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

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get limitMinor => $composableBuilder(
    column: $table.limitMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get rollover => $composableBuilder(
    column: $table.rollover,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<int> get limitMinor => $composableBuilder(
    column: $table.limitMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<bool> get rollover =>
      $composableBuilder(column: $table.rollover, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $BudgetsTable,
          BudgetRow,
          $$BudgetsTableFilterComposer,
          $$BudgetsTableOrderingComposer,
          $$BudgetsTableAnnotationComposer,
          $$BudgetsTableCreateCompanionBuilder,
          $$BudgetsTableUpdateCompanionBuilder,
          (BudgetRow, $$BudgetsTableReferences),
          BudgetRow,
          PrefetchHooks Function({bool categoryId})
        > {
  $$BudgetsTableTableManager(_$PulseDatabase db, $BudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> month = const Value.absent(),
                Value<int> limitMinor = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<bool> rollover = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion(
                id: id,
                categoryId: categoryId,
                month: month,
                limitMinor: limitMinor,
                currency: currency,
                rollover: rollover,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String categoryId,
                required String month,
                required int limitMinor,
                Value<String> currency = const Value.absent(),
                Value<bool> rollover = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion.insert(
                id: id,
                categoryId: categoryId,
                month: month,
                limitMinor: limitMinor,
                currency: currency,
                rollover: rollover,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BudgetsTable, BudgetRow>(table),
                  $$BudgetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
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
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$BudgetsTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$BudgetsTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
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

typedef $$BudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $BudgetsTable,
      BudgetRow,
      $$BudgetsTableFilterComposer,
      $$BudgetsTableOrderingComposer,
      $$BudgetsTableAnnotationComposer,
      $$BudgetsTableCreateCompanionBuilder,
      $$BudgetsTableUpdateCompanionBuilder,
      (BudgetRow, $$BudgetsTableReferences),
      BudgetRow,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$MerchantRulesTableCreateCompanionBuilder =
    MerchantRulesCompanion Function({
      required String id,
      Value<String?> merchantKey,
      Value<String?> name,
      Value<int> priority,
      Value<bool> isActive,
      Value<String> conditions,
      Value<String?> categoryId,
      Value<String?> renameMerchant,
      Value<bool> markTransfer,
      Value<bool> excludeFromBudget,
      Value<String> tags,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$MerchantRulesTableUpdateCompanionBuilder =
    MerchantRulesCompanion Function({
      Value<String> id,
      Value<String?> merchantKey,
      Value<String?> name,
      Value<int> priority,
      Value<bool> isActive,
      Value<String> conditions,
      Value<String?> categoryId,
      Value<String?> renameMerchant,
      Value<bool> markTransfer,
      Value<bool> excludeFromBudget,
      Value<String> tags,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$MerchantRulesTableReferences
    extends BaseReferences<_$PulseDatabase, $MerchantRulesTable, RuleRow> {
  $$MerchantRulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryIdTable(_$PulseDatabase db) =>
      db.categories.createAlias('merchant_rules__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MerchantRulesTableFilterComposer
    extends Composer<_$PulseDatabase, $MerchantRulesTable> {
  $$MerchantRulesTableFilterComposer({
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

  ColumnFilters<String> get merchantKey => $composableBuilder(
    column: $table.merchantKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conditions => $composableBuilder(
    column: $table.conditions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get renameMerchant => $composableBuilder(
    column: $table.renameMerchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get markTransfer => $composableBuilder(
    column: $table.markTransfer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get excludeFromBudget => $composableBuilder(
    column: $table.excludeFromBudget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MerchantRulesTableOrderingComposer
    extends Composer<_$PulseDatabase, $MerchantRulesTable> {
  $$MerchantRulesTableOrderingComposer({
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

  ColumnOrderings<String> get merchantKey => $composableBuilder(
    column: $table.merchantKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conditions => $composableBuilder(
    column: $table.conditions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get renameMerchant => $composableBuilder(
    column: $table.renameMerchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get markTransfer => $composableBuilder(
    column: $table.markTransfer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get excludeFromBudget => $composableBuilder(
    column: $table.excludeFromBudget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MerchantRulesTableAnnotationComposer
    extends Composer<_$PulseDatabase, $MerchantRulesTable> {
  $$MerchantRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get merchantKey => $composableBuilder(
    column: $table.merchantKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get conditions => $composableBuilder(
    column: $table.conditions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get renameMerchant => $composableBuilder(
    column: $table.renameMerchant,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get markTransfer => $composableBuilder(
    column: $table.markTransfer,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get excludeFromBudget => $composableBuilder(
    column: $table.excludeFromBudget,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MerchantRulesTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $MerchantRulesTable,
          RuleRow,
          $$MerchantRulesTableFilterComposer,
          $$MerchantRulesTableOrderingComposer,
          $$MerchantRulesTableAnnotationComposer,
          $$MerchantRulesTableCreateCompanionBuilder,
          $$MerchantRulesTableUpdateCompanionBuilder,
          (RuleRow, $$MerchantRulesTableReferences),
          RuleRow,
          PrefetchHooks Function({bool categoryId})
        > {
  $$MerchantRulesTableTableManager(
    _$PulseDatabase db,
    $MerchantRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MerchantRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MerchantRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MerchantRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> merchantKey = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> conditions = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> renameMerchant = const Value.absent(),
                Value<bool> markTransfer = const Value.absent(),
                Value<bool> excludeFromBudget = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MerchantRulesCompanion(
                id: id,
                merchantKey: merchantKey,
                name: name,
                priority: priority,
                isActive: isActive,
                conditions: conditions,
                categoryId: categoryId,
                renameMerchant: renameMerchant,
                markTransfer: markTransfer,
                excludeFromBudget: excludeFromBudget,
                tags: tags,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> merchantKey = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> conditions = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> renameMerchant = const Value.absent(),
                Value<bool> markTransfer = const Value.absent(),
                Value<bool> excludeFromBudget = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MerchantRulesCompanion.insert(
                id: id,
                merchantKey: merchantKey,
                name: name,
                priority: priority,
                isActive: isActive,
                conditions: conditions,
                categoryId: categoryId,
                renameMerchant: renameMerchant,
                markTransfer: markTransfer,
                excludeFromBudget: excludeFromBudget,
                tags: tags,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MerchantRulesTable, RuleRow>(table),
                  $$MerchantRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
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
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$MerchantRulesTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$MerchantRulesTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
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

typedef $$MerchantRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $MerchantRulesTable,
      RuleRow,
      $$MerchantRulesTableFilterComposer,
      $$MerchantRulesTableOrderingComposer,
      $$MerchantRulesTableAnnotationComposer,
      $$MerchantRulesTableCreateCompanionBuilder,
      $$MerchantRulesTableUpdateCompanionBuilder,
      (RuleRow, $$MerchantRulesTableReferences),
      RuleRow,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$StatementsTableCreateCompanionBuilder = StatementsCompanion Function({
  required String id,
  Value<String?> accountId,
  Value<String?> periodStart,
  Value<String?> periodEnd,
  Value<String> currency,
  Value<int?> openingBalanceMinor,
  Value<int?> closingBalanceMinor,
  Value<String> parseStatus,
  Value<String> reconciliationStatus,
  Value<int?> diffMinor,
  Value<String?> institution,
  Value<String?> kind,
  Value<String> source,
  Value<String?> fileSha256,
  Value<String?> originalFilename,
  Value<String?> parseError,
  Value<String?> summary,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$StatementsTableUpdateCompanionBuilder = StatementsCompanion Function({
  Value<String> id,
  Value<String?> accountId,
  Value<String?> periodStart,
  Value<String?> periodEnd,
  Value<String> currency,
  Value<int?> openingBalanceMinor,
  Value<int?> closingBalanceMinor,
  Value<String> parseStatus,
  Value<String> reconciliationStatus,
  Value<int?> diffMinor,
  Value<String?> institution,
  Value<String?> kind,
  Value<String> source,
  Value<String?> fileSha256,
  Value<String?> originalFilename,
  Value<String?> parseError,
  Value<String?> summary,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$StatementsTableReferences
    extends BaseReferences<_$PulseDatabase, $StatementsTable, StatementRow> {
  $$StatementsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$PulseDatabase db) =>
      db.accounts.createAlias('statements__account_id__accounts__id');

  $$AccountsTableProcessedTableManager? get accountId {
    final $_column = $_itemColumn<String>('account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$StatementLinesTable, List<StatementLineRow>>
  _statementLinesRefsTable(_$PulseDatabase db) => MultiTypedResultKey.fromTable(
    db.statementLines,
    aliasName: 'statements__id__statement_lines__statement_id',
  );

  $$StatementLinesTableProcessedTableManager get statementLinesRefs {
    final manager = $$StatementLinesTableTableManager(
      $_db,
      $_db.statementLines,
    ).filter((f) => f.statementId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_statementLinesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StatementsTableFilterComposer
    extends Composer<_$PulseDatabase, $StatementsTable> {
  $$StatementsTableFilterComposer({
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

  ColumnFilters<String> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodEnd => $composableBuilder(
    column: $table.periodEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openingBalanceMinor => $composableBuilder(
    column: $table.openingBalanceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get closingBalanceMinor => $composableBuilder(
    column: $table.closingBalanceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parseStatus => $composableBuilder(
    column: $table.parseStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reconciliationStatus => $composableBuilder(
    column: $table.reconciliationStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diffMinor => $composableBuilder(
    column: $table.diffMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileSha256 => $composableBuilder(
    column: $table.fileSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalFilename => $composableBuilder(
    column: $table.originalFilename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parseError => $composableBuilder(
    column: $table.parseError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> statementLinesRefs(
    Expression<bool> Function($$StatementLinesTableFilterComposer f) f,
  ) {
    final $$StatementLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.statementLines,
      getReferencedColumn: (t) => t.statementId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StatementLinesTableFilterComposer(
            $db: $db,
            $table: $db.statementLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StatementsTableOrderingComposer
    extends Composer<_$PulseDatabase, $StatementsTable> {
  $$StatementsTableOrderingComposer({
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

  ColumnOrderings<String> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodEnd => $composableBuilder(
    column: $table.periodEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openingBalanceMinor => $composableBuilder(
    column: $table.openingBalanceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get closingBalanceMinor => $composableBuilder(
    column: $table.closingBalanceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parseStatus => $composableBuilder(
    column: $table.parseStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reconciliationStatus => $composableBuilder(
    column: $table.reconciliationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diffMinor => $composableBuilder(
    column: $table.diffMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileSha256 => $composableBuilder(
    column: $table.fileSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalFilename => $composableBuilder(
    column: $table.originalFilename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parseError => $composableBuilder(
    column: $table.parseError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StatementsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $StatementsTable> {
  $$StatementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get periodStart => $composableBuilder(
    column: $table.periodStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get periodEnd =>
      $composableBuilder(column: $table.periodEnd, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get openingBalanceMinor => $composableBuilder(
    column: $table.openingBalanceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get closingBalanceMinor => $composableBuilder(
    column: $table.closingBalanceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parseStatus => $composableBuilder(
    column: $table.parseStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reconciliationStatus => $composableBuilder(
    column: $table.reconciliationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get diffMinor =>
      $composableBuilder(column: $table.diffMinor, builder: (column) => column);

  GeneratedColumn<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get fileSha256 => $composableBuilder(
    column: $table.fileSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalFilename => $composableBuilder(
    column: $table.originalFilename,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parseError => $composableBuilder(
    column: $table.parseError,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> statementLinesRefs<T extends Object>(
    Expression<T> Function($$StatementLinesTableAnnotationComposer a) f,
  ) {
    final $$StatementLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.statementLines,
      getReferencedColumn: (t) => t.statementId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StatementLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.statementLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StatementsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $StatementsTable,
          StatementRow,
          $$StatementsTableFilterComposer,
          $$StatementsTableOrderingComposer,
          $$StatementsTableAnnotationComposer,
          $$StatementsTableCreateCompanionBuilder,
          $$StatementsTableUpdateCompanionBuilder,
          (StatementRow, $$StatementsTableReferences),
          StatementRow,
          PrefetchHooks Function({bool accountId, bool statementLinesRefs})
        > {
  $$StatementsTableTableManager(_$PulseDatabase db, $StatementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StatementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StatementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StatementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> periodStart = const Value.absent(),
                Value<String?> periodEnd = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int?> openingBalanceMinor = const Value.absent(),
                Value<int?> closingBalanceMinor = const Value.absent(),
                Value<String> parseStatus = const Value.absent(),
                Value<String> reconciliationStatus = const Value.absent(),
                Value<int?> diffMinor = const Value.absent(),
                Value<String?> institution = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> fileSha256 = const Value.absent(),
                Value<String?> originalFilename = const Value.absent(),
                Value<String?> parseError = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StatementsCompanion(
                id: id,
                accountId: accountId,
                periodStart: periodStart,
                periodEnd: periodEnd,
                currency: currency,
                openingBalanceMinor: openingBalanceMinor,
                closingBalanceMinor: closingBalanceMinor,
                parseStatus: parseStatus,
                reconciliationStatus: reconciliationStatus,
                diffMinor: diffMinor,
                institution: institution,
                kind: kind,
                source: source,
                fileSha256: fileSha256,
                originalFilename: originalFilename,
                parseError: parseError,
                summary: summary,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> accountId = const Value.absent(),
                Value<String?> periodStart = const Value.absent(),
                Value<String?> periodEnd = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int?> openingBalanceMinor = const Value.absent(),
                Value<int?> closingBalanceMinor = const Value.absent(),
                Value<String> parseStatus = const Value.absent(),
                Value<String> reconciliationStatus = const Value.absent(),
                Value<int?> diffMinor = const Value.absent(),
                Value<String?> institution = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> fileSha256 = const Value.absent(),
                Value<String?> originalFilename = const Value.absent(),
                Value<String?> parseError = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StatementsCompanion.insert(
                id: id,
                accountId: accountId,
                periodStart: periodStart,
                periodEnd: periodEnd,
                currency: currency,
                openingBalanceMinor: openingBalanceMinor,
                closingBalanceMinor: closingBalanceMinor,
                parseStatus: parseStatus,
                reconciliationStatus: reconciliationStatus,
                diffMinor: diffMinor,
                institution: institution,
                kind: kind,
                source: source,
                fileSha256: fileSha256,
                originalFilename: originalFilename,
                parseError: parseError,
                summary: summary,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StatementsTable, StatementRow>(table),
                  $$StatementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({accountId = false, statementLinesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (statementLinesRefs) db.statementLines,
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
                        if (accountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.accountId,
                            referencedTable: $$StatementsTableReferences
                                ._accountIdTable(db),
                            referencedColumn: $$StatementsTableReferences
                                ._accountIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (statementLinesRefs)
                        await $_getPrefetchedDataByColumns<
                          StatementRow,
                          $StatementsTable,
                          StatementLineRow,
                          $StatementLinesTable
                        >(
                          currentTable: table,
                          referencedTable: $$StatementsTableReferences
                              ._statementLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StatementsTableReferences(
                                db,
                                table,
                                p0,
                              ).statementLinesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'statement_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$StatementsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $StatementsTable,
      StatementRow,
      $$StatementsTableFilterComposer,
      $$StatementsTableOrderingComposer,
      $$StatementsTableAnnotationComposer,
      $$StatementsTableCreateCompanionBuilder,
      $$StatementsTableUpdateCompanionBuilder,
      (StatementRow, $$StatementsTableReferences),
      StatementRow,
      PrefetchHooks Function({bool accountId, bool statementLinesRefs})
    >;
typedef $$StatementLinesTableCreateCompanionBuilder =
    StatementLinesCompanion Function({
      required String id,
      required String statementId,
      required int lineNo,
      required String postedOn,
      required String description,
      required int amountMinor,
      Value<String> currency,
      required String direction,
      Value<int?> foreignAmountMinor,
      Value<String?> foreignCurrency,
      Value<int?> balanceMinor,
      Value<String?> transactionId,
      Value<String> matchStatus,
      Value<int?> matchScore,
      Value<int> rowid,
    });
typedef $$StatementLinesTableUpdateCompanionBuilder =
    StatementLinesCompanion Function({
      Value<String> id,
      Value<String> statementId,
      Value<int> lineNo,
      Value<String> postedOn,
      Value<String> description,
      Value<int> amountMinor,
      Value<String> currency,
      Value<String> direction,
      Value<int?> foreignAmountMinor,
      Value<String?> foreignCurrency,
      Value<int?> balanceMinor,
      Value<String?> transactionId,
      Value<String> matchStatus,
      Value<int?> matchScore,
      Value<int> rowid,
    });

final class $$StatementLinesTableReferences
    extends
        BaseReferences<
          _$PulseDatabase,
          $StatementLinesTable,
          StatementLineRow
        > {
  $$StatementLinesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StatementsTable _statementIdTable(_$PulseDatabase db) => db.statements
      .createAlias('statement_lines__statement_id__statements__id');

  $$StatementsTableProcessedTableManager get statementId {
    final $_column = $_itemColumn<String>('statement_id')!;

    final manager = $$StatementsTableTableManager(
      $_db,
      $_db.statements,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_statementIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TransactionsTable _transactionIdTable(_$PulseDatabase db) => db
      .transactions
      .createAlias('statement_lines__transaction_id__transactions__id');

  $$TransactionsTableProcessedTableManager? get transactionId {
    final $_column = $_itemColumn<String>('transaction_id');
    if ($_column == null) return null;
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StatementLinesTableFilterComposer
    extends Composer<_$PulseDatabase, $StatementLinesTable> {
  $$StatementLinesTableFilterComposer({
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

  ColumnFilters<int> get lineNo => $composableBuilder(
    column: $table.lineNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postedOn => $composableBuilder(
    column: $table.postedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get foreignAmountMinor => $composableBuilder(
    column: $table.foreignAmountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foreignCurrency => $composableBuilder(
    column: $table.foreignCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get balanceMinor => $composableBuilder(
    column: $table.balanceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchStatus => $composableBuilder(
    column: $table.matchStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get matchScore => $composableBuilder(
    column: $table.matchScore,
    builder: (column) => ColumnFilters(column),
  );

  $$StatementsTableFilterComposer get statementId {
    final $$StatementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.statementId,
      referencedTable: $db.statements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StatementsTableFilterComposer(
            $db: $db,
            $table: $db.statements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StatementLinesTableOrderingComposer
    extends Composer<_$PulseDatabase, $StatementLinesTable> {
  $$StatementLinesTableOrderingComposer({
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

  ColumnOrderings<int> get lineNo => $composableBuilder(
    column: $table.lineNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postedOn => $composableBuilder(
    column: $table.postedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get foreignAmountMinor => $composableBuilder(
    column: $table.foreignAmountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foreignCurrency => $composableBuilder(
    column: $table.foreignCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get balanceMinor => $composableBuilder(
    column: $table.balanceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchStatus => $composableBuilder(
    column: $table.matchStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get matchScore => $composableBuilder(
    column: $table.matchScore,
    builder: (column) => ColumnOrderings(column),
  );

  $$StatementsTableOrderingComposer get statementId {
    final $$StatementsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.statementId,
      referencedTable: $db.statements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StatementsTableOrderingComposer(
            $db: $db,
            $table: $db.statements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StatementLinesTableAnnotationComposer
    extends Composer<_$PulseDatabase, $StatementLinesTable> {
  $$StatementLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lineNo =>
      $composableBuilder(column: $table.lineNo, builder: (column) => column);

  GeneratedColumn<String> get postedOn =>
      $composableBuilder(column: $table.postedOn, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get foreignAmountMinor => $composableBuilder(
    column: $table.foreignAmountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get foreignCurrency => $composableBuilder(
    column: $table.foreignCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<int> get balanceMinor => $composableBuilder(
    column: $table.balanceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get matchStatus => $composableBuilder(
    column: $table.matchStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get matchScore => $composableBuilder(
    column: $table.matchScore,
    builder: (column) => column,
  );

  $$StatementsTableAnnotationComposer get statementId {
    final $$StatementsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.statementId,
      referencedTable: $db.statements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StatementsTableAnnotationComposer(
            $db: $db,
            $table: $db.statements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StatementLinesTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $StatementLinesTable,
          StatementLineRow,
          $$StatementLinesTableFilterComposer,
          $$StatementLinesTableOrderingComposer,
          $$StatementLinesTableAnnotationComposer,
          $$StatementLinesTableCreateCompanionBuilder,
          $$StatementLinesTableUpdateCompanionBuilder,
          (StatementLineRow, $$StatementLinesTableReferences),
          StatementLineRow,
          PrefetchHooks Function({bool statementId, bool transactionId})
        > {
  $$StatementLinesTableTableManager(
    _$PulseDatabase db,
    $StatementLinesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StatementLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StatementLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StatementLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> statementId = const Value.absent(),
                Value<int> lineNo = const Value.absent(),
                Value<String> postedOn = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<int?> foreignAmountMinor = const Value.absent(),
                Value<String?> foreignCurrency = const Value.absent(),
                Value<int?> balanceMinor = const Value.absent(),
                Value<String?> transactionId = const Value.absent(),
                Value<String> matchStatus = const Value.absent(),
                Value<int?> matchScore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StatementLinesCompanion(
                id: id,
                statementId: statementId,
                lineNo: lineNo,
                postedOn: postedOn,
                description: description,
                amountMinor: amountMinor,
                currency: currency,
                direction: direction,
                foreignAmountMinor: foreignAmountMinor,
                foreignCurrency: foreignCurrency,
                balanceMinor: balanceMinor,
                transactionId: transactionId,
                matchStatus: matchStatus,
                matchScore: matchScore,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String statementId,
                required int lineNo,
                required String postedOn,
                required String description,
                required int amountMinor,
                Value<String> currency = const Value.absent(),
                required String direction,
                Value<int?> foreignAmountMinor = const Value.absent(),
                Value<String?> foreignCurrency = const Value.absent(),
                Value<int?> balanceMinor = const Value.absent(),
                Value<String?> transactionId = const Value.absent(),
                Value<String> matchStatus = const Value.absent(),
                Value<int?> matchScore = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StatementLinesCompanion.insert(
                id: id,
                statementId: statementId,
                lineNo: lineNo,
                postedOn: postedOn,
                description: description,
                amountMinor: amountMinor,
                currency: currency,
                direction: direction,
                foreignAmountMinor: foreignAmountMinor,
                foreignCurrency: foreignCurrency,
                balanceMinor: balanceMinor,
                transactionId: transactionId,
                matchStatus: matchStatus,
                matchScore: matchScore,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StatementLinesTable, StatementLineRow>(table),
                  $$StatementLinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({statementId = false, transactionId = false}) {
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
                        if (statementId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.statementId,
                            referencedTable: $$StatementLinesTableReferences
                                ._statementIdTable(db),
                            referencedColumn: $$StatementLinesTableReferences
                                ._statementIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (transactionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.transactionId,
                            referencedTable: $$StatementLinesTableReferences
                                ._transactionIdTable(db),
                            referencedColumn: $$StatementLinesTableReferences
                                ._transactionIdTable(db)
                                .id,
                          ) as T;
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

typedef $$StatementLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $StatementLinesTable,
      StatementLineRow,
      $$StatementLinesTableFilterComposer,
      $$StatementLinesTableOrderingComposer,
      $$StatementLinesTableAnnotationComposer,
      $$StatementLinesTableCreateCompanionBuilder,
      $$StatementLinesTableUpdateCompanionBuilder,
      (StatementLineRow, $$StatementLinesTableReferences),
      StatementLineRow,
      PrefetchHooks Function({bool statementId, bool transactionId})
    >;
typedef $$AssetsTableCreateCompanionBuilder = AssetsCompanion Function({
  required String id,
  required String kind,
  required String name,
  Value<double?> quantity,
  Value<String?> unit,
  Value<String> currency,
  Value<int?> costBasisMinor,
  Value<int?> manualValueMinor,
  Value<String> valuationSource,
  Value<DateTime?> valuedAt,
  Value<String?> acquiredOn,
  Value<int?> marketValueMinor,
  Value<DateTime?> marketValuedAt,
  Value<String?> valuationNote,
  Value<String> meta,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$AssetsTableUpdateCompanionBuilder = AssetsCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> name,
  Value<double?> quantity,
  Value<String?> unit,
  Value<String> currency,
  Value<int?> costBasisMinor,
  Value<int?> manualValueMinor,
  Value<String> valuationSource,
  Value<DateTime?> valuedAt,
  Value<String?> acquiredOn,
  Value<int?> marketValueMinor,
  Value<DateTime?> marketValuedAt,
  Value<String?> valuationNote,
  Value<String> meta,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$AssetsTableFilterComposer
    extends Composer<_$PulseDatabase, $AssetsTable> {
  $$AssetsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costBasisMinor => $composableBuilder(
    column: $table.costBasisMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get manualValueMinor => $composableBuilder(
    column: $table.manualValueMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valuationSource => $composableBuilder(
    column: $table.valuationSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get valuedAt => $composableBuilder(
    column: $table.valuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get acquiredOn => $composableBuilder(
    column: $table.acquiredOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get marketValueMinor => $composableBuilder(
    column: $table.marketValueMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get marketValuedAt => $composableBuilder(
    column: $table.marketValuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valuationNote => $composableBuilder(
    column: $table.valuationNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AssetsTableOrderingComposer
    extends Composer<_$PulseDatabase, $AssetsTable> {
  $$AssetsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costBasisMinor => $composableBuilder(
    column: $table.costBasisMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get manualValueMinor => $composableBuilder(
    column: $table.manualValueMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valuationSource => $composableBuilder(
    column: $table.valuationSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get valuedAt => $composableBuilder(
    column: $table.valuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get acquiredOn => $composableBuilder(
    column: $table.acquiredOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get marketValueMinor => $composableBuilder(
    column: $table.marketValueMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get marketValuedAt => $composableBuilder(
    column: $table.marketValuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valuationNote => $composableBuilder(
    column: $table.valuationNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AssetsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $AssetsTable> {
  $$AssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get costBasisMinor => $composableBuilder(
    column: $table.costBasisMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get manualValueMinor => $composableBuilder(
    column: $table.manualValueMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get valuationSource => $composableBuilder(
    column: $table.valuationSource,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get valuedAt =>
      $composableBuilder(column: $table.valuedAt, builder: (column) => column);

  GeneratedColumn<String> get acquiredOn => $composableBuilder(
    column: $table.acquiredOn,
    builder: (column) => column,
  );

  GeneratedColumn<int> get marketValueMinor => $composableBuilder(
    column: $table.marketValueMinor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get marketValuedAt => $composableBuilder(
    column: $table.marketValuedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get valuationNote => $composableBuilder(
    column: $table.valuationNote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$AssetsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $AssetsTable,
          AssetRow,
          $$AssetsTableFilterComposer,
          $$AssetsTableOrderingComposer,
          $$AssetsTableAnnotationComposer,
          $$AssetsTableCreateCompanionBuilder,
          $$AssetsTableUpdateCompanionBuilder,
          (AssetRow, BaseReferences<_$PulseDatabase, $AssetsTable, AssetRow>),
          AssetRow,
          PrefetchHooks Function()
        > {
  $$AssetsTableTableManager(_$PulseDatabase db, $AssetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> quantity = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int?> costBasisMinor = const Value.absent(),
                Value<int?> manualValueMinor = const Value.absent(),
                Value<String> valuationSource = const Value.absent(),
                Value<DateTime?> valuedAt = const Value.absent(),
                Value<String?> acquiredOn = const Value.absent(),
                Value<int?> marketValueMinor = const Value.absent(),
                Value<DateTime?> marketValuedAt = const Value.absent(),
                Value<String?> valuationNote = const Value.absent(),
                Value<String> meta = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetsCompanion(
                id: id,
                kind: kind,
                name: name,
                quantity: quantity,
                unit: unit,
                currency: currency,
                costBasisMinor: costBasisMinor,
                manualValueMinor: manualValueMinor,
                valuationSource: valuationSource,
                valuedAt: valuedAt,
                acquiredOn: acquiredOn,
                marketValueMinor: marketValueMinor,
                marketValuedAt: marketValuedAt,
                valuationNote: valuationNote,
                meta: meta,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String name,
                Value<double?> quantity = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int?> costBasisMinor = const Value.absent(),
                Value<int?> manualValueMinor = const Value.absent(),
                Value<String> valuationSource = const Value.absent(),
                Value<DateTime?> valuedAt = const Value.absent(),
                Value<String?> acquiredOn = const Value.absent(),
                Value<int?> marketValueMinor = const Value.absent(),
                Value<DateTime?> marketValuedAt = const Value.absent(),
                Value<String?> valuationNote = const Value.absent(),
                Value<String> meta = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetsCompanion.insert(
                id: id,
                kind: kind,
                name: name,
                quantity: quantity,
                unit: unit,
                currency: currency,
                costBasisMinor: costBasisMinor,
                manualValueMinor: manualValueMinor,
                valuationSource: valuationSource,
                valuedAt: valuedAt,
                acquiredOn: acquiredOn,
                marketValueMinor: marketValueMinor,
                marketValuedAt: marketValuedAt,
                valuationNote: valuationNote,
                meta: meta,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AssetsTable, AssetRow>(table),
                  BaseReferences<_$PulseDatabase, $AssetsTable, AssetRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $AssetsTable,
      AssetRow,
      $$AssetsTableFilterComposer,
      $$AssetsTableOrderingComposer,
      $$AssetsTableAnnotationComposer,
      $$AssetsTableCreateCompanionBuilder,
      $$AssetsTableUpdateCompanionBuilder,
      (AssetRow, BaseReferences<_$PulseDatabase, $AssetsTable, AssetRow>),
      AssetRow,
      PrefetchHooks Function()
    >;
typedef $$LiabilitiesTableCreateCompanionBuilder =
    LiabilitiesCompanion Function({
      required String id,
      Value<String?> accountId,
      required String kind,
      required String name,
      Value<String?> lender,
      Value<String> currency,
      Value<int?> principalMinor,
      required int outstandingMinor,
      Value<int?> interestRateBps,
      Value<int?> emiMinor,
      Value<String?> nextDueOn,
      Value<String?> endDate,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$LiabilitiesTableUpdateCompanionBuilder =
    LiabilitiesCompanion Function({
      Value<String> id,
      Value<String?> accountId,
      Value<String> kind,
      Value<String> name,
      Value<String?> lender,
      Value<String> currency,
      Value<int?> principalMinor,
      Value<int> outstandingMinor,
      Value<int?> interestRateBps,
      Value<int?> emiMinor,
      Value<String?> nextDueOn,
      Value<String?> endDate,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$LiabilitiesTableReferences
    extends BaseReferences<_$PulseDatabase, $LiabilitiesTable, LiabilityRow> {
  $$LiabilitiesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$PulseDatabase db) =>
      db.accounts.createAlias('liabilities__account_id__accounts__id');

  $$AccountsTableProcessedTableManager? get accountId {
    final $_column = $_itemColumn<String>('account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LiabilitiesTableFilterComposer
    extends Composer<_$PulseDatabase, $LiabilitiesTable> {
  $$LiabilitiesTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lender => $composableBuilder(
    column: $table.lender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get principalMinor => $composableBuilder(
    column: $table.principalMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outstandingMinor => $composableBuilder(
    column: $table.outstandingMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get interestRateBps => $composableBuilder(
    column: $table.interestRateBps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get emiMinor => $composableBuilder(
    column: $table.emiMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextDueOn => $composableBuilder(
    column: $table.nextDueOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LiabilitiesTableOrderingComposer
    extends Composer<_$PulseDatabase, $LiabilitiesTable> {
  $$LiabilitiesTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lender => $composableBuilder(
    column: $table.lender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get principalMinor => $composableBuilder(
    column: $table.principalMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outstandingMinor => $composableBuilder(
    column: $table.outstandingMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interestRateBps => $composableBuilder(
    column: $table.interestRateBps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get emiMinor => $composableBuilder(
    column: $table.emiMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextDueOn => $composableBuilder(
    column: $table.nextDueOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LiabilitiesTableAnnotationComposer
    extends Composer<_$PulseDatabase, $LiabilitiesTable> {
  $$LiabilitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get lender =>
      $composableBuilder(column: $table.lender, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get principalMinor => $composableBuilder(
    column: $table.principalMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outstandingMinor => $composableBuilder(
    column: $table.outstandingMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get interestRateBps => $composableBuilder(
    column: $table.interestRateBps,
    builder: (column) => column,
  );

  GeneratedColumn<int> get emiMinor =>
      $composableBuilder(column: $table.emiMinor, builder: (column) => column);

  GeneratedColumn<String> get nextDueOn =>
      $composableBuilder(column: $table.nextDueOn, builder: (column) => column);

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LiabilitiesTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $LiabilitiesTable,
          LiabilityRow,
          $$LiabilitiesTableFilterComposer,
          $$LiabilitiesTableOrderingComposer,
          $$LiabilitiesTableAnnotationComposer,
          $$LiabilitiesTableCreateCompanionBuilder,
          $$LiabilitiesTableUpdateCompanionBuilder,
          (LiabilityRow, $$LiabilitiesTableReferences),
          LiabilityRow,
          PrefetchHooks Function({bool accountId})
        > {
  $$LiabilitiesTableTableManager(_$PulseDatabase db, $LiabilitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LiabilitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LiabilitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LiabilitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> lender = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int?> principalMinor = const Value.absent(),
                Value<int> outstandingMinor = const Value.absent(),
                Value<int?> interestRateBps = const Value.absent(),
                Value<int?> emiMinor = const Value.absent(),
                Value<String?> nextDueOn = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LiabilitiesCompanion(
                id: id,
                accountId: accountId,
                kind: kind,
                name: name,
                lender: lender,
                currency: currency,
                principalMinor: principalMinor,
                outstandingMinor: outstandingMinor,
                interestRateBps: interestRateBps,
                emiMinor: emiMinor,
                nextDueOn: nextDueOn,
                endDate: endDate,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> accountId = const Value.absent(),
                required String kind,
                required String name,
                Value<String?> lender = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int?> principalMinor = const Value.absent(),
                required int outstandingMinor,
                Value<int?> interestRateBps = const Value.absent(),
                Value<int?> emiMinor = const Value.absent(),
                Value<String?> nextDueOn = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LiabilitiesCompanion.insert(
                id: id,
                accountId: accountId,
                kind: kind,
                name: name,
                lender: lender,
                currency: currency,
                principalMinor: principalMinor,
                outstandingMinor: outstandingMinor,
                interestRateBps: interestRateBps,
                emiMinor: emiMinor,
                nextDueOn: nextDueOn,
                endDate: endDate,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LiabilitiesTable, LiabilityRow>(table),
                  $$LiabilitiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
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
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$LiabilitiesTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$LiabilitiesTableReferences
                            ._accountIdTable(db)
                            .id,
                      ) as T;
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

typedef $$LiabilitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $LiabilitiesTable,
      LiabilityRow,
      $$LiabilitiesTableFilterComposer,
      $$LiabilitiesTableOrderingComposer,
      $$LiabilitiesTableAnnotationComposer,
      $$LiabilitiesTableCreateCompanionBuilder,
      $$LiabilitiesTableUpdateCompanionBuilder,
      (LiabilityRow, $$LiabilitiesTableReferences),
      LiabilityRow,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$SalaryRecordsTableCreateCompanionBuilder =
    SalaryRecordsCompanion Function({
      required String id,
      Value<String?> accountId,
      Value<String?> employer,
      required int amountMinor,
      Value<String> currency,
      required String receivedOn,
      Value<String?> transactionId,
      Value<String?> matchedBy,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$SalaryRecordsTableUpdateCompanionBuilder =
    SalaryRecordsCompanion Function({
      Value<String> id,
      Value<String?> accountId,
      Value<String?> employer,
      Value<int> amountMinor,
      Value<String> currency,
      Value<String> receivedOn,
      Value<String?> transactionId,
      Value<String?> matchedBy,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$SalaryRecordsTableReferences
    extends BaseReferences<_$PulseDatabase, $SalaryRecordsTable, SalaryRow> {
  $$SalaryRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _accountIdTable(_$PulseDatabase db) =>
      db.accounts.createAlias('salary_records__account_id__accounts__id');

  $$AccountsTableProcessedTableManager? get accountId {
    final $_column = $_itemColumn<String>('account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TransactionsTable _transactionIdTable(_$PulseDatabase db) => db
      .transactions
      .createAlias('salary_records__transaction_id__transactions__id');

  $$TransactionsTableProcessedTableManager? get transactionId {
    final $_column = $_itemColumn<String>('transaction_id');
    if ($_column == null) return null;
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SalaryRecordsTableFilterComposer
    extends Composer<_$PulseDatabase, $SalaryRecordsTable> {
  $$SalaryRecordsTableFilterComposer({
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

  ColumnFilters<String> get employer => $composableBuilder(
    column: $table.employer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receivedOn => $composableBuilder(
    column: $table.receivedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchedBy => $composableBuilder(
    column: $table.matchedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SalaryRecordsTableOrderingComposer
    extends Composer<_$PulseDatabase, $SalaryRecordsTable> {
  $$SalaryRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get employer => $composableBuilder(
    column: $table.employer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receivedOn => $composableBuilder(
    column: $table.receivedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchedBy => $composableBuilder(
    column: $table.matchedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SalaryRecordsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $SalaryRecordsTable> {
  $$SalaryRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get employer =>
      $composableBuilder(column: $table.employer, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get receivedOn => $composableBuilder(
    column: $table.receivedOn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get matchedBy =>
      $composableBuilder(column: $table.matchedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SalaryRecordsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $SalaryRecordsTable,
          SalaryRow,
          $$SalaryRecordsTableFilterComposer,
          $$SalaryRecordsTableOrderingComposer,
          $$SalaryRecordsTableAnnotationComposer,
          $$SalaryRecordsTableCreateCompanionBuilder,
          $$SalaryRecordsTableUpdateCompanionBuilder,
          (SalaryRow, $$SalaryRecordsTableReferences),
          SalaryRow,
          PrefetchHooks Function({bool accountId, bool transactionId})
        > {
  $$SalaryRecordsTableTableManager(
    _$PulseDatabase db,
    $SalaryRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalaryRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalaryRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalaryRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> employer = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> receivedOn = const Value.absent(),
                Value<String?> transactionId = const Value.absent(),
                Value<String?> matchedBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SalaryRecordsCompanion(
                id: id,
                accountId: accountId,
                employer: employer,
                amountMinor: amountMinor,
                currency: currency,
                receivedOn: receivedOn,
                transactionId: transactionId,
                matchedBy: matchedBy,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> accountId = const Value.absent(),
                Value<String?> employer = const Value.absent(),
                required int amountMinor,
                Value<String> currency = const Value.absent(),
                required String receivedOn,
                Value<String?> transactionId = const Value.absent(),
                Value<String?> matchedBy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SalaryRecordsCompanion.insert(
                id: id,
                accountId: accountId,
                employer: employer,
                amountMinor: amountMinor,
                currency: currency,
                receivedOn: receivedOn,
                transactionId: transactionId,
                matchedBy: matchedBy,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SalaryRecordsTable, SalaryRow>(table),
                  $$SalaryRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false, transactionId = false}) {
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
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$SalaryRecordsTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$SalaryRecordsTableReferences
                            ._accountIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (transactionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.transactionId,
                        referencedTable: $$SalaryRecordsTableReferences
                            ._transactionIdTable(db),
                        referencedColumn: $$SalaryRecordsTableReferences
                            ._transactionIdTable(db)
                            .id,
                      ) as T;
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

typedef $$SalaryRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $SalaryRecordsTable,
      SalaryRow,
      $$SalaryRecordsTableFilterComposer,
      $$SalaryRecordsTableOrderingComposer,
      $$SalaryRecordsTableAnnotationComposer,
      $$SalaryRecordsTableCreateCompanionBuilder,
      $$SalaryRecordsTableUpdateCompanionBuilder,
      (SalaryRow, $$SalaryRecordsTableReferences),
      SalaryRow,
      PrefetchHooks Function({bool accountId, bool transactionId})
    >;
typedef $$SavingsGoalsTableCreateCompanionBuilder =
    SavingsGoalsCompanion Function({
      required String id,
      required String name,
      required int targetMinor,
      Value<int> savedMinor,
      Value<String> currency,
      Value<String?> targetDate,
      Value<int?> monthlyContributionMinor,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$SavingsGoalsTableUpdateCompanionBuilder =
    SavingsGoalsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> targetMinor,
      Value<int> savedMinor,
      Value<String> currency,
      Value<String?> targetDate,
      Value<int?> monthlyContributionMinor,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$SavingsGoalsTableFilterComposer
    extends Composer<_$PulseDatabase, $SavingsGoalsTable> {
  $$SavingsGoalsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetMinor => $composableBuilder(
    column: $table.targetMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get savedMinor => $composableBuilder(
    column: $table.savedMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthlyContributionMinor => $composableBuilder(
    column: $table.monthlyContributionMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavingsGoalsTableOrderingComposer
    extends Composer<_$PulseDatabase, $SavingsGoalsTable> {
  $$SavingsGoalsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetMinor => $composableBuilder(
    column: $table.targetMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get savedMinor => $composableBuilder(
    column: $table.savedMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthlyContributionMinor => $composableBuilder(
    column: $table.monthlyContributionMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavingsGoalsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $SavingsGoalsTable> {
  $$SavingsGoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get targetMinor => $composableBuilder(
    column: $table.targetMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get savedMinor => $composableBuilder(
    column: $table.savedMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get monthlyContributionMinor => $composableBuilder(
    column: $table.monthlyContributionMinor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$SavingsGoalsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $SavingsGoalsTable,
          GoalRow,
          $$SavingsGoalsTableFilterComposer,
          $$SavingsGoalsTableOrderingComposer,
          $$SavingsGoalsTableAnnotationComposer,
          $$SavingsGoalsTableCreateCompanionBuilder,
          $$SavingsGoalsTableUpdateCompanionBuilder,
          (
            GoalRow,
            BaseReferences<_$PulseDatabase, $SavingsGoalsTable, GoalRow>,
          ),
          GoalRow,
          PrefetchHooks Function()
        > {
  $$SavingsGoalsTableTableManager(_$PulseDatabase db, $SavingsGoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavingsGoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavingsGoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavingsGoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> targetMinor = const Value.absent(),
                Value<int> savedMinor = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> targetDate = const Value.absent(),
                Value<int?> monthlyContributionMinor = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavingsGoalsCompanion(
                id: id,
                name: name,
                targetMinor: targetMinor,
                savedMinor: savedMinor,
                currency: currency,
                targetDate: targetDate,
                monthlyContributionMinor: monthlyContributionMinor,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int targetMinor,
                Value<int> savedMinor = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> targetDate = const Value.absent(),
                Value<int?> monthlyContributionMinor = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavingsGoalsCompanion.insert(
                id: id,
                name: name,
                targetMinor: targetMinor,
                savedMinor: savedMinor,
                currency: currency,
                targetDate: targetDate,
                monthlyContributionMinor: monthlyContributionMinor,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavingsGoalsTable, GoalRow>(table),
                  BaseReferences<_$PulseDatabase, $SavingsGoalsTable, GoalRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavingsGoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $SavingsGoalsTable,
      GoalRow,
      $$SavingsGoalsTableFilterComposer,
      $$SavingsGoalsTableOrderingComposer,
      $$SavingsGoalsTableAnnotationComposer,
      $$SavingsGoalsTableCreateCompanionBuilder,
      $$SavingsGoalsTableUpdateCompanionBuilder,
      (GoalRow, BaseReferences<_$PulseDatabase, $SavingsGoalsTable, GoalRow>),
      GoalRow,
      PrefetchHooks Function()
    >;
typedef $$RawIngestsTableCreateCompanionBuilder = RawIngestsCompanion Function({
  required String id,
  required String channel,
  required String externalHash,
  required String payload,
  Value<String> parseStatus,
  Value<String?> parseResult,
  Value<String?> error,
  Value<String?> transactionId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$RawIngestsTableUpdateCompanionBuilder = RawIngestsCompanion Function({
  Value<String> id,
  Value<String> channel,
  Value<String> externalHash,
  Value<String> payload,
  Value<String> parseStatus,
  Value<String?> parseResult,
  Value<String?> error,
  Value<String?> transactionId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$RawIngestsTableReferences
    extends BaseReferences<_$PulseDatabase, $RawIngestsTable, RawIngestRow> {
  $$RawIngestsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TransactionsTable _transactionIdTable(_$PulseDatabase db) => db
      .transactions
      .createAlias('raw_ingests__transaction_id__transactions__id');

  $$TransactionsTableProcessedTableManager? get transactionId {
    final $_column = $_itemColumn<String>('transaction_id');
    if ($_column == null) return null;
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RawIngestsTableFilterComposer
    extends Composer<_$PulseDatabase, $RawIngestsTable> {
  $$RawIngestsTableFilterComposer({
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

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalHash => $composableBuilder(
    column: $table.externalHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parseStatus => $composableBuilder(
    column: $table.parseStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parseResult => $composableBuilder(
    column: $table.parseResult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RawIngestsTableOrderingComposer
    extends Composer<_$PulseDatabase, $RawIngestsTable> {
  $$RawIngestsTableOrderingComposer({
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

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalHash => $composableBuilder(
    column: $table.externalHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parseStatus => $composableBuilder(
    column: $table.parseStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parseResult => $composableBuilder(
    column: $table.parseResult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RawIngestsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $RawIngestsTable> {
  $$RawIngestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get externalHash => $composableBuilder(
    column: $table.externalHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get parseStatus => $composableBuilder(
    column: $table.parseStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parseResult => $composableBuilder(
    column: $table.parseResult,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RawIngestsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $RawIngestsTable,
          RawIngestRow,
          $$RawIngestsTableFilterComposer,
          $$RawIngestsTableOrderingComposer,
          $$RawIngestsTableAnnotationComposer,
          $$RawIngestsTableCreateCompanionBuilder,
          $$RawIngestsTableUpdateCompanionBuilder,
          (RawIngestRow, $$RawIngestsTableReferences),
          RawIngestRow,
          PrefetchHooks Function({bool transactionId})
        > {
  $$RawIngestsTableTableManager(_$PulseDatabase db, $RawIngestsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RawIngestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RawIngestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RawIngestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> channel = const Value.absent(),
                Value<String> externalHash = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> parseStatus = const Value.absent(),
                Value<String?> parseResult = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String?> transactionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RawIngestsCompanion(
                id: id,
                channel: channel,
                externalHash: externalHash,
                payload: payload,
                parseStatus: parseStatus,
                parseResult: parseResult,
                error: error,
                transactionId: transactionId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String channel,
                required String externalHash,
                required String payload,
                Value<String> parseStatus = const Value.absent(),
                Value<String?> parseResult = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String?> transactionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RawIngestsCompanion.insert(
                id: id,
                channel: channel,
                externalHash: externalHash,
                payload: payload,
                parseStatus: parseStatus,
                parseResult: parseResult,
                error: error,
                transactionId: transactionId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RawIngestsTable, RawIngestRow>(table),
                  $$RawIngestsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionId = false}) {
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
                    if (transactionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.transactionId,
                        referencedTable: $$RawIngestsTableReferences
                            ._transactionIdTable(db),
                        referencedColumn: $$RawIngestsTableReferences
                            ._transactionIdTable(db)
                            .id,
                      ) as T;
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

typedef $$RawIngestsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $RawIngestsTable,
      RawIngestRow,
      $$RawIngestsTableFilterComposer,
      $$RawIngestsTableOrderingComposer,
      $$RawIngestsTableAnnotationComposer,
      $$RawIngestsTableCreateCompanionBuilder,
      $$RawIngestsTableUpdateCompanionBuilder,
      (RawIngestRow, $$RawIngestsTableReferences),
      RawIngestRow,
      PrefetchHooks Function({bool transactionId})
    >;
typedef $$NetWorthSnapshotsTableCreateCompanionBuilder =
    NetWorthSnapshotsCompanion Function({
      required String id,
      required String snapshotDate,
      required int assetsMinor,
      required int liabilitiesMinor,
      required int netWorthMinor,
      Value<String> breakdown,
      Value<int> rowid,
    });
typedef $$NetWorthSnapshotsTableUpdateCompanionBuilder =
    NetWorthSnapshotsCompanion Function({
      Value<String> id,
      Value<String> snapshotDate,
      Value<int> assetsMinor,
      Value<int> liabilitiesMinor,
      Value<int> netWorthMinor,
      Value<String> breakdown,
      Value<int> rowid,
    });

class $$NetWorthSnapshotsTableFilterComposer
    extends Composer<_$PulseDatabase, $NetWorthSnapshotsTable> {
  $$NetWorthSnapshotsTableFilterComposer({
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

  ColumnFilters<String> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get assetsMinor => $composableBuilder(
    column: $table.assetsMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get liabilitiesMinor => $composableBuilder(
    column: $table.liabilitiesMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get netWorthMinor => $composableBuilder(
    column: $table.netWorthMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get breakdown => $composableBuilder(
    column: $table.breakdown,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NetWorthSnapshotsTableOrderingComposer
    extends Composer<_$PulseDatabase, $NetWorthSnapshotsTable> {
  $$NetWorthSnapshotsTableOrderingComposer({
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

  ColumnOrderings<String> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get assetsMinor => $composableBuilder(
    column: $table.assetsMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get liabilitiesMinor => $composableBuilder(
    column: $table.liabilitiesMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get netWorthMinor => $composableBuilder(
    column: $table.netWorthMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get breakdown => $composableBuilder(
    column: $table.breakdown,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NetWorthSnapshotsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $NetWorthSnapshotsTable> {
  $$NetWorthSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get assetsMinor => $composableBuilder(
    column: $table.assetsMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get liabilitiesMinor => $composableBuilder(
    column: $table.liabilitiesMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get netWorthMinor => $composableBuilder(
    column: $table.netWorthMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get breakdown =>
      $composableBuilder(column: $table.breakdown, builder: (column) => column);
}

class $$NetWorthSnapshotsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $NetWorthSnapshotsTable,
          SnapshotRow,
          $$NetWorthSnapshotsTableFilterComposer,
          $$NetWorthSnapshotsTableOrderingComposer,
          $$NetWorthSnapshotsTableAnnotationComposer,
          $$NetWorthSnapshotsTableCreateCompanionBuilder,
          $$NetWorthSnapshotsTableUpdateCompanionBuilder,
          (
            SnapshotRow,
            BaseReferences<
              _$PulseDatabase,
              $NetWorthSnapshotsTable,
              SnapshotRow
            >,
          ),
          SnapshotRow,
          PrefetchHooks Function()
        > {
  $$NetWorthSnapshotsTableTableManager(
    _$PulseDatabase db,
    $NetWorthSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NetWorthSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NetWorthSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NetWorthSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> snapshotDate = const Value.absent(),
                Value<int> assetsMinor = const Value.absent(),
                Value<int> liabilitiesMinor = const Value.absent(),
                Value<int> netWorthMinor = const Value.absent(),
                Value<String> breakdown = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NetWorthSnapshotsCompanion(
                id: id,
                snapshotDate: snapshotDate,
                assetsMinor: assetsMinor,
                liabilitiesMinor: liabilitiesMinor,
                netWorthMinor: netWorthMinor,
                breakdown: breakdown,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String snapshotDate,
                required int assetsMinor,
                required int liabilitiesMinor,
                required int netWorthMinor,
                Value<String> breakdown = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NetWorthSnapshotsCompanion.insert(
                id: id,
                snapshotDate: snapshotDate,
                assetsMinor: assetsMinor,
                liabilitiesMinor: liabilitiesMinor,
                netWorthMinor: netWorthMinor,
                breakdown: breakdown,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NetWorthSnapshotsTable, SnapshotRow>(table),
                  BaseReferences<
                    _$PulseDatabase,
                    $NetWorthSnapshotsTable,
                    SnapshotRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NetWorthSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $NetWorthSnapshotsTable,
      SnapshotRow,
      $$NetWorthSnapshotsTableFilterComposer,
      $$NetWorthSnapshotsTableOrderingComposer,
      $$NetWorthSnapshotsTableAnnotationComposer,
      $$NetWorthSnapshotsTableCreateCompanionBuilder,
      $$NetWorthSnapshotsTableUpdateCompanionBuilder,
      (
        SnapshotRow,
        BaseReferences<_$PulseDatabase, $NetWorthSnapshotsTable, SnapshotRow>,
      ),
      SnapshotRow,
      PrefetchHooks Function()
    >;
typedef $$RecurringReviewsTableCreateCompanionBuilder =
    RecurringReviewsCompanion Function({
      required String seriesKey,
      required String status,
      Value<int> rowid,
    });
typedef $$RecurringReviewsTableUpdateCompanionBuilder =
    RecurringReviewsCompanion Function({
      Value<String> seriesKey,
      Value<String> status,
      Value<int> rowid,
    });

class $$RecurringReviewsTableFilterComposer
    extends Composer<_$PulseDatabase, $RecurringReviewsTable> {
  $$RecurringReviewsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecurringReviewsTableOrderingComposer
    extends Composer<_$PulseDatabase, $RecurringReviewsTable> {
  $$RecurringReviewsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecurringReviewsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $RecurringReviewsTable> {
  $$RecurringReviewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get seriesKey =>
      $composableBuilder(column: $table.seriesKey, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$RecurringReviewsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $RecurringReviewsTable,
          ReviewRow,
          $$RecurringReviewsTableFilterComposer,
          $$RecurringReviewsTableOrderingComposer,
          $$RecurringReviewsTableAnnotationComposer,
          $$RecurringReviewsTableCreateCompanionBuilder,
          $$RecurringReviewsTableUpdateCompanionBuilder,
          (
            ReviewRow,
            BaseReferences<_$PulseDatabase, $RecurringReviewsTable, ReviewRow>,
          ),
          ReviewRow,
          PrefetchHooks Function()
        > {
  $$RecurringReviewsTableTableManager(
    _$PulseDatabase db,
    $RecurringReviewsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringReviewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurringReviewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecurringReviewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> seriesKey = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringReviewsCompanion(
                seriesKey: seriesKey,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String seriesKey,
                required String status,
                Value<int> rowid = const Value.absent(),
              }) => RecurringReviewsCompanion.insert(
                seriesKey: seriesKey,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecurringReviewsTable, ReviewRow>(table),
                  BaseReferences<
                    _$PulseDatabase,
                    $RecurringReviewsTable,
                    ReviewRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecurringReviewsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $RecurringReviewsTable,
      ReviewRow,
      $$RecurringReviewsTableFilterComposer,
      $$RecurringReviewsTableOrderingComposer,
      $$RecurringReviewsTableAnnotationComposer,
      $$RecurringReviewsTableCreateCompanionBuilder,
      $$RecurringReviewsTableUpdateCompanionBuilder,
      (
        ReviewRow,
        BaseReferences<_$PulseDatabase, $RecurringReviewsTable, ReviewRow>,
      ),
      ReviewRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$PulseDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
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

class $$AppSettingsTableOrderingComposer
    extends Composer<_$PulseDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
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

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
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

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $AppSettingsTable,
          SettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$PulseDatabase, $AppSettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$PulseDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, SettingRow>(table),
                  BaseReferences<
                    _$PulseDatabase,
                    $AppSettingsTable,
                    SettingRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $AppSettingsTable,
      SettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$PulseDatabase, $AppSettingsTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$PriceCacheTableCreateCompanionBuilder = PriceCacheCompanion Function({
  required String symbol,
  required double price,
  Value<String> unit,
  Value<String?> source,
  Value<String> status,
  Value<DateTime?> quotedAt,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$PriceCacheTableUpdateCompanionBuilder = PriceCacheCompanion Function({
  Value<String> symbol,
  Value<double> price,
  Value<String> unit,
  Value<String?> source,
  Value<String> status,
  Value<DateTime?> quotedAt,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$PriceCacheTableFilterComposer
    extends Composer<_$PulseDatabase, $PriceCacheTable> {
  $$PriceCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get quotedAt => $composableBuilder(
    column: $table.quotedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PriceCacheTableOrderingComposer
    extends Composer<_$PulseDatabase, $PriceCacheTable> {
  $$PriceCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get quotedAt => $composableBuilder(
    column: $table.quotedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PriceCacheTableAnnotationComposer
    extends Composer<_$PulseDatabase, $PriceCacheTable> {
  $$PriceCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get quotedAt =>
      $composableBuilder(column: $table.quotedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$PriceCacheTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $PriceCacheTable,
          PriceRow,
          $$PriceCacheTableFilterComposer,
          $$PriceCacheTableOrderingComposer,
          $$PriceCacheTableAnnotationComposer,
          $$PriceCacheTableCreateCompanionBuilder,
          $$PriceCacheTableUpdateCompanionBuilder,
          (
            PriceRow,
            BaseReferences<_$PulseDatabase, $PriceCacheTable, PriceRow>,
          ),
          PriceRow,
          PrefetchHooks Function()
        > {
  $$PriceCacheTableTableManager(_$PulseDatabase db, $PriceCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PriceCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PriceCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PriceCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> symbol = const Value.absent(),
                Value<double> price = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> quotedAt = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PriceCacheCompanion(
                symbol: symbol,
                price: price,
                unit: unit,
                source: source,
                status: status,
                quotedAt: quotedAt,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String symbol,
                required double price,
                Value<String> unit = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> quotedAt = const Value.absent(),
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => PriceCacheCompanion.insert(
                symbol: symbol,
                price: price,
                unit: unit,
                source: source,
                status: status,
                quotedAt: quotedAt,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PriceCacheTable, PriceRow>(table),
                  BaseReferences<_$PulseDatabase, $PriceCacheTable, PriceRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PriceCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $PriceCacheTable,
      PriceRow,
      $$PriceCacheTableFilterComposer,
      $$PriceCacheTableOrderingComposer,
      $$PriceCacheTableAnnotationComposer,
      $$PriceCacheTableCreateCompanionBuilder,
      $$PriceCacheTableUpdateCompanionBuilder,
      (PriceRow, BaseReferences<_$PulseDatabase, $PriceCacheTable, PriceRow>),
      PriceRow,
      PrefetchHooks Function()
    >;
typedef $$JewelleryItemsTableCreateCompanionBuilder =
    JewelleryItemsCompanion Function({
      required String id,
      required String name,
      required double weightGrams,
      required int karat,
      Value<double?> purityOverride,
      Value<int?> purchasePriceMinor,
      Value<String?> purchaseDate,
      Value<int?> makingChargesMinor,
      Value<String?> notes,
      Value<String> photoPaths,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$JewelleryItemsTableUpdateCompanionBuilder =
    JewelleryItemsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<double> weightGrams,
      Value<int> karat,
      Value<double?> purityOverride,
      Value<int?> purchasePriceMinor,
      Value<String?> purchaseDate,
      Value<int?> makingChargesMinor,
      Value<String?> notes,
      Value<String> photoPaths,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$JewelleryItemsTableFilterComposer
    extends Composer<_$PulseDatabase, $JewelleryItemsTable> {
  $$JewelleryItemsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get karat => $composableBuilder(
    column: $table.karat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get purityOverride => $composableBuilder(
    column: $table.purityOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get purchasePriceMinor => $composableBuilder(
    column: $table.purchasePriceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purchaseDate => $composableBuilder(
    column: $table.purchaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get makingChargesMinor => $composableBuilder(
    column: $table.makingChargesMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPaths => $composableBuilder(
    column: $table.photoPaths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$JewelleryItemsTableOrderingComposer
    extends Composer<_$PulseDatabase, $JewelleryItemsTable> {
  $$JewelleryItemsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get karat => $composableBuilder(
    column: $table.karat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get purityOverride => $composableBuilder(
    column: $table.purityOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get purchasePriceMinor => $composableBuilder(
    column: $table.purchasePriceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purchaseDate => $composableBuilder(
    column: $table.purchaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get makingChargesMinor => $composableBuilder(
    column: $table.makingChargesMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPaths => $composableBuilder(
    column: $table.photoPaths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JewelleryItemsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $JewelleryItemsTable> {
  $$JewelleryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => column,
  );

  GeneratedColumn<int> get karat =>
      $composableBuilder(column: $table.karat, builder: (column) => column);

  GeneratedColumn<double> get purityOverride => $composableBuilder(
    column: $table.purityOverride,
    builder: (column) => column,
  );

  GeneratedColumn<int> get purchasePriceMinor => $composableBuilder(
    column: $table.purchasePriceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get purchaseDate => $composableBuilder(
    column: $table.purchaseDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get makingChargesMinor => $composableBuilder(
    column: $table.makingChargesMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get photoPaths => $composableBuilder(
    column: $table.photoPaths,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$JewelleryItemsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $JewelleryItemsTable,
          JewelleryRow,
          $$JewelleryItemsTableFilterComposer,
          $$JewelleryItemsTableOrderingComposer,
          $$JewelleryItemsTableAnnotationComposer,
          $$JewelleryItemsTableCreateCompanionBuilder,
          $$JewelleryItemsTableUpdateCompanionBuilder,
          (
            JewelleryRow,
            BaseReferences<_$PulseDatabase, $JewelleryItemsTable, JewelleryRow>,
          ),
          JewelleryRow,
          PrefetchHooks Function()
        > {
  $$JewelleryItemsTableTableManager(
    _$PulseDatabase db,
    $JewelleryItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JewelleryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JewelleryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JewelleryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> weightGrams = const Value.absent(),
                Value<int> karat = const Value.absent(),
                Value<double?> purityOverride = const Value.absent(),
                Value<int?> purchasePriceMinor = const Value.absent(),
                Value<String?> purchaseDate = const Value.absent(),
                Value<int?> makingChargesMinor = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> photoPaths = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JewelleryItemsCompanion(
                id: id,
                name: name,
                weightGrams: weightGrams,
                karat: karat,
                purityOverride: purityOverride,
                purchasePriceMinor: purchasePriceMinor,
                purchaseDate: purchaseDate,
                makingChargesMinor: makingChargesMinor,
                notes: notes,
                photoPaths: photoPaths,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required double weightGrams,
                required int karat,
                Value<double?> purityOverride = const Value.absent(),
                Value<int?> purchasePriceMinor = const Value.absent(),
                Value<String?> purchaseDate = const Value.absent(),
                Value<int?> makingChargesMinor = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> photoPaths = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JewelleryItemsCompanion.insert(
                id: id,
                name: name,
                weightGrams: weightGrams,
                karat: karat,
                purityOverride: purityOverride,
                purchasePriceMinor: purchasePriceMinor,
                purchaseDate: purchaseDate,
                makingChargesMinor: makingChargesMinor,
                notes: notes,
                photoPaths: photoPaths,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JewelleryItemsTable, JewelleryRow>(table),
                  BaseReferences<
                    _$PulseDatabase,
                    $JewelleryItemsTable,
                    JewelleryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JewelleryItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $JewelleryItemsTable,
      JewelleryRow,
      $$JewelleryItemsTableFilterComposer,
      $$JewelleryItemsTableOrderingComposer,
      $$JewelleryItemsTableAnnotationComposer,
      $$JewelleryItemsTableCreateCompanionBuilder,
      $$JewelleryItemsTableUpdateCompanionBuilder,
      (
        JewelleryRow,
        BaseReferences<_$PulseDatabase, $JewelleryItemsTable, JewelleryRow>,
      ),
      JewelleryRow,
      PrefetchHooks Function()
    >;
typedef $$DocumentAttachmentsTableCreateCompanionBuilder =
    DocumentAttachmentsCompanion Function({
      required String id,
      required String title,
      required String category,
      Value<String?> notes,
      Value<String> filePaths,
      Value<String?> dueOn,
      Value<String> dueKind,
      Value<int?> remindDaysBefore,
      Value<int?> notificationId,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$DocumentAttachmentsTableUpdateCompanionBuilder =
    DocumentAttachmentsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> category,
      Value<String?> notes,
      Value<String> filePaths,
      Value<String?> dueOn,
      Value<String> dueKind,
      Value<int?> remindDaysBefore,
      Value<int?> notificationId,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$DocumentAttachmentsTableFilterComposer
    extends Composer<_$PulseDatabase, $DocumentAttachmentsTable> {
  $$DocumentAttachmentsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePaths => $composableBuilder(
    column: $table.filePaths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueOn => $composableBuilder(
    column: $table.dueOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueKind => $composableBuilder(
    column: $table.dueKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remindDaysBefore => $composableBuilder(
    column: $table.remindDaysBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentAttachmentsTableOrderingComposer
    extends Composer<_$PulseDatabase, $DocumentAttachmentsTable> {
  $$DocumentAttachmentsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePaths => $composableBuilder(
    column: $table.filePaths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueOn => $composableBuilder(
    column: $table.dueOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueKind => $composableBuilder(
    column: $table.dueKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remindDaysBefore => $composableBuilder(
    column: $table.remindDaysBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentAttachmentsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $DocumentAttachmentsTable> {
  $$DocumentAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get filePaths =>
      $composableBuilder(column: $table.filePaths, builder: (column) => column);

  GeneratedColumn<String> get dueOn =>
      $composableBuilder(column: $table.dueOn, builder: (column) => column);

  GeneratedColumn<String> get dueKind =>
      $composableBuilder(column: $table.dueKind, builder: (column) => column);

  GeneratedColumn<int> get remindDaysBefore => $composableBuilder(
    column: $table.remindDaysBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DocumentAttachmentsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $DocumentAttachmentsTable,
          DocumentRow,
          $$DocumentAttachmentsTableFilterComposer,
          $$DocumentAttachmentsTableOrderingComposer,
          $$DocumentAttachmentsTableAnnotationComposer,
          $$DocumentAttachmentsTableCreateCompanionBuilder,
          $$DocumentAttachmentsTableUpdateCompanionBuilder,
          (
            DocumentRow,
            BaseReferences<
              _$PulseDatabase,
              $DocumentAttachmentsTable,
              DocumentRow
            >,
          ),
          DocumentRow,
          PrefetchHooks Function()
        > {
  $$DocumentAttachmentsTableTableManager(
    _$PulseDatabase db,
    $DocumentAttachmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentAttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentAttachmentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DocumentAttachmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> filePaths = const Value.absent(),
                Value<String?> dueOn = const Value.absent(),
                Value<String> dueKind = const Value.absent(),
                Value<int?> remindDaysBefore = const Value.absent(),
                Value<int?> notificationId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentAttachmentsCompanion(
                id: id,
                title: title,
                category: category,
                notes: notes,
                filePaths: filePaths,
                dueOn: dueOn,
                dueKind: dueKind,
                remindDaysBefore: remindDaysBefore,
                notificationId: notificationId,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String category,
                Value<String?> notes = const Value.absent(),
                Value<String> filePaths = const Value.absent(),
                Value<String?> dueOn = const Value.absent(),
                Value<String> dueKind = const Value.absent(),
                Value<int?> remindDaysBefore = const Value.absent(),
                Value<int?> notificationId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentAttachmentsCompanion.insert(
                id: id,
                title: title,
                category: category,
                notes: notes,
                filePaths: filePaths,
                dueOn: dueOn,
                dueKind: dueKind,
                remindDaysBefore: remindDaysBefore,
                notificationId: notificationId,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DocumentAttachmentsTable, DocumentRow>(table),
                  BaseReferences<
                    _$PulseDatabase,
                    $DocumentAttachmentsTable,
                    DocumentRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentAttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $DocumentAttachmentsTable,
      DocumentRow,
      $$DocumentAttachmentsTableFilterComposer,
      $$DocumentAttachmentsTableOrderingComposer,
      $$DocumentAttachmentsTableAnnotationComposer,
      $$DocumentAttachmentsTableCreateCompanionBuilder,
      $$DocumentAttachmentsTableUpdateCompanionBuilder,
      (
        DocumentRow,
        BaseReferences<_$PulseDatabase, $DocumentAttachmentsTable, DocumentRow>,
      ),
      DocumentRow,
      PrefetchHooks Function()
    >;
typedef $$FundHoldingsTableCreateCompanionBuilder =
    FundHoldingsCompanion Function({
      required String id,
      required String kind,
      Value<String?> schemeCode,
      required String name,
      Value<String> currency,
      required double units,
      Value<double?> avgCostNav,
      required double nav,
      Value<String?> navDate,
      Value<String> navSource,
      Value<DateTime?> navFetchedAt,
      Value<int?> sipAmountMinor,
      Value<int?> sipDay,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$FundHoldingsTableUpdateCompanionBuilder =
    FundHoldingsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String?> schemeCode,
      Value<String> name,
      Value<String> currency,
      Value<double> units,
      Value<double?> avgCostNav,
      Value<double> nav,
      Value<String?> navDate,
      Value<String> navSource,
      Value<DateTime?> navFetchedAt,
      Value<int?> sipAmountMinor,
      Value<int?> sipDay,
      Value<DateTime> createdAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$FundHoldingsTableFilterComposer
    extends Composer<_$PulseDatabase, $FundHoldingsTable> {
  $$FundHoldingsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schemeCode => $composableBuilder(
    column: $table.schemeCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get units => $composableBuilder(
    column: $table.units,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgCostNav => $composableBuilder(
    column: $table.avgCostNav,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get nav => $composableBuilder(
    column: $table.nav,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get navDate => $composableBuilder(
    column: $table.navDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get navSource => $composableBuilder(
    column: $table.navSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get navFetchedAt => $composableBuilder(
    column: $table.navFetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sipAmountMinor => $composableBuilder(
    column: $table.sipAmountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sipDay => $composableBuilder(
    column: $table.sipDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FundHoldingsTableOrderingComposer
    extends Composer<_$PulseDatabase, $FundHoldingsTable> {
  $$FundHoldingsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schemeCode => $composableBuilder(
    column: $table.schemeCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get units => $composableBuilder(
    column: $table.units,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgCostNav => $composableBuilder(
    column: $table.avgCostNav,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get nav => $composableBuilder(
    column: $table.nav,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get navDate => $composableBuilder(
    column: $table.navDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get navSource => $composableBuilder(
    column: $table.navSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get navFetchedAt => $composableBuilder(
    column: $table.navFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sipAmountMinor => $composableBuilder(
    column: $table.sipAmountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sipDay => $composableBuilder(
    column: $table.sipDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FundHoldingsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $FundHoldingsTable> {
  $$FundHoldingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get schemeCode => $composableBuilder(
    column: $table.schemeCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<double> get units =>
      $composableBuilder(column: $table.units, builder: (column) => column);

  GeneratedColumn<double> get avgCostNav => $composableBuilder(
    column: $table.avgCostNav,
    builder: (column) => column,
  );

  GeneratedColumn<double> get nav =>
      $composableBuilder(column: $table.nav, builder: (column) => column);

  GeneratedColumn<String> get navDate =>
      $composableBuilder(column: $table.navDate, builder: (column) => column);

  GeneratedColumn<String> get navSource =>
      $composableBuilder(column: $table.navSource, builder: (column) => column);

  GeneratedColumn<DateTime> get navFetchedAt => $composableBuilder(
    column: $table.navFetchedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sipAmountMinor => $composableBuilder(
    column: $table.sipAmountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sipDay =>
      $composableBuilder(column: $table.sipDay, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$FundHoldingsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $FundHoldingsTable,
          FundRow,
          $$FundHoldingsTableFilterComposer,
          $$FundHoldingsTableOrderingComposer,
          $$FundHoldingsTableAnnotationComposer,
          $$FundHoldingsTableCreateCompanionBuilder,
          $$FundHoldingsTableUpdateCompanionBuilder,
          (
            FundRow,
            BaseReferences<_$PulseDatabase, $FundHoldingsTable, FundRow>,
          ),
          FundRow,
          PrefetchHooks Function()
        > {
  $$FundHoldingsTableTableManager(_$PulseDatabase db, $FundHoldingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FundHoldingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FundHoldingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FundHoldingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> schemeCode = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<double> units = const Value.absent(),
                Value<double?> avgCostNav = const Value.absent(),
                Value<double> nav = const Value.absent(),
                Value<String?> navDate = const Value.absent(),
                Value<String> navSource = const Value.absent(),
                Value<DateTime?> navFetchedAt = const Value.absent(),
                Value<int?> sipAmountMinor = const Value.absent(),
                Value<int?> sipDay = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FundHoldingsCompanion(
                id: id,
                kind: kind,
                schemeCode: schemeCode,
                name: name,
                currency: currency,
                units: units,
                avgCostNav: avgCostNav,
                nav: nav,
                navDate: navDate,
                navSource: navSource,
                navFetchedAt: navFetchedAt,
                sipAmountMinor: sipAmountMinor,
                sipDay: sipDay,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                Value<String?> schemeCode = const Value.absent(),
                required String name,
                Value<String> currency = const Value.absent(),
                required double units,
                Value<double?> avgCostNav = const Value.absent(),
                required double nav,
                Value<String?> navDate = const Value.absent(),
                Value<String> navSource = const Value.absent(),
                Value<DateTime?> navFetchedAt = const Value.absent(),
                Value<int?> sipAmountMinor = const Value.absent(),
                Value<int?> sipDay = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FundHoldingsCompanion.insert(
                id: id,
                kind: kind,
                schemeCode: schemeCode,
                name: name,
                currency: currency,
                units: units,
                avgCostNav: avgCostNav,
                nav: nav,
                navDate: navDate,
                navSource: navSource,
                navFetchedAt: navFetchedAt,
                sipAmountMinor: sipAmountMinor,
                sipDay: sipDay,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FundHoldingsTable, FundRow>(table),
                  BaseReferences<_$PulseDatabase, $FundHoldingsTable, FundRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FundHoldingsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $FundHoldingsTable,
      FundRow,
      $$FundHoldingsTableFilterComposer,
      $$FundHoldingsTableOrderingComposer,
      $$FundHoldingsTableAnnotationComposer,
      $$FundHoldingsTableCreateCompanionBuilder,
      $$FundHoldingsTableUpdateCompanionBuilder,
      (FundRow, BaseReferences<_$PulseDatabase, $FundHoldingsTable, FundRow>),
      FundRow,
      PrefetchHooks Function()
    >;
typedef $$ValuationSnapshotsTableCreateCompanionBuilder =
    ValuationSnapshotsCompanion Function({
      required String id,
      required String subjectKind,
      required String subjectId,
      required String snapshotDate,
      required int valueMinor,
      Value<double?> unitPrice,
      Value<int> rowid,
    });
typedef $$ValuationSnapshotsTableUpdateCompanionBuilder =
    ValuationSnapshotsCompanion Function({
      Value<String> id,
      Value<String> subjectKind,
      Value<String> subjectId,
      Value<String> snapshotDate,
      Value<int> valueMinor,
      Value<double?> unitPrice,
      Value<int> rowid,
    });

class $$ValuationSnapshotsTableFilterComposer
    extends Composer<_$PulseDatabase, $ValuationSnapshotsTable> {
  $$ValuationSnapshotsTableFilterComposer({
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

  ColumnFilters<String> get subjectKind => $composableBuilder(
    column: $table.subjectKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get valueMinor => $composableBuilder(
    column: $table.valueMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ValuationSnapshotsTableOrderingComposer
    extends Composer<_$PulseDatabase, $ValuationSnapshotsTable> {
  $$ValuationSnapshotsTableOrderingComposer({
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

  ColumnOrderings<String> get subjectKind => $composableBuilder(
    column: $table.subjectKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get valueMinor => $composableBuilder(
    column: $table.valueMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ValuationSnapshotsTableAnnotationComposer
    extends Composer<_$PulseDatabase, $ValuationSnapshotsTable> {
  $$ValuationSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectKind => $composableBuilder(
    column: $table.subjectKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get valueMinor => $composableBuilder(
    column: $table.valueMinor,
    builder: (column) => column,
  );

  GeneratedColumn<double> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);
}

class $$ValuationSnapshotsTableTableManager
    extends
        RootTableManager<
          _$PulseDatabase,
          $ValuationSnapshotsTable,
          ValuationRow,
          $$ValuationSnapshotsTableFilterComposer,
          $$ValuationSnapshotsTableOrderingComposer,
          $$ValuationSnapshotsTableAnnotationComposer,
          $$ValuationSnapshotsTableCreateCompanionBuilder,
          $$ValuationSnapshotsTableUpdateCompanionBuilder,
          (
            ValuationRow,
            BaseReferences<
              _$PulseDatabase,
              $ValuationSnapshotsTable,
              ValuationRow
            >,
          ),
          ValuationRow,
          PrefetchHooks Function()
        > {
  $$ValuationSnapshotsTableTableManager(
    _$PulseDatabase db,
    $ValuationSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ValuationSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ValuationSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ValuationSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> subjectKind = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String> snapshotDate = const Value.absent(),
                Value<int> valueMinor = const Value.absent(),
                Value<double?> unitPrice = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ValuationSnapshotsCompanion(
                id: id,
                subjectKind: subjectKind,
                subjectId: subjectId,
                snapshotDate: snapshotDate,
                valueMinor: valueMinor,
                unitPrice: unitPrice,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String subjectKind,
                required String subjectId,
                required String snapshotDate,
                required int valueMinor,
                Value<double?> unitPrice = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ValuationSnapshotsCompanion.insert(
                id: id,
                subjectKind: subjectKind,
                subjectId: subjectId,
                snapshotDate: snapshotDate,
                valueMinor: valueMinor,
                unitPrice: unitPrice,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ValuationSnapshotsTable, ValuationRow>(table),
                  BaseReferences<
                    _$PulseDatabase,
                    $ValuationSnapshotsTable,
                    ValuationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ValuationSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$PulseDatabase,
      $ValuationSnapshotsTable,
      ValuationRow,
      $$ValuationSnapshotsTableFilterComposer,
      $$ValuationSnapshotsTableOrderingComposer,
      $$ValuationSnapshotsTableAnnotationComposer,
      $$ValuationSnapshotsTableCreateCompanionBuilder,
      $$ValuationSnapshotsTableUpdateCompanionBuilder,
      (
        ValuationRow,
        BaseReferences<_$PulseDatabase, $ValuationSnapshotsTable, ValuationRow>,
      ),
      ValuationRow,
      PrefetchHooks Function()
    >;

class $PulseDatabaseManager {
  final _$PulseDatabase _db;
  $PulseDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CatalogCardsTableTableManager get catalogCards =>
      $$CatalogCardsTableTableManager(_db, _db.catalogCards);
  $$UserCardsTableTableManager get userCards =>
      $$UserCardsTableTableManager(_db, _db.userCards);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$MerchantRulesTableTableManager get merchantRules =>
      $$MerchantRulesTableTableManager(_db, _db.merchantRules);
  $$StatementsTableTableManager get statements =>
      $$StatementsTableTableManager(_db, _db.statements);
  $$StatementLinesTableTableManager get statementLines =>
      $$StatementLinesTableTableManager(_db, _db.statementLines);
  $$AssetsTableTableManager get assets =>
      $$AssetsTableTableManager(_db, _db.assets);
  $$LiabilitiesTableTableManager get liabilities =>
      $$LiabilitiesTableTableManager(_db, _db.liabilities);
  $$SalaryRecordsTableTableManager get salaryRecords =>
      $$SalaryRecordsTableTableManager(_db, _db.salaryRecords);
  $$SavingsGoalsTableTableManager get savingsGoals =>
      $$SavingsGoalsTableTableManager(_db, _db.savingsGoals);
  $$RawIngestsTableTableManager get rawIngests =>
      $$RawIngestsTableTableManager(_db, _db.rawIngests);
  $$NetWorthSnapshotsTableTableManager get netWorthSnapshots =>
      $$NetWorthSnapshotsTableTableManager(_db, _db.netWorthSnapshots);
  $$RecurringReviewsTableTableManager get recurringReviews =>
      $$RecurringReviewsTableTableManager(_db, _db.recurringReviews);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$PriceCacheTableTableManager get priceCache =>
      $$PriceCacheTableTableManager(_db, _db.priceCache);
  $$JewelleryItemsTableTableManager get jewelleryItems =>
      $$JewelleryItemsTableTableManager(_db, _db.jewelleryItems);
  $$DocumentAttachmentsTableTableManager get documentAttachments =>
      $$DocumentAttachmentsTableTableManager(_db, _db.documentAttachments);
  $$FundHoldingsTableTableManager get fundHoldings =>
      $$FundHoldingsTableTableManager(_db, _db.fundHoldings);
  $$ValuationSnapshotsTableTableManager get valuationSnapshots =>
      $$ValuationSnapshotsTableTableManager(_db, _db.valuationSnapshots);
}
