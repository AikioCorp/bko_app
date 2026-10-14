import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/bko_api.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/shell/shell_providers.dart';
import '../../features/notifications/services/notification_destination_handler.dart';

const int _kInactivityDelaySeconds = 180; // 3 minutes d'inactivité

/// Modèle pour un message dans le chat avec Ali
class AliChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime timestamp;

  AliChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.timestamp,
  });
}

/// Contrôleur d'état Riverpod pour le chat d'Ali
final aliChatProvider =
    StateNotifierProvider<AliChatNotifier, AliChatState>((ref) {
  return AliChatNotifier(ref);
});

class AliChatState {
  final List<AliChatMessage> messages;
  final bool isLoading;
  final int unreadCount;
  final bool isChatOpen;

  const AliChatState({
    this.messages = const [],
    this.isLoading = false,
    this.unreadCount = 0,
    this.isChatOpen = false,
  });

  AliChatState copyWith({
    List<AliChatMessage>? messages,
    bool? isLoading,
    int? unreadCount,
    bool? isChatOpen,
  }) {
    return AliChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      unreadCount: unreadCount ?? this.unreadCount,
      isChatOpen: isChatOpen ?? this.isChatOpen,
    );
  }
}

class AliChatNotifier extends StateNotifier<AliChatState> {
  final Ref _ref;
  Timer? _inactivityTimer;
  bool _hasSentInactivity = false;
  String? _sessionId;

  AliChatNotifier(this._ref) : super(const AliChatState()) {
    _initSession();
  }

  Future<void> _initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString('bko_ali_session_id');
    if (_sessionId == null) {
      _sessionId = 'session_app_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('bko_ali_session_id', _sessionId!);
    }

    final auth = _ref.read(authProvider);
    final user = auth.user;
    final fullName = user?['fullName'] ?? user?['name'] ?? '';
    final firstName = fullName.toString().split(' ').first;

    final welcomeText = firstName.isNotEmpty
        ? 'Salut $firstName ! Moi c\'est Ali, ton conseiller d’écoute sur Bamako Podcast. Qu\'est-ce qui te ferait plaisir d\'écouter aujourd\'hui ?'
        : 'Salut ! Moi c\'est Ali, ton conseiller d’écoute sur Bamako Podcast. Qu\'est-ce qui te ferait plaisir d\'écouter aujourd\'hui ?';

    state = state.copyWith(
      messages: [
        AliChatMessage(
          id: 'welcome',
          isUser: false,
          text: welcomeText,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  void setChatOpen(bool open) {
    state = state.copyWith(
      isChatOpen: open,
      unreadCount: open ? 0 : state.unreadCount,
    );
    if (!open) {
      _inactivityTimer?.cancel();
    } else {
      _startInactivityTimer();
    }
  }

  void notifyTyping() {
    // Si l'utilisateur tape, annuler et repousser le timer
    _inactivityTimer?.cancel();
    _startInactivityTimer();
  }

  /// 4. RELANCE APRÈS INACTIVITÉ (3 MINUTES)
  /// Affiche la relance DIRECTEMENT en local sans appel au modèle pour économiser l'API et supprimer toute latence.
  /// Conditions strictes :
  /// - Annulée si audio en cours de lecture
  /// - Annulée si chat fermé
  /// - Annulée si saisie ou requête en cours
  /// - 1 seule relance max
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();

    // Verrous : si chat fermé ou lecture audio active, pas de relance
    final isPlaying = _ref.read(activeEpisodeProvider.select((s) => s.isPlaying));
    if (!state.isChatOpen || isPlaying || _hasSentInactivity) {
      return;
    }

    _inactivityTimer = Timer(const Duration(seconds: _kInactivityDelaySeconds), () {
      _triggerInactivityFollowUp();
    });
  }

  void _triggerInactivityFollowUp() {
    final isPlaying = _ref.read(activeEpisodeProvider.select((s) => s.isPlaying));
    if (_hasSentInactivity || state.isLoading || !state.isChatOpen || isPlaying) {
      return;
    }
    _hasSentInactivity = true;

    final auth = _ref.read(authProvider);
    final user = auth.user;
    final fullName = user?['fullName'] ?? user?['name'] ?? '';
    final firstName = fullName.toString().split(' ').first;

    final followUpText = firstName.isNotEmpty
        ? 'Hey $firstName, tu es toujours là ? 🙂'
        : 'Hey, tu es toujours là ? 🙂';

    final newMsg = AliChatMessage(
      id: 'relance_${DateTime.now().millisecondsSinceEpoch}',
      isUser: false,
      text: followUpText,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, newMsg],
    );
  }

  /// 3. TRANSMISSION SÉCURISÉE VIA LE BACKEND (ZERO TRUST)
  /// Le client passe par /advisor/chat avec le JWT Session Bearer géré par BkoApi.
  /// L'identité est résolue et vérifiée côté serveur.
  Future<void> sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || state.isLoading) return;

