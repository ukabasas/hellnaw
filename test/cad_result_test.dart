import 'package:flutter_test/flutter_test.dart';
import 'package:nova3d_frontend/features/cad/models/cad_models.dart';

void main() {
  test('extracts GLB URL from successful sketch_to_3d output', () {
    final result = CadResult.fromJson({
      'sketch_to_3d_generator': [
        {
          'model_url': 'https://example.test/model.glb',
          'provider': 'openrouter',
        },
      ],
    });

    expect(result.failed, isFalse);
    expect(result.glbUrl, 'https://example.test/model.glb');
    expect(result.errorMessage, isNull);
  });

  test('extracts structured soft failure from nested tool result', () {
    final result = CadResult.fromJson({
      'sketch_to_3d_generator': [
        {
          'result': {
            'status': 'failed',
            'ok': false,
            'failure': {
              'category': 'model_access_denied',
              'user_message':
                  'OpenRouter does not allow this key to use the selected model.',
              'provider': 'openrouter',
              'retryable': false,
            },
          },
        },
      ],
    });

    expect(result.failed, isTrue);
    expect(result.glbUrl, isNull);
    expect(
      result.errorMessage,
      'OpenRouter does not allow this key to use the selected model.',
    );
    expect(result.errorCategory, 'model_access_denied');
    expect(result.provider, 'openrouter');
    expect(result.retryable, isFalse);
  });

  test('builds user message from failure category when message is absent', () {
    final result = CadResult.fromJson({
      'sketch_to_3d_generator': [
        {
          'status': 'failed',
          'failure': {'category': 'insufficient_credits', 'provider': 'gemini'},
        },
      ],
    });

    expect(result.failed, isTrue);
    expect(result.errorMessage, contains('gemini'));
    expect(result.errorMessage, contains('credits'));
  });
}
