import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/database.dart';
import '../data/sync/sync_engine.dart';
import '../data/models/notification_preferences.dart';
import 'auth_provider.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.instance;
  db.ensureFtsReindexOnce();
  return db;
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

final userByClerkIdProvider = FutureProvider.family<User?, String>((
  ref,
  clerkId,
) async {
  if (clerkId.isEmpty) return null;
  final db = ref.watch(databaseProvider);
  return db.getUserByClerkId(clerkId);
});

final userByClerkIdStreamProvider = StreamProvider.family<User?, String>((
  ref,
  clerkId,
) {
  if (clerkId.isEmpty) return const Stream.empty();
  final db = ref.watch(databaseProvider);
  return db.watchUserByClerkId(clerkId);
});

final notificationHistoryProvider = FutureProvider.family<List<dynamic>, int>((
  ref,
  limit,
) async {
  final convex = ref.watch(convexClientProvider);
  return await convex.query('notifications:getNotificationHistory', {
        'limit': limit,
      })
      as List<dynamic>;
});

final notificationPrefsCacheProvider =
    NotifierProvider<NotificationPrefsCacheNotifier, NotificationPreferences?>(
        NotificationPrefsCacheNotifier.new);

class NotificationPrefsCacheNotifier
    extends Notifier<NotificationPreferences?> {
  @override
  NotificationPreferences? build() => null;

  void set(NotificationPreferences? value) {
    state = value;
  }
}

class ProfileGenderNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return 'M';
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('profile_gender');
    if (value == 'M' || value == 'F') {
      state = value!;
    }
  }

  Future<void> setGender(String value) async {
    if (value != 'M' && value != 'F') return;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_gender', value);
  }
}

final profileGenderProvider =
    NotifierProvider<ProfileGenderNotifier, String>(ProfileGenderNotifier.new);

class HomeRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final homeRefreshProvider = NotifierProvider<HomeRefreshNotifier, int>(() {
  return HomeRefreshNotifier();
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

final itemsCountStreamProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchItemsCount(userId);
});

class PaginatedItemsParams {
  final String userId;
  final String? status;
  final String? type;
  final String? searchQuery;
  final int page;
  final int pageSize;
  final int refreshToken;

  const PaginatedItemsParams({
    required this.userId,
    this.status,
    this.type,
    this.searchQuery,
    this.page = 0,
    this.pageSize = 15,
    this.refreshToken = 0,
  });

  PaginatedItemsParams copyWith({
    String? userId,
    String? status,
    String? type,
    String? searchQuery,
    int? page,
    int? pageSize,
    int? refreshToken,
  }) {
    return PaginatedItemsParams(
      userId: userId ?? this.userId,
      status: status,
      type: type,
      searchQuery: searchQuery,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaginatedItemsParams &&
        other.userId == userId &&
        other.status == status &&
        other.type == type &&
        other.searchQuery == searchQuery &&
        other.page == page &&
        other.pageSize == pageSize &&
        other.refreshToken == refreshToken;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      status,
      type,
      searchQuery,
      page,
      pageSize,
      refreshToken,
    );
  }
}

class PaginatedItemsResult {
  final List<Item> items;
  final int totalCount;
  final bool hasMore;
  final int page;

  const PaginatedItemsResult({
    required this.items,
    required this.totalCount,
    required this.hasMore,
    required this.page,
  });
}

final paginatedItemsProvider =
    FutureProvider.family<PaginatedItemsResult, PaginatedItemsParams>((
      ref,
      params,
    ) async {
      final db = ref.watch(databaseProvider);

      final offset = params.page * params.pageSize;

      final items = await db.getItemsPaginated(
        params.userId,
        status: params.status,
        type: params.type,
        searchQuery: params.searchQuery?.isNotEmpty == true
            ? params.searchQuery
            : null,
        limit: params.pageSize,
        offset: offset,
      );

      final totalCount = await db.getItemsCount(
        params.userId,
        status: params.status,
        type: params.type,
        searchQuery: params.searchQuery?.isNotEmpty == true
            ? params.searchQuery
            : null,
      );

      return PaginatedItemsResult(
        items: items,
        totalCount: totalCount,
        hasMore: offset + items.length < totalCount,
        page: params.page,
      );
    });
