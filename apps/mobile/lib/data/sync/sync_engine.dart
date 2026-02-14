import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../models/notification_preferences.dart';
import '../../core/services/convex_client.dart';

enum SyncStatus { idle, syncing, error, offline }

class SyncEngine {
  final AppDatabase _db;
  final ConvexClient _convex;

  ConvexClient get convex => _convex;

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
    
    if (!_convex.isAuthenticated) {
      debugPrint('Sync skipped: not authenticated');
      return;
    }

    try {
      _isSyncing = true;
      _updateStatus(SyncStatus.syncing);

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.isEmpty ||
          connectivity.first == ConnectivityResult.none) {
        _updateStatus(SyncStatus.offline);
        return;
      }

      try {
        await _convex.mutation('users:getOrCreateUser', {});
      } catch (e) {
        debugPrint('Failed to create/get user: $e');
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
    final cleanPayload = Map<String, dynamic>.fromEntries(
      payload.entries.where((e) => e.value != null),
    );

    switch (syncItem.operation) {
      case 'create':
        final createPayload = Map<String, dynamic>.from(cleanPayload);

        createPayload.remove('remindCount');
        createPayload.remove('status');
        createPayload.remove('visibility');
        createPayload.remove('userId');

        try {
          final result = await _convex.mutation(
            'items:createItem',
            createPayload,
          );
          if (result != null) {
            String? convexId;
            if (result is String) {
              convexId = result;
            } else if (result is Map<String, dynamic>) {
              convexId = result['_id'] as String? ?? result['id'] as String?;
            }

            if (convexId != null) {
              await _db.updateItemSyncStatus(
                syncItem.recordId,
                convexId: convexId,
                syncStatus: 'synced',
              );
            }
          }
        } catch (e) {
          final message = e.toString();
          if (message.contains('Duplicate URL')) {
            await _db.updateItemSyncStatus(
              syncItem.recordId,
              syncStatus: 'synced',
            );
            return;
          }
          rethrow;
        }
        break;

      case 'update':
        final convexId = payload['convexId'];
        if (convexId != null) {
          final updatePayload = Map<String, dynamic>.from(cleanPayload)
            ..remove('convexId');
          updatePayload.remove('readAt');
          updatePayload.remove('remindCount');
          updatePayload.remove('lastRemindedAt');
          try {
            await _convex.mutation('items:updateItem', {
              'itemId': convexId,
              ...updatePayload,
            });
          } catch (e) {
            final message = e.toString();
            if (message.contains('Object contains extra field')) {
              await _db.updateItemSyncStatus(
                syncItem.recordId,
                syncStatus: 'synced',
              );
              return;
            }
            rethrow;
          }
          await _db.updateItemSyncStatus(
            syncItem.recordId,
            syncStatus: 'synced',
          );
        }
        break;

      case 'delete':
        final convexId = payload['convexId'];
        if (convexId != null) {
          try {
            await _convex.mutation('items:deleteItem', {'itemId': convexId});
          } catch (e) {
            final message = e.toString().toLowerCase();
            if (message.contains('nonexistent document')) {
              return;
            }
            rethrow;
          }
        }
        break;
    }
  }

  Future<void> _syncTag(
    SyncQueueData syncItem,
    Map<String, dynamic> payload,
  ) async {
    debugPrint('Tag sync skipped - tags are synced via items');
    await _db.removeSyncItem(syncItem.id);
  }

  Future<void> _syncUser(
    SyncQueueData syncItem,
    Map<String, dynamic> payload,
  ) async {
    if (syncItem.operation == 'update') {
      final userId = payload['userId'];
      if (userId is String && userId.isNotEmpty) {
        final cleanPayload = Map<String, dynamic>.from(payload)
          ..remove('userId');
        await _convex.mutation(
          'users:updateNotificationPreferences',
          cleanPayload,
        );
        await _db.removeSyncItemsForRecord(
          tableName: 'users',
          recordId: userId,
        );
      }
    }
  }

