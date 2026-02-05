import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'search',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(width: 48, height: 48),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search your vault...',
                  prefixIcon: const Icon(CupertinoIcons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _RecentSearchItem(text: 'flutter tutorial', onTap: () {}),
                  _RecentSearchItem(text: 'design patterns', onTap: () {}),
                  _RecentSearchItem(text: 'productivity', onTap: () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSearchItem extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _RecentSearchItem({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        CupertinoIcons.clock,
        color: context.textSecondary,
        size: 20,
      ),
      title: Text(text),
      trailing: Icon(
        CupertinoIcons.arrow_up_left,
        color: context.textTertiary,
        size: 18,
      ),
      onTap: onTap,
    );
  }
}
