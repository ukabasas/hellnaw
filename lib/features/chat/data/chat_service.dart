import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:nova3d_frontend/core/constants.dart';
import 'package:nova3d_frontend/features/auth/data/auth_service.dart';
import 'package:nova3d_frontend/shared/models/conversation_model.dart';
import 'package:nova3d_frontend/shared/models/message_model.dart';

class ChatService {
  final AuthService _auth;
  late final Dio _dio;

  ChatService(this._auth) {
    _dio = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
    ));
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth.getToken();
    if (token == null) throw AuthException('Not authenticated');
    return {'Authorization': 'Bearer $token'};
  }

  // ── Conversations ─────────────────────────────────────────────────────────

  Future<List<ConversationModel>> getConversations() async {
    final headers = await _authHeaders();
    final resp = await _dio.get('/conversations',
        options: Options(headers: headers));
    final list = resp.data as List<dynamic>;
    return list
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ConversationModel> createConversation(String firstMessage) async {
    final headers = await _authHeaders();
    final resp = await _dio.post(
      '/conversations',
      data: {'title': firstMessage.length > 50
          ? '${firstMessage.substring(0, 50)}…'
          : firstMessage},
      options: Options(headers: headers),
    );
    return ConversationModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteConversation(String id) async {
    final headers = await _authHeaders();
    await _dio.delete('/conversations/$id',
        options: Options(headers: headers));
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<List<MessageModel>> getMessages(String conversationId) async {
    final headers = await _authHeaders();
    final resp = await _dio.get('/conversations/$conversationId/messages',
        options: Options(headers: headers));
    final list = resp.data as List<dynamic>;
    return list
        .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Streaming send ────────────────────────────────────────────────────────
  // Yields partial MessageModel updates as the server streams JSON lines.
  Stream<MessageModel> sendMessage(
    String conversationId,
    String text,
  ) async* {
    final token = await _auth.getToken();
    if (token == null) throw AuthException('Not authenticated');

    final client = Dio(BaseOptions(baseUrl: kApiBaseUrl));
    final placeholder = MessageModel(
      id: 'streaming',
      role: MessageRole.assistant,
      text: '',
      createdAt: DateTime.now(),
      isStreaming: true,
    );
    yield placeholder;

    final response = await client.post(
      '/conversations/$conversationId/chat',
      data: {'message': text},
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.stream,
      ),
    );

    final stream = response.data.stream as Stream<List<int>>;
    final buffer = StringBuffer();
    String accumulated = '';

    await for (final chunk in stream) {
      final decoded = utf8.decode(chunk);
      buffer.write(decoded);
      final lines = buffer.toString().split('\n');
      buffer.clear();
      if (!decoded.endsWith('\n')) {
        buffer.write(lines.removeLast());
      }
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final data = json.decode(trimmed) as Map<String, dynamic>;
          if (data['text'] != null) {
            accumulated += data['text'] as String;
            yield placeholder.copyWith(text: accumulated);
          }
          if (data['done'] == true) {
            final finalMsg = data['message'] != null
                ? MessageModel.fromJson(
                    data['message'] as Map<String, dynamic>)
                : placeholder.copyWith(text: accumulated, isStreaming: false);
            yield finalMsg;
          }
        } catch (_) {
          // non-JSON chunk, skip
        }
      }
    }
  }
}
