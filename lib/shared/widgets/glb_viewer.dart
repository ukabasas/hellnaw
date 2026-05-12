import 'package:flutter/material.dart';
import 'package:nova3d_frontend/features/cad/models/generation_model_option.dart';

import 'glb_viewer_stub.dart'
    if (dart.library.js_interop) 'glb_viewer_web.dart';

class GlbViewer extends StatelessWidget {
  const GlbViewer({
    super.key,
    required this.src,
    this.autoRotate = true,
    this.codeArtifact,
    this.sourceWorkflowId,
    this.editModelOptions = const [],
    this.defaultEditModelOptionId,
  });

  final String src;
  final bool autoRotate;
  final Map<String, dynamic>? codeArtifact;
  final String? sourceWorkflowId;
  final List<GenerationModelOption> editModelOptions;
  final String? defaultEditModelOptionId;

  @override
  Widget build(BuildContext context) {
    return GlbViewerPlatform(
      src: src,
      autoRotate: autoRotate,
      codeArtifact: codeArtifact,
      sourceWorkflowId: sourceWorkflowId,
      editModelOptions: editModelOptions,
      defaultEditModelOptionId: defaultEditModelOptionId,
    );
  }
}
