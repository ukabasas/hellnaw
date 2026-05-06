import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:nova3d_frontend/core/theme.dart';
import 'package:nova3d_frontend/shared/services/glb_asset_cache.dart';
import 'package:web/web.dart' as web;

class GlbViewerPlatform extends StatefulWidget {
  const GlbViewerPlatform({
    super.key,
    required this.src,
    required this.autoRotate,
  });

  final String src;
  final bool autoRotate;

  @override
  State<GlbViewerPlatform> createState() => _GlbViewerPlatformState();
}

class _GlbViewerPlatformState extends State<GlbViewerPlatform> {
  static int _counter = 0;

  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;

  String? _resolvedSrc;

  @override
  void initState() {
    super.initState();
    _viewType = 'nova3d-viewer-${++_counter}';
    _iframe = web.HTMLIFrameElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..style.background = '#0d0d0d'
      ..setAttribute('allow', 'fullscreen *')
      ..setAttribute('allowfullscreen', 'true');

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int id) => _iframe,
    );

    _resolveAndLoad(widget.src);
  }

  @override
  void didUpdateWidget(covariant GlbViewerPlatform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src ||
        oldWidget.autoRotate != widget.autoRotate) {
      GlbAssetCache.revoke(_resolvedSrc ?? '');
      _resolvedSrc = null;
      _resolveAndLoad(widget.src);
    }
  }

  @override
  void dispose() {
    GlbAssetCache.revoke(_resolvedSrc ?? '');
    super.dispose();
  }

  Future<void> _resolveAndLoad(String src) async {
    final resolved = await GlbAssetCache.resolve(src);
    if (!mounted || src != widget.src) {
      GlbAssetCache.revoke(resolved);
      return;
    }

    setState(() => _resolvedSrc = resolved);
    _iframe.src = _buildViewerUrl(resolved);
  }

  String _buildViewerUrl(String modelUrl) {
    final params = {
      'glb': modelUrl,
      'autoRotate': widget.autoRotate.toString(),
    };
    return Uri(path: '/nova3d_viewer.html', queryParameters: params).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      clipBehavior: Clip.hardEdge,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
