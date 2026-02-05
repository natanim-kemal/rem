import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rem/core/services/metadata_service.dart';
import '../theme/app_theme.dart';

class AddItemSheet extends StatefulWidget {
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
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _metadataService = MetadataService();
  
  String _selectedType = 'link';
  String _selectedPriority = 'medium';
  bool _isLoadingMetadata = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      _selectedType = 'link';
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
       // We could also show thumbnail preview here
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
    super.dispose();
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
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: CupertinoButton(
                color: AppTheme.accent,
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

  void _saveItem() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item saved to vault'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
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
