import 'package:flutter_test/flutter_test.dart';
import 'package:nova3d_frontend/features/api_keys/models/api_key_models.dart';
import 'package:nova3d_frontend/features/cad/models/generation_model_option.dart';

void main() {
  test('returns generation options only for supported direct providers', () {
    final options = GenerationModelOption.forKeys({
      AiProvider.gemini.id: 'gemini-key',
      AiProvider.anthropic.id: 'anthropic-key',
      AiProvider.openai.id: 'openai-key',
      'legacy_provider': 'legacy-key',
    });

    expect(options, isNotEmpty);
    expect(
      GenerationProvider.values.map((provider) => provider.id),
      orderedEquals(['auto', 'anthropic', 'openai', 'gemini']),
    );
    expect(
      options.map((option) => option.payloadProvider),
      unorderedEquals([
        'anthropic',
        'anthropic',
        'anthropic',
        'openai',
        'gemini',
      ]),
    );
    expect(
      {for (final option in options) option.llm: option.label},
      equals({
        'claude-sonnet': 'claude-sonnet-4-6',
        'claude-opus': 'claude-opus-4-6',
        'claude-opus-latest': 'claude-opus-4-7',
        'gpt55': 'gpt-5.5',
        'gemini': 'gemini-3.1-pro-preview',
      }),
    );
  });
}
