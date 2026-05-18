import 'package:flutter/foundation.dart';
import 'package:nova3d_frontend/features/chat/data/chat_service.dart';
import 'package:nova3d_frontend/features/chat/data/conversation_local_source.dart';
import 'package:nova3d_frontend/shared/models/conversation_model.dart';

class ConversationRepository {
  const ConversationRepository(this._local, this._remote);

  final ConversationLocalSource _local;
  final ChatService _remote;

  Future<List<ConversationModel>> load() => _local.loadConversations();

  Future<void> persist(List<ConversationModel> convs) => _local.save(convs);

  Future<void> delete(String id) async {
    // Best-effort remote delete — a 404 or network error is non-fatal since
    // the conversation is already removed from the local list.
    try {
      await _remote.deleteConversation(id);
    } catch (e, st) {
      debugPrint(
        '[ConversationRepository] remote delete($id) failed: $e\n$st',
      );
    }
    await _local.deleteMessages(id);
  }
}
