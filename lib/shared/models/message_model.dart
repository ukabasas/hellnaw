import 'package:nova3d_frontend/features/cad/models/generation_request.dart';

enum MessageRole { user, assistant }

class MessageModel {
  final String id;
  final MessageRole role;
  final String text;
  final DateTime createdAt;
  final bool isStreaming;
  final String? modelUrl;
  final String? workflowId;
  final Map<String, dynamic>? codeArtifact;
  final String? modelOptionId;
  // Shown as a thumbnail in the user bubble.
  final String? imageDataUrl;
  // Non-null on failed assistant messages — enables the retry button.
  final GenerationRequest? retryRequest;

  const MessageModel({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.isStreaming = false,
    this.modelUrl,
    this.workflowId,
    this.codeArtifact,
    this.modelOptionId,
    this.imageDataUrl,
    this.retryRequest,
  });

  MessageModel copyWith({
    String? text,
    bool? isStreaming,
    String? modelUrl,
    String? workflowId,
    Map<String, dynamic>? codeArtifact,
    String? modelOptionId,
    String? imageDataUrl,
    GenerationRequest? retryRequest,
    bool clearRetryRequest = false,
  }) => MessageModel(
    id: id,
    role: role,
    text: text ?? this.text,
    createdAt: createdAt,
    isStreaming: isStreaming ?? this.isStreaming,
    modelUrl: modelUrl ?? this.modelUrl,
    workflowId: workflowId ?? this.workflowId,
    codeArtifact: codeArtifact ?? this.codeArtifact,
    modelOptionId: modelOptionId ?? this.modelOptionId,
    imageDataUrl: imageDataUrl ?? this.imageDataUrl,
    retryRequest: clearRetryRequest
        ? null
        : (retryRequest ?? this.retryRequest),
  );

  // ── Local persistence (SharedPreferences) ─────────────────────────────────

  Map<String, dynamic> toLocalJson() => {
    'id': id,
    'role': role == MessageRole.user ? 'user' : 'assistant',
    'text': text,
    'created_at': createdAt.toIso8601String(),
    'is_streaming': isStreaming,
    if (modelUrl != null) 'model_url': modelUrl,
    if (workflowId != null) 'workflow_id': workflowId,
    if (codeArtifact != null) 'code_artifact': codeArtifact,
    if (modelOptionId != null) 'model_option_id': modelOptionId,
    if (imageDataUrl != null) 'image_data_url': imageDataUrl,
  };

  factory MessageModel.fromLocalJson(Map<String, dynamic> json) => MessageModel(
    id: json['id'] as String,
    role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
    text: (json['text'] as String?) ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
    isStreaming: json['is_streaming'] == true,
    modelUrl: json['model_url'] as String?,
    workflowId: json['workflow_id'] as String?,
    codeArtifact: _asStringMap(json['code_artifact']),
    modelOptionId: json['model_option_id'] as String?,
    imageDataUrl: json['image_data_url'] as String?,
  );

  // ── Remote API response ───────────────────────────────────────────────────

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
    id: json['id'] as String,
    role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
    text: (json['content']?['text'] as String?) ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
    modelUrl: json['content']?['model_url'] as String?,
    workflowId: json['content']?['workflow_id'] as String?,
    codeArtifact: _asStringMap(json['content']?['code_artifact']),
    modelOptionId: json['content']?['model_option_id'] as String?,
    imageDataUrl: json['content']?['image_data_url'] as String?,
  );

  static Map<String, dynamic>? _asStringMap(Object? value) {
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
}
