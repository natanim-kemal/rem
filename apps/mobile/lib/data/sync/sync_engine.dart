import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../../core/services/convex_client.dart';

enum SyncStatus { idle, syncing, error, offline }

class SyncEngine {
  final AppDatabase _db;
  final ConvexClient _convex;

  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get currentStatus => _currentStatus;

  SyncEngine({required AppDatabase db, required ConvexClient convex})
    : _db = db,
      _convex = convex;

  Future<void> initialize() async {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      if (result.isNotEmpty && result.first != ConnectivityResult.none) {
        _triggerSync();
      }
    });

    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _triggerSync();
    });

    await _triggerSync();
  }

  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

  Future<void> _triggerSync() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      _updateStatus(SyncStatus.syncing);

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.isEmpty ||
          connectivity.first == ConnectivityResult.none) {
        _updateStatus(SyncStatus.offline);
        return;
      }

      await _pushLocalChanges();
      await _pullRemoteChanges();

      _updateStatus(SyncStatus.idle);
    } catch (e) {
      debugPrint('Sync error: $e');
      _updateStatus(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }

  Future<void> _pushLocalChanges() async {
    final pendingItems = await _db.getPendingSyncItems();

    for (final item in pendingItems) {
      try {
        final payload = jsonDecode(item.payload) as Map<String, dynamic>;

        switch (item.syncTableName) {
          case 'items':
            await _syncItem(item, payload);
            break;
          case 'tags':
            await _syncTag(item, payload);
            break;
          case 'users':
            await _syncUser(item, payload);
            break;
        }

        await _db.removeSyncItem(item.id);
      } catch (e) {
        debugPrint('Failed to sync ${item.syncTableName}/${item.recordId}: $e');
        await _db.markSyncItemFailed(item.id, e.toString());
      }
    }
  }

  Future<void> _syncItem(
    SyncQueueData syncItem,
    Map<String, dynamic> payload,
  ) async {
    switch (syncItem.operation) {
      case 'create':
        final result = await _convex.mutation('items:create', payload);
        if (result != null) {
          final convexId = result['_id'] as String?;
          if (convexId != null) {
            await _db.updateItemSyncStatus(
              syncItem.recordId,
              convexId: convexId,
              syncStatus: 'synced',
            );
          }
        }
        break;

      case 'update':
        final convexId = payload['convexId'];
        if (convexId != null) {
          await _convex.mutation('items:update', {'id': convexId, ...payload});
          await _db.updateItemSyncStatus(
            syncItem.recordId,
            syncStatus: 'synced',
          );
        }
        break;

      case 'delete':
        final convexId = payload['convexId'];
        if (convexId != null) {
          await _convex.mutation('items:remove', {'id': convexId});
        }
        break;
    }
  }

  Future<void> _syncTag(
    SyncQueueData syncItem,
    Map<String, dynamic> payload,
  ) async {
    switch (syncItem.operation) {
      case 'create':
        final result = await _convex.mutation('tags:create', payload);
        if (result != null) {
          final convexId = result['_id'] as String?;
          if (convexId != null) {}
        }
        break;

      case 'delete':
        final convexId = payload['convexId'];
        if (convexId != null) {
          await _convex.mutation('tags:remove', {'id': convexId});
        }
        break;
    }
  }

  Future<void> _syncUser(
    SyncQueueData syncItem,
    Map<String, dynamic> payload,
  ) async {
    if (syncItem.operation == 'update') {
      await _convex.mutation('users:updatePreferences', payload);
    }
  }

  Future<void> _pullRemoteChanges() async {
    try {
      final lastSyncAt = await _getLastSyncTimestamp();

      final remoteItems =
          await _convex.query('items:getItemsSince', {'since': lastSyncAt})
              as List<dynamic>?;

      if (remoteItems == null || remoteItems.isEmpty) return;

      for (final remoteItem in remoteItems) {
        await _mergeRemoteItem(remoteItem as Map<String, dynamic>);
      }

      await _setLastSyncTimestamp(DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error pulling remote changes: $e');
    }
  }

  Future<void> _mergeRemoteItem(Map<String, dynamic> remoteItem) async {
    final localId = remoteItem['localId'] as String?;
    final convexId = remoteItem['_id'] as String?;

    if (localId == null || convexId == null) return;

    final localItem = await _db.getItemById(localId);

    if (localItem == null) {
      await _insertRemoteItem(remoteItem);
    } else {
      await _resolveConflict(localItem, remoteItem);
    }
  }

  Future<void> _insertRemoteItem(Map<String, dynamic> remoteItem) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final remoteUpdatedAt = remoteItem['updatedAt'] as int? ?? now;

    await _db.insertItem(
      ItemsCompanion.insert(
        id: remoteItem['localId'] as String,
        convexId: Value(remoteItem['_id'] as String?),
        userId: remoteItem['userId'] as String,
        type: remoteItem['type'] as String,
        title: remoteItem['title'] as String,
        url: Value(remoteItem['url'] as String?),
        description: Value(remoteItem['description'] as String?),
        thumbnailUrl: Value(remoteItem['thumbnailUrl'] as String?),
        estimatedReadTime: Value(remoteItem['estimatedReadTime'] as int?),
        priority: Value(remoteItem['priority'] as String? ?? 'medium'),
        tags: Value(jsonEncode(remoteItem['tags'] as List<dynamic>? ?? [])),
        status: Value(remoteItem['status'] as String? ?? 'unread'),
        readAt: Value(remoteItem['readAt'] as int?),
        visibility: Value(remoteItem['visibility'] as String? ?? 'private'),
        syncStatus: const Value('synced'),
        createdAt: remoteItem['createdAt'] as int? ?? now,
        updatedAt: remoteUpdatedAt,
      ),
    );
  }

  Future<void> _resolveConflict(
    Item localItem,
    Map<String, dynamic> remoteItem,
  ) async {
    final localUpdatedAt = localItem.updatedAt;
    final remoteUpdatedAt = remoteItem['updatedAt'] as int? ?? 0;

    if (remoteUpdatedAt > localUpdatedAt) {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.updateItemById(
        localItem.id,
        ItemsCompanion(
          title: Value(remoteItem['title'] as String),
          url: Value(remoteItem['url'] as String?),
          description: Value(remoteItem['description'] as String?),
          thumbnailUrl: Value(remoteItem['thumbnailUrl'] as String?),
          estimatedReadTime: Value(remoteItem['estimatedReadTime'] as int?),
          priority: Value(remoteItem['priority'] as String? ?? 'medium'),
          tags: Value(jsonEncode(remoteItem['tags'] as List<dynamic>? ?? [])),
          status: Value(remoteItem['status'] as String? ?? 'unread'),
          readAt: Value(remoteItem['readAt'] as int?),
          visibility: Value(remoteItem['visibility'] as String? ?? 'private'),
          syncStatus: const Value('synced'),
          updatedAt: Value(remoteUpdatedAt),
        ),
      );
    }
  }

  Future<int> _getLastSyncTimestamp() async {
    return 0;
  }

  Future<void> _setLastSyncTimestamp(int timestamp) async {}

  Future<String> createItem({
    required String userId,
    required String type,
    required String title,
    String? url,
    String? description,
    String? thumbnailUrl,
    int? estimatedReadTime,
    String priority = 'medium',
    List<String> tags = const [],
    String visibility = 'private',
  }) async {
    final duplicate = await _db.findDuplicateItem(userId, url);
    if (duplicate != null) {
      throw DuplicateItemException(
        'Item with this URL already exists',
        duplicate.id,
      );
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.insertItem(
      ItemsCompanion.insert(
        id: id,
        userId: userId,
        type: type,
        title: title,
        url: Value(url),
        description: Value(description),
        thumbnailUrl: Value(thumbnailUrl),
        estimatedReadTime: Value(estimatedReadTime),
        priority: Value(priority),
        tags: Value(jsonEncode(tags)),
        status: const Value('unread'),
        visibility: Value(visibility),
        syncStatus: const Value('pending'),
        createdAt: now,
        updatedAt: now,
      ),
    );

    await _db.addToSyncQueue(
      tableName: 'items',
      recordId: id,
      operation: 'create',
      payload: jsonEncode({
        'localId': id,
        'userId': userId,
        'type': type,
        'title': title,
        'url': url,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'estimatedReadTime': estimatedReadTime,
        'priority': priority,
        'tags': tags,
        'visibility': visibility,
        'status': 'unread',
        'remindCount': 0,
      }),
    );

    _triggerSync();

    return id;
  }

  Future<void> updateItemStatus(String itemId, String status) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = await _db.getItemById(itemId);

    if (item == null) return;

    await _db.updateItemById(
      itemId,
      ItemsCompanion(
        status: Value(status),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
        readAt: status == 'read' ? Value(now) : const Value.absent(),
      ),
    );

    await _db.addToSyncQueue(
      tableName: 'items',
      recordId: itemId,
      operation: 'update',
      payload: jsonEncode({
        'convexId': item.convexId,
        'status': status,
        'readAt': status == 'read' ? now : item.readAt,
      }),
    );

    _triggerSync();
  }

  Future<void> deleteItem(String itemId) async {
    final item = await _db.getItemById(itemId);
    if (item == null) return;

    await _db.deleteItem(itemId);

    if (item.convexId != null) {
      await _db.addToSyncQueue(
        tableName: 'items',
        recordId: itemId,
        operation: 'delete',
        payload: jsonEncode({'convexId': item.convexId}),
      );
    }

    _triggerSync();
  }

  Future<void> updateItemPriority(String itemId, String priority) async {
    final item = await _db.getItemById(itemId);
    if (item == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.updateItemById(
      itemId,
      ItemsCompanion(
        priority: Value(priority),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    await _db.addToSyncQueue(
      tableName: 'items',
      recordId: itemId,
      operation: 'update',
      payload: jsonEncode({'convexId': item.convexId, 'priority': priority}),
    );

    _triggerSync();
  }

  Future<void> updateItemTags(String itemId, List<String> tags) async {
    final item = await _db.getItemById(itemId);
    if (item == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.updateItemById(
      itemId,
      ItemsCompanion(
        tags: Value(jsonEncode(tags)),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    await _db.addToSyncQueue(
      tableName: 'items',
      recordId: itemId,
      operation: 'update',
      payload: jsonEncode({'convexId': item.convexId, 'tags': tags}),
    );

    _triggerSync();
  }

  Future<void> syncNow() async {
    await _triggerSync();
  }
}

class DuplicateItemException implements Exception {
  final String message;
  final String existingItemId;

  DuplicateItemException(this.message, this.existingItemId);

  @override
  String toString() => message;
}
