import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/search_bar.dart' as custom;
import '../widgets/filter_chips.dart';
import '../widgets/item_card.dart';
import '../theme/app_theme.dart';
import 'item_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _items = [
    {
      'title': 'The Future of AI in Mobile Development',
      'url': 'medium.com',
      'type': 'link',
      'priority': 'high',
      'readTime': '8 min',
      'date': '2 hours ago',
      'thumbnail':
          'https://images.unsplash.com/photo-1677442136019-21780ecad995?auto=format&fit=crop&q=80&w=800',
    },
    {
      'title': 'Beautiful UI Design Patterns',
      'url': 'dribbble.com',
      'type': 'image',
      'priority': 'medium',
      'readTime': '3 min',
      'date': 'Yesterday',
      'thumbnail':
          'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&q=80&w=800',
    },
    {
      'title': 'Flutter State Management Guide',
      'url': 'flutter.dev',
      'type': 'link',
      'priority': 'low',
      'readTime': '15 min',
      'date': '3 days ago',
      'thumbnail': null,
    },
    {
      'title': 'Minimalist Architecture in 2024',
      'url': 'archdaily.com',
      'type': 'image',
      'priority': 'high',
      'readTime': '5 min',
      'date': '4 days ago',
      'thumbnail':
          'https://images.unsplash.com/photo-1486718448742-163732cd1544?auto=format&fit=crop&q=80&w=800',
    },
  ];

  @override
  Widget build(BuildContext context) {
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
                await Future.delayed(const Duration(seconds: 1));
                if (mounted) setState(() {});
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
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(CupertinoIcons.bell),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: custom.SearchBar(
                  hintText: 'Search your vault...',
                  onChanged: (value) {},
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
            if (_items.isEmpty)
              SliverFillRemaining(child: _EmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ItemCard(
                      title: _items[index]['title'],
                      url: _items[index]['url'],
                      type: _items[index]['type'],
                      priority: _items[index]['priority'],
                      thumbnailUrl: _items[index]['thumbnail'],
                      readTime: _items[index]['readTime'],
                      date: _items[index]['date'],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ItemDetailScreen(item: _items[index]),
                          ),
                        );
                      },
                    ),
                    childCount: _items.length,
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
              'Your vault is empty',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to save your first item',
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
