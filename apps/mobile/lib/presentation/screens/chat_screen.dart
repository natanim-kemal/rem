import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/database/database.dart';
import '../../providers/chat_providers.dart';
import '../widgets/confirmation_snackbar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;

  const ChatScreen({super.key, required this.item});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  int _lastCount = 0;
  int _lastChars = 0;

  String get _itemId => widget.item['id'] as String? ?? '';

  String get _serverItemId =>
      widget.item['convexId'] as String? ?? widget.item['id'] as String? ?? '';

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(Conversation conversation) async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    final modelId = ref.read(modelSelectionProvider);
    final webSearch = ref.read(webSearchProvider);
    await ref
        .read(chatServiceProvider)
        .sendMessage(
          conversationId: conversation.id,
          itemId: _serverItemId,
          text: text,
          modelId: modelId?.isEmpty == true ? null : modelId,
          webSearch: webSearch,
        );
  }

  Future<void> _stop() async {
    await ref.read(chatServiceProvider).stopStreaming();
  }

  Future<void> _retry(Conversation conversation) async {
    final modelId = ref.read(modelSelectionProvider);
    final webSearch = ref.read(webSearchProvider);
    await ref
        .read(chatServiceProvider)
        .retryLast(
          conversationId: conversation.id,
          itemId: _serverItemId,
          modelId: modelId?.isEmpty == true ? null : modelId,
          webSearch: webSearch,
        );
  }

  void _showModelsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => const _ModelsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conversationAsync = ref.watch(conversationProvider(_itemId));
    final itemAsync = ref.watch(itemByIdProvider(_itemId));
    final itemDeleted = itemAsync.value == null;
    final conversation = conversationAsync.value;
    final messagesAsync = conversation == null
        ? null
        : ref.watch(messagesProvider(conversation.id));
    final messages = messagesAsync?.value ?? const <ChatMessage>[];
    final isStreaming = messages.any((m) => m.status == 'streaming');
    final service = ref.watch(chatServiceProvider);
    final streamingNow = isStreaming || service.isStreaming;

    final totalChars = messages.fold<int>(
      0,
      (sum, message) => sum + message.content.length,
    );
    if (messages.length != _lastCount || totalChars != _lastChars) {
      _lastCount = messages.length;
      _lastChars = totalChars;
      if (messages.isNotEmpty) {
        _scrollToBottom();
      }
    }

    if (conversationAsync.isLoading) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item['title'] ?? 'Chat',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (itemDeleted)
              Text(
                'Item deleted. History is still readable.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showModelsSheet,
            tooltip: 'Models',
            icon: const Icon(CupertinoIcons.slider_horizontal_3),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return _MessageBubble(
                    message: message,
                    onRetry: conversation == null
                        ? null
                        : () => _retry(conversation),
                  );
                },
              ),
            ),
            if (!itemDeleted && conversation != null)
              _InputBar(
                enabled: !streamingNow,
                textController: _input,
                onSend: () => _send(conversation),
                onStop: _stop,
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const _MessageBubble({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == 'user';
    final isStreaming = message.status == 'streaming';
    final isFailed = message.status == 'failed';
    final bubbleColor = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: isStreaming && message.content.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: CupertinoActivityIndicator(),
                  )
                : isUser
                ? Text(
                    message.content,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  )
                : MarkdownBody(
                    data: message.content,
                    onTapLink: (text, href, title) {
                      final uri = Uri.tryParse(href ?? '');
                      if (uri != null && uri.hasScheme) {
                        launchUrl(uri);
                      }
                    },
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: textColor,
                      ),
                      a: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
          ),
          if (!isUser && message.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: message.content));
                  if (!context.mounted) return;
                  showConfirmationSnackBar(context, 'Copied');
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.doc_on_doc,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Copy',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (isFailed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Failed',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onRetry,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.arrow_clockwise,
                            size: 12,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Retry',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final bool enabled;
  final TextEditingController textController;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const _InputBar({
    required this.enabled,
    required this.textController,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: textController,
                placeholder: 'Ask about this item...',
                placeholderStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(),
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) {
                  if (enabled) onSend();
                },
              ),
            ),
            const SizedBox(width: 8),
            if (enabled)
              FilledButton(
                onPressed: onSend,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                  minimumSize: const Size(0, 0),
                ),
                child: const Icon(CupertinoIcons.paperplane, size: 18),
              )
            else
              IconButton(
                onPressed: onStop,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
                icon: Icon(
                  CupertinoIcons.stop_circle,
                  size: 22,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModelsSheet extends ConsumerWidget {
  const _ModelsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final catalogAsync = ref.watch(chatModelsProvider);
    final catalog = catalogAsync.value;
    final selected = ref.watch(modelSelectionProvider);
    final webSearch = ref.watch(webSearchProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Models', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Flexible(
              child: catalog == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto (default)'),
                          trailing: selected == null || selected.isEmpty
                              ? Icon(
                                  CupertinoIcons.check_mark,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          onTap: () => ref
                              .read(modelSelectionProvider.notifier)
                              .select(''),
                        ),
                        for (final provider in catalog.providers)
                          _ProviderSection(
                            provider: provider,
                            models: catalog.models
                                .where((m) => m.provider == provider.id)
                                .toList(),
                            selectedId: selected,
                            onSelect: (id) => ref
                                .read(modelSelectionProvider.notifier)
                                .select(id),
                          ),
                      ],
                    ),
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Search the web',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                Switch(
                  value: webSearch,
                  onChanged: (value) =>
                      ref.read(webSearchProvider.notifier).set(value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderSection extends StatelessWidget {
  final ChatProviderInfo provider;
  final List<ChatModelInfo> models;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _ProviderSection({
    required this.provider,
    required this.models,
    this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Icon(
        CupertinoIcons.sparkles,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(provider.label),
      children: [
        for (final model in models)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 32, right: 8),
            title: Text(model.label),
            trailing: selectedId == model.id
                ? Icon(
                    CupertinoIcons.check_mark,
                    size: 18,
                    color: theme.colorScheme.primary,
                  )
                : null,
            onTap: () => onSelect(model.id),
          ),
      ],
    );
  }
}
