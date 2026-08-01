import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/services/chat_service.dart';
import '../core/services/chat_stream_client.dart';
import '../data/database/database.dart';
import 'auth_provider.dart';
import 'data_providers.dart';

final chatStreamClientProvider = Provider<ChatStreamClient>((ref) {
  final convex = ref.watch(convexClientProvider);
  return ChatStreamClient(
    siteUrl: AppConfig.convexSiteUrl,
    tokenProvider: () => convex.authToken,
  );
});

final chatServiceProvider = Provider<ChatService>((ref) {
  final db = ref.watch(databaseProvider);
  final client = ref.watch(chatStreamClientProvider);
  return ChatService(db: db, streamClient: client);
});

final conversationProvider = FutureProvider.family<Conversation, String>((
  ref,
  itemId,
) {
  final db = ref.watch(databaseProvider);
  return db.getOrCreateConversationForItem(itemId);
});

final messagesProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  conversationId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchMessages(conversationId);
});

final itemByIdProvider = FutureProvider.family<Item?, String>((ref, itemId) {
  final db = ref.watch(databaseProvider);
  return db.getItemById(itemId);
});

class ConversationSummary {
  final Conversation conversation;
  final Item? item;
  final ChatMessage? lastMessage;

  const ConversationSummary({
    required this.conversation,
    this.item,
    this.lastMessage,
  });
}

final conversationsProvider = StreamProvider<List<ConversationSummary>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchConversations().asyncMap((conversations) async {
    final summaries = <ConversationSummary>[];
    for (final conversation in conversations) {
      summaries.add(
        ConversationSummary(
          conversation: conversation,
          item: await db.getItemById(conversation.itemId),
          lastMessage: await db.getLastMessage(conversation.id),
        ),
      );
    }
    return summaries;
  });
});
