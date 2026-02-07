import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

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
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
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

class ItemsFts extends Table {
  TextColumn get itemId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get url => text().nullable()();

  @override
  String get tableName => 'items_fts';
}

class PendingNotifications extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get itemId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get type => text()();
  IntColumn get scheduledAt => integer()();
  IntColumn get createdAt => integer()();
}

@DriftDatabase(
  tables: [Users, Items, Tags, SyncQueue, ItemsFts, PendingNotifications],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await customStatement('DROP TABLE IF EXISTS items_fts');
      await customStatement('''
        CREATE VIRTUAL TABLE items_fts USING fts5(
          item_id UNINDEXED,
          title,
          description,
          url,
          tokenize='porter'
        );
      ''');
      await customStatement('''
        INSERT INTO items_fts(item_id, title, description, url)
        SELECT id, title, coalesce(description, ''), coalesce(url, '') FROM items;
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS items_ai AFTER INSERT ON items BEGIN
          INSERT INTO items_fts(item_id, title, description, url)
          VALUES (new.id, new.title, coalesce(new.description, ''), coalesce(new.url, ''));
        END;
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS items_au AFTER UPDATE ON items BEGIN
          DELETE FROM items_fts WHERE item_id = old.id;
          INSERT INTO items_fts(item_id, title, description, url)
          VALUES (new.id, new.title, coalesce(new.description, ''), coalesce(new.url, ''));
        END;
      ''');
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS items_ad AFTER DELETE ON items BEGIN
          DELETE FROM items_fts WHERE item_id = old.id;
        END;
      ''');
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await customStatement('DROP TABLE IF EXISTS items_fts');
        await customStatement('''
          CREATE VIRTUAL TABLE items_fts USING fts5(
            item_id UNINDEXED,
            title,
            description,
            url,
            tokenize='porter'
          );
        ''');
      }
      if (from < 3) {
        await m.createTable(pendingNotifications);
      }
      if (from < 4) {
        await customStatement('DROP TABLE IF EXISTS items_fts');
        await customStatement('''
          CREATE VIRTUAL TABLE items_fts USING fts5(
            item_id UNINDEXED,
            title,
            description,
            url,
            tokenize='porter'
          );
        ''');
        await customStatement('''
          INSERT INTO items_fts(item_id, title, description, url)
          SELECT id, title, coalesce(description, ''), coalesce(url, '') FROM items;
        ''');
        await customStatement('''
          CREATE TRIGGER IF NOT EXISTS items_ai AFTER INSERT ON items BEGIN
            INSERT INTO items_fts(item_id, title, description, url)
            VALUES (new.id, new.title, coalesce(new.description, ''), coalesce(new.url, ''));
          END;
        ''');
        await customStatement('''
          CREATE TRIGGER IF NOT EXISTS items_au AFTER UPDATE ON items BEGIN
            DELETE FROM items_fts WHERE item_id = old.id;
            INSERT INTO items_fts(item_id, title, description, url)
            VALUES (new.id, new.title, coalesce(new.description, ''), coalesce(new.url, ''));
          END;
        ''');
        await customStatement('''
          CREATE TRIGGER IF NOT EXISTS items_ad AFTER DELETE ON items BEGIN
            DELETE FROM items_fts WHERE item_id = old.id;
          END;
        ''');
      }
    },
  );

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase();

  static const _ftsReindexKey = 'fts_reindex_done_v1';

  Future<User?> getUserByClerkId(String clerkId) {
    return (select(
      users,
    )..where((u) => u.clerkId.equals(clerkId))).getSingleOrNull();
  }

  Stream<User?> watchUserByClerkId(String clerkId) {
    return (select(
      users,
    )..where((u) => u.clerkId.equals(clerkId))).watchSingleOrNull();
  }

  Future<int> upsertUser(UsersCompanion user) {
    return into(users).insertOnConflictUpdate(user);
  }

  Stream<int> watchItemsCount(String userId) {
    final countExpr = countAll();
    final query = selectOnly(items)..addColumns([countExpr]);
    query.where(items.userId.equals(userId));
    return query.watchSingle().map((row) => row.read(countExpr) ?? 0);
  }

  Future<void> ensureFtsReindexOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyDone = prefs.getBool(_ftsReindexKey) ?? false;
    if (alreadyDone) return;

    await customStatement('DELETE FROM items_fts');
    await customStatement('''
      INSERT INTO items_fts(item_id, title, description, url)
      SELECT id, title, coalesce(description, ''), coalesce(url, '') FROM items;
    ''');

    await prefs.setBool(_ftsReindexKey, true);
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

  Future<Item?> getItemByConvexId(String convexId) {
    return (select(
      items,
    )..where((i) => i.convexId.equals(convexId))).getSingleOrNull();
  }

  Future<Item?> findDuplicateItem(
    String userId,
    String? url, {
    String? excludeId,
  }) async {
    if (url == null || url.isEmpty) return null;

    var query = select(items)
      ..where((i) => i.userId.equals(userId))
      ..where((i) => i.url.equals(url));

    if (excludeId != null) {
      query = query..where((i) => i.id.isNotValue(excludeId));
    }

    return query.getSingleOrNull();
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

  Future<void> updateItemSearchIndex(
    String itemId,
    String title,
    String? description,
    String? url,
  ) async {
    await customStatement('DELETE FROM items_fts WHERE item_id = ?', [itemId]);
    await customStatement(
      'INSERT INTO items_fts(item_id, title, description, url) VALUES (?, ?, ?, ?)',
      [itemId, title, description ?? '', url ?? ''],
    );
  }

  Future<void> deleteItemSearchIndex(String itemId) async {
    await customStatement('DELETE FROM items_fts WHERE item_id = ?', [itemId]);
  }

  Future<List<Item>> searchItems(String userId, String query) async {
    final results = await customSelect(
      'SELECT item_id FROM items_fts WHERE items_fts MATCH ? ORDER BY rank',
      variables: [Variable(query)],
    ).get();

    final itemIds = results.map((r) => r.read<String>('item_id')).toList();

    if (itemIds.isEmpty) return [];

    return (select(items)
          ..where((i) => i.userId.equals(userId))
          ..where((i) => i.id.isIn(itemIds)))
        .get();
  }

  Future<List<Item>> getItemsPaginated(
    String userId, {
    String? status,
    String? type,
    String? searchQuery,
    int limit = 20,
    int offset = 0,
  }) async {
    List<String>? searchItemIds;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final results = await customSelect(
        'SELECT item_id FROM items_fts WHERE items_fts MATCH ? ORDER BY rank',
        variables: [Variable(searchQuery)],
      ).get();
      searchItemIds = results.map((r) => r.read<String>('item_id')).toList();

      if (searchItemIds.isEmpty) return [];
    }

    var query = select(items)..where((i) => i.userId.equals(userId));

    if (status != null) {
      query = query..where((i) => i.status.equals(status));
    }
    if (type != null) {
      query = query..where((i) => i.type.equals(type));
    }
    if (searchItemIds != null && searchItemIds.isNotEmpty) {
      final ids = searchItemIds;
      query = query..where((i) => i.id.isIn(ids));
    }

    return (query
          ..orderBy([(i) => OrderingTerm.desc(i.createdAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<int> getItemsCount(
    String userId, {
    String? status,
    String? type,
    String? searchQuery,
  }) async {
    List<String>? searchItemIds;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final results = await customSelect(
        'SELECT item_id FROM items_fts WHERE items_fts MATCH ?',
        variables: [Variable(searchQuery)],
      ).get();
      searchItemIds = results.map((r) => r.read<String>('item_id')).toList();

      if (searchItemIds.isEmpty) return 0;
    }

    var query = select(items)..where((i) => i.userId.equals(userId));

    if (status != null) {
      query = query..where((i) => i.status.equals(status));
    }
    if (type != null) {
      query = query..where((i) => i.type.equals(type));
    }
    if (searchItemIds != null && searchItemIds.isNotEmpty) {
      final ids = searchItemIds;
      query = query..where((i) => i.id.isIn(ids));
    }

    final countExpr = countAll();
    final countQuery = selectOnly(items)..addColumns([countExpr]);
    countQuery.where(items.userId.equals(userId));

    if (status != null) {
      countQuery.where(items.status.equals(status));
    }
    if (type != null) {
      countQuery.where(items.type.equals(type));
    }
    if (searchItemIds != null && searchItemIds.isNotEmpty) {
      final ids = searchItemIds;
      countQuery.where(items.id.isIn(ids));
    }

    final result = await countQuery.getSingle();
    return result.read(countExpr) ?? 0;
  }

  Future<int> addPendingNotification({
    required String userId,
    String? itemId,
    required String title,
    required String body,
    required String type,
    required int scheduledAt,
  }) {
    return into(pendingNotifications).insert(
      PendingNotificationsCompanion.insert(
        userId: userId,
        itemId: Value(itemId),
        title: title,
        body: body,
        type: type,
        scheduledAt: scheduledAt,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<List<PendingNotification>> getPendingNotifications(String userId) {
    return (select(pendingNotifications)
          ..where((n) => n.userId.equals(userId))
          ..orderBy([(n) => OrderingTerm.asc(n.scheduledAt)]))
        .get();
  }

  Future<int> deletePendingNotification(int id) {
    return (delete(pendingNotifications)..where((n) => n.id.equals(id))).go();
  }

  Future<int> clearDeliveredPendingNotifications(int beforeTimestamp) {
    return (delete(
      pendingNotifications,
    )..where((n) => n.scheduledAt.isSmallerThanValue(beforeTimestamp))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'rem.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
