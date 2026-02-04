import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get convexId => text().nullable()();
  TextColumn get clerkId => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();
  TextColumn get notificationPreferences =>
      text().withDefault(const Constant('{}'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get convexId => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get type => text()();
  TextColumn get url => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get estimatedReadTime => integer().nullable()();
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get status => text().withDefault(const Constant('unread'))();
  IntColumn get readAt => integer().nullable()();
  IntColumn get lastRemindedAt => integer().nullable()();
  IntColumn get remindCount => integer().withDefault(const Constant(0))();
  IntColumn get snoozedUntil => integer().nullable()();
  TextColumn get visibility => text().withDefault(const Constant('private'))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get convexId => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  IntColumn get createdAt => integer()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncTableName => text()();
  TextColumn get recordId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  IntColumn get createdAt => integer()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

@DriftDatabase(tables: [Users, Items, Tags, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase();

  Future<User?> getUserByClerkId(String clerkId) {
    return (select(
      users,
    )..where((u) => u.clerkId.equals(clerkId))).getSingleOrNull();
  }

  Future<int> upsertUser(UsersCompanion user) {
    return into(users).insertOnConflictUpdate(user);
  }

  Future<List<Item>> getItemsByUserId(
    String userId, {
    String? status,
    String? type,
  }) {
    var query = select(items)..where((i) => i.userId.equals(userId));

    if (status != null) {
      query = query..where((i) => i.status.equals(status));
    }
    if (type != null) {
      query = query..where((i) => i.type.equals(type));
    }

    return (query..orderBy([(i) => OrderingTerm.desc(i.createdAt)])).get();
  }

  Future<Item?> getItemById(String id) {
    return (select(items)..where((i) => i.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertItem(ItemsCompanion item) {
    return into(items).insert(item);
  }

  Future<bool> updateItemById(String id, ItemsCompanion updates) {
    return (update(
      items,
    )..where((i) => i.id.equals(id))).write(updates).then((rows) => rows > 0);
  }

  Future<int> deleteItem(String id) {
    return (delete(items)..where((i) => i.id.equals(id))).go();
  }

  Stream<List<Item>> watchItemsByUserId(String userId) {
    return (select(items)
          ..where((i) => i.userId.equals(userId))
          ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]))
        .watch();
  }

  Future<List<Tag>> getTagsByUserId(String userId) {
    return (select(tags)..where((t) => t.userId.equals(userId))).get();
  }

  Future<int> insertTag(TagsCompanion tag) {
    return into(tags).insert(tag);
  }

  Future<List<SyncQueueData>> getPendingSyncItems() {
    return (select(syncQueue)
          ..orderBy([(s) => OrderingTerm.asc(s.createdAt)])
          ..limit(50))
        .get();
  }

  Future<int> addToSyncQueue({
    required String tableName,
    required String recordId,
    required String operation,
    required String payload,
  }) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        syncTableName: tableName,
        recordId: recordId,
        operation: operation,
        payload: payload,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<int> removeSyncItem(int id) {
    return (delete(syncQueue)..where((s) => s.id.equals(id))).go();
  }

  Future<void> markSyncItemFailed(int id, String error) async {
    await (update(syncQueue)..where((s) => s.id.equals(id))).write(
      SyncQueueCompanion(attempts: const Value(1), lastError: Value(error)),
    );
  }

  Future<void> updateItemSyncStatus(
    String id, {
    String? convexId,
    required String syncStatus,
  }) async {
    await (update(items)..where((i) => i.id.equals(id))).write(
      ItemsCompanion(
        convexId: convexId != null ? Value(convexId) : const Value.absent(),
        syncStatus: Value(syncStatus),
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'rem.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
