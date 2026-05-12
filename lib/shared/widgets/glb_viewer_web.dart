import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:nova3d_frontend/core/theme.dart';
import 'package:nova3d_frontend/features/cad/data/cad_service.dart';
import 'package:nova3d_frontend/features/cad/models/generation_model_option.dart';
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
      return;
    }

    if (oldWidget.codeArtifact != widget.codeArtifact ||
        oldWidget.sourceWorkflowId != widget.sourceWorkflowId ||
        oldWidget.defaultEditModelOptionId != widget.defaultEditModelOptionId ||
        !_sameModelOptions(
          oldWidget.editModelOptions,
          widget.editModelOptions,
        )) {
      _postEditConfig();
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
    _postEditConfigSoon(src);
  }

  void _postEditConfigSoon(String src) {
    for (final delay in const [
      Duration(milliseconds: 250),
      Duration(milliseconds: 1000),
      Duration(milliseconds: 2500),
    ]) {
      Future<void>.delayed(delay, () {
        if (!mounted || src != widget.src) return;
        _postEditConfig();
      });
    }
  }

  String _buildViewerUrl(String modelUrl) {
    final params = {
      'viewerId': _viewerId,
      'stateKey': widget.src.hashCode.toRadixString(16),
      'glb': modelUrl,
      'autoRotate': widget.autoRotate.toString(),
      if (widget.codeArtifact != null)
        'codeArtifact': json.encode(widget.codeArtifact),
      if (widget.sourceWorkflowId != null)
        'sourceWorkflowId': widget.sourceWorkflowId!,
      'editModelOptions': json.encode(_editModelOptionsPayload()),
      if (widget.defaultEditModelOptionId != null)
        'editDefaultModelId': widget.defaultEditModelOptionId!,
    };
    return Uri(path: '/nova3d_viewer.html', queryParameters: params).toString();
  }

  List<Map<String, String>> _editModelOptionsPayload() => widget
      .editModelOptions
      .map(
        (option) => {
          'id': option.id,
          'label': option.label,
          'provider': option.provider.label,
        },
      )
      .toList();

  void _postEditConfig() {
    _iframe.contentWindow?.postMessage(
      {
        'type': 'nova3d-edit-config',
        if (widget.codeArtifact != null) 'codeArtifact': widget.codeArtifact,
        'sourceWorkflowId': widget.sourceWorkflowId ?? '',
        'editModelOptions': _editModelOptionsPayload(),
        'editDefaultModelId': widget.defaultEditModelOptionId ?? '',
      }.jsify(),
      '*'.toJS,
    );
  }

  bool _sameModelOptions(
    List<GenerationModelOption> a,
    List<GenerationModelOption> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].label != b[i].label) return false;
    }
    return true;
  }

  void _handleEditRequest(JSString requestJson) {
    final request = _decodeEditRequest(requestJson.toDart);
    _runEditWorkflow(
      requestId: request.requestId,
      operation: request.operation,
      description: request.description,
      partType: request.partType,
      codeArtifact: request.codeArtifact,
      sourceWorkflowId: request.sourceWorkflowId,
      modelOptionId: request.modelOptionId,
    );
  }

  Future<void> _runEditWorkflow({
    required String requestId,
    required String operation,
    required String description,
    required String partType,
    required Map<String, dynamic>? codeArtifact,
    required String sourceWorkflowId,
    required String modelOptionId,
  }) async {
    final cad = ref.read(cadServiceProvider);
    final modelOption = GenerationModelOption.findById(
      widget.editModelOptions,
      modelOptionId,
    ) ?? GenerationModelOption.findById(
      GenerationModelOption.all,
      modelOptionId,
    );
    var editableCodeArtifact = codeArtifact;
    final workflowIdForSource = sourceWorkflowId.isNotEmpty
        ? sourceWorkflowId
        : (widget.sourceWorkflowId ?? '');
    if (editableCodeArtifact == null && workflowIdForSource.isNotEmpty) {
      _postEditResult({
        'requestId': requestId,
        'status': 'running',
        'message': 'Loading editable source from the original workflow...',
      });
      try {
        editableCodeArtifact = (await cad.getResult(
          workflowIdForSource,
        )).codeArtifact;
      } on CadException catch (e) {
        _postEditResult({
          'requestId': requestId,
          'status': 'failed',
          'message': _editableSourceLoadMessage(e, workflowIdForSource),
        });
        return;
      }
    }

    if (editableCodeArtifact == null) {
      _postEditResult({
        'requestId': requestId,
        'status': 'failed',
        'message':
            'This model does not include editable source code yet. Generate it again before using AI edits.',
      });
      return;
    }
    if (modelOption == null) {
      _postEditResult({
        'requestId': requestId,
        'status': 'failed',
        'message': 'Add a Gemini, Anthropic, or OpenAI key in Settings.',
      });
      return;
    }

    try {
      _postEditResult({
        'requestId': requestId,
        'status': 'running',
        'message': operation == 'add_3d_part'
            ? 'Starting add-part workflow...'
            : 'Starting selected-part regeneration...',
      });
      final workflowId = operation == 'add_3d_part'
          ? await cad.startAddPart(
              codeArtifact: editableCodeArtifact,
              description: description,
              modelOption: modelOption,
            )
          : await cad.startRegeneratePart(
              codeArtifact: editableCodeArtifact,
              description: description,
              modelOption: modelOption,
              partType: partType,
            );

      final result = await cad.runWorkflow(
        workflowId,
        onProgress: (status) => _postEditResult({
          'requestId': requestId,
          'status': 'running',
          'workflowId': workflowId,
          'message': status.progressLabel,
        }),
      );
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

  _EditRequest _decodeEditRequest(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return const _EditRequest();
      final request = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return _EditRequest(
        requestId: (request['requestId'] as String?) ?? '',
        operation: (request['operation'] as String?) ?? '',
        description: (request['description'] as String?) ?? '',
        partType: (request['partType'] as String?) ?? '',
        modelOptionId: (request['modelOptionId'] as String?) ?? '',
        sourceWorkflowId: (request['sourceWorkflowId'] as String?) ?? '',
        codeArtifact: _asStringMap(request['codeArtifact']),
      );
    } catch (_) {
      return const _EditRequest();
    }
  }

  Map<String, dynamic>? _asStringMap(Object? value) {
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  void _postEditResult(Map<String, dynamic> payload) {
    _iframe.contentWindow?.postMessage(
      {'type': 'nova3d-edit-result', ...payload}.jsify(),
      '*'.toJS,
    );
  }

  String _editableSourceLoadMessage(CadException error, String workflowId) {
    final message = error.message.trim();
    final lower = message.toLowerCase();
    if (lower.contains('workflow not found') || lower.contains('404')) {
      return workflowId.isEmpty
          ? 'This model does not include editable source code yet. Generate it again before using AI edits.'
          : 'This model does not include editable source code, and Nova3D could not find source for workflow $workflowId. Generate it again before using AI edits.';
    }
    return message.isEmpty
        ? 'Nova3D could not load editable source code for this model.'
        : message;
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

class _EditRequest {
  const _EditRequest({
    this.requestId = '',
    this.operation = '',
    this.description = '',
    this.partType = '',
    this.modelOptionId = '',
    this.sourceWorkflowId = '',
    this.codeArtifact,
  });

  final String requestId;
  final String operation;
  final String description;
  final String partType;
  final String modelOptionId;
  final String sourceWorkflowId;
  final Map<String, dynamic>? codeArtifact;
}
