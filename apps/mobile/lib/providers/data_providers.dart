import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/database.dart';
import '../data/sync/sync_engine.dart';
import 'auth_provider.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final convex = ref.watch(convexClientProvider);

  final engine = SyncEngine(db: db, convex: convex);

  engine.initialize();

  ref.onDispose(() {
    engine.dispose();
  });

  return engine;
});

final itemsStreamProvider = StreamProvider.family<List<Item>, String>((
  ref,
  userId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchItemsByUserId(userId);
});

final itemsProvider = FutureProvider.family<List<Item>, String>((
  ref,
  userId,
) async {
  final db = ref.watch(databaseProvider);
  return db.getItemsByUserId(userId);
});

final tagsProvider = FutureProvider.family<List<Tag>, String>((
  ref,
  userId,
) async {
  final db = ref.watch(databaseProvider);
  return db.getTagsByUserId(userId);
});
