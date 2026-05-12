import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:nova3d_frontend/core/theme.dart';
import 'package:nova3d_frontend/features/cad/data/cad_service.dart';
import 'package:nova3d_frontend/features/cad/state/cad_provider.dart';
import 'package:nova3d_frontend/shared/services/glb_asset_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

@JS('nova3dRegisterEditHandler')
external void _registerEditHandler(JSString viewerId, JSFunction handler);

@JS('nova3dUnregisterEditHandler')
external void _unregisterEditHandler(JSString viewerId);

class GlbViewerPlatform extends ConsumerStatefulWidget {
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
  ConsumerState<GlbViewerPlatform> createState() => _GlbViewerPlatformState();
}

class _GlbViewerPlatformState extends ConsumerState<GlbViewerPlatform> {
  static int _counter = 0;

  late final String _viewType;
  late final String _viewerId;
  late final web.HTMLIFrameElement _iframe;

  String? _resolvedSrc;

  @override
  void initState() {
    super.initState();
    _viewerId = 'nova3d-viewer-${++_counter}';
    _viewType = _viewerId;
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
    _registerEditHandler(_viewerId.toJS, _handleEditRequest.toJS);
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
    _unregisterEditHandler(_viewerId.toJS);
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
      'viewerId': _viewerId,
      'stateKey': widget.src.hashCode.toRadixString(16),
      'glb': modelUrl,
      'autoRotate': widget.autoRotate.toString(),
      if (widget.codeArtifact != null)
        'codeArtifact': json.encode(widget.codeArtifact),
    };
    return Uri(path: '/nova3d_viewer.html', queryParameters: params).toString();
  }

  void _handleEditRequest(
    JSString requestId,
    JSString operation,
    JSString description,
    JSString partType,
    JSString codeArtifactJson,
  ) {
    _runEditWorkflow(
      requestId: requestId.toDart,
      operation: operation.toDart,
      description: description.toDart,
      partType: partType.toDart,
      codeArtifactJson: codeArtifactJson.toDart,
    );
  }

  Future<void> _runEditWorkflow({
    required String requestId,
    required String operation,
    required String description,
    required String partType,
    required String codeArtifactJson,
  }) async {
    final cad = ref.read(cadServiceProvider);
    final codeArtifact = _decodeArtifact(codeArtifactJson);
    if (codeArtifact == null) {
      _postEditResult({
        'requestId': requestId,
        'status': 'failed',
        'message':
            'This model does not include editable source code yet. Generate it again before using AI edits.',
      });
      return;
    }

    try {
      final workflowId = operation == 'add_3d_part'
          ? await cad.startAddPart(
              codeArtifact: codeArtifact,
              description: description,
            )
          : await cad.startRegeneratePart(
              codeArtifact: codeArtifact,
              description: description,
              partType: partType,
            );

      final result = await cad.runWorkflow(workflowId);
      if (result.failed ||
          result.glbUrl == null ||
          result.codeArtifact == null) {
        _postEditResult({
          'requestId': requestId,
          'status': 'failed',
          'workflowId': workflowId,
          'message':
              result.errorMessage ??
              'The edit workflow did not produce a model.',
        });
        return;
      }

      final resolved = await GlbAssetCache.resolve(result.glbUrl!);
      if (!mounted) {
        GlbAssetCache.revoke(resolved);
        return;
      }
      _postEditResult({
        'requestId': requestId,
        'status': 'completed',
        'operation': operation,
        'workflowId': workflowId,
        'modelUrl': resolved,
        'codeArtifact': result.codeArtifact,
      });
    } on CadException catch (e) {
      _postEditResult({
        'requestId': requestId,
        'status': 'failed',
        'message': e.message,
      });
    } catch (_) {
      _postEditResult({
        'requestId': requestId,
        'status': 'failed',
        'message': 'Edit failed. Try again or switch provider keys.',
      });
    }
  }

  Map<String, dynamic>? _decodeArtifact(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return null;
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return null;
    }
  }

  void _postEditResult(Map<String, dynamic> payload) {
    _iframe.contentWindow?.postMessage(
      {'type': 'nova3d-edit-result', ...payload}.jsify(),
      '*'.toJS,
    );
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
