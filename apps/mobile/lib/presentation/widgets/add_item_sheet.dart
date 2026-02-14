import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'confirmation_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rem/core/services/metadata_service.dart';
import 'package:rem/data/sync/sync_engine.dart';
import 'package:rem/providers/auth_provider.dart';
import 'package:rem/providers/data_providers.dart';
import '../theme/app_theme.dart';

class AddItemSheet extends ConsumerStatefulWidget {
  final String? initialUrl;
  final String? initialTitle;
  final List<String>? initialFiles;

  const AddItemSheet({
    super.key,
    this.initialUrl,
    this.initialTitle,
    this.initialFiles,
  });

  @override
  ConsumerState<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<AddItemSheet> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _tagController = TextEditingController();
  final _metadataService = MetadataService();

  String _selectedType = 'link';
  String _selectedPriority = 'medium';
  bool _isLoadingMetadata = false;
  File? _selectedImage;
  String? _thumbnailUrl;
  final List<String> _tags = [];
  final FocusNode _tagFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      _selectedType = _isVideoUrl(widget.initialUrl!) ? 'video' : 'link';
      _fetchMetadata();
    }
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialFiles != null && widget.initialFiles!.isNotEmpty) {
      _selectedImage = File(widget.initialFiles!.first);
      _selectedType = 'image';
    }
  }

  Future<void> _fetchMetadata() async {
    final url = _urlController.text;
    if (url.isEmpty) return;

    setState(() => _isLoadingMetadata = true);
    final metadata = await _metadataService.fetchMetadata(url);
    final isTikTok = _isTikTokUrl(url);
    final isX = _isXUrl(url);
    final tiktokMetadata = isTikTok
        ? await _metadataService.fetchTikTokOEmbed(url)
        : null;
    final xMetadata = isX ? await _metadataService.fetchXOEmbed(url) : null;
    if (!mounted) {
      return;
    }

    final metadataTitle = metadata?.title;
    final metadataImage = metadata?.image;

    if (_titleController.text.isEmpty) {
      String? title;
      if (isTikTok) {
        final tiktokTitle = tiktokMetadata?.title;
        title = (tiktokTitle != null && tiktokTitle.isNotEmpty)
            ? tiktokTitle
            : metadataTitle;
      } else if (isX) {
        title = _pickXTitle(
          metadataTitle,
          metadata?.description,
          xMetadata?.html,
        );
      } else {
        title = metadataTitle;
      }

      if (title != null && title.isNotEmpty && !_isGenericTitle(title, isX)) {
        final cleanedTitle = _stripHashtags(title);
        if (cleanedTitle.isNotEmpty) {
          _titleController.text = cleanedTitle;
        }
      }
    }

    if (_thumbnailUrl == null || _thumbnailUrl!.isEmpty) {
      String? thumbnail;
      if (isX) {
        thumbnail = _extractXImageUrl(xMetadata?.html);
      } else {
        thumbnail = metadataImage?.isNotEmpty == true
            ? metadataImage
            : tiktokMetadata?.thumbnailUrl;
      }
      if (thumbnail != null && thumbnail.isNotEmpty) {
        setState(() {
          _thumbnailUrl = thumbnail;
        });
      }
    }

    if (_selectedType == 'link' && _isVideoUrl(url)) {
      setState(() {
        _selectedType = 'video';
      });
    }
    setState(() => _isLoadingMetadata = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _selectedType = 'image';
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _tagController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim().toLowerCase();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add Item', style: theme.textTheme.headlineSmall),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_selectedType == 'image') ...[
              Text('Image', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    image: _selectedImage != null
                        ? DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.camera,
                              size: 32,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to select image',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Text('URL', style: theme.textTheme.labelLarge),
                  if (_isLoadingMetadata) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CupertinoActivityIndicator(radius: 6),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                autofocus: widget.initialUrl == null,
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _fetchMetadata(),
                decoration: const InputDecoration(
                  hintText: 'https://...',
                  prefixIcon: Icon(CupertinoIcons.link, size: 20),
                ),
              ),
            ],
            const SizedBox(height: 20),

            Text('Title (optional)', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'Custom title...'),
            ),
            const SizedBox(height: 20),

            Text('Type', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                _TypeChip(
                  icon: CupertinoIcons.link,
                  label: 'Link',
                  isSelected: _selectedType == 'link',
                  onTap: () => setState(() => _selectedType = 'link'),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  icon: CupertinoIcons.photo,
                  label: 'Image',
                  isSelected: _selectedType == 'image',
                  onTap: () => setState(() => _selectedType = 'image'),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  icon: CupertinoIcons.play_circle,
                  label: 'Video',
                  isSelected: _selectedType == 'video',
                  onTap: () => setState(() => _selectedType = 'video'),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  icon: CupertinoIcons.book,
                  label: 'Book',
                  isSelected: _selectedType == 'book',
                  onTap: () => setState(() => _selectedType = 'book'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text('Priority', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                _PriorityChip(
                  color: const Color(0xFF1A8A6E),
                  label: 'High',
                  isSelected: _selectedPriority == 'high',
                  onTap: () => setState(() => _selectedPriority = 'high'),
                ),
                const SizedBox(width: 8),
                _PriorityChip(
                  color: const Color(0xFF2FBF9A),
                  label: 'Medium',
                  isSelected: _selectedPriority == 'medium',
                  onTap: () => setState(() => _selectedPriority = 'medium'),
                ),
                const SizedBox(width: 8),
                _PriorityChip(
                  color: const Color(0xFF7DDBC4),
                  label: 'Low',
                  isSelected: _selectedPriority == 'low',
                  onTap: () => setState(() => _selectedPriority = 'low'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text('Tags', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    focusNode: _tagFocusNode,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    spellCheckConfiguration:
                        const SpellCheckConfiguration.disabled(),
                    onSubmitted: (_) => _addTag(),
                    decoration: const InputDecoration(
                      hintText: 'Add a tag...',
                      prefixIcon: Icon(CupertinoIcons.tag, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  onPressed: _addTag,
                  child: const Icon(
                    CupertinoIcons.add,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(CupertinoIcons.xmark, size: 16),
                    onDeleted: () => _removeTag(tag),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    side: BorderSide(color: theme.colorScheme.outline),
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: CupertinoButton(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                onPressed: _saveItem,
                child: const Text(
                  'Save to Vault',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveItem() async {
    final url = _urlController.text.trim();
    final title = _titleController.text.trim();

    if (title.isEmpty && url.isEmpty && _selectedImage == null) {
      showWarningSnackBar(context, 'Please enter a URL or select an image');
      return;
    }

    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated || authState.userId == null) {
      showWarningSnackBar(context, 'Please sign in to save items');
      return;
    }

    final syncEngine = ref.read(syncEngineProvider);
    final resolvedType = _selectedType == 'link' && _isVideoUrl(url)
        ? 'video'
        : _selectedType;

    try {
      String? localImagePath;
      if (_selectedImage != null) {
        localImagePath = _selectedImage!.path;
      }

      await syncEngine.createItem(
        userId: authState.userId!,
        type: resolvedType,
        title: title.isNotEmpty ? title : (url.isNotEmpty ? url : 'Image'),
        url: url.isNotEmpty ? url : null,
        localPath: (resolvedType == 'image' || resolvedType == 'book')
            ? localImagePath
            : null,
        description: null,
        thumbnailUrl: _thumbnailUrl,
        priority: _selectedPriority,
        tags: _tags,
      );

      if (mounted) {
        ref.read(homeRefreshProvider.notifier).bump();
        Navigator.pop(context);
        showConfirmationSnackBar(context, 'Saved to vault');
      }
    } on DuplicateItemException {
      if (mounted) {
        showWarningSnackBar(
          context,
          'This item already exists in your vault',
          actionLabel: 'View',
          onAction: () {
            Navigator.pop(context);
          },
        );
      }
    } catch (e) {
      if (mounted) {
        showWarningSnackBar(context, 'Failed to save item: $e');
      }
    }
  }

  bool _isYouTubeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    var uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      uri = Uri.tryParse('https://$trimmed');
    }
    final host = uri?.host.toLowerCase() ?? '';
    return host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtu.be' ||
        host.endsWith('.youtu.be');
  }

  bool _isTikTokUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    var uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      uri = Uri.tryParse('https://$trimmed');
    }
    final host = uri?.host.toLowerCase() ?? '';
    return host == 'tiktok.com' ||
        host.endsWith('.tiktok.com') ||
        host == 'vm.tiktok.com' ||
        host == 'vt.tiktok.com';
  }

  bool _isXUrl(String url) {
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

  bool _isVideoUrl(String url) {
    return _isYouTubeUrl(url) || _isTikTokUrl(url);
  }

  bool _isGenericTitle(String title, bool isX) {
    final normalized = title.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (normalized == 'tiktok - make your day' ||
        normalized == 'tiktok' ||
        normalized == 'make your day') {
      return true;
    }
    if (isX && _isGenericXTitle(normalized)) {
      return true;
    }
    return false;
  }

  bool _isGenericXTitle(String normalizedTitle) {
    return normalizedTitle == 'x' ||
        normalizedTitle == 'twitter' ||
        normalizedTitle == 'x / twitter' ||
        normalizedTitle == 'twitter / x';
  }

  String? _pickXTitle(String? title, String? description, String? html) {
    final trimmedTitle = title?.trim() ?? '';
    if (trimmedTitle.isNotEmpty &&
        !_isGenericXTitle(trimmedTitle.toLowerCase())) {
      return trimmedTitle;
    }
    final htmlText = _extractXPostText(html);
    if (htmlText != null && htmlText.isNotEmpty) {
      return _takeWords(htmlText, 5);
    }
    final trimmedDescription = description?.trim() ?? '';
    if (trimmedDescription.isEmpty) return null;
    return _takeWords(trimmedDescription, 5);
  }

  String? _extractXPostText(String? html) {
    if (html == null || html.isEmpty) return null;
    final match = RegExp(r'<p[^>]*>([\s\S]*?)</p>').firstMatch(html);
    if (match == null) return null;
    final raw = match.group(1) ?? '';
    final noTags = raw.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final normalized = noTags.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  String? _extractXImageUrl(String? html) {
    if (html == null || html.isEmpty) return null;
    final match = RegExp(
      "<img[^>]+src=['\\\"]([^'\\\"]+)['\\\"]",
    ).firstMatch(html);
    return match?.group(1);
  }

  String _takeWords(String text, int count) {
    final words = text.split(RegExp(r'\s+'));
    final limit = words.length < count ? words.length : count;
    return words.take(limit).join(' ').trim();
  }

  String _stripHashtags(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    final kept = parts.where((part) => !part.startsWith('#')).toList();
    return kept.join(' ').trim();
  }
}

class _TypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.outline,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : theme.colorScheme.outline,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? color
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
