import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../../core/services/convex_client.dart';

class SyncEngine {
  final AppDatabase _db;
  final ConvexClient _convex;

  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

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

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.isEmpty ||
          connectivity.first == ConnectivityResult.none) {
        return;
      }

      await _pushLocalChanges();

      await _pullRemoteChanges();
    } catch (e) {
      debugPrint('Sync error: $e');
    } finally {
      _isSyncing = false;
    }
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

  Future<void> _pullRemoteChanges() async {}

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

  Future<void> syncNow() async {
    await _triggerSync();
  }
}
