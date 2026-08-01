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

final currentUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final convex = ref.watch(convexClientProvider);
  final result = await convex.query('users:getCurrentUser');
  if (result == null) return null;
  return result as Map<String, dynamic>;
});

class ChatProviderInfo {
  final String id;
  final String label;

  const ChatProviderInfo({required this.id, required this.label});

  factory ChatProviderInfo.fromJson(Map<String, dynamic> json) {
    return ChatProviderInfo(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class ChatModelInfo {
  final String id;
  final String label;
  final String provider;
  final bool tools;

  const ChatModelInfo({
    required this.id,
    required this.label,
    required this.provider,
    required this.tools,
  });

  factory ChatModelInfo.fromJson(Map<String, dynamic> json) {
    return ChatModelInfo(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      tools: json['tools'] as bool? ?? false,
    );
  }
}

class ChatModelCatalog {
  final List<ChatProviderInfo> providers;
  final List<ChatModelInfo> models;

  const ChatModelCatalog({required this.providers, required this.models});

  factory ChatModelCatalog.fromJson(Map<String, dynamic> json) {
    final providers = (json['providers'] as List<dynamic>? ?? const [])
        .map((e) => ChatProviderInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    final models = (json['models'] as List<dynamic>? ?? const [])
        .map((e) => ChatModelInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    return ChatModelCatalog(providers: providers, models: models);
  }
}

final chatModelsProvider = FutureProvider<ChatModelCatalog?>((ref) async {
  final convex = ref.watch(convexClientProvider);
  final result = await convex.query('chat/models:listModels');
  if (result == null) return null;
  return ChatModelCatalog.fromJson(result as Map<String, dynamic>);
});

class ModelSelectionNotifier extends Notifier<String?> {
  @override
  String? build() {
    final currentUser = ref.watch(currentUserProvider).value;
    final defaultModel = currentUser?['defaultModel'];
    return defaultModel is String ? defaultModel : null;
  }

  Future<void> select(String? modelId) async {
    final value = modelId?.isEmpty == true ? '' : modelId;
    state = value;
    final convex = ref.read(convexClientProvider);
    await convex.mutation('users:updateModelPreference', {'modelId': value});
    ref.invalidate(currentUserProvider);
  }
}

final modelSelectionProvider =
    NotifierProvider<ModelSelectionNotifier, String?>(
      ModelSelectionNotifier.new,
    );

class WebSearchNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) {
    state = value;
  }
}

final webSearchProvider = NotifierProvider<WebSearchNotifier, bool>(
  WebSearchNotifier.new,
);
