import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/network/bko_api.dart';
import '../../../core/theme/bko_theme.dart';
import '../../../core/widgets/bko_bounceable.dart';
import '../../../core/widgets/bko_haptics.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_modal.dart';

/// Feuille modale des commentaires d'un épisode.
/// Conforme aux compétences `mobile-designer` et `apple-design` :
/// - Icônes Iconsax uniquement (Linear par défaut, Bold pour l'actif)
/// - Zéro ombre, zéro dégradé, surfaces solides élégantes
/// - Aimer un commentaire (Like avec micro-animation spring & double-tap to like)
/// - Répondre à un commentaire avec le geste Swipe-to-Reply inspiré de WhatsApp
/// - Réagir avec des émotions (Appui long style WhatsApp / Telegram avec dock flottant)
/// - Haptiques anti-saturation calibrées (tapDown, light, medium, select)
class EpisodeCommentsSheet extends ConsumerStatefulWidget {
  final String episodeId;
  final String episodeTitle;
  final Function(int count)? onCommentCountChanged;

  const EpisodeCommentsSheet({
    super.key,
    required this.episodeId,
    required this.episodeTitle,
    this.onCommentCountChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String episodeId,
    required String episodeTitle,
    Function(int count)? onCommentCountChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EpisodeCommentsSheet(
        episodeId: episodeId,
        episodeTitle: episodeTitle,
        onCommentCountChanged: onCommentCountChanged,
      ),
    );
  }

  @override
  ConsumerState<EpisodeCommentsSheet> createState() =>
      _EpisodeCommentsSheetState();
}

