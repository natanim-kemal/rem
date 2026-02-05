import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rem/providers/data_providers.dart';
import '../theme/app_theme.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  bool _isDeleting = false;

  // Local mutable state copied from widget
  late String _priority;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    // Initialize local state from widget
    _priority = widget.item['priority'] as String? ?? 'medium';
    _tags = List<String>.from(
      (widget.item['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return const Color(0xFFFF3B30);
      case 'medium':
        return const Color(0xFFFF9500);
      case 'low':
        return const Color(0xFF34C759);
      default:
        return const Color(0xFFFF9500);
    }
  }

  Widget _buildTagsPreview() {
    if (_tags.isEmpty) {
      return Text(
        'Add tags...',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }

    return Text(
      _tags.take(3).join(', ') +
          (_tags.length > 3 ? ' +${_tags.length - 3} more' : ''),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Future<void> _launchUrl(BuildContext context) async {
    final url = Uri.parse(widget.item['url'] ?? '');
    final canLaunch = await canLaunchUrl(url);
    if (!context.mounted) return;

    if (canLaunch) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Item'),
        content: const Text(
          'Are you sure you want to delete this item? This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      final syncEngine = ref.read(syncEngineProvider);
      final itemId = widget.item['id'] as String?;

      if (itemId != null) {
        await syncEngine.deleteItem(itemId);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete item: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showEditPrioritySheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Change Priority'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => _updatePriority('high'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('High'),
                if (_priority == 'high') ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 16),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => _updatePriority('medium'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF9500),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Medium'),
                if (_priority == 'medium') ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 16),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => _updatePriority('low'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34C759),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Low'),
                if (_priority == 'low') ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 16),
                ],
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _updatePriority(String priority) async {
    Navigator.pop(context);

    final itemId = widget.item['id'] as String?;
    if (itemId == null) return;

    try {
      final syncEngine = ref.read(syncEngineProvider);
      await syncEngine.updateItemPriority(itemId, priority);

      if (mounted) {
        setState(() {
          _priority = priority;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Priority updated'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update priority: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showEditTagsSheet() {
    final tempTags = List<String>.from(_tags);
    final textController = TextEditingController();

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const Text(
                        'Edit Tags',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          final itemId = widget.item['id'] as String?;
                          if (itemId != null) {
                            try {
                              final syncEngine = ref.read(syncEngineProvider);
                              await syncEngine.updateItemTags(itemId, tempTags);
                              if (mounted) {
                                setState(() {
                                  _tags = tempTags;
                                });
                                Navigator.of(this.context).pop();
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Tags updated'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to update tags: $e'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: textController,
                          placeholder: 'Add a tag...',
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty &&
                                !tempTags.contains(value.trim())) {
                              setModalState(() {
                                tempTags.add(value.trim());
                              });
                              textController.clear();
                            }
                          },
                        ),
                      ),
                      CupertinoButton(
                        child: const Icon(CupertinoIcons.add),
                        onPressed: () {
                          final value = textController.text.trim();
                          if (value.isNotEmpty && !tempTags.contains(value)) {
                            setModalState(() {
                              tempTags.add(value);
                            });
                            textController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: tempTags.isEmpty
                      ? Center(
                          child: Text(
                            'No tags yet',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: tempTags.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(CupertinoIcons.tag, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(tempTags[index])),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    child: const Icon(
                                      CupertinoIcons.xmark,
                                      size: 16,
                                      color: CupertinoColors.destructiveRed,
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        tempTags.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = widget.item['thumbnailUrl'] != null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: hasImage ? 300 : null,
            pinned: true,
            flexibleSpace: hasImage
                ? FlexibleSpaceBar(
                    background: Image.network(
                      widget.item['thumbnailUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  )
                : null,
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(CupertinoIcons.heart),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(CupertinoIcons.share),
              ),
              if (_isDeleting)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CupertinoActivityIndicator(),
                )
              else
                IconButton(
                  onPressed: _deleteItem,
                  icon: const Icon(CupertinoIcons.trash),
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Text(
                      (widget.item['type'] as String? ?? '').toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _showEditPrioritySheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(
                            _priority,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _getPriorityColor(_priority),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _priority.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _getPriorityColor(_priority),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              CupertinoIcons.chevron_down,
                              size: 10,
                              color: _getPriorityColor(_priority),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.item['title'] ?? 'No Title',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                _MetaRow(
                  icon: CupertinoIcons.link,
                  text: widget.item['url'] ?? '',
                  onTap: () => _launchUrl(context),
                  isLink: true,
                ),
                const SizedBox(height: 12),
                _MetaRow(
                  icon: CupertinoIcons.calendar,
                  text:
                      'Added ${widget.item['createdAt'] != null ? _formatDate(widget.item['createdAt'] as int) : ''}',
                ),
                const SizedBox(height: 12),
                if (widget.item['estimatedReadTime'] != null)
                  _MetaRow(
                    icon: CupertinoIcons.time,
                    text: '${widget.item['estimatedReadTime']} min read',
                  ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _showEditTagsSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.tag,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTagsPreview()),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
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
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isLink
                    ? AppTheme.accent
                    : Theme.of(context).colorScheme.onSurface,
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
