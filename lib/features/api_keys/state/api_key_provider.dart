import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova3d_frontend/features/api_keys/data/api_key_service.dart';
import 'package:nova3d_frontend/features/api_keys/models/api_key_models.dart';

final apiKeyServiceProvider = Provider<ApiKeyService>((_) => ApiKeyService());

final apiKeysProvider = StateNotifierProvider<ApiKeysNotifier, ApiKeysState>((
  ref,
) {
  return ApiKeysNotifier(ref.watch(apiKeyServiceProvider));
});

class ApiKeysNotifier extends StateNotifier<ApiKeysState> {
  ApiKeysNotifier(this._service) : super(ApiKeysState.empty()) {
    load();
  }

  final ApiKeyService _service;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearMessage: true);
    final keys = await _service.loadStates();
    state = state.copyWith(keys: keys, loading: false);
  }

  Future<void> save(AiProvider provider, String apiKey) async {
    state = state.copyWith(validating: provider, clearMessage: true);
    final result = await _service.saveValidated(provider, apiKey);
    final updated = Map<AiProvider, ProviderKeyState>.from(state.keys);
    updated[provider] = ProviderKeyState(
      provider: provider,
      hasKey: result.isValid,
      isValid: result.isValid,
      lastValidatedAt: result.isValid ? DateTime.now() : null,
    );
    state = state.copyWith(
      keys: updated,
      clearValidating: true,
      message: result.message,
    );
  }

  Future<void> clear(AiProvider provider) async {
    await _service.clear(provider);
    final updated = Map<AiProvider, ProviderKeyState>.from(state.keys);
    updated[provider] = ProviderKeyState(provider: provider);
    state = state.copyWith(
      keys: updated,
      message: '${provider.label} key removed.',
    );
  }
}
