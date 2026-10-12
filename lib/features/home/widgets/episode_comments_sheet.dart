import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/bko_api.dart';
import '../../../core/theme/bko_theme.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_modal.dart';

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
  final ScrollController _scrollCtrl = ScrollController();
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _comments = [];
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = ref.read(authProvider).token;
      final res = await BkoApi.get(
        '/episodes/${widget.episodeId}/comments?limit=100',
        token: token,
      );

      if (!mounted) return;
      if (res is List) {
        setState(() {
          _comments = res
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
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
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) {
      AuthRequiredModal.show(context,
          actionTitle: 'commenter cet épisode');
      return;
    }

    setState(() => _isSending = true);

    try {
      final res = await BkoApi.post(
        '/episodes/${widget.episodeId}/comments',
        {'text': text},
        token: auth.token,
      );

      if (!mounted) return;
      _commentCtrl.clear();
      FocusScope.of(context).unfocus();

      if (res is Map) {
        final newComment = Map<String, dynamic>.from(res);
        setState(() {
          _comments = [newComment, ..._comments];
          _totalCount += 1;
          _isSending = false;
        });
        widget.onCommentCountChanged?.call(_totalCount);
      } else {
        setState(() => _isSending = false);
        _fetchComments();
      }

      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’envoyer votre commentaire.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Supprimer le commentaire ?',
          style: BkoTheme.fontLato(
            fontSize: 16,
            fontWeight: FontWeight.bold,
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
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
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
      });
      widget.onCommentCountChanged?.call(_totalCount);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Commentaire supprimé.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de supprimer le commentaire.'),
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
          // Drag handle
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
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Commentaires',
                      style: BkoTheme.fontLato(
                        fontSize: 18,
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
                        style: BkoTheme.fontLato(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: BkoTheme.goldAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF242428)),

          // Comments List
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
                                  const Icon(Icons.chat_bubble_outline_rounded,
                                      size: 40, color: Colors.white38),
                                  const SizedBox(height: 10),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              itemCount: _comments.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 16, color: Color(0xFF1E1E22)),
                              itemBuilder: (context, index) {
                                final item = _comments[index];
                                final author = item['user'] is Map
                                    ? item['user'] as Map
                                    : const {};
                                final authorName =
                                    '${author['fullName'] ?? author['username'] ?? 'Auditeur'}';
                                final avatarUrl = '${author['avatar'] ?? ''}';
                                final text = '${item['text'] ?? ''}';
                                final dateStr = _formatDate(item['createdAt']);
                                final isAuthor = currentUserId != null &&
                                    ('${item['userId']}' == '$currentUserId' ||
                                        '${author['id']}' == '$currentUserId');

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Avatar
                                    CircleAvatar(
                                      radius: 17,
                                      backgroundColor: const Color(0xFF282830),
                                      backgroundImage: avatarUrl.isNotEmpty &&
                                              avatarUrl.startsWith('http')
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      child: avatarUrl.isEmpty ||
                                              !avatarUrl.startsWith('http')
                                          ? Text(
                                              authorName.isNotEmpty
                                                  ? authorName[0].toUpperCase()
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

                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                authorName,
                                                style: BkoTheme.fontLato(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: textPri,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    dateStr,
                                                    style: BkoTheme.fontLato(
                                                      fontSize: 11,
                                                      color: Colors.white38,
                                                    ),
                                                  ),
                                                  if (isAuthor) ...[
                                                    const SizedBox(width: 4),
                                                    GestureDetector(
                                                      onTap: () => _deleteComment(
                                                          '${item['id']}'),
                                                      child: const Padding(
                                                        padding:
                                                            EdgeInsets.all(4),
                                                        child: Icon(
                                                          Icons
                                                              .delete_outline_rounded,
                                                          size: 15,
                                                          color:
                                                              Colors.redAccent,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            text,
                                            style: BkoTheme.fontLato(
                                              fontSize: 13,
                                              color: Colors.white.withValues(alpha: 0.9),
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
          ),

          // Input field bar
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
                      minLines: 1,
                      maxLines: 4,
                      style: BkoTheme.fontLato(fontSize: 13.5, color: textPri),
                      decoration: InputDecoration(
                        hintText: 'Participer à la discussion...',
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
                GestureDetector(
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
                            Icons.arrow_upward_rounded,
                            color: Colors.black,
                            size: 22,
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
}
