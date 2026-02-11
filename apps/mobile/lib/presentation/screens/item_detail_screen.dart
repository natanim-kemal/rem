import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:rem/providers/data_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/confirmation_snackbar.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  bool _isDeleting = false;

  late String _priority;
  late String _status;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _priority = widget.item['priority'] as String? ?? 'medium';
    _status = widget.item['status'] as String? ?? 'unread';
    final tagsData = widget.item['tags'];
    List<String> parsedTags = [];
    if (tagsData is List) {
      parsedTags = tagsData
          .whereType<String>()
          .where((t) => t.isNotEmpty)
          .toList();
    } else if (tagsData is String) {
      if (tagsData.isNotEmpty && tagsData != '[]') {
        parsedTags = [tagsData];
      }
    }
    _tags = parsedTags
        .where(
          (tag) => tag.isNotEmpty && tag != '[]' && tag != '[' && tag != ']',
        )
        .toList();
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'read':
        return const Color(0xFF34C759);
      case 'in_progress':
        return const Color(0xFFFF9500);
      case 'archived':
        return const Color(0xFF8E8E93);
      case 'unread':
      default:
        return const Color(0xFF007AFF);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'read':
        return CupertinoIcons.checkmark_circle_fill;
      case 'in_progress':
        return CupertinoIcons.time;
      case 'unread':
      default:
        return CupertinoIcons.circle;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'read':
        return 'Read';
      case 'in_progress':
        return 'In Progress';
      case 'unread':
      default:
        return 'Unread';
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
      showWarningSnackBar(context, 'Could not launch URL');
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
        showConfirmationSnackBar(context, 'Item deleted');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        showWarningSnackBar(context, 'Failed to delete item: $e');
      }
    }
  }

  Future<void> _toggleArchive() async {
    final itemId = widget.item['id'] as String?;
    if (itemId == null) return;

    final newStatus = _status == 'archived' ? 'unread' : 'archived';

    try {
      final syncEngine = ref.read(syncEngineProvider);
      await syncEngine.updateItemStatus(itemId, newStatus);

      if (mounted) {
        setState(() {
          _status = newStatus;
        });
        showConfirmationSnackBar(
          context,
          newStatus == 'archived' ? 'Archived item' : 'Restored item',
        );
      }
    } catch (e) {
      if (mounted) {
        showWarningSnackBar(context, 'Failed to update archive: $e');
      }
    }
  }

  Future<void> _shareItem() async {
    final url = widget.item['url'] as String?;
    final title = widget.item['title'] as String? ?? 'Check this out';

    if (url == null || url.isEmpty) {
      if (mounted) {
        showWarningSnackBar(context, 'No URL to share');
      }
      return;
    }

    try {
      final shareText = '$title\n$url';
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: title),
      );
    } catch (e) {
      if (mounted) {
        showWarningSnackBar(context, 'Failed to share: $e');
      }
    }
  }

  void _showEditPrioritySheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Change Priority', style: TextStyle(fontSize: 15)),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => _updatePriority('high'),
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 15),
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
          ),
          CupertinoActionSheetAction(
            onPressed: () => _updatePriority('medium'),
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 15),
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
          ),
          CupertinoActionSheetAction(
            onPressed: () => _updatePriority('low'),
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 15),
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
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(fontSize: 15)),
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
        showConfirmationSnackBar(context, 'Priority updated');
      }
    } catch (e) {
      if (mounted) {
        showWarningSnackBar(context, 'Failed to update priority: $e');
      }
    }
  }

  void _showStatusPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Change Status', style: TextStyle(fontSize: 15)),
        actions: [
          _buildStatusAction('unread'),
          _buildStatusAction('in_progress'),
          _buildStatusAction('read'),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(fontSize: 15)),
        ),
      ),
    );
  }

  CupertinoActionSheetAction _buildStatusAction(String status) {
    final isSelected = _status == status;
    return CupertinoActionSheetAction(
      onPressed: () => _updateStatus(status),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getStatusIcon(status),
              size: 16,
              color: _getStatusColor(status),
            ),
            const SizedBox(width: 8),
            Text(_getStatusLabel(status)),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.checkmark, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(String status) async {
    Navigator.pop(context);

    final itemId = widget.item['id'] as String?;
    if (itemId == null) return;

    try {
      final syncEngine = ref.read(syncEngineProvider);
      await syncEngine.updateItemStatus(itemId, status);

      if (mounted) {
        setState(() {
          _status = status;
        });
        showConfirmationSnackBar(
          context,
          'Marked as ${_getStatusLabel(status).toLowerCase()}',
        );
      }
    } catch (e) {
      if (mounted) {
        showWarningSnackBar(context, 'Failed to update status: $e');
      }
    }
  }

  void _showEditTagsSheet() {
    final tempTags = List<String>.from(
      _tags
          .where(
            (tag) => tag.isNotEmpty && tag != '[]' && tag != '[' && tag != ']',
          )
          .toList(),
    );
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
                      Text(
                        'Edit Tags',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                          decoration: TextDecoration.none,
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
                                showConfirmationSnackBar(
                                  this.context,
                                  'Tags updated',
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                showWarningSnackBar(
                                  this.context,
                                  'Failed to update tags: $e',
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
                            final cleanValue = value.trim().toLowerCase();
                            if (cleanValue.isNotEmpty &&
                                !tempTags.contains(cleanValue)) {
                              setModalState(() {
                                tempTags.add(cleanValue);
                              });
                              textController.clear();
                            }
                          },
                        ),
                      ),
                      CupertinoButton(
                        child: const Icon(CupertinoIcons.add),
                        onPressed: () {
                          final value = textController.text
                              .trim()
                              .toLowerCase();
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  CupertinoIcons.tag,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No tags yet',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      decoration: TextDecoration.none,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Add a few to organize this item',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      decoration: TextDecoration.none,
                                    ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: tempTags
                              .where((t) => t.isNotEmpty && t != '[]')
                              .length,
                          itemBuilder: (context, index) {
                            final validTags = tempTags
                                .where((t) => t.isNotEmpty && t != '[]')
                                .toList();
                            if (index >= validTags.length) {
                              return const SizedBox.shrink();
                            }
                            final tag = validTags[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.tag,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    child: Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        tempTags.remove(tag);
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
    final actionBackground = hasImage
        ? Colors.black.withValues(alpha: 0.45)
        : theme.colorScheme.surfaceContainerHighest;
    final actionForeground = hasImage
        ? Colors.white
        : theme.colorScheme.onSurface;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: hasImage ? 300 : null,
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: actionForeground),
            actionsIconTheme: IconThemeData(color: actionForeground),
            flexibleSpace: hasImage
                ? FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          widget.item['thumbnailUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.7),
                                Colors.black.withValues(alpha: 0.25),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.4, 0.7],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
            actions: [
              IconButton(
                onPressed: _toggleArchive,
                style: IconButton.styleFrom(
                  backgroundColor: actionBackground,
                  foregroundColor: actionForeground,
                ),
                icon: Icon(
                  _status == 'archived'
                      ? CupertinoIcons.archivebox_fill
                      : CupertinoIcons.archivebox,
                ),
              ),
              IconButton(
                onPressed: _shareItem,
                style: IconButton.styleFrom(
                  backgroundColor: actionBackground,
                  foregroundColor: actionForeground,
                ),
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
                  style: IconButton.styleFrom(
                    backgroundColor: actionBackground,
                    foregroundColor: actionForeground,
                  ),
                  icon: const Icon(CupertinoIcons.trash),
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Text(
                      (widget.item['type'] as String? ?? '').toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _showEditPrioritySheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(
                            _priority,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getPriorityColor(_priority),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _priority.toUpperCase(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: _getPriorityColor(_priority),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.chevron_down,
                              size: 12,
                              color: _getPriorityColor(_priority),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showStatusPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            _status,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(_status),
                              size: 14,
                              color: _getStatusColor(_status),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getStatusLabel(_status).toUpperCase(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: _getStatusColor(_status),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.chevron_down,
                              size: 12,
                              color: _getStatusColor(_status),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.item['title'] ?? 'No Title',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                _MetaRow(
                  icon: CupertinoIcons.link,
                  text: widget.item['url'] ?? '',
                  onTap: () => _launchUrl(context),
                  isLink: true,
                ),
                const SizedBox(height: 16),
                _MetaRow(
                  icon: CupertinoIcons.calendar,
                  text:
                      'Added ${widget.item['createdAt'] != null ? _formatDate(widget.item['createdAt'] as int) : ''}',
                ),
                const SizedBox(height: 16),
                if (widget.item['estimatedReadTime'] != null)
                  _MetaRow(
                    icon: CupertinoIcons.time,
                    text: '${widget.item['estimatedReadTime']} min read',
                  ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _showEditTagsSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.tag,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTagsPreview()),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _launchUrl(context),
                  icon: const Icon(CupertinoIcons.compass, size: 20),
                  label: const Text(
                    'Open Original',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 100),
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
                decoration: null,
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
