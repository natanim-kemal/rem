import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      _selectedType = _isYouTubeUrl(widget.initialUrl!) ? 'video' : 'link';
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
    if (mounted && metadata != null) {
      if (_titleController.text.isEmpty && metadata.title != null) {
        _titleController.text = metadata.title!;
      }
      if (metadata.image != null && metadata.image!.isNotEmpty) {
        setState(() {
          _thumbnailUrl = metadata.image;
        });
      }
      if (_selectedType == 'link' && _isYouTubeUrl(url)) {
        setState(() {
          _selectedType = 'video';
        });
      }
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
                      child: CircularProgressIndicator(strokeWidth: 2),
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
                  color: const Color(0xFFFF3B30),
                  label: 'High',
                  isSelected: _selectedPriority == 'high',
                  onTap: () => setState(() => _selectedPriority = 'high'),
                ),
                const SizedBox(width: 8),
                _PriorityChip(
                  color: const Color(0xFFFF9500),
                  label: 'Medium',
                  isSelected: _selectedPriority == 'medium',
                  onTap: () => setState(() => _selectedPriority = 'medium'),
                ),
                const SizedBox(width: 8),
                _PriorityChip(
                  color: const Color(0xFF34C759),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a URL or select an image'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated || authState.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save items'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final syncEngine = ref.read(syncEngineProvider);
    final resolvedType = _selectedType == 'link' && _isYouTubeUrl(url)
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
        description: null,
        thumbnailUrl: localImagePath ?? _thumbnailUrl,
        priority: _selectedPriority,
        tags: _tags,
      );

      if (mounted) {
        ref.read(homeRefreshProvider.notifier).bump();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: const Color(0xFF34C759),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Saved to vault',
                      style: TextStyle(
                        color: const Color(0xFF34C759),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.only(bottom: 40),
          ),
        );
      }
    } on DuplicateItemException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('This item already exists in your vault'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save item: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