class _EpisodeCommentsSheetState extends ConsumerState<EpisodeCommentsSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _comments = [];
  int _totalCount = 0;

  // États pour les likes, réactions et réponses
  final Set<String> _likedCommentIds = {};
  final Map<String, int> _likeCounts = {};
  final Map<String, String?> _userReactions = {};
  final Map<String, Map<String, int>> _commentReactions = {};

  // Commentaire auquel on est en train de répondre
  Map<String, dynamic>? _replyingTo;

  // Commentaire sur lequel le dock de réactions est actuellement ouvert
  String? _activeReactionsCommentId;

  // Palette d'émotions rapides (style WhatsApp / Telegram)
  static const List<String> _reactionEmojis = ['❤️', '🔥', '😂', '👏', '💡', '🎙️'];

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _inputFocusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _getAuthorName(Map<String, dynamic> comment) {
    final author = comment['user'] is Map ? comment['user'] as Map : const {};
    return '${author['fullName'] ?? author['username'] ?? 'Auditeur'}';
  }

  Future<void> _fetchComments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _activeReactionsCommentId = null;
    });

    try {
      final token = ref.read(authProvider).token;
      final res = await BkoApi.get(
        '/episodes/${widget.episodeId}/comments?limit=100',
        token: token,
      );

      if (!mounted) return;
      if (res is List) {
        final loaded = res
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();

        // Initialisation des compteurs et réactions
        for (final c in loaded) {
          final id = '${c['id']}';
          _likeCounts[id] ??= (c['likesCount'] as num?)?.toInt() ?? 0;
          if (c['userLiked'] == true) {
            _likedCommentIds.add(id);
          }
          if (c['userReaction'] != null) {
            _userReactions[id] = '${c['userReaction']}';
          }
          if (c['reactions'] is Map) {
            final m = Map<String, int>.from(c['reactions']);
            _commentReactions[id] = m;
          }
        }

        setState(() {
          _comments = loaded;
          _totalCount = _comments.length;
          _isLoading = false;
        });
        widget.onCommentCountChanged?.call(_totalCount);
      } else {
        setState(() {
          _comments = [];
          _totalCount = 0;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Impossible de charger les commentaires.';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final rawText = _commentCtrl.text.trim();
    if (rawText.isEmpty) return;

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) {
      AuthRequiredModal.show(context, actionTitle: 'commenter cet épisode');
      return;
    }

    // Si on répond à quelqu'un, on mentionne l'auteur
    final String finalText;
    if (_replyingTo != null) {
      final authorName = _getAuthorName(_replyingTo!);
      final prefix = '@$authorName ';
      finalText = rawText.startsWith(prefix) ? rawText : '$prefix$rawText';
    } else {
      finalText = rawText;
    }

    setState(() => _isSending = true);

    try {
      final res = await BkoApi.post(
        '/episodes/${widget.episodeId}/comments',
        {'text': finalText},
        token: auth.token,
      );

      if (!mounted) return;
      _commentCtrl.clear();
      _inputFocusNode.unfocus();
      BkoHaptics.success();

      if (res is Map) {
        final newComment = Map<String, dynamic>.from(res);
        final newId = '${newComment['id']}';
        _likeCounts[newId] = 0;

        setState(() {
          _comments = [newComment, ..._comments];
          _totalCount += 1;
          _isSending = false;
          _replyingTo = null;
        });
        widget.onCommentCountChanged?.call(_totalCount);
      } else {
        setState(() {
          _isSending = false;
          _replyingTo = null;
        });
        _fetchComments();
      }

      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: const Color(0xFF222226),
          content: Text(e.message, style: const TextStyle(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          elevation: 0,
          backgroundColor: Color(0xFF222226),
          content: Text('Impossible d’envoyer votre commentaire.',
              style: TextStyle(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleLike(String commentId) {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      AuthRequiredModal.show(context, actionTitle: 'aimer ce commentaire');
      return;
    }

    BkoHaptics.light();

    final isLiked = _likedCommentIds.contains(commentId);
    setState(() {
      if (isLiked) {
        _likedCommentIds.remove(commentId);
        _likeCounts[commentId] = ((_likeCounts[commentId] ?? 1) - 1).clamp(0, 999999);
      } else {
        _likedCommentIds.add(commentId);
        _likeCounts[commentId] = (_likeCounts[commentId] ?? 0) + 1;
      }
    });

    if (auth.token != null) {
      if (isLiked) {
        BkoApi.delete('/comments/$commentId/like', token: auth.token).catchError((_) {});
      } else {
        BkoApi.post('/comments/$commentId/like', {}, token: auth.token).catchError((_) {});
      }
    }
  }

  void _onDoubleTapComment(String commentId) {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      AuthRequiredModal.show(context, actionTitle: 'aimer ce commentaire');
      return;
    }

    if (!_likedCommentIds.contains(commentId)) {
      _toggleLike(commentId);
    } else {
      BkoHaptics.light();
    }
  }

  void _triggerReplyTo(Map<String, dynamic> comment) {
    BkoHaptics.tapDown();
    setState(() {
      _replyingTo = comment;
      _activeReactionsCommentId = null;
    });

    _inputFocusNode.requestFocus();
  }

  void _cancelReply() {
    BkoHaptics.light();
    setState(() => _replyingTo = null);
  }

  void _toggleReaction(String commentId, String emoji) {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      AuthRequiredModal.show(context, actionTitle: 'réagir à ce commentaire');
      return;
    }

    BkoHaptics.select();

    final currentReaction = _userReactions[commentId];
    setState(() {
      final map = Map<String, int>.from(_commentReactions[commentId] ?? {});

      if (currentReaction == emoji) {
        // Retirer la réaction
        _userReactions[commentId] = null;
        final count = (map[emoji] ?? 1) - 1;
        if (count <= 0) {
          map.remove(emoji);
        } else {
          map[emoji] = count;
        }
      } else {
        // Si une autre réaction était active, la décrémenter
        if (currentReaction != null) {
          final oldCount = (map[currentReaction] ?? 1) - 1;
          if (oldCount <= 0) {
            map.remove(currentReaction);
          } else {
            map[currentReaction] = oldCount;
          }
        }
        // Ajouter la nouvelle réaction
        _userReactions[commentId] = emoji;
        map[emoji] = (map[emoji] ?? 0) + 1;
      }

      _commentReactions[commentId] = map;
      _activeReactionsCommentId = null;
    });

    if (auth.token != null) {
      if (currentReaction == emoji) {
        BkoApi.delete('/comments/$commentId/reactions', token: auth.token).catchError((_) {});
      } else {
        BkoApi.post('/comments/$commentId/reactions', {'emoji': emoji}, token: auth.token).catchError((_) {});
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    BkoHaptics.medium();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF28282E)),
        ),
        title: Text(
          'Supprimer le commentaire ?',
          style: BkoTheme.fontPoppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Cette action est irréversible.',
          style: BkoTheme.fontLato(fontSize: 13, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await BkoApi.delete('/comments/$commentId', token: token);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => '${c['id']}' == commentId);
        _totalCount = _comments.length;
        if (_replyingTo != null && '${_replyingTo!['id']}' == commentId) {
          _replyingTo = null;
        }
      });
      widget.onCommentCountChanged?.call(_totalCount);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          elevation: 0,
          backgroundColor: Color(0xFF222226),
          content: Text('Commentaire supprimé.',
              style: TextStyle(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          elevation: 0,
          backgroundColor: Color(0xFF222226),
          content: Text('Impossible de supprimer le commentaire.',
              style: TextStyle(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'À l’instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).user?['id'];
    const bgSurface = Color(0xFF141416);
    const border = Color(0xFF262626);
    const textPri = Colors.white;
    const textSec = Colors.white70;

    return GestureDetector(
      onTap: () {
        if (_activeReactionsCommentId != null) {
          setState(() => _activeReactionsCommentId = null);
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: border),
        ),
        padding: EdgeInsets.only(
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            // Barre de saisie tactile supérieure (Drag handle)
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // En-tête
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Commentaires',
                        style: BkoTheme.fontPoppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textPri,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_totalCount',
                          style: BkoTheme.fontPoppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: BkoTheme.goldAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(IconsaxPlusLinear.close_circle,
                        color: Colors.white70, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFF242428)),

            // Liste des commentaires
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: BkoTheme.goldAccent))
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_errorMessage!,
                                  style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _fetchComments,
                                child: const Text('Réessayer',
                                    style: TextStyle(color: BkoTheme.goldAccent)),
                              ),
                            ],
                          ),
                        )
                      : _comments.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      IconsaxPlusLinear.message_text,
                                      size: 42,
                                      color: Colors.white38,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Soyez le premier à commenter cet épisode !',
                                      style: BkoTheme.fontLato(
                                          fontSize: 14, color: textSec),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: BkoTheme.goldAccent,
                              backgroundColor: const Color(0xFF1E1E22),
                              onRefresh: _fetchComments,
                              child: ListView.separated(
                                controller: _scrollCtrl,
                                physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics()),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                itemCount: _comments.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 16, color: Color(0xFF1E1E22)),
                                itemBuilder: (context, index) {
                                  final item = _comments[index];
                                  final commentId = '${item['id']}';
                                  final authorName = _getAuthorName(item);
                                  final author = item['user'] is Map
                                      ? item['user'] as Map
                                      : const {};
                                  final avatarUrl = '${author['avatar'] ?? ''}';
                                  final text = '${item['text'] ?? ''}';
                                  final dateStr = _formatDate(item['createdAt']);
                                  final isAuthor = currentUserId != null &&
                                      ('${item['userId']}' == '$currentUserId' ||
                                          '${author['id']}' == '$currentUserId');

                                  final isLiked = _likedCommentIds.contains(commentId);
                                  final likeCount = _likeCounts[commentId] ?? 0;
                                  final reactions = _commentReactions[commentId] ?? {};
                                  final userReaction = _userReactions[commentId];
                                  final isReactionsOpen =
                                      _activeReactionsCommentId == commentId;

                                  return _CommentItem(
                                    commentId: commentId,
                                    authorName: authorName,
                                    avatarUrl: avatarUrl,
                                    text: text,
                                    dateStr: dateStr,
                                    isAuthor: isAuthor,
                                    isLiked: isLiked,
                                    likeCount: likeCount,
                                    reactions: reactions,
                                    userReaction: userReaction,
                                    isReactionsOpen: isReactionsOpen,
                                    reactionEmojis: _reactionEmojis,
                                    onLike: () => _toggleLike(commentId),
                                    onDoubleTap: () => _onDoubleTapComment(commentId),
                                    onReply: () => _triggerReplyTo(item),
                                    onToggleReaction: (emoji) =>
                                        _toggleReaction(commentId, emoji),
                                    onOpenReactions: () {
                                      BkoHaptics.medium();
                                      setState(() {
                                        _activeReactionsCommentId =
                                            isReactionsOpen ? null : commentId;
                                      });
                                    },
                                    onDelete: () => _deleteComment(commentId),
                                  );
                                },
                              ),
                            ),
            ),

            // Bandeau de prévisualisation "Réponse à @..." inspiré de WhatsApp
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF1B1B20),
                  border: Border(
                    top: BorderSide(color: Color(0xFF28282E)),
                    left: BorderSide(color: BkoTheme.goldAccent, width: 3.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(IconsaxPlusLinear.arrow_right_3,
                        size: 16, color: BkoTheme.goldAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Réponse à @${_getAuthorName(_replyingTo!)}',
                            style: BkoTheme.fontPoppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: BkoTheme.goldAccent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_replyingTo!['text'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BkoTheme.fontLato(
                              fontSize: 11.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: const Icon(IconsaxPlusLinear.close_circle,
                          size: 18, color: Colors.white54),
                      onPressed: _cancelReply,
                    ),
                  ],
                ),
              ),

            // Barre de saisie inférieure avec bouton envoyer Iconsax
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF18181C),
                border: Border(top: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF222228),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _commentCtrl,
                        focusNode: _inputFocusNode,
                        minLines: 1,
                        maxLines: 4,
                        style: BkoTheme.fontLato(fontSize: 13.5, color: textPri),
                        decoration: InputDecoration(
                          hintText: _replyingTo != null
                              ? 'Répondre à @${_getAuthorName(_replyingTo!)}...'
                              : 'Participer à la discussion...',
                          hintStyle: BkoTheme.fontLato(
                              fontSize: 13, color: Colors.white38),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BkoBounceable(
                    onTap: _isSending ? null : _submitComment,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: BkoTheme.goldAccent,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              ),
                            )
                          : const Icon(
                              IconsaxPlusLinear.send_1,
                              color: Colors.black,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Élément de commentaire individuel avec micro-interactions complètes :
/// - Swipe-to-Reply avec résistance physique (friction spring)
/// - Double-tap pour aimer avec coeur flottant animé
/// - Long-press pour afficher le dock d'émotions
/// - Badges de réactions cliquables
class _CommentItem extends StatefulWidget {
  final String commentId;
  final String authorName;
  final String avatarUrl;
  final String text;
  final String dateStr;
  final bool isAuthor;
  final bool isLiked;
  final int likeCount;
  final Map<String, int> reactions;
  final String? userReaction;
  final bool isReactionsOpen;
  final List<String> reactionEmojis;
  final VoidCallback onLike;
  final VoidCallback onDoubleTap;
  final VoidCallback onReply;
  final Function(String emoji) onToggleReaction;
  final VoidCallback onOpenReactions;
  final VoidCallback onDelete;

  const _CommentItem({
    required this.commentId,
    required this.authorName,
    required this.avatarUrl,
    required this.text,
    required this.dateStr,
    required this.isAuthor,
    required this.isLiked,
    required this.likeCount,
    required this.reactions,
    required this.userReaction,
    required this.isReactionsOpen,
    required this.reactionEmojis,
    required this.onLike,
    required this.onDoubleTap,
    required this.onReply,
    required this.onToggleReaction,
    required this.onOpenReactions,
    required this.onDelete,
  });

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _thresholdReached = false;
  bool _showFloatingHeart = false;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // Seul le glissement vers la droite (Swipe to Reply à la WhatsApp) est capté
    if (details.delta.dx > 0 || _dragOffset > 0) {
      setState(() {
        _dragOffset = (_dragOffset + details.delta.dx * 0.55).clamp(0.0, 72.0);
        if (_dragOffset >= 48.0 && !_thresholdReached) {
          _thresholdReached = true;
          BkoHaptics.tapDown();
        } else if (_dragOffset < 48.0 && _thresholdReached) {
          _thresholdReached = false;
        }
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_thresholdReached) {
      widget.onReply();
    }
    setState(() {
      _dragOffset = 0.0;
      _thresholdReached = false;
    });
  }

  void _handleDoubleTap() {
    widget.onDoubleTap();
    setState(() => _showFloatingHeart = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showFloatingHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    const textPri = Colors.white;
    const textSec = Colors.white70;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Indicateur d'action Swipe-to-Reply incurvé derrière le commentaire
        if (_dragOffset > 0)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: (_dragOffset / 48.0).clamp(0.0, 1.0),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _thresholdReached
                        ? BkoTheme.goldAccent.withValues(alpha: 0.22)
                        : const Color(0xFF222228),
                    border: Border.all(
                      color: _thresholdReached
                          ? BkoTheme.goldAccent
                          : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    IconsaxPlusLinear.arrow_right_3,
                    size: 16,
                    color: _thresholdReached
                        ? BkoTheme.goldAccent
                        : Colors.white70,
                  ),
                ),
              ),
            ),
          ),

        // Corps principal du commentaire translaté selon le glissement
        Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            onDoubleTap: _handleDoubleTap,
            onLongPress: widget.onOpenReactions,
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar utilisateur
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFF282830),
                  backgroundImage: widget.avatarUrl.isNotEmpty &&
                          widget.avatarUrl.startsWith('http')
                      ? NetworkImage(widget.avatarUrl)
                      : null,
                  child: widget.avatarUrl.isEmpty ||
                          !widget.avatarUrl.startsWith('http')
                      ? Text(
                          widget.authorName.isNotEmpty
                              ? widget.authorName[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: BkoTheme.goldAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),

                // Contenu & actions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête : Pseudo, Date & Suppression
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.authorName,
                            style: BkoTheme.fontPoppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textPri,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                widget.dateStr,
                                style: BkoTheme.fontLato(
                                  fontSize: 11,
                                  color: Colors.white38,
                                ),
                              ),
                              if (widget.isAuthor) ...[
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: widget.onDelete,
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      IconsaxPlusLinear.trash,
                                      size: 14,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Texte du commentaire
                      Text(
                        widget.text,
                        style: BkoTheme.fontLato(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.38,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Ligne d'actions sous le commentaire : Like, Répondre & Réagir
                      Row(
                        children: [
                          // 1. Bouton Like avec animation et compteur
                          BkoBounceable(
                            onTap: widget.onLike,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.isLiked
                                      ? IconsaxPlusBold.heart
                                      : IconsaxPlusLinear.heart,
                                  size: 15,
                                  color: widget.isLiked
                                      ? const Color(0xFFFF4D4D)
                                      : textSec,
                                ),
                                if (widget.likeCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.likeCount}',
                                    style: BkoTheme.fontLato(
                                      fontSize: 11.5,
                                      fontWeight: widget.isLiked
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: widget.isLiked
                                          ? const Color(0xFFFF4D4D)
                                          : textSec,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // 2. Bouton Répondre
                          BkoBounceable(
                            onTap: widget.onReply,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  IconsaxPlusLinear.messages_2,
                                  size: 14,
                                  color: textSec,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Répondre',
                                  style: BkoTheme.fontLato(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),

                          // 3. Bouton Réagir (dock d'émotions)
                          BkoBounceable(
                            onTap: widget.onOpenReactions,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  IconsaxPlusLinear.emoji_happy,
                                  size: 14,
                                  color: textSec,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Réagir',
                                  style: BkoTheme.fontLato(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: textSec,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Badges de réactions existantes (chips élégantes)
                      if (widget.reactions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: widget.reactions.entries.map((entry) {
                            final emoji = entry.key;
                            final count = entry.value;
                            final isMyReaction = widget.userReaction == emoji;

                            return BkoBounceable(
                              onTap: () => widget.onToggleReaction(emoji),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isMyReaction
                                      ? BkoTheme.goldAccent
                                          .withValues(alpha: 0.18)
                                      : const Color(0xFF1E1E24),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isMyReaction
                                        ? BkoTheme.goldAccent
                                            .withValues(alpha: 0.45)
                                        : const Color(0xFF2C2C34),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(emoji,
                                        style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$count',
                                      style: BkoTheme.fontLato(
                                        fontSize: 11,
                                        fontWeight: isMyReaction
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: isMyReaction
                                            ? BkoTheme.goldAccent
                                            : textSec,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Dock flottant de sélection d'émotions (style WhatsApp)
        if (widget.isReactionsOpen)
          Positioned(
            left: 48,
            top: -38,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF32323C)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.reactionEmojis.map((emoji) {
                    final isSelected = widget.userReaction == emoji;
                    return BkoBounceable(
                      onTap: () => widget.onToggleReaction(emoji),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? BkoTheme.goldAccent.withValues(alpha: 0.22)
                              : Colors.transparent,
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

        // Animation popup grand coeur au centre du commentaire lors d'un double tap
        if (_showFloatingHeart)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Icon(
                  IconsaxPlusBold.heart,
                  size: 58,
                  color: Color(0xFFFF4D4D),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
