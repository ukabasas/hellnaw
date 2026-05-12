import 'package:flutter/material.dart';
import 'package:nova3d_frontend/core/theme.dart';

class GlbViewerPlatform extends StatelessWidget {
  const GlbViewerPlatform({
    super.key,
    required this.src,
    required this.autoRotate,
    this.codeArtifact,
  });

  final String src;
  final bool autoRotate;
  final Map<String, dynamic>? codeArtifact;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: const Text(
        '3D preview is available in the web app.',
        style: TextStyle(color: kTextSecondary, fontSize: 13),
      ),
    );
  }
}
