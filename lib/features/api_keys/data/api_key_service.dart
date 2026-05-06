import 'package:dio/dio.dart';
import 'package:nova3d_frontend/features/api_keys/models/api_key_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiKeyValidationResult {
  const ApiKeyValidationResult({required this.isValid, required this.message});
  final bool isValid;
  final String message;
}

class ApiKeyService {
  static const _prefix = 'nova3d_api_key_';
  static const _validPrefix = 'nova3d_api_key_valid_';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<Map<AiProvider, ProviderKeyState>> loadStates() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final provider in AiProvider.values)
        provider: ProviderKeyState(
          provider: provider,
          hasKey: (prefs.getString(_keyName(provider)) ?? '').isNotEmpty,
          isValid: prefs.getBool(_validName(provider)) ?? false,
        ),
    };
  }

  Future<void> clear(AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName(provider));
    await prefs.remove(_validName(provider));
  }

  Future<Map<String, String>> loadValidKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = <String, String>{};
    for (final provider in AiProvider.values) {
      final apiKey = prefs.getString(_keyName(provider));
      final valid = prefs.getBool(_validName(provider)) ?? false;
      if (valid && apiKey != null && apiKey.isNotEmpty) {
        keys[provider.id] = apiKey;
      }
    }
    return keys;
  }

  Future<ApiKeyValidationResult> saveValidated(
    AiProvider provider,
    String apiKey,
  ) async {
    final trimmed = apiKey.trim();
    final formatError = _formatError(provider, trimmed);
    if (formatError != null) {
      return ApiKeyValidationResult(isValid: false, message: formatError);
    }

    final validation = await validate(provider, trimmed);
    if (!validation.isValid) return validation;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName(provider), trimmed);
    await prefs.setBool(_validName(provider), true);
    return validation;
  }

  Future<ApiKeyValidationResult> validate(
    AiProvider provider,
    String apiKey,
  ) async {
    try {
      switch (provider) {
        case AiProvider.gemini:
          await _dio.get(
            'https://generativelanguage.googleapis.com/v1beta/models',
            queryParameters: {'key': apiKey},
          );
        case AiProvider.anthropic:
          await _dio.get(
            'https://api.anthropic.com/v1/models',
            options: Options(
              headers: {
                'x-api-key': apiKey,
                'anthropic-version': '2023-06-01',
                'anthropic-dangerous-direct-browser-access': 'true',
              },
            ),
          );
        case AiProvider.openai:
          await _dio.get(
            'https://api.openai.com/v1/models',
            options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
          );
      }
      return ApiKeyValidationResult(
        isValid: true,
        message:
            '${provider.label} key saved. Keep at least \$10 credit available for generation.',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return ApiKeyValidationResult(
          isValid: false,
          message: '${provider.label} rejected this key.',
        );
      }
      return ApiKeyValidationResult(
        isValid: false,
        message:
            'Could not validate ${provider.label}. Check the key, browser network access, and provider account status.',
      );
    } catch (_) {
      return ApiKeyValidationResult(
        isValid: false,
        message: 'Could not validate ${provider.label}.',
      );
    }
  }

  String _keyName(AiProvider provider) => '$_prefix${provider.id}';
  String _validName(AiProvider provider) => '$_validPrefix${provider.id}';

  String? _formatError(AiProvider provider, String apiKey) {
    if (apiKey.length < 16) return 'Key is too short.';
    switch (provider) {
      case AiProvider.gemini:
        return apiKey.startsWith('AIza')
            ? null
            : 'Gemini keys usually start with AIza.';
      case AiProvider.anthropic:
        return apiKey.startsWith('sk-ant-')
            ? null
            : 'Anthropic keys usually start with sk-ant-.';
      case AiProvider.openai:
        return apiKey.startsWith('sk-') && !apiKey.startsWith('sk-ant-')
            ? null
            : 'OpenAI keys usually start with sk-.';
    }
  }
}
