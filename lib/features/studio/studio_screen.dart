import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_modal.dart';

class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({super.key});

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> {
  bool _loading = true;
  Map<String, dynamic>? _profile;
  List<dynamic> _podcasts = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStudioData();
  }

  Future<void> _fetchStudioData() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profileData = await BkoApi.get('/me/creator-profile', token: auth.token);
      final podcastsData = await BkoApi.get('/creator/podcasts', token: auth.token);

      if (!mounted) return;
      setState(() {
        _profile = profileData is Map ? Map<String, dynamic>.from(profileData) : null;
        _podcasts = (podcastsData as List?) ?? [];
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger l\'espace créateur.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final bgSurf = BkoTheme.getBgSurface(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    if (!auth.isAuthenticated) {
      return Scaffold(
        backgroundColor: bgSurf,
        appBar: AppBar(
          backgroundColor: bgSurf,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPri, size: 20),
            onPressed: () => context.pop(),
          ),
          title: Text('Studio Créateur', style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w900, color: textPri)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic_external_on_rounded, size: 64, color: BkoTheme.goldAccent),
                const SizedBox(height: 16),
                Text('Rejoignez le Studio Bko', style: BkoTheme.fontLato(fontSize: 22, fontWeight: FontWeight.w900, color: textPri)),
                const SizedBox(height: 8),
                Text(
                  'Publiez vos émission audio et vidéo, importez vos flux RSS et suivez vos statistiques.',
                  textAlign: TextAlign.center,
                  style: BkoTheme.fontLato(fontSize: 13.5, color: textSec, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BkoTheme.goldAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 20, color: Colors.black),
                  label: Text('SE CONNECTER', style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black)),
                  onPressed: () => AuthRequiredModal.show(context, actionTitle: 'accéder au Studio Créateur'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgSurf,
      appBar: AppBar(
        backgroundColor: bgSurf,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPri, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Studio Bko Podcast', style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w900, color: textPri)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textPri, size: 22),
            onPressed: _fetchStudioData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: BkoTheme.goldAccent))
          : RefreshIndicator(
              color: BkoTheme.goldAccent,
              onRefresh: _fetchStudioData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: BkoTheme.getBgSurfaceElevated(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderSub),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: BkoTheme.goldAccent.withValues(alpha: 0.15),
                            child: Text(
                              _profile?['displayName']?.toString().substring(0, 1).toUpperCase() ??
                                  auth.user?['fullName']?.toString().substring(0, 1).toUpperCase() ??
                                  'C',
                              style: BkoTheme.fontLato(fontSize: 22, fontWeight: FontWeight.w900, color: BkoTheme.goldAccent),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profile?['displayName'] ?? auth.user?['fullName'] ?? 'Créateur Bko',
                                  style: BkoTheme.fontLato(fontSize: 16, fontWeight: FontWeight.w900, color: textPri),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Compte Créateur Vérifié • ${_podcasts.length} Émission(s)',
                                  style: BkoTheme.fontLato(fontSize: 12, color: textSec),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Studio Action Hub
                    Text('GESTION DU CONTENU', style: BkoTheme.fontLato(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textSec)),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _actionCard(
                            context,
                            title: 'Nouvelle Émission',
                            subtitle: 'Créer une série audio/vidéo',
                            icon: Icons.add_circle_outline_rounded,
                            color: BkoTheme.goldAccent,
                            onTap: () => context.push('/studio/podcasts/new'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _actionCard(
                            context,
                            title: 'Nouvel Épisode',
                            subtitle: 'Publier un média',
                            icon: Icons.video_call_rounded,
                            color: const Color(0xFF38BDF8),
                            onTap: () => context.push('/studio/episodes/new'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _actionCard(
                      context,
                      title: 'Importer une émission via RSS',
                      subtitle: 'Connecter et synchroniser un flux externe (Anchor, Spotify, RSS)',
                      icon: Icons.rss_feed_rounded,
                      color: const Color(0xFFF97316),
                      onTap: () => context.push('/studio/import-rss'),
                    ),

                    const SizedBox(height: 28),

                    // Podcasts List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('MES ÉMISSIONS (${_podcasts.length})', style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: textPri)),
                        TextButton(
                          onPressed: () => context.push('/studio/podcasts/new'),
                          child: Text('+ CRÉER', style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w900, color: BkoTheme.goldAccent)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
                        child: Text(_error!, style: BkoTheme.fontLato(fontSize: 13, color: Colors.red.shade300)),
                      )
                    else if (_podcasts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: BkoTheme.getBgSurfaceElevated(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: borderSub)),
                        child: Column(
                          children: [
                            Icon(Icons.podcasts_rounded, size: 48, color: textSec.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text('Aucune émission pour le moment', style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w800, color: textPri)),
                            const SizedBox(height: 4),
                            Text('Commencez par créer votre première émission ou importez un flux RSS.', textAlign: TextAlign.center, style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _podcasts.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final pod = Map<String, dynamic>.from(_podcasts[index] as Map);
                          final name = pod['name'] ?? 'Émission';
                          final format = pod['format'] ?? 'AUDIO_AND_VIDEO';
                          final cover = pod['cover'] ?? '';
                          final episodeCount = pod['_count']?['episodes'] ?? (pod['episodes'] as List?)?.length ?? 0;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: BkoTheme.getBgSurfaceElevated(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderSub),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: cover.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: cover,
                                          width: 52,
                                          height: 52,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => _coverFallback(),
                                        )
                                      : _coverFallback(),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w800, color: textPri)),
                                      const SizedBox(height: 4),
                                      Text('$format • $episodeCount épisode(s)', style: BkoTheme.fontLato(fontSize: 11.5, color: textSec)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: textSec),
                              ],
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderSub),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.w800, color: textPri)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: BkoTheme.fontLato(fontSize: 11, color: textSec)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback() => Container(
        width: 52,
        height: 52,
        color: BkoTheme.goldAccent.withValues(alpha: 0.15),
        child: const Icon(Icons.podcasts_rounded, color: BkoTheme.goldAccent),
      );
}
