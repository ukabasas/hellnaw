import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nova3d_frontend/core/errors.dart';
import 'package:nova3d_frontend/shared/models/conversation_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kConversationsKey = 'local_conversations';
const _kMessagesPrefix = 'local_messages_';

class ConversationLocalSource {
  Future<List<ConversationModel>> loadConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kConversationsKey);
      if (raw == null) return [];
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ConversationModel.fromJson)
          .toList();
    } catch (e, st) {
      debugPrint('[ConversationLocalSource] load failed: $e\n$st');
      throw AppError(
        'Failed to load conversations from storage.',
        kind: AppErrorKind.persistence,
        cause: e,
      );
    }
  }

  Future<void> save(List<ConversationModel> convs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kConversationsKey,
        json.encode(convs.map((c) => c.toJson()).toList()),
      );
    } catch (e, st) {
      debugPrint('[ConversationLocalSource] save failed: $e\n$st');
      throw AppError(
        'Failed to persist conversations.',
        kind: AppErrorKind.persistence,
        cause: e,
      );
    }
  }

  // Non-fatal cleanup — orphaned message data in storage is acceptable.
  Future<void> deleteMessages(String convId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kMessagesPrefix$convId');
    } catch (e, st) {
      debugPrint(
        '[ConversationLocalSource] deleteMessages($convId) failed: $e\n$st',
      );
    }
  }
}
