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

  List<Item> _filterItems(List<Item> items) {
    return items.where((item) {
      if (_selectedFilter != 'All') {
        if (_selectedFilter == 'Unread' && item.status == 'read') {
          return false;
        } else if (_selectedFilter != 'Unread' &&
            item.type.toLowerCase() != _selectedFilter.toLowerCase()) {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final titleMatch = item.title.toLowerCase().contains(query);
        final urlMatch = item.url?.toLowerCase().contains(query) ?? false;
        final tagsMatch = item.tags.toLowerCase().contains(query);
        if (!titleMatch && !urlMatch && !tagsMatch) {
          return false;
        }
      }

      return true;
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.userId;

    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final itemsAsync = ref.watch(itemsStreamProvider(userId));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                final syncEngine = ref.read(syncEngineProvider);
                await syncEngine.syncNow();
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
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
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
                onSelected: (filter) {
                  setState(() => _selectedFilter = filter);
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            itemsAsync.when(
              data: (items) {
                final filteredItems = _filterItems(items);

                if (filteredItems.isEmpty) {
                  return SliverFillRemaining(
                    child: _EmptyState(hasItems: items.isNotEmpty),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = filteredItems[index];
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
                    }, childCount: filteredItems.length),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          size: 64,
                          color: context.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading items',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
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
  final bool hasItems;

  const _EmptyState({this.hasItems = false});

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
              hasItems ? 'No items match your filters' : 'Your vault is empty',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              hasItems
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
