// ── Workflow state ────────────────────────────────────────────────────────────

enum WorkflowState {
  pending,
  running,
  completed,
  budgetExhausted,
  failed,
  terminated,
  unknown;

  static WorkflowState parse(String? s) => switch (s?.toLowerCase()) {
    'pending' => pending,
    'running' => running,
    'completed' || 'succeeded' || 'success' => completed,
    'budget_exhausted' => budgetExhausted,
    'failed' => failed,
    'terminated' || 'cancelled' || 'timed_out' || 'timeout' => terminated,
    _ => unknown,
  };

  bool get isTerminal =>
      this == completed ||
      this == budgetExhausted ||
      this == failed ||
      this == terminated;
}

// ── GraphFlow readiness (from GET /workflow/readiness/sketch_to_3d) ───────────

class GenerationReadiness {
  const GenerationReadiness({
    required this.ready,
    this.reason,
    this.projectedCost = 0,
    this.authorizedBudget = 0,
  });

  final bool ready;
  final String? reason;
  final num projectedCost;
  final num authorizedBudget;

  factory GenerationReadiness.fromJson(Map<String, dynamic> json) =>
      GenerationReadiness(
        ready: json['ready'] == true,
        reason: json['reason'] as String?,
        projectedCost: json['projected_cost'] as num? ?? 0,
        authorizedBudget: json['authorized_budget'] as num? ?? 0,
      );

  String get userMessage {
    if (ready) return 'Generation is ready.';
    if (reason == 'generation_service_unavailable') {
      return 'The generation service is unavailable right now. Please try again shortly.';
    }
    return 'Generation is not available right now.';
  }
}

// ── Workflow status (from GET /status/<id>) ───────────────────────────────────

class WorkflowStatus {
  final String workflowId;
  final WorkflowState state;
  final String? currentNode;
  final String? lastExitNode;
  final int retryCount;

  const WorkflowStatus({
    required this.workflowId,
    required this.state,
    this.currentNode,
    this.lastExitNode,
    this.retryCount = 0,
  });

  static const _terminalNodes = {
    'success_final',
    'success_original_glb',
    'failed_final',
  };

  static const _nodeLabels = {
    'sketch_to_3d_generator': 'Generating your 3D model...',
  };

  String get progressLabel {
    final node = currentNode ?? lastExitNode ?? '';
    return _nodeLabels[node] ?? 'Generating…';
  }

  bool get isTerminalByNode =>
      _terminalNodes.contains(currentNode) ||
      _terminalNodes.contains(lastExitNode);

  bool get isTerminal => state.isTerminal || isTerminalByNode;

  factory WorkflowStatus.fromJson(
    String workflowId,
    Map<String, dynamic> json,
  ) {
    final runtime = json['runtime'] as Map<String, dynamic>? ?? {};
    final visitSeq = json['node_visit_seq'] as Map<String, dynamic>? ?? {};

    return WorkflowStatus(
      workflowId: workflowId,
      state: WorkflowState.parse(runtime['state'] as String?),
      currentNode: visitSeq.keys.isNotEmpty ? visitSeq.keys.last : null,
      lastExitNode: runtime['last_exit_node_id'] as String?,
      retryCount: 0,
    );
  }
}

// ── CAD result (from GET /result/<id>) ────────────────────────────────────────

class CadResult {
  final String? glbUrl;
  final bool failed;
  final String? errorMessage;

  const CadResult({this.glbUrl, required this.failed, this.errorMessage});

  factory CadResult.fromJson(Map<String, dynamic> json) {
    final glbUrl = _extractGlbUrl(json);
    final errorMessage = _extractError(json);
    final failed = glbUrl == null && (_isFailed(json) || errorMessage != null);

    return CadResult(
      glbUrl: glbUrl,
      failed: failed,
      errorMessage: errorMessage,
    );
  }

  static String? _extractGlbUrl(Map<String, dynamic> json) {
    final generator = json['sketch_to_3d_generator'];
    if (generator is! List || generator.isEmpty) return null;
    final first = generator.first;
    if (first is! Map) return null;

    final modelUrl = first['model_url'] as String?;
    if (modelUrl != null && modelUrl.isNotEmpty) return modelUrl;

    for (final artifactKey in ['model', 'model_artifact']) {
      final artifact = first[artifactKey];
      if (artifact is Map) {
        final url = artifact['url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
    }
    return null;
  }

  static String? _extractError(Map<String, dynamic> json) {
    final generator = json['sketch_to_3d_generator'];
    if (generator is! List || generator.isEmpty) return null;
    final first = generator.first;
    if (first is! Map) return null;

    final status = (first['status'] as String?)?.toLowerCase();
    final action = (first['action'] as String?)?.toLowerCase();
    if (status != 'failed' && action != 'error') return null;

    final error = first['error'] ?? first['detail'] ?? first['message'];
    if (error == null) return 'Generation failed.';
    return error.toString();
  }

  static bool _isFailed(Map<String, dynamic> json) {
    final state = (json['state'] as String?)?.toLowerCase();
    if (state == 'failed' || state == 'failure') return true;
    final runtime = json['runtime'] as Map<String, dynamic>?;
    final rState = (runtime?['state'] as String?)?.toLowerCase();
    if (rState == 'failed' ||
        rState == 'failure' ||
        rState == 'budget_exhausted') {
      return true;
    }
    return false;
  }
}

// ── Credits (from GET /api/credits/balance/me) ────────────────────────────────

class CadCredits {
  final int balance;
  final int available;

  const CadCredits({required this.balance, required this.available});

  factory CadCredits.fromJson(Map<String, dynamic> json) => CadCredits(
    balance: (json['balance'] as num).toInt(),
    available: (json['available'] as num).toInt(),
  );
}
