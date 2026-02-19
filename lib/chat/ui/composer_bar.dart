import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../data/attachment_manager.dart';
import 'attachment_preview_tray.dart';
import 'voice_recorder.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Emoji data
// ─────────────────────────────────────────────────────────────────────────────
const _emojiCategories = <String, List<String>>{
  '😀': [
    '😀','😃','😄','😁','😆','😅','🤣','😂','🙂','🙃',
    '😉','😊','😇','🥰','😍','🤩','😘','😗','😚','😙',
    '🥲','😋','😛','😜','🤪','😝','🤑','🤗','🤭','🤫',
    '🤔','🤐','🤨','😐','😑','😶','😏','😒','🙄','😬',
    '🤥','😌','😔','😪','🤤','😴','😷','🤒','🤕','🤢',
    '🤧','🥵','🥶','🥴','😵','🤯','🤠','🥳','🥸','😎',
    '🤓','🧐','😕','😟','🙁','☹️','😮','😯','😲','😳',
    '🥺','😦','😧','😨','😰','😥','😢','😭','😱','😖',
    '😣','😞','😓','😩','😫','🥱','😤','😡','😠','🤬',
  ],
  '👋': [
    '👋','🤚','🖐','✋','🖖','👌','🤌','🤏','✌️','🤞',
    '🤟','🤘','🤙','👈','👉','👆','🖕','👇','☝️','👍',
    '👎','✊','👊','🤛','🤜','👏','🙌','👐','🤲','🤝',
    '🙏','✍️','💅','🤳','💪','🦾','🦿','🦵','🦶','👂',
    '🦻','👃','🫀','🫁','🧠','🦷','🦴','👀','👁','👅',
    '👄','💋','🫦','👶','🧒','👦','👧','🧑','👱','👨',
    '🧔','👩','🧓','👴','👵','🙍','🙎','🙅','🙆','💁',
    '🙋','🧏','🙇','🤦','🤷','👮','🕵️','💂','🥷','👷',
  ],
  '🐶': [
    '🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐻‍❄️','🐨',
    '🐯','🦁','🐮','🐷','🐸','🐵','🙈','🙉','🙊','🐒',
    '🐔','🐧','🐦','🐤','🦆','🦅','🦉','🦇','🐺','🐗',
    '🐴','🦄','🐝','🐛','🦋','🐌','🐞','🐜','🦟','🦗',
    '🕷','🦂','🐢','🐍','🦎','🦖','🦕','🐙','🦑','🦐',
    '🦞','🦀','🐡','🐠','🐟','🐬','🐳','🐋','🦈','🐊',
    '🐅','🐆','🦓','🦍','🦧','🦣','🐘','🦛','🦏','🐪',
    '🌸','🌺','🌻','🌹','🌷','🌱','🌿','🍀','🍁','🍂',
  ],
  '🍕': [
    '🍕','🍔','🌮','🌯','🥙','🧆','🥚','🍳','🥘','🍲',
    '🫕','🥣','🥗','🍿','🧂','🥫','🍱','🍘','🍙','🍚',
    '🍛','🍜','🍝','🍠','🍢','🍣','🍤','🍥','🥮','🍡',
    '🥟','🥠','🥡','🦪','🍦','🍧','🍨','🍩','🍪','🎂',
    '🍰','🧁','🥧','🍫','🍬','🍭','🍮','🍯','🍼','🥛',
    '☕','🫖','🍵','🧃','🥤','🧋','🍶','🍺','🍻','🥂',
    '🍷','🥃','🍸','🍹','🧉','🍾','🧊','🥄','🍴','🍽',
    '🥢','🧇','🥞','🧈','🍞','🥐','🥖','🫓','🥨','🥯',
  ],
  '⚽': [
    '⚽','🏀','🏈','⚾','🥎','🎾','🏐','🏉','🥏','🎱',
    '🪀','🏓','🏸','🏒','🥍','🏑','🏏','🪃','🥅','⛳',
    '🪁','🏹','🎣','🤿','🥊','🥋','🎽','🛹','🛼','🛷',
    '⛸','🥌','🎿','⛷','🏂','🪂','🏋️','🤼','🤸','⛹',
    '🤺','🏇','🧘','🏄','🏊','🤽','🚣','🧗','🚵','🚴',
    '🏆','🥇','🥈','🥉','🏅','🎖','🏵','🎗','🎫','🎟',
    '🎪','🤹','🎭','🩰','🎨','🎬','🎤','🎧','🎼','🎹',
    '🥁','🪘','🎷','🎺','🎸','🪕','🎻','🪗','🎲','♟',
  ],
  '💡': [
    '💡','🔦','🕯','🪔','💰','💴','💵','💶','💷','💸',
    '💳','🪙','💹','📈','📉','📊','📋','📌','📍','📎',
    '🖇','📏','📐','✂️','🗃','🗄','🗑','🔒','🔓','🔏',
    '🔐','🔑','🗝','🔨','🪓','⛏','⚒','🛠','🗡','⚔',
    '🛡','🪚','🔧','🪛','🔩','⚙️','🗜','⚖️','🦯','🔗',
    '⛓','🪝','🧲','🪜','⚗️','🧪','🧫','🧬','🔬','🔭',
    '📡','💉','🩸','💊','🩹','🩺','🚪','🛗','🪞','🪟',
    '🛏','🛋','🚽','🪠','🚿','🛁','🪤','🧴','🧷','🧹',
  ],
};

