import 'package:nova3d_frontend/features/cad/models/generation_model_option.dart';

class GenerationRequest {
  const GenerationRequest({
    required this.prompt,
    required this.modelOption,
    this.imageDataUrl,
    this.imageName,
  });

  final String prompt;
  final GenerationModelOption modelOption;
  final String? imageDataUrl;
  final String? imageName;

  bool get hasText => prompt.trim().isNotEmpty;
  bool get hasImage => imageDataUrl != null && imageDataUrl!.isNotEmpty;
  String get imageBase64Payload {
    final data = imageDataUrl ?? '';
    if (data.startsWith('data:') && data.contains(',')) {
      return data.substring(data.indexOf(',') + 1);
    }
    return data;
  }

  String get imageMime {
    final data = imageDataUrl ?? '';
    if (data.startsWith('data:') && data.contains(';')) {
      return data.substring(5, data.indexOf(';'));
    }
    return 'image/png';
  }

  String get conversationTitle {
    if (hasText) {
      final trimmed = prompt.trim();
      return trimmed.length > 50 ? '${trimmed.substring(0, 50)}...' : trimmed;
    }
    return imageName == null ? 'Image generation' : 'Image: $imageName';
  }

  String get messageText {
    if (hasText && hasImage) return '$prompt\n\nAttached image: $imageName';
    if (hasText) return prompt;
    return 'Attached image: $imageName';
  }
}
