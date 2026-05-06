import 'package:flutter/material.dart';

import 'glb_viewer_stub.dart'
    if (dart.library.js_interop) 'glb_viewer_web.dart';

class GlbViewer extends StatelessWidget {
  const GlbViewer({super.key, required this.src, this.autoRotate = true});

  final String src;
  final bool autoRotate;

  @override
  Widget build(BuildContext context) {
    return GlbViewerPlatform(src: src, autoRotate: autoRotate);
  }
}
