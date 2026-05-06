import 'package:dio/dio.dart';
import 'package:nova3d_frontend/core/constants.dart';
import 'package:nova3d_frontend/features/api_keys/data/api_key_service.dart';
import 'package:nova3d_frontend/features/auth/data/auth_service.dart';
import 'package:nova3d_frontend/features/cad/models/cad_models.dart';
import 'package:nova3d_frontend/features/cad/models/generation_model_option.dart';
import 'package:nova3d_frontend/features/cad/models/generation_request.dart';

class CadException implements Exception {
  CadException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CadService {
  CadService(this._auth, this._apiKeys) {
    _dio = Dio(
      BaseOptions(
        baseUrl: kCadBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  final AuthService _auth;
  final ApiKeyService _apiKeys;
  late final Dio _dio;

  Future<Options> _authOptions() async {
    final token = await _auth.getToken();
    if (token == null) throw AuthException('Please sign in again.');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['error'] ?? data['message'];
      if (detail != null) {
        final message = detail.toString();
        if (e.response?.statusCode == 401) {
          return message.toLowerCase().contains('expired')
              ? 'Your session expired. Please sign in again.'
              : 'GraphFlow rejected the current sign-in token. Please sign out and sign in again.';
        }
        return message;
      }
    }
    if (e.response?.statusCode == 401) {
      return 'GraphFlow rejected the current sign-in token. Please sign out and sign in again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'The generation service is unavailable right now. Please try again shortly.';
    }
    return 'Request failed (${e.response?.statusCode})';
  }

  Future<GenerationReadiness> checkReadiness() async {
    try {
      final resp = await _dio.get(
        '/workflow/readiness/$kSketchTo3dWorkflow',
        options: await _authOptions(),
      );
      return GenerationReadiness.fromJson(resp.data as Map<String, dynamic>);
    } on AuthException catch (e) {
      throw CadException(e.message);
    } on DioException catch (e) {
      throw CadException(_errorMessage(e));
    }
  }

  Future<String> startGeneration(GenerationRequest request) async {
    final readiness = await checkReadiness();
    if (!readiness.ready) throw CadException(readiness.userMessage);

    try {
      final apiKey = await _apiKeyFor(request.modelOption);
      final response = await _dio.post(
        '/run/state/$kSketchTo3dWorkflow',
        queryParameters: {
          'request_id': 'state-${DateTime.now().millisecondsSinceEpoch}',
        },
        data: {
          'payload': {
            'prompt': request.prompt.trim(),
            'llm': request.modelOption.llm,
            'provider': request.modelOption.payloadProvider,
            'api_key': apiKey,
            'validate': false,
            if (request.hasImage) ...{
              // Send plain base64 so GraphFlow passes it through to the tool.
              // data: URLs are normalized to CAS artifacts before tool execution.
              'image_base64': request.imageBase64Payload,
              'image_mime': request.imageMime,
            },
          },
          'return_nodes': ['sketch_to_3d_generator'],
        },
        options: await _authOptions(),
      );
      final workflowId = response.data['workflow_id'] as String?;
      if (workflowId == null || workflowId.isEmpty) {
        throw CadException('Generation did not return a workflow id.');
      }
      return workflowId;
    } on DioException catch (e) {
      throw CadException(_errorMessage(e));
    }
  }

  Future<String> _apiKeyFor(GenerationModelOption option) async {
    final keys = await _apiKeys.loadValidKeys();
    final apiKey = keys[option.keyProvider.id];
    if (apiKey == null || apiKey.isEmpty) {
      throw CadException('Add a ${option.keyProvider.label} key in Settings.');
    }
    return apiKey;
  }

  Future<WorkflowStatus> getStatus(String workflowId) async {
    try {
      final resp = await _dio.get(
        '/status/$workflowId',
        options: await _authOptions(),
      );
      return WorkflowStatus.fromJson(
        workflowId,
        resp.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw CadException(_errorMessage(e));
    }
  }

  Future<CadResult> getResult(String workflowId) async {
    try {
      final resp = await _dio.get(
        '/result/$workflowId',
        options: await _authOptions(),
      );
      return CadResult.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw CadException(_errorMessage(e));
    }
  }

  // GraphFlow generations commonly take several minutes. Poll gently so
  // multiple browser chats can run in parallel without hammering the backend.
  Future<CadResult> runWorkflow(
    String workflowId, {
    void Function(WorkflowStatus status)? onProgress,
  }) async {
    final deadline = DateTime.now().add(const Duration(minutes: 30));

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 3));
      final status = await getStatus(workflowId);
      onProgress?.call(status);

      if (status.isTerminal) {
        if (status.state == WorkflowState.budgetExhausted) {
          throw CadException(
            'Your provider or generation budget was exhausted before the model completed.',
          );
        }
        break;
      }
    }

    return getResult(workflowId);
  }
}
