import 'package:nova3d_frontend/features/api_keys/models/api_key_models.dart';

enum GenerationProvider {
  auto('auto', 'Auto'),
  anthropic('anthropic', 'Anthropic'),
  openai('openai', 'OpenAI'),
  gemini('gemini', 'Gemini');

  const GenerationProvider(this.id, this.label);
  final String id;
  final String label;
}

class GenerationModelOption {
  const GenerationModelOption({
    required this.id,
    required this.label,
    required this.llm,
    required this.provider,
    required this.keyProvider,
  });

  final String id;
  final String label;
  final String llm;
  final GenerationProvider provider;
  final AiProvider keyProvider;

  String get payloadProvider => provider.id;

  static const all = [
    ..._anthropicOptions,
    _openAiOption,
    _geminiOption,
  ];

  static List<GenerationModelOption> forKeys(Map<String, String> keys) {
    final options = <GenerationModelOption>[];
    if ((keys[AiProvider.anthropic.id] ?? '').isNotEmpty) {
      options.addAll(_anthropicOptions);
    }
    if ((keys[AiProvider.openai.id] ?? '').isNotEmpty) {
      options.add(_openAiOption);
    }
    if ((keys[AiProvider.gemini.id] ?? '').isNotEmpty) {
      options.add(_geminiOption);
    }
    return options;
  }

  static GenerationModelOption? findById(
    Iterable<GenerationModelOption> options,
    String? id,
  ) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    return options.isEmpty ? null : options.first;
  }
}

const _anthropicOptions = [
  GenerationModelOption(
    id: 'anthropic_claude_sonnet',
    label: 'claude-sonnet-4-6',
    llm: 'claude-sonnet',
    provider: GenerationProvider.anthropic,
    keyProvider: AiProvider.anthropic,
  ),
  GenerationModelOption(
    id: 'anthropic_claude_opus',
    label: 'claude-opus-4-6',
    llm: 'claude-opus',
    provider: GenerationProvider.anthropic,
    keyProvider: AiProvider.anthropic,
  ),
  GenerationModelOption(
    id: 'anthropic_claude_opus_latest',
    label: 'claude-opus-4-7',
    llm: 'claude-opus-latest',
    provider: GenerationProvider.anthropic,
    keyProvider: AiProvider.anthropic,
  ),
];

const _openAiOption = GenerationModelOption(
  id: 'openai_gpt55',
  label: 'gpt-5.5',
  llm: 'gpt55',
  provider: GenerationProvider.openai,
  keyProvider: AiProvider.openai,
);

const _geminiOption = GenerationModelOption(
  id: 'gemini_gemini',
  label: 'gemini-3.1-pro-preview',
  llm: 'gemini',
  provider: GenerationProvider.gemini,
  keyProvider: AiProvider.gemini,
);