    _inactivityTimer?.cancel();
    _hasSentInactivity = false;

    final userMsg = AliChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      isUser: true,
      text: cleanText,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
    );

    try {
      final response = await BkoApi.post(
        'advisor/chat',
        {
          'sessionId': _sessionId ?? 'bko_mobile_user',
          'chatInput': cleanText,
        },
      );

      final data = response is Map ? response['data'] : null;
      final output = data is Map ? (data['output'] ?? data['text']) : null;
      final aliReply = output?.toString() ?? 'Je regarde ça pour toi !';

      final aliMsg = AliChatMessage(
        id: 'ali_${DateTime.now().millisecondsSinceEpoch}',
        isUser: false,
        text: aliReply,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aliMsg],
        isLoading: false,
        unreadCount: state.isChatOpen ? 0 : state.unreadCount + 1,
      );

      // Relancer le chronomètre de 3 minutes
      _startInactivityTimer();
    } catch (_) {
      _handleError('Désolé, je n\'ai pas pu accéder au catalogue. Réessaie dans un instant !');
    }
  }

  void _handleError(String message) {
    state = state.copyWith(
      isLoading: false,
      messages: [
        ...state.messages,
        AliChatMessage(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          isUser: false,
          text: message,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }
}

/// Pastille flottante glissable (Draggable) d'Ali sur mobile
class BkoAliDraggableBubble extends ConsumerStatefulWidget {
  const BkoAliDraggableBubble({super.key});

  @override
  ConsumerState<BkoAliDraggableBubble> createState() =>
      _BkoAliDraggableBubbleState();
}

class _BkoAliDraggableBubbleState extends ConsumerState<BkoAliDraggableBubble> {
  Offset? _position;
  bool _hasMoved = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPosition();
  }

  Future<void> _loadSavedPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final dx = prefs.getDouble('bko_ali_pos_x');
    final dy = prefs.getDouble('bko_ali_pos_y');
    if (dx != null && dy != null && mounted) {
      setState(() {
        _position = Offset(dx, dy);
      });
    }
  }

  Future<void> _savePosition(Offset pos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bko_ali_pos_x', pos.dx);
    await prefs.setDouble('bko_ali_pos_y', pos.dy);
  }

  void _openChatModal() {
    if (_hasMoved) return;
    BkoHaptics.selection();
    ref.read(aliChatProvider.notifier).setChatOpen(true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AliChatBottomSheet(),
    ).whenComplete(() {
      if (mounted) {
        ref.read(aliChatProvider.notifier).setChatOpen(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aliChatProvider);
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    final defaultPos = Offset(
      size.width - 70,
      size.height - padding.bottom - 160,
    );
    final currentPos = _position ?? defaultPos;

    return Positioned(
      left: currentPos.dx,
      top: currentPos.dy,
      child: GestureDetector(
        onPanStart: (_) {
          _hasMoved = false;
        },
        onPanUpdate: (details) {
          _hasMoved = true;
          final nextX =
              (currentPos.dx + details.delta.dx).clamp(12.0, size.width - 68.0);
          final nextY = (currentPos.dy + details.delta.dy)
              .clamp(padding.top + 20, size.height - padding.bottom - 80);

          setState(() {
            _position = Offset(nextX, nextY);
          });
        },
        onPanEnd: (_) {
          if (_hasMoved && _position != null) {
            _savePosition(_position!);
          }
        },
        onTap: _openChatModal,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFBF00),
                    width: 2.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    IconsaxPlusLinear.headphone,
                    color: Color(0xFFFFBF00),
                    size: 24,
                  ),
                ),
              ),

              if (chatState.unreadCount > 0 && !chatState.isChatOpen)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFBF00),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF141416),
                        width: 2,
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Center(
                      child: Text(
                        '${chatState.unreadCount}',
                        style: const TextStyle(
                          color: Color(0xFF0E0E10),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),

              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF141416),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet pour discuter avec Ali
class _AliChatBottomSheet extends ConsumerStatefulWidget {
  const _AliChatBottomSheet();

  @override
  ConsumerState<_AliChatBottomSheet> createState() =>
      _AliChatBottomSheetState();
}

class _AliChatBottomSheetState extends ConsumerState<_AliChatBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _submit() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    ref.read(aliChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aliChatProvider);
    final viewInsets = MediaQuery.of(context).viewInsets;

    ref.listen(aliChatProvider.select((s) => s.messages.length), (_, __) {
      _scrollToBottom();
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      margin: EdgeInsets.only(bottom: viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF121214),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF27272A), width: 1),
          left: BorderSide(color: Color(0xFF27272A), width: 1),
          right: BorderSide(color: Color(0xFF27272A), width: 1),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3F3F46),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C20),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFBF00),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          IconsaxPlusLinear.magicpen,
                          color: Color(0xFFFFBF00),
                          size: 18,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF121214),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Ali',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF27272A),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Conseiller',
                              style: TextStyle(
                                color: Color(0xFFFFBF00),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Bamako Podcast • Toujours là',
                        style: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(IconsaxPlusLinear.close_circle,
                      color: Color(0xFFA1A1AA), size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF27272A), height: 1),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chatState.messages.length,
              itemBuilder: (context, index) {
                final msg = chatState.messages[index];
                return _buildMessageItem(context, msg);
              },
            ),
          ),

          if (chatState.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2E2E34)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFFBF00),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Ali réfléchit...',
                        style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              MediaQuery.of(context).padding.bottom > 0
                  ? MediaQuery.of(context).padding.bottom + 8
                  : 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF18181B),
              border: Border(top: BorderSide(color: Color(0xFF27272A), width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onChanged: (_) {
                      ref.read(aliChatProvider.notifier).notifyTyping();
                    },
                    onSubmitted: (_) => _submit(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Demande un podcast, un thème, tes favoris...',
                      hintStyle:
                          const TextStyle(color: Color(0xFF71717A), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF121214),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2E2E34)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2E2E34)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFFBF00)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _submit,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFBF00),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        IconsaxPlusBold.send_2,
                        color: Color(0xFF0E0E10),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(BuildContext context, AliChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isUser ? const Color(0xFF27272A) : const Color(0xFF1C1C20),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
          border: Border.all(
            color: msg.isUser ? const Color(0xFF3F3F46) : const Color(0xFF2E2E34),
            width: 1,
          ),
        ),
        child: _renderFormattedText(context, msg.text),
      ),
    );
  }

  /// Rend le texte avec support des liens Markdown cliquables et du texte en gras.
  /// Normalise automatiquement tout lien complet en chemin interne Flutter.
  Widget _renderFormattedText(BuildContext context, String content) {
    final regex = RegExp(r'(\[[^\]]+\]\([^)]+\)|\*\*[^*]+\*\*)');
    final matches = regex.allMatches(content);

    if (matches.isEmpty) {
      return Text(
        content,
        style: const TextStyle(
          color: Color(0xFFE4E4E7),
          fontSize: 13.5,
          height: 1.4,
        ),
      );
    }

    final spans = <InlineSpan>[];
    int currentIndex = 0;

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: content.substring(currentIndex, match.start),
          style: const TextStyle(color: Color(0xFFE4E4E7), fontSize: 13.5, height: 1.4),
        ));
      }

      final matchedText = match.group(0)!;

      if (matchedText.startsWith('[') && matchedText.endsWith(')')) {
        final linkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
        final linkMatch = linkRegex.firstMatch(matchedText);
        if (linkMatch != null) {
          final label = linkMatch.group(1)!;
          final rawUrl = linkMatch.group(2)!;

          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop(); // Fermer le chat
                  // NotificationDestinationHandler gère la normalisation universelle
                  NotificationDestinationHandler.navigate(context, rawUrl);
                },
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFFFBF00),
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFFFFBF00),
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          );
        }
      } else if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        final boldContent = matchedText.substring(2, matchedText.length - 2);
        spans.add(TextSpan(
          text: boldContent,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
            height: 1.4,
          ),
        ));
      }

      currentIndex = match.end;
    }

    if (currentIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(currentIndex),
        style: const TextStyle(color: Color(0xFFE4E4E7), fontSize: 13.5, height: 1.4),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }
}
