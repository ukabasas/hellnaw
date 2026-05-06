import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nova3d_frontend/core/constants.dart';
import 'package:nova3d_frontend/core/theme.dart';
import 'package:nova3d_frontend/features/api_keys/state/api_key_provider.dart';
import 'package:nova3d_frontend/features/auth/state/auth_provider.dart';
import 'package:nova3d_frontend/features/cad/data/cad_service.dart';
import 'package:nova3d_frontend/features/cad/models/generation_model_option.dart';
import 'package:nova3d_frontend/features/cad/models/generation_request.dart';
import 'package:nova3d_frontend/features/cad/state/cad_provider.dart';
import 'package:nova3d_frontend/features/chat/presentation/chat_page.dart';
import 'package:nova3d_frontend/features/chat/state/chat_provider.dart';
import 'package:nova3d_frontend/shared/models/conversation_model.dart';

const _genericReadinessError =
    'The generation service is unavailable right now. Please try again shortly.';

String _readinessErrorMessage(Object error) =>
    error is CadException ? error.message : _genericReadinessError;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _ctrl = TextEditingController();
  bool _creating = false;
  String? _imageDataUrl;
  String? _imageName;
  String? _selectedModelId;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    if (bytes.length > kMaxReferenceImageBytes) {
      _showInlineMessage('Images must be 8 MB or smaller.');
      return;
    }

    final extension = (file.extension ?? 'png').toLowerCase();
    final mime = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'image/png',
    };

    setState(() {
      _imageName = file.name;
      _imageDataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    });
  }

  void _clearImage() {
    setState(() {
      _imageName = null;
      _imageDataUrl = null;
    });
  }

  Future<void> _startConversation(String text) async {
    if (_creating) return;
    final keys = await ref.read(apiKeyServiceProvider).loadValidKeys();
    final options = GenerationModelOption.forKeys(keys);
    final modelOption = GenerationModelOption.findById(
      options,
      _selectedModelId,
    );
    if (modelOption == null) {
      _showKeyRequiredDialog();
      return;
    }

    final request = GenerationRequest(
      prompt: text.trim(),
      modelOption: modelOption,
      imageDataUrl: _imageDataUrl,
      imageName: _imageName,
    );
    if (!request.hasText && !request.hasImage) return;

    setState(() => _creating = true);
    try {
      final readiness = await ref.read(cadServiceProvider).checkReadiness();
      if (!readiness.ready) {
        _showInlineMessage(readiness.userMessage);
        return;
      }
    } on CadException catch (e) {
      _showInlineMessage(e.message);
      return;
    } catch (_) {
      _showInlineMessage(_genericReadinessError);
      return;
    } finally {
      if (mounted) setState(() => _creating = false);
    }

    setState(() => _creating = true);
    final user = ref.read(authProvider).user;
    final id = 'conv_${DateTime.now().millisecondsSinceEpoch}';
    final conv = ConversationModel(
      id: id,
      title: request.conversationTitle,
      userId: user?.id ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    ref.read(conversationsProvider.notifier).prepend(conv);
    ref.read(generationDraftsProvider.notifier).put(id, request);
    // Seed the messages provider immediately so ChatPage has content on its
    // first frame — prevents the empty-state flash during navigation.
    ref.read(messagesProvider(id).notifier).seed(request);
    if (mounted) {
      context.go('/chat/$id');
    }
    setState(() => _creating = false);
  }

  void _showInlineMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showKeyRequiredDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kBgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add a provider key',
          style: TextStyle(color: kTextPrimary),
        ),
        content: Text(
          'Add and validate at least one Gemini, Anthropic, or OpenAI key in Settings before generating. Make sure the provider account has at least \$10 in available credit.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: kTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/settings');
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelOptions = ref.watch(generationModelOptionsProvider);
    final readiness = ref.watch(generationReadinessProvider);

    return Scaffold(
      backgroundColor: kBgDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hero icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: kAccentBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: kAccentBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.view_in_ar,
                    color: kAccentBlue,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'What do you want to create?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Describe an object, upload a reference image, or use both.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                readiness.when(
                  data: (state) => state.ready
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _StatusBanner(message: state.userMessage),
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: _StatusBanner(
                      message: 'Checking generation service...',
                    ),
                  ),
                  error: (error, _) => Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: _StatusBanner(
                      message: _readinessErrorMessage(error),
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kBgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _ctrl,
                        maxLines: 4,
                        minLines: 2,
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          hintText:
                              'Describe what to create, or upload an image and add optional guidance...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.all(4),
                          fillColor: Colors.transparent,
                          filled: false,
                        ),
                        onSubmitted: _startConversation,
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 560;
                          final modelDropdown = modelOptions.when(
                            data: (options) {
                              final selected = GenerationModelOption.findById(
                                options,
                                _selectedModelId,
                              );
                              if (selected != null &&
                                  selected.id != _selectedModelId) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) {
                                    setState(
                                      () => _selectedModelId = selected.id,
                                    );
                                  }
                                });
                              }
                              return _ModelDropdown(
                                width: compact ? double.infinity : 220,
                                options: options,
                                selected: selected,
                                onChanged: (option) => setState(
                                  () => _selectedModelId = option?.id,
                                ),
                              );
                            },
                            loading: () => _ModelDropdownSkeleton(
                              width: compact ? double.infinity : 150,
                            ),
                            error: (_, _) => _ModelDropdownSkeleton(
                              width: compact ? double.infinity : 150,
                            ),
                          );

                          final uploadButton = OutlinedButton.icon(
                            onPressed: _creating ? null : _pickImage,
                            icon: const Icon(Icons.image_outlined, size: 18),
                            label: Text(
                              _imageName == null
                                  ? 'Upload image'
                                  : 'Change image',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );

                          final generateButton = ElevatedButton(
                            onPressed:
                                _creating ||
                                    readiness.isLoading ||
                                    readiness.valueOrNull?.ready == false
                                ? null
                                : () => _startConversation(_ctrl.text),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                            child: _creating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Generate'),
                                      SizedBox(width: 6),
                                      Icon(Icons.arrow_forward, size: 16),
                                    ],
                                  ),
                          );

                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                uploadButton,
                                const SizedBox(height: 10),
                                modelDropdown,
                                if (_imageName != null) ...[
                                  const SizedBox(height: 10),
                                  _ImageAttachmentChip(
                                    name: _imageName!,
                                    onClear: _clearImage,
                                  ),
                                ],
                                const SizedBox(height: 10),
                                generateButton,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Flexible(child: uploadButton),
                              const SizedBox(width: 10),
                              modelDropdown,
                              const SizedBox(width: 10),
                              if (_imageName != null)
                                Expanded(
                                  child: _ImageAttachmentChip(
                                    name: _imageName!,
                                    onClear: _clearImage,
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox()),
                              const SizedBox(width: 10),
                              generateButton,
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Suggestion pills
                SuggestionPills(onSelect: _startConversation),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({
    required this.width,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final double width;
  final List<GenerationModelOption> options;
  final GenerationModelOption? selected;
  final ValueChanged<GenerationModelOption?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 40,
    child: DropdownButtonFormField<String>(
      key: ValueKey(selected?.id ?? 'no-model'),
      initialValue: selected?.id,
      isExpanded: true,
      dropdownColor: kBgTertiary,
      style: const TextStyle(color: kTextPrimary, fontSize: 13),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.tune, size: 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        filled: true,
        fillColor: kBgTertiary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kBorderColor),
        ),
      ),
      hint: const Text('Model', overflow: TextOverflow.ellipsis),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option.id,
              child: Text(option.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: options.isEmpty
          ? null
          : (id) => onChanged(GenerationModelOption.findById(options, id)),
    ),
  );
}

class _ModelDropdownSkeleton extends StatelessWidget {
  const _ModelDropdownSkeleton({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 40,
    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: kBgSecondary,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kBorderColor),
    ),
    child: Text(message, style: const TextStyle(color: kTextSecondary)),
  );
}

class _ImageAttachmentChip extends StatelessWidget {
  const _ImageAttachmentChip({required this.name, required this.onClear});
  final String name;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.only(left: 12, right: 4),
    decoration: BoxDecoration(
      color: kBgTertiary,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: kBorderColor),
    ),
    child: Row(
      children: [
        const Icon(Icons.image_outlined, size: 16, color: kAccentBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kTextSecondary, fontSize: 13),
          ),
        ),
        IconButton(
          tooltip: 'Remove image',
          onPressed: onClear,
          icon: const Icon(Icons.close, size: 16),
          color: kTextMuted,
        ),
      ],
    ),
  );
}