  Future<void> _pullRemoteChanges() async {
    try {
      final lastSyncAt = await _getLastSyncTimestamp();

      var remoteItems =
          await _convex.query('items:getItemsSince', {'since': lastSyncAt})
              as List<dynamic>?;

      if ((remoteItems == null || remoteItems.isEmpty) && lastSyncAt == 0) {
        remoteItems =
            await _convex.query('items:getItems', {'limit': 200})
                as List<dynamic>?;
      }

      if (remoteItems == null || remoteItems.isEmpty) return;

      for (final remoteItem in remoteItems) {
        if (remoteItem is! Map<String, dynamic>) continue;
        await _mergeRemoteItem(remoteItem);
      }

      await _setLastSyncTimestamp(DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error pulling remote changes: $e');
    }
  }

  Future<void> _mergeRemoteItem(Map<String, dynamic> remoteItem) async {
    final convexId = _asString(remoteItem['_id']);
    final localId = _asString(remoteItem['localId']) ?? convexId;
    final userId = _asString(remoteItem['userId']);
    final type = _asString(remoteItem['type']) ?? 'link';
    final title = _asString(remoteItem['title']) ?? 'Untitled';

    if (localId == null || convexId == null || userId == null) {
      return;
    }

    final existingByConvex = await _db.getItemByConvexId(convexId);
    if (existingByConvex != null) {
      await _resolveConflict(existingByConvex, remoteItem, title);
      return;
    }

    final localItem = await _db.getItemById(localId);

    if (localItem == null) {
      await _insertRemoteItem(
        remoteItem,
        localId,
        convexId,
        userId,
        type,
        title,
      );
    } else {
      await _resolveConflict(localItem, remoteItem, title);
    }
  }

  Future<void> _insertRemoteItem(
    Map<String, dynamic> remoteItem,
    String localId,
    String convexId,
    String userId,
    String type,
    String title,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final remoteUpdatedAt = _asInt(remoteItem['updatedAt']) ?? now;
    final url = _asString(remoteItem['url']);
    final description = _asString(remoteItem['description']);
    final thumbnailUrl = _asString(remoteItem['thumbnailUrl']);
    final priority = _asString(remoteItem['priority']) ?? 'medium';
    final status = _asString(remoteItem['status']) ?? 'unread';
    final visibility = _asString(remoteItem['visibility']) ?? 'private';

    await _db.insertItem(
      ItemsCompanion.insert(
        id: localId,
        convexId: Value(convexId),
        userId: userId,
        type: type,
        title: title,
        url: Value(url),
        description: Value(description),
        thumbnailUrl: Value(thumbnailUrl),
        estimatedReadTime: Value(_asInt(remoteItem['estimatedReadTime'])),
        priority: Value(priority),
        tags: Value(jsonEncode(_asList(remoteItem['tags']))),
        status: Value(status),
        readAt: Value(_asInt(remoteItem['readAt'])),
        visibility: Value(visibility),
        isFavorite: Value(remoteItem['isFavorite'] == true),
        syncStatus: const Value('synced'),
        createdAt: _asInt(remoteItem['createdAt']) ?? now,
        updatedAt: remoteUpdatedAt,
      ),
    );
  }

  Future<void> _resolveConflict(
    Item localItem,
    Map<String, dynamic> remoteItem,
    String title,
  ) async {
    final localUpdatedAt = localItem.updatedAt;
    final remoteUpdatedAt = _asInt(remoteItem['updatedAt']) ?? 0;

    if (remoteUpdatedAt > localUpdatedAt) {
      final url = _asString(remoteItem['url']);
      final description = _asString(remoteItem['description']);
      final thumbnailUrl = _asString(remoteItem['thumbnailUrl']);
      final priority = _asString(remoteItem['priority']) ?? 'medium';
      final status = _asString(remoteItem['status']) ?? 'unread';
      final visibility = _asString(remoteItem['visibility']) ?? 'private';
      await _db.updateItemById(
        localItem.id,
        ItemsCompanion(
          title: Value(title),
          url: Value(url),
          description: Value(description),
          thumbnailUrl: Value(thumbnailUrl),
          estimatedReadTime: Value(_asInt(remoteItem['estimatedReadTime'])),
          priority: Value(priority),
          tags: Value(jsonEncode(_asList(remoteItem['tags']))),
          status: Value(status),
          readAt: Value(_asInt(remoteItem['readAt'])),
          visibility: Value(visibility),
          isFavorite: Value(remoteItem['isFavorite'] == true),
          syncStatus: const Value('synced'),
          updatedAt: Value(remoteUpdatedAt),
          snoozedUntil: Value(_asInt(remoteItem['snoozedUntil'])),
        ),
      );
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return [];
  }

  String? _asString(dynamic value) {
    if (value is String) return value;
    return null;
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
        'isFavorite': false,
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

  Future<void> updateItemFavorite(String itemId, bool isFavorite) async {
    final item = await _db.getItemById(itemId);
    if (item == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.updateItemById(
      itemId,
      ItemsCompanion(
        isFavorite: Value(isFavorite),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    await _db.addToSyncQueue(
      tableName: 'items',
      recordId: itemId,
      operation: 'update',
      payload: jsonEncode({
        'convexId': item.convexId,
        'isFavorite': isFavorite,
      }),
    );

    _triggerSync();
  }

  Future<void> snoozeItem(String itemId, Duration duration) async {
    final item = await _db.getItemById(itemId);
    if (item == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final snoozedUntil = now + duration.inMilliseconds;

    await _db.updateItemById(
      itemId,
      ItemsCompanion(
        snoozedUntil: Value(snoozedUntil),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    await _db.addToSyncQueue(
      tableName: 'items',
      recordId: itemId,
      operation: 'update',
      payload: jsonEncode({
        'convexId': item.convexId,
        'snoozedUntil': snoozedUntil,
      }),
    );

    _triggerSync();
  }

  Future<void> updateNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final user = await _db.getUserByClerkId(userId);
    final userIdValue = user?.id ?? userId;

    await _db.upsertUser(
      UsersCompanion(
        id: Value(userIdValue),
        clerkId: Value(user?.clerkId ?? userId),
        email: Value(user?.email ?? ''),
        displayName: Value(user?.displayName),
        avatarUrl: Value(user?.avatarUrl),
        isPremium: Value(user?.isPremium ?? false),
        notificationPreferences: Value(jsonEncode(preferences.toJson())),
        createdAt: Value(user?.createdAt ?? now),
        updatedAt: Value(now),
        syncStatus: Value(user?.syncStatus ?? 'pending'),
      ),
    );

    await _db.addToSyncQueue(
      tableName: 'users',
      recordId: userId,
      operation: 'update',
      payload: jsonEncode({'userId': userId, ...preferences.toJson()}),
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