const _categoryLabels = <String, String>{
  '😀': 'Smileys',
  '👋': 'People',
  '🐶': 'Nature',
  '🍕': 'Food',
  '⚽': 'Activities',
  '💡': 'Objects',
};

/// Premium composer bar with emoji picker + full attachment support
class ComposerBar extends StatefulWidget {
  final String conversationId;
  final Function(String, List<String>,
      {Map<String, dynamic>? voiceMetadata, List<String>? localPaths}) onSendMessage;
  final AttachmentManager attachmentManager;

  const ComposerBar({
    Key? key,
    required this.conversationId,
    required this.onSendMessage,
    required this.attachmentManager,
  }) : super(key: key);

  @override
  State<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<ComposerBar>
    with SingleTickerProviderStateMixin {
  late TextEditingController _textController;
  late AnimationController _sendButtonAnim;
  bool _hasText = false;
  bool _showVoiceRecorder = false;
  bool _showEmojiPicker = false;
  List<AttachmentPreview> _attachments = [];
  StreamSubscription? _attachmentSubscription;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _sendButtonAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _textController.addListener(_onTextChanged);

    _attachmentSubscription =
        widget.attachmentManager.attachments.listen((attachments) {
      setState(() => _attachments = attachments);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _sendButtonAnim.dispose();
    _attachmentSubscription?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
      if (hasText) {
        _sendButtonAnim.forward();
      } else {
        _sendButtonAnim.reverse();
      }
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) _showVoiceRecorder = false;
    });
  }

  void _insertEmoji(String emoji) {
    final text = _textController.text;
    final sel = _textController.selection;
    final cursor = sel.isValid ? sel.baseOffset : text.length;
    final newText = text.substring(0, cursor) + emoji + text.substring(cursor);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + emoji.length),
    );
  }

  bool get _canSend {
    final hasContent = _hasText || _attachments.isNotEmpty;
    if (!hasContent) return false;
    return !_attachments.any((a) => a.state == AttachmentState.failed);
  }

  Future<void> _send() async {
    if (!_canSend) return;

    final text = _textController.text.trim();

    try {
      final uploadResult =
          await widget.attachmentManager.uploadAllAttachments();
      final localPaths = uploadResult['localPaths'] as List<String>?;
      final uploadIds = uploadResult['uploadIds'] as List<String>;
      final voiceMetadata =
          uploadResult['voiceMetadata'] as Map<String, dynamic>?;

      if (text.isNotEmpty || uploadIds.isNotEmpty) {
        widget.onSendMessage(text, uploadIds, voiceMetadata: voiceMetadata, localPaths: localPaths);
        _textController.clear();
        setState(() {
          _hasText = false;
          _showEmojiPicker = false;
        });
        await widget.attachmentManager.clearAllAttachments();
      } else if (_attachments.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Upload failed. Please try again.'),
            backgroundColor: DesignTokens.surfaceGlass,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: DesignTokens.surfaceGlass,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Voice recorder
        if (_showVoiceRecorder)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            decoration: BoxDecoration(
              color: DesignTokens.surfaceGlass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: VoiceRecorder(
                onRecordingComplete:
                    (audioPath, durationSeconds, waveformData, bytes) {
                  Uint8List? convertedBytes;
                  if (bytes != null) {
                    if (bytes is Uint8List) {
                      convertedBytes = bytes;
                    } else if (bytes is List<int>) {
                      convertedBytes = Uint8List.fromList(bytes);
                    }
                  }
                  widget.attachmentManager.addVoiceRecording(
                    audioPath: audioPath,
                    durationSeconds: durationSeconds,
                    waveformData: waveformData,
                    bytes: convertedBytes,
                  );
                  setState(() => _showVoiceRecorder = false);
                },
              ),
            ),
          ),

        // Attachment preview tray
        AttachmentPreviewTray(
          attachments: _attachments,
          onRemoveAttachment: widget.attachmentManager.removeAttachment,
          onRetryUpload: (id) => widget.attachmentManager.retryUpload(id),
        ),

        // Main composer row
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment button
              _ComposerIconButton(
                icon: Icons.add_rounded,
                onTap: _showAttachmentMenu,
                tooltip: 'Attach',
              ),
              const SizedBox(width: 8),

              // Text field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          style: DesignTokens.bodyL.copyWith(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Message…',
                            hintStyle: DesignTokens.bodyM,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          onTap: () {
                            // Close emoji picker when tapping text field
                            if (_showEmojiPicker) {
                              setState(() => _showEmojiPicker = false);
                            }
                          },
                        ),
                      ),
                      // Emoji toggle button
                      Padding(
                        padding: const EdgeInsets.only(right: 4, bottom: 4),
                        child: GestureDetector(
                          onTap: _toggleEmojiPicker,
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                _showEmojiPicker
                                    ? Icons.keyboard_rounded
                                    : Icons.emoji_emotions_rounded,
                                key: ValueKey(_showEmojiPicker),
                                color: _showEmojiPicker
                                    ? DesignTokens.accentGold
                                    : DesignTokens.textSecondary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send / mic button
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: _canSend
                    ? _SendButton(key: const ValueKey('send'), onTap: _send)
                    : _ComposerIconButton(
                        key: const ValueKey('mic'),
                        icon: Icons.mic_rounded,
                        onTap: () {
                          setState(() {
                            _showVoiceRecorder = true;
                            _showEmojiPicker = false;
                          });
                        },
                        tooltip: 'Voice message',
                        isAccent: false,
                      ),
              ),
            ],
          ),
        ),

        // Emoji picker panel
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: _showEmojiPicker
              ? _EmojiPickerPanel(onEmojiSelected: _insertEmoji)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showAttachmentMenu() {
    setState(() => _showEmojiPicker = false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttachmentSheet(
        onCamera: () {
          Navigator.pop(context);
          widget.attachmentManager.selectImages(fromCamera: true);
        },
        onGallery: () {
          Navigator.pop(context);
          widget.attachmentManager.selectImages(fromCamera: false);
        },
        onFile: () {
          Navigator.pop(context);
          widget.attachmentManager.selectFiles();
        },
        onVoice: () {
          Navigator.pop(context);
          setState(() => _showVoiceRecorder = true);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Emoji picker panel
// ─────────────────────────────────────────────────────────────────────────────
class _EmojiPickerPanel extends StatefulWidget {
  final ValueChanged<String> onEmojiSelected;
  const _EmojiPickerPanel({required this.onEmojiSelected});

  @override
  State<_EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<_EmojiPickerPanel> {
  String _selectedCategory = '😀';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _displayedEmojis {
    if (_searchQuery.isNotEmpty) {
      // Search across all categories
      return _emojiCategories.values
          .expand((e) => e)
          .where((e) => e.contains(_searchQuery))
          .toList();
    }
    return _emojiCategories[_selectedCategory] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _searchController,
                style: DesignTokens.bodyM.copyWith(
                  color: DesignTokens.textLight,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Search emoji…',
                  hintStyle: DesignTokens.bodyM.copyWith(fontSize: 13),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: DesignTokens.textSecondary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _searchController.clear(),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: DesignTokens.textSecondary,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                ),
              ),
            ),
          ),

          // Category tabs (hidden during search)
          if (_searchQuery.isEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: _emojiCategories.keys.map((cat) {
                  final isSelected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? DesignTokens.accentGold.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? DesignTokens.accentGold.withOpacity(0.6)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat, style: const TextStyle(fontSize: 16)),
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            Text(
                              _categoryLabels[cat] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: DesignTokens.accentGold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Divider
          Container(height: 1, color: Colors.white.withOpacity(0.05)),

          // Emoji grid
          Expanded(
            child: _displayedEmojis.isEmpty
                ? Center(
                    child: Text(
                      'No emoji found',
                      style: DesignTokens.bodyM,
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: _displayedEmojis.length,
                    itemBuilder: (context, index) {
                      final emoji = _displayedEmojis[index];
                      return _EmojiCell(
                        emoji: emoji,
                        onTap: () => widget.onEmojiSelected(emoji),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single emoji cell with hover/press effect
// ─────────────────────────────────────────────────────────────────────────────
class _EmojiCell extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;
  const _EmojiCell({required this.emoji, required this.onTap});

  @override
  State<_EmojiCell> createState() => _EmojiCellState();
}

class _EmojiCellState extends State<_EmojiCell> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _pressed
              ? DesignTokens.accentGold.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.emoji,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Send button
// ─────────────────────────────────────────────────────────────────────────────
class _SendButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SendButton({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [DesignTokens.accentGold, Color(0xFF8B6914)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: DesignTokens.accentGold.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Composer icon button
// ─────────────────────────────────────────────────────────────────────────────
class _ComposerIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool isAccent;

  const _ComposerIconButton({
    Key? key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.isAccent = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isAccent
                ? DesignTokens.accentGold.withOpacity(0.15)
                : Colors.white.withOpacity(0.06),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Icon(
            icon,
            color: isAccent
                ? DesignTokens.accentGold
                : DesignTokens.textSecondary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attachment bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _AttachmentSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onFile;
  final VoidCallback onVoice;

  const _AttachmentSheet({
    required this.onCamera,
    required this.onGallery,
    required this.onFile,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Share',
              style: DesignTokens.bodyL.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Options grid
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AttachOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFF6C63FF),
                  onTap: onCamera,
                ),
                _AttachOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF4CAF50),
                  onTap: onGallery,
                ),
                _AttachOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'File',
                  color: DesignTokens.accentGold,
                  onTap: onFile,
                ),
                _AttachOption(
                  icon: Icons.mic_rounded,
                  label: 'Voice',
                  color: Colors.redAccent,
                  onTap: onVoice,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: DesignTokens.caption.copyWith(
              color: DesignTokens.textLight.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
