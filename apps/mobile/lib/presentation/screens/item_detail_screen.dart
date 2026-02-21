import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:rem/providers/data_providers.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'web_view_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/confirmation_snackbar.dart';
import '../../models/content_block.dart';
import '../../core/services/metadata_service.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  bool _isDeleting = false;
  bool _isLoadingContent = false;
  List<ContentBlock> _loadedContent = [];

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
        return const Color(0xFF1A8A6E);
      case 'medium':
        return const Color(0xFF2FBF9A);
      case 'low':
        return const Color(0xFF7DDBC4);
      default:
        return const Color(0xFF2FBF9A);
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
        title: Column(
          children: [
            const Text('Delete Item'),
            const SizedBox(height: 8),
            Divider(color: CupertinoColors.separator.resolveFrom(context)),
          ],
        ),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Are you sure you want to delete this item? This action cannot be undone.',
          ),
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

  bool _isXUrl(String url) {
    return url.contains('x.com') || url.contains('twitter.com');
  }

  String? _extractXPostText(String? html) {
    if (html == null || html.isEmpty) return null;
    final match = RegExp(r'<p[^>]*>([\s\S]*?)</p>').firstMatch(html);
    if (match == null) return null;
    final raw = match.group(1) ?? '';
    final noTags = raw.replaceAll(RegExp(r'<[^>]+>'), ' ');
    return noTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _loadXContent(String url) async {
    try {
      final metadataService = MetadataService();
      final xEmbed = await metadataService.fetchXOEmbed(url);

      if (!mounted) return;

      if (xEmbed?.html != null) {
        final extractedText = _extractXPostText(xEmbed!.html);
        if (extractedText != null && extractedText.isNotEmpty) {
          setState(() {
            _loadedContent = [
              ContentBlock(
                type: ContentBlockType.paragraph,
                content: extractedText,
              ),
            ];
            _isLoadingContent = false;
          });
          return;
        }
      }

      _showUnableToExtract();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingContent = false);
        _showUnableToExtract();
      }
    }
  }

  void _showUnableToExtract() {
    setState(() {
      _loadedContent = [
        ContentBlock(
          type: ContentBlockType.paragraph,
          content:
              'Unable to extract content from this page. Please open the original link.',
        ),
      ];
      _isLoadingContent = false;
    });
  }

  Future<void> _loadContent() async {
    final url = widget.item['url'] as String?;
    if (url == null || url.isEmpty) {
      if (mounted) {
        showWarningSnackBar(context, 'No URL to load content from');
      }
      return;
    }

    setState(() => _isLoadingContent = true);

    if (_isXUrl(url)) {
      await _loadXContent(url);
      return;
    }

    bool isTimedOut = false;

    try {
      final dio = Dio();

      final response = await Future.any([
        dio.get(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.9',
              'Accept-Encoding': 'gzip, deflate',
              'Cache-Control': 'no-cache',
              'Connection': 'keep-alive',
              'Pragma': 'no-cache',
              'Upgrade-Insecure-Requests': '1',
            },
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
          ),
        ),
        Future.delayed(const Duration(seconds: 20), () {
          isTimedOut = true;
          throw Exception('Timeout');
        }),
      ]);

      if (isTimedOut) {
        if (mounted) {
          setState(() => _isLoadingContent = false);
          _showUnableToExtract();
        }
        return;
      }

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data as String;

        final fallbackContent = _extractTextFromHtmlFallback(html);

        List<ContentBlock> content;
        if (fallbackContent.isNotEmpty) {
          content = [
            ContentBlock(
              type: ContentBlockType.paragraph,
              content: fallbackContent,
            ),
          ];
        } else if (widget.item['content'] != null &&
            (widget.item['content'] as String).isNotEmpty) {
          content = [
            ContentBlock(
              type: ContentBlockType.paragraph,
              content: widget.item['content'] as String,
            ),
          ];
        } else {
          content = [
            ContentBlock(
              type: ContentBlockType.paragraph,
              content:
                  'Unable to extract content from this page. Please open the original link.',
            ),
          ];
        }

        if (mounted) {
          setState(() {
            _loadedContent = content;
            _isLoadingContent = false;
          });
          _updateReadTimeFromContent(content);
        }
      } else {
        throw Exception('Failed to fetch content: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isLoadingContent = false);
        if (e.response?.statusCode == 403) {
          _showUnableToExtract();
          return;
        }
        String errorMessage = 'Failed to load content';
        if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage = 'Connection timed out';
        } else if (e.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'Server took too long to respond';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage = 'No internet connection';
        }
        showWarningSnackBar(context, '$errorMessage: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingContent = false);
        if (isTimedOut) {
          _showUnableToExtract();
        } else {
          showWarningSnackBar(context, 'Failed to load content: $e');
        }
      }
    }
  }

  Future<void> _updateReadTimeFromContent(List<ContentBlock> content) async {
    if (content.isEmpty) return;

    final isExtractionFailed =
        content.length == 1 &&
        content.first.content ==
            'Unable to extract content from this page. Please open the original link.';
    if (isExtractionFailed) return;

    final textContent = content
        .where((block) => block.type == ContentBlockType.paragraph)
        .map((block) => block.content)
        .join(' ');

    if (textContent.trim().isEmpty) return;

    final wordCount = textContent.split(RegExp(r'\s+')).length;
    final readTime = (wordCount / 225).ceil();

    final currentReadTime = widget.item['estimatedReadTime'] as int?;
    if (currentReadTime != readTime) {
      final syncEngine = ref.read(syncEngineProvider);
      await syncEngine.updateItemReadTime(
        widget.item['id'] as String,
        readTime,
      );
    }
  }

  String _extractTextFromHtmlFallback(String html) {
    String text = html.replaceAll(
      RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<header[^>]*>[\s\S]*?</header>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<footer[^>]*>[\s\S]*?</footer>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<nav[^>]*>[\s\S]*?</nav>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<aside[^>]*>[\s\S]*?</aside>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<iframe[^>]*>[\s\S]*?</iframe>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

    text = text.replaceAll(
      RegExp(r'<(p|div|h[1-6])[^>]*>', caseSensitive: false),
      '\n\n',
    );
    text = text.replaceAll(RegExp(r'<br[^>]*>', caseSensitive: false), '\n');
    text = text.replaceAll(
      RegExp(r'</(p|div|h[1-6]|li|tr)[^>]*>', caseSensitive: false),
      '\n',
    );
    text = text.replaceAll(RegExp(r'</li[^>]*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ');

    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll('&apos;', "'");
    text = text.replaceAll('&mdash;', '—');
    text = text.replaceAll('&ndash;', '–');
    text = text.replaceAll('&hellip;', '...');

    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '');
      if (code != null) {
        return String.fromCharCode(code);
      }
      return match.group(0) ?? '';
    });

    text = text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '', radix: 16);
      if (code != null) {
        return String.fromCharCode(code);
      }
      return match.group(0) ?? '';
    });

    text = text.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'•\s*\n'), '\n');
    text = text.replaceAll(RegExp(r'\n\s*•\s*\n'), '\n');
    text = text.replaceAll(RegExp(r'^\s*•\s*\n', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*•\s*$', multiLine: true), '');
    return text.trim();
  }

  void _showEditPrioritySheet() {
    final theme = Theme.of(context);
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
                      color: Color(0xFF1A8A6E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'High',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  if (_priority == 'high') ...[
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.checkmark,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
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
                      color: Color(0xFF2FBF9A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Medium',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  if (_priority == 'medium') ...[
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.checkmark,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
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
                      color: Color(0xFF7DDBC4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Low',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  if (_priority == 'low') ...[
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.checkmark,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
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
    final theme = Theme.of(context);
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
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              _getStatusLabel(status),
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.checkmark,
                size: 16,
                color: theme.colorScheme.primary,
              ),
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

    final url = widget.item['url'] as String? ?? '';
    final isXUrl = url.contains('x.com') || url.contains('twitter.com');
    final hasImage = widget.item['thumbnailUrl'] != null || isXUrl;

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
                        if (widget.item['thumbnailUrl'] != null)
                          CachedNetworkImage(
                            imageUrl: widget.item['thumbnailUrl'] as String,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                            errorWidget: (context, url, error) =>
                                _buildDefaultImage(theme, isXUrl),
                          )
                        else if (isXUrl)
                          _buildDefaultImage(theme, isXUrl),
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
                _MetaRow(
                  icon: CupertinoIcons.time,
                  text: '${widget.item['estimatedReadTime'] ?? 0} min read',
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
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _launchUrl(context),
                        icon: const Icon(CupertinoIcons.compass, size: 16),
                        label: const Text(
                          'Open Original',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(180, 40),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () {
                          final url = widget.item['url'] as String?;
                          final title =
                              widget.item['title'] as String? ?? 'Content';
                          if (url != null && url.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    WebViewScreen(url: url, title: title),
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          CupertinoIcons.arrow_down_circle,
                          size: 16,
                          color: Colors.black,
                        ),
                        label: const Text(
                          'Load Content',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(180, 40),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loadedContent.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.doc_text,
                              size: 18,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.9,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Content',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildContentList(theme),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentList(ThemeData theme) {
    if (_loadedContent.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _loadedContent.length,
      itemBuilder: (context, index) {
        return _buildContentBlock(theme, _loadedContent[index]);
      },
    );
  }

  Widget _buildContentBlock(ThemeData theme, ContentBlock block) {
    switch (block.type) {
      case ContentBlockType.heading1:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 8),
          child: Text(
            block.content,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
        );
      case ContentBlockType.heading2:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8),
          child: Text(
            block.content,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
        );
      case ContentBlockType.heading3:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            block.content,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
        );
      case ContentBlockType.image:
        if (block.imageUrl == null || block.imageUrl!.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: GestureDetector(
            onTap: () => _showFullScreenImage(context, block.imageUrl!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 400),
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: block.imageUrl!,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) =>
                      _buildImageError(theme, block.imageUrl!),
                ),
              ),
            ),
          ),
        );
      case ContentBlockType.listItem:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: theme.textTheme.bodyMedium),
              Expanded(
                child: Text(block.content, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        );
      case ContentBlockType.paragraph:
      default:
        final isExtractionFailed =
            block.content ==
            'Unable to extract content from this page. Please open the original link.';
        if (isExtractionFailed) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  CupertinoIcons.info_circle,
                  color: Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    block.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTextWithLinks(theme, block.content),
        );
    }
  }

  Widget _buildTextWithLinks(ThemeData theme, String text) {
    final urlPattern = RegExp(r'https?://[^\s<>"{}|\\^`\[\]]+');
    final matches = urlPattern.allMatches(text).toList();

    if (matches.isEmpty) {
      return SelectableText(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
      );
    }

    final List<InlineSpan> spans = [];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final url = match.group(0) ?? '';
      spans.add(
        WidgetSpan(
          child: GestureDetector(
            onTap: () => _openUrl(url),
            child: Text(
              url,
              style: TextStyle(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildImageError(ThemeData theme, String imageUrl) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.photo,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'Image failed to load',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _openUrl(imageUrl),
              child: Text(
                'Open in browser',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext ctx, String imageUrl) {
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(CupertinoIcons.share),
                onPressed: () =>
                    SharePlus.instance.share(ShareParams(text: imageUrl)),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.arrow_up_square),
                onPressed: () => _openUrl(imageUrl),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultImage(ThemeData theme, bool isXUrl) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: isXUrl
            ? Image.asset(
                'assets/images/x-img.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/images/fallback.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              )
            : Image.asset(
                'assets/images/fallback.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
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
