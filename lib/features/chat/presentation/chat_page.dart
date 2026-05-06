import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova3d_frontend/core/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:nova3d_frontend/features/cad/models/generation_request.dart';
import 'package:nova3d_frontend/features/chat/presentation/widgets/message_bubble.dart';
import 'package:nova3d_frontend/features/chat/state/chat_provider.dart';
import 'package:nova3d_frontend/shared/models/message_model.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draft = ref
          .read(generationDraftsProvider.notifier)
          .take(widget.conversationId);
      if (draft != null) {
        ref
            .read(messagesProvider(widget.conversationId).notifier)
            .sendGeneration(draft);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messageState = ref.watch(messagesProvider(widget.conversationId));
    final messages = messageState.messages;
    final isStreaming = messages.any((m) => m.isStreaming);
    final pendingDraft = ref.watch(
      generationDraftsProvider,
    )[widget.conversationId];
    final generationDone = messages.isNotEmpty && !isStreaming;

    ref.listen(messagesProvider(widget.conversationId), (_, _) {
      _scrollToBottom();
    });

    // Prompt text for the sticky header — first message is the user prompt.
    final promptText =
        messages.isNotEmpty && messages.first.role == MessageRole.user
        ? messages.first.text.isNotEmpty
              ? messages.first.text
              : null
        : pendingDraft?.prompt.isNotEmpty == true
        ? pendingDraft!.prompt
        : null;

    return Column(
      children: [
        // Sticky prompt header — always visible above the scroll area.
        if (promptText != null) _PromptHeader(text: promptText),

        // Message list.
        Expanded(
          child: _buildBody(
            messages,
            pendingDraft,
            isStreaming,
            messageState.loaded,
          ),
        ),

        // Bottom bar — new-creation CTA after done, nothing during generation.
        if (generationDone)
          _NewCreationBar()
        else if (messages.isEmpty && pendingDraft == null)
          // Edge case: navigated directly to a chat URL with no data.
          _NewCreationBar(),
      ],
    );
  }

  Widget _buildBody(
    List<MessageModel> messages,
    GenerationRequest? pendingDraft,
    bool isStreaming,
    bool loaded,
  ) {
    if (!loaded) {
      return const Center(child: CircularProgressIndicator(color: kAccentBlue));
    }

    // Show optimistic placeholders while the draft is being processed so the
    // user never sees the "Start the conversation" empty screen.
    if (messages.isEmpty && pendingDraft != null) {
      return _PendingView(draft: pendingDraft);
    }

    if (messages.isEmpty) {
      return _EmptyState();
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (_, i) => _CenteredMessage(
        child: MessageBubble(
          message: messages[i],
          onRetry: messages[i].retryRequest != null
              ? () => ref
                    .read(messagesProvider(widget.conversationId).notifier)
                    .retry(messages[i].id)
              : null,
        ),
      ),
    );
  }
}

// ── Optimistic pending view ───────────────────────────────────────────────────

class _PendingView extends StatelessWidget {
  const _PendingView({required this.draft});
  final GenerationRequest draft;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    children: [
      _CenteredMessage(
        child: MessageBubble(
          message: MessageModel(
            id: '_pending_user',
            role: MessageRole.user,
            text: draft.prompt,
            createdAt: DateTime.now(),
            imageDataUrl: draft.imageDataUrl,
          ),
        ),
      ),
      _CenteredMessage(
        child: MessageBubble(
          message: MessageModel(
            id: '_pending_asst',
            role: MessageRole.assistant,
            text: 'Starting generation…',
            createdAt: DateTime.now(),
            isStreaming: true,
          ),
        ),
      ),
    ],
  );
}

// ── Sticky header showing the user's prompt ───────────────────────────────────

class _PromptHeader extends StatelessWidget {
  const _PromptHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
    decoration: const BoxDecoration(
      color: kBgSecondary,
      border: Border(bottom: BorderSide(color: kBorderColor)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: kTextSecondary, fontSize: 13),
        ),
      ),
    ),
  );
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _NewCreationBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: const BoxDecoration(
      color: kBgSecondary,
      border: Border(top: BorderSide(color: kBorderColor)),
    ),
    child: Center(
      child: TextButton.icon(
        onPressed: () => context.go('/'),
        icon: const Icon(Icons.add, size: 16, color: kAccentBlue),
        label: const Text(
          'Start a new 3D creation',
          style: TextStyle(color: kAccentBlue, fontSize: 13),
        ),
      ),
    ),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: child,
    ),
  );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: kAccentBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome, color: kAccentBlue, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          'Start the conversation',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: kTextPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Describe the 3D model you want to create.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}

// ── Suggestion pills (used by home page) ─────────────────────────────────────

class SuggestionPills extends StatelessWidget {
  const SuggestionPills({super.key, required this.onSelect});
  final void Function(String) onSelect;

  static const _suggestions = [
    'A modern chair with wooden legs',
    'A low-poly mountain landscape',
    'A sci-fi space helmet',
    'A medieval stone castle tower',
    'A futuristic car concept',
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: _suggestions
        .map(
          (s) => ActionChip(
            label: Text(
              s,
              style: const TextStyle(color: kTextSecondary, fontSize: 13),
            ),
            backgroundColor: kBgTertiary,
            side: const BorderSide(color: kBorderColor),
            onPressed: () => onSelect(s),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        )
        .toList(),
  );
}
