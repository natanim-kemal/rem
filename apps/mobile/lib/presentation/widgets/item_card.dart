import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ItemCard extends StatelessWidget {
  final String title;
  final String url;
  final String priority;
  final String type;
  final String? thumbnailUrl;
  final String? readTime;
  final String? date;
  final VoidCallback? onTap;

  const ItemCard({
    super.key,
    required this.title,
    required this.url,
    required this.priority,
    required this.type,
    this.thumbnailUrl,
    this.readTime,
    this.date,
    this.onTap,
  });

  bool _isLocalFile(String path) {
    return path.startsWith('/') || path.startsWith('file://');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cacheSize = (82 * MediaQuery.of(context).devicePixelRatio).round();
    final isXSource = _isXSource(url);
    final isBook = type == 'book';
    final hasThumbnailUrl = thumbnailUrl != null && thumbnailUrl!.isNotEmpty;
    final isLocalThumbnail = hasThumbnailUrl && _isLocalFile(thumbnailUrl!);
    final hasNetworkThumbnail = hasThumbnailUrl && !isLocalThumbnail;
    final hasAssetThumbnail =
        isBook || (isXSource && !hasNetworkThumbnail && !isLocalThumbnail);
    final hasThumbnail =
        hasAssetThumbnail || hasNetworkThumbnail || isLocalThumbnail;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.6),
              width: 0.6,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 3,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _getPriorityColor(),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          url,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (date != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '•',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          date!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        _getTypeLabel(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (readTime != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '•',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          readTime!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (hasThumbnail) ...[
              const SizedBox(width: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: hasAssetThumbnail
                    ? Image.asset(
                        isBook
                            ? 'assets/images/book-img.png'
                            : 'assets/images/x-img.png',
                        width: 82,
                        height: 82,
                        fit: BoxFit.cover,
                        cacheWidth: cacheSize,
                        cacheHeight: cacheSize,
                      )
                    : isLocalThumbnail
                    ? Image.file(
                        File(thumbnailUrl!),
                        width: 82,
                        height: 82,
                        fit: BoxFit.cover,
                        cacheWidth: cacheSize,
                        cacheHeight: cacheSize,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 82,
                          height: 82,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            _getTypeIcon(),
                            size: 30,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : hasNetworkThumbnail
                    ? CachedNetworkImage(
                        imageUrl: thumbnailUrl!,
                        width: 82,
                        height: 82,
                        fit: BoxFit.cover,
                        memCacheWidth: cacheSize,
                        memCacheHeight: cacheSize,
                        placeholder: (context, url) => Container(
                          width: 82,
                          height: 82,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CupertinoActivityIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 82,
                          height: 82,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            _getTypeIcon(),
                            size: 30,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ] else ...[
              const SizedBox(width: 14),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getTypeIcon(),
                  size: 30,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTypeLabel() {
    switch (type) {
      case 'image':
        return 'Image';
      case 'video':
        return 'Video';
      case 'book':
        return 'Book';
      case 'note':
        return 'Note';
      default:
        return 'Link';
    }
  }

  IconData _getTypeIcon() {
    switch (type) {
      case 'image':
        return CupertinoIcons.photo;
      case 'video':
        return CupertinoIcons.play_circle;
      case 'book':
        return CupertinoIcons.book;
      case 'note':
        return CupertinoIcons.doc_text;
      default:
        return CupertinoIcons.link;
    }
  }

  Color _getPriorityColor() {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFF1A8A6E);
      case 'medium':
        return const Color(0xFF2FBF9A);
      case 'low':
        return const Color(0xFF7DDBC4);
      default:
        return const Color(0xFF2FBF9A);
    }
  }

  bool _isXSource(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    var uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      uri = Uri.tryParse('https://$trimmed');
    }
    final host = uri?.host.toLowerCase() ?? '';
    return host == 'x.com' ||
        host.endsWith('.x.com') ||
        host == 'twitter.com' ||
        host.endsWith('.twitter.com') ||
        host == 'mobile.twitter.com' ||
        host == 't.co';
  }
}
