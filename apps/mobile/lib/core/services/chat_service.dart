import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/database.dart';
import 'chat_stream_client.dart';

class ChatService {
  final AppDatabase db;
  final ChatStreamClient streamClient;

  ChatService({required this.db, required this.streamClient});

  String? _streamingMessageId;
  String? _activeConversationId;
  final StringBuffer _buffer = StringBuffer();
  bool _cancelRequested = false;
  StreamSubscription<String>? _activeSubscription;
  Completer<void>? _activeCompleter;
  final List<Future<int>> _pendingWrites = [];
  int _lastTimestamp = 0;

  int _nowMs() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = now > _lastTimestamp ? now : _lastTimestamp + 1;
    _lastTimestamp = next;
    return next;
  }

  bool get isStreaming => _streamingMessageId != null;

  Future<Conversation> getOrCreateConversation(String itemId) {
    return db.getOrCreateConversationForItem(itemId);
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return db.watchMessages(conversationId);
  }

  Future<void> sendMessage({
    required String conversationId,
    required String itemId,
    required String text,
    String? modelId,
    bool webSearch = false,
  }) async {
    if (isStreaming) return;
    await db.insertMessage(
      ChatMessagesCompanion.insert(
        id: const Uuid().v4(),
        conversationId: conversationId,
        role: 'user',
        content: text,
        createdAt: _nowMs(),
      ),
    );
    await db.touchConversation(conversationId);
    await _streamAssistantReply(
      conversationId: conversationId,
      itemId: itemId,
      modelId: modelId,
      webSearch: webSearch,
    );
  }

  Future<void> retryLast({
    required String conversationId,
    required String itemId,
    String? modelId,
    bool webSearch = false,
  }) async {
    if (isStreaming) return;
    final recent = await db.getLastMessages(conversationId, limit: 10);
    final failed = recent
        .where((m) => m.role == 'assistant' && m.status == 'failed')
        .firstOrNull;
    if (failed == null) return;
    await db.deleteMessage(failed.id);
    await _streamAssistantReply(
      conversationId: conversationId,
      itemId: itemId,
      modelId: modelId,
      webSearch: webSearch,
    );
  }

  Future<void> stopStreaming() async {
    _cancelRequested = true;
    await _activeSubscription?.cancel();
    _activeSubscription = null;
    final id = _streamingMessageId;
    _streamingMessageId = null;
    if (id != null) {
      final content = _buffer.isEmpty ? 'Stopped.' : _buffer.toString();
      _buffer.clear();
      if (_pendingWrites.isNotEmpty) {
        await Future.wait(_pendingWrites);
        _pendingWrites.clear();
      }
      await db.updateMessage(id, content: content, status: 'failed');
      final conversationId = _activeConversationId;
      if (conversationId != null) {
        await db.touchConversation(conversationId);
      }
    }
    _activeConversationId = null;
    _activeCompleter?.complete();
    _activeCompleter = null;
  }

  Future<void> _streamAssistantReply({
    required String conversationId,
    required String itemId,
    String? modelId,
    bool webSearch = false,
  }) async {
    final assistantId = const Uuid().v4();
    await db.insertMessage(
      ChatMessagesCompanion.insert(
        id: assistantId,
        conversationId: conversationId,
        role: 'assistant',
        content: '',
        status: const Value('streaming'),
        createdAt: _nowMs(),
      ),
    );

    final history = await db.getLastMessages(conversationId, limit: 20);
    final historyPayload = history
        .where((m) => m.id != assistantId && m.status != 'failed')
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    _streamingMessageId = assistantId;
    _activeConversationId = conversationId;
    _cancelRequested = false;
    _buffer.clear();

    final completer = Completer<void>();
    _activeCompleter = completer;

    final ChatStreamResult result;
    try {
      result = await streamClient.streamCompletions(
        itemId: itemId,
        history: historyPayload,
        modelId: modelId,
        webSearch: webSearch,
      );
    } catch (_) {
      await _finalize(
        assistantId,
        conversationId,
        failed: true,
        fallback: 'Failed to reach chat service. Try again.',
      );
      return;
    }

    if (_streamingMessageId != assistantId) return;

    if (result.statusCode != 200) {
      await _finalize(
        assistantId,
        conversationId,
        failed: true,
        fallback: result.errorMessage ?? 'Failed to get a response.',
      );
      return;
    }

    final subscription = result.tokens.listen(
      (token) {
        _buffer.write(token);
        _pendingWrites.add(
          db.updateMessage(
            assistantId,
            content: _buffer.toString(),
            status: 'streaming',
          ),
        );
      },
      onError: (Object _) {
        _finalize(
          assistantId,
          conversationId,
          failed: true,
          fallback: 'The stream was interrupted. Try again.',
        );
      },
      onDone: () {
        _finalize(
          assistantId,
          conversationId,
          failed: _cancelRequested,
          fallback: 'Stopped.',
        );
      },
    );
    _activeSubscription = subscription;

    await completer.future;
    _activeCompleter = null;
  }

  Future<void> _finalize(
    String assistantId,
    String conversationId, {
    required bool failed,
    String? fallback,
  }) async {
    if (_streamingMessageId != assistantId) return;
    _streamingMessageId = null;
    _activeSubscription = null;
    final content = _buffer.isEmpty ? (fallback ?? '') : _buffer.toString();
    _buffer.clear();
    _activeConversationId = null;
    if (_pendingWrites.isNotEmpty) {
      await Future.wait(_pendingWrites);
      _pendingWrites.clear();
    }
    await db.updateMessage(
      assistantId,
      content: content,
      status: failed ? 'failed' : 'complete',
    );
    await db.touchConversation(conversationId);
    _activeCompleter?.complete();
    _activeCompleter = null;
  }
}
