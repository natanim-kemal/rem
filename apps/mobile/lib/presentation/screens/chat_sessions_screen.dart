import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_providers.dart';
import '../../providers/data_providers.dart';
import 'chat_screen.dart';

class ChatSessionsScreen extends ConsumerStatefulWidget {
  const ChatSessionsScreen({super.key});

  @override
  ConsumerState<ChatSessionsScreen> createState() => _ChatSessionsScreenState();
}

class _ChatSessionsScreenState extends ConsumerState<ChatSessionsScreen> {
  void _openNewChat(String userId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemPickerSheet(
        userId: userId,
        onSelect: (item) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatScreen(item: item)),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _itemMap(Item item) {
    return {
      'id': item.id,
      'title': item.title,
      'url': item.url,
      'type': item.type,
      'description': item.description,
      'thumbnailUrl': item.thumbnailUrl,
      'convexId': item.convexId,
      'createdAt': item.createdAt,
    };
  }

  Future<void> _confirmDelete(String conversationId) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete chat?'),
        content: const Text('This chat and its messages will be removed.'),
        actions: [
          CupertinoDialogAction(
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
    if (confirmed != true) return;
    final db = ref.read(databaseProvider);
    await db.deleteConversation(conversationId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final clerkId = authState.userId;
    if (clerkId == null) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }
    final userAsync = ref.watch(userByClerkIdProvider(clerkId));
    final user = userAsync.value;
    if (user == null) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }

    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Chat',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _openNewChat(user.id),
                    icon: const Icon(CupertinoIcons.bubble_left, size: 16),
                    label: const Text('New Chat'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: conversationsAsync.when(
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (error, _) =>
                    Center(child: Text('Failed to load chats: $error')),
                data: (conversations) => conversations.isEmpty
                    ? _EmptyChatState(onNewChat: () => _openNewChat(user.id))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        itemCount: conversations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final summary = conversations[index];
                          final item = summary.item;
                          return _ConversationTile(
                            title: item?.title ?? 'Unknown item',
                            preview: summary.lastMessage?.content,
                            isFailed: summary.lastMessage?.status == 'failed',
                            onDelete: () =>
                                _confirmDelete(summary.conversation.id),
                            onTap: item == null
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ChatScreen(item: _itemMap(item)),
                                      ),
                                    );
                                  },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  final VoidCallback onNewChat;

  const _EmptyChatState({required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.bubble_left,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Chat with your saved items',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Pick an item and ask questions about it',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onNewChat,
              icon: const Icon(CupertinoIcons.bubble_left, size: 16),
              label: const Text('New Chat'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String title;
  final String? preview;
  final bool isFailed;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _ConversationTile({
    required this.title,
    this.preview,
    this.isFailed = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFailed && (preview == null || preview!.isEmpty)
                          ? 'Failed message — tap to retry'
                          : (preview ?? 'No messages yet'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isFailed
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                PopupMenuButton<String>(
                  icon: Icon(
                    CupertinoIcons.ellipsis,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') onDelete!();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.trash,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemPickerSheet extends ConsumerWidget {
  final String userId;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _ItemPickerSheet({required this.userId, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(itemsProvider(userId));
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Choose an item to chat about',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (error, _) =>
                  Center(child: Text('Failed to load items: $error')),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No items saved yet.'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          leading: Icon(
                            CupertinoIcons.doc_text,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(item.type),
                          onTap: () => onSelect({
                            'id': item.id,
                            'title': item.title,
                            'url': item.url,
                            'type': item.type,
                            'description': item.description,
                            'thumbnailUrl': item.thumbnailUrl,
                            'convexId': item.convexId,
                            'createdAt': item.createdAt,
                          }),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
