import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class ItemDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;

  const ItemDetailScreen({super.key, required this.item});

  Future<void> _launchUrl(BuildContext context) async {
    final url = Uri.parse(item['url'] ?? '');
    final canLaunch = await canLaunchUrl(url);
    if (!context.mounted) return;

    if (canLaunch) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch URL')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = item['thumbnail'] != null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: hasImage ? 300 : null,
            pinned: true,
            flexibleSpace: hasImage
                ? FlexibleSpaceBar(
                    background: Image.network(
                      item['thumbnail'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: theme.colorScheme.surfaceContainerHighest),
                    ),
                  )
                : null,
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(CupertinoIcons.heart)),
              IconButton(onPressed: () {}, icon: const Icon(CupertinoIcons.share)),
              IconButton(onPressed: () {}, icon: const Icon(CupertinoIcons.trash)),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  item['type'].toString().toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['title'] ?? 'No Title',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                _MetaRow(
                  icon: CupertinoIcons.link,
                  text: item['url'] ?? '',
                  onTap: () => _launchUrl(context),
                  isLink: true,
                ),
                const SizedBox(height: 12),
                _MetaRow(
                  icon: CupertinoIcons.calendar,
                  text: 'Added ${item['date']}',
                ),
                const SizedBox(height: 12),
                _MetaRow(
                  icon: CupertinoIcons.time,
                  text: item['readTime'],
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _launchUrl(context),
                  icon: const Icon(CupertinoIcons.compass),
                  label: const Text('Open Original'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 100), // Bottom padding
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final bool isLink;

  const _MetaRow({
    required this.icon,
    required this.text,
    this.onTap,
    this.isLink = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isLink ? AppTheme.accent : Theme.of(context).colorScheme.onSurface,
                    decoration: isLink ? TextDecoration.underline : null,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
