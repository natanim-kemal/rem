import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../widgets/search_bar.dart' as custom;
import '../widgets/filter_chips.dart';
import '../widgets/item_card.dart';
import '../widgets/sync_status_indicator.dart';
import '../theme/app_theme.dart';
import 'item_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  int _currentPage = 0;
  final List<Item> _allItems = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _lastHandledKey;
  int _refreshToken = 0;
  int _lastItemCount = 0;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoading) return;
    if (_allItems.isEmpty) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const threshold = 200.0;

    if (maxScroll - currentScroll <= threshold) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (!_hasMore || _isLoading) return;
    setState(() {
      _currentPage++;
      _isLoading = true;
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _currentPage = 0;
      _allItems.clear();
      _hasMore = true;
      _isLoading = true;
      _lastHandledKey = null;
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _currentPage = 0;
      _allItems.clear();
      _hasMore = true;
      _isLoading = true;
      _lastHandledKey = null;
    });
  }

  String? _getStatusFilter() {
    if (_selectedFilter == 'Unread') return 'unread';
    return null;
  }

  String? _getTypeFilter() {
    switch (_selectedFilter) {
      case 'Links':
        return 'link';
      case 'Images':
        return 'image';
      case 'Videos':
        return 'video';
      case 'Books':
        return 'book';
      case 'Notes':
        return 'note';
      default:
        return null;
    }
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  List<String> _parseTags(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded.whereType<String>().toList();
        }
      } catch (_) {}
    }
    return trimmed
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  void _handlePaginationResult(PaginatedItemsResult result) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (_currentPage == 0) {
        _allItems.clear();
        _allItems.addAll(result.items);
      } else {
        final existingIds = _allItems.map((i) => i.id).toSet();
        final newItems = result.items.where(
          (item) => !existingIds.contains(item.id),
        );
        _allItems.addAll(newItems);
      }
      _hasMore = result.hasMore;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.userId;
    final manualRefreshToken = ref.watch(homeRefreshProvider);

    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final params = PaginatedItemsParams(
      userId: userId,
      status: _getStatusFilter(),
      type: _getTypeFilter(),
      searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      page: _currentPage,
      pageSize: 20,
      refreshToken: _refreshToken + manualRefreshToken,
    );

    final paginatedAsync = ref.watch(paginatedItemsProvider(params));
    ref.listen<AsyncValue<int>>(itemsCountStreamProvider(userId), (
      previous,
      next,
    ) {
      if (!mounted) return;
      final nextValue = next.value;
      if (nextValue == null) return;
      final prevValue = previous?.value ?? _lastItemCount;
      _lastItemCount = nextValue;
      if (nextValue > prevValue) {
        setState(() {
          _currentPage = 0;
          _allItems.clear();
          _hasMore = true;
          _isLoading = true;
          _lastHandledKey = null;
          _refreshToken++;
        });
      }
    });
    final result = paginatedAsync.value;
    if (result != null) {
      final key =
          '$_selectedFilter|$_searchQuery|${result.page}|$_refreshToken';
      if (_lastHandledKey != key) {
        _lastHandledKey = key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _handlePaginationResult(result);
        });
      }
    }
    final isLoading = _isLoading || paginatedAsync.isLoading;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                setState(() {
                  _currentPage = 0;
                  _allItems.clear();
                  _hasMore = true;
                  _isLoading = true;
                  _lastHandledKey = null;
                  _refreshToken++;
                });
                final syncEngine = ref.read(syncEngineProvider);
                await syncEngine.syncNow();
                ref.invalidate(paginatedItemsProvider);
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'rem',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SyncStatusIndicator(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: custom.SearchBar(
                  hintText: 'Search your vault...',
                  onChanged: _onSearchChanged,
                  onFilterTap: () {},
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FilterChips(
                filters: const [
                  'All',
                  'Unread',
                  'Links',
                  'Images',
                  'Videos',
                  'Books',
                ],
                selected: _selectedFilter,
                onSelected: _onFilterChanged,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (_allItems.isEmpty && isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_allItems.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(
                  hasSearchOrFilter:
                      _searchQuery.isNotEmpty || _selectedFilter != 'All',
                  error: paginatedAsync.hasError
                      ? paginatedAsync.error.toString()
                      : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _allItems.length) {
                        if (_hasMore && isLoading) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CupertinoActivityIndicator()),
                          );
                        }
                        return const SizedBox.shrink();
                      }

                      final item = _allItems[index];
                      return ItemCard(
                        title: item.title,
                        url: item.url ?? 'No URL',
                        type: item.type,
                        priority: item.priority,
                        thumbnailUrl: item.thumbnailUrl,
                        readTime: item.estimatedReadTime != null
                            ? '${item.estimatedReadTime} min'
                            : null,
                        date: _formatDate(item.createdAt),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ItemDetailScreen(
                                item: {
                                  'id': item.id,
                                  'title': item.title,
                                  'url': item.url,
                                  'type': item.type,
                                  'priority': item.priority,
                                  'description': item.description,
                                  'thumbnailUrl': item.thumbnailUrl,
                                  'tags': _parseTags(item.tags),
                                  'status': item.status,
                                  'createdAt': item.createdAt,
                                  'convexId': item.convexId,
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount:
                        _allItems.length + (_hasMore && isLoading ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearchOrFilter;
  final String? error;

  const _EmptyState({this.hasSearchOrFilter = false, this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.tray, size: 64, color: context.textTertiary),
            const SizedBox(height: 16),
            Text(
              hasSearchOrFilter
                  ? 'No items match your filters'
                  : 'Your vault is empty',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              hasSearchOrFilter
                  ? 'Try adjusting your search or filters'
                  : 'Tap the + button to save your first item',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
