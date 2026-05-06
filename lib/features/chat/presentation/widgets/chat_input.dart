import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nova3d_frontend/core/constants.dart';
import 'package:nova3d_frontend/core/theme.dart';
import 'package:nova3d_frontend/features/cad/models/generation_model_option.dart';
import 'package:nova3d_frontend/features/cad/models/generation_request.dart';

class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.onSend,
    required this.modelOptions,
    required this.selectedModel,
    required this.onModelChanged,
    this.disabled = false,
  });

  final FutureOr<bool> Function(GenerationRequest request) onSend;
  final List<GenerationModelOption> modelOptions;
  final GenerationModelOption? selectedModel;
  final ValueChanged<GenerationModelOption?> onModelChanged;
  final bool disabled;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  String? _imageDataUrl;
  String? _imageName;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !widget.disabled &&
      widget.selectedModel != null &&
      (_ctrl.text.trim().isNotEmpty ||
          (_imageDataUrl != null && _imageDataUrl!.isNotEmpty));

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    if (bytes.length > kMaxReferenceImageBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Images must be 8 MB or smaller.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    final modelOption = widget.selectedModel;
    if (modelOption == null) return;
    final request = GenerationRequest(
      prompt: text,
      modelOption: modelOption,
      imageDataUrl: _imageDataUrl,
      imageName: _imageName,
    );
    if (!request.hasText && !request.hasImage) return;
    if (widget.disabled) return;

    final accepted = await widget.onSend(request);
    if (accepted) {
      _ctrl.clear();
      _clearImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kBgDark,
        border: Border(top: BorderSide(color: kBorderColor)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Container(
            decoration: BoxDecoration(
              color: kBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: _imageName == null
                          ? 'Upload image'
                          : 'Change image',
                      onPressed: widget.disabled ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      color: kTextSecondary,
                    ),
                    Expanded(
                      child: CallbackShortcuts(
                        bindings: {
                          const SingleActivator(LogicalKeyboardKey.enter):
                              _submit,
                          const SingleActivator(
                            LogicalKeyboardKey.enter,
                            shift: true,
                          ): () {},
                        },
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focusNode,
                          enabled: !widget.disabled,
                          maxLines: 6,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          style: const TextStyle(
                            color: kTextPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Describe the 3D model you want to create...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 14,
                            ),
                            hintStyle: TextStyle(
                              color: kTextMuted,
                              fontSize: 14,
                            ),
                            fillColor: Colors.transparent,
                            filled: false,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ChatModelDropdown(
                      options: widget.modelOptions,
                      selected: widget.selectedModel,
                      disabled: widget.disabled,
                      onChanged: widget.onModelChanged,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: AnimatedOpacity(
                        opacity: _canSubmit ? 1.0 : 0.4,
                        duration: const Duration(milliseconds: 150),
                        child: IconButton(
                          onPressed: _canSubmit ? _submit : null,
                          icon: const Icon(Icons.send_rounded),
                          color: kAccentBlue,
                          style: IconButton.styleFrom(
                            backgroundColor: kAccentBlue.withValues(
                              alpha: 0.12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_imageName != null)
                  _ImageAttachmentChip(
                    name: _imageName!,
                    onClear: widget.disabled ? null : _clearImage,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatModelDropdown extends StatelessWidget {
  const _ChatModelDropdown({
    required this.options,
    required this.selected,
    required this.disabled,
    required this.onChanged,
  });

  final List<GenerationModelOption> options;
  final GenerationModelOption? selected;
  final bool disabled;
  final ValueChanged<GenerationModelOption?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
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
      onChanged: disabled || options.isEmpty
          ? null
          : (id) => onChanged(GenerationModelOption.findById(options, id)),
    ),
  );
}

class _ImageAttachmentChip extends StatelessWidget {
  const _ImageAttachmentChip({required this.name, required this.onClear});

  final String name;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: Container(
      height: 36,
      padding: const EdgeInsets.only(left: 10, right: 2),
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
    ),
  );
}
