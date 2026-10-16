import '../../core/widgets/app_header_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
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
  Map<String, dynamic>? _dashboardMetrics;
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
      final results = await Future.wait([
        BkoApi.get('/me/creator-profile', token: auth.token),
        BkoApi.get('/creator/podcasts', token: auth.token),
        BkoApi.get('/creator/dashboard', token: auth.token),
      ]);

      if (!mounted) return;
      setState(() {
        _profile = results[0] is Map
            ? Map<String, dynamic>.from(results[0] as Map)
            : null;
        _podcasts = (results[1] as List?) ?? [];
        _dashboardMetrics = results[2] is Map
            ? Map<String, dynamic>.from(results[2] as Map)
            : null;
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
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    if (!auth.isAuthenticated) {
      return Scaffold(
        backgroundColor: bgSurf,
        appBar: AppBar(
        actions: const [AppHeaderActions()],
          backgroundColor: bgSurf,
          elevation: 0,
          leading: const AppBackButton(),
          title: Text(
            'Studio Créateur',
            style: BkoTheme.fontLato(
                fontSize: 18, fontWeight: FontWeight.w800, color: textPri),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(IconsaxPlusLinear.microphone_2,
                    size: 56, color: BkoTheme.getAccent(context)),
                const SizedBox(height: 16),
                Text(
                  'Rejoignez le Studio Bko',
                  style: BkoTheme.fontLato(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textPri),
                ),
                const SizedBox(height: 8),
                Text(
                  'Publiez vos émissions audio et vidéo, importez vos flux RSS et suivez vos statistiques en direct.',
                  textAlign: TextAlign.center,
                  style: BkoTheme.fontLato(
                      fontSize: 13, color: textSec, height: 1.4),
                ),
                const SizedBox(height: 24),
                BkoBounceable(
                  onTap: () {
                    BkoHaptics.light();
                    AuthRequiredModal.show(context,
                        actionTitle: 'accéder au Studio Créateur');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: BkoTheme.goldAccent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(IconsaxPlusLinear.login,
                            size: 20, color: BkoTheme.darkBgObsidian),
                        const SizedBox(width: 8),
                        Text(
                          'SE CONNECTER',
                          style: BkoTheme.fontLato(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: BkoTheme.darkBgObsidian,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final plays30d = _dashboardMetrics?['plays30d'] ?? 0;
    final totalFollowers = _dashboardMetrics?['totalFollowers'] ?? 0;
    final episodesCount = _dashboardMetrics?['episodesCount'] ?? 0;
    final draftEpisodes = _dashboardMetrics?['draftEpisodes'] ?? 0;
    final rejected = (_dashboardMetrics?['rejected'] as List?) ?? [];

    return Scaffold(
      backgroundColor: bgSurf,
      appBar: AppBar(
        backgroundColor: bgSurf,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Studio Bko Podcast',
          style: BkoTheme.fontLato(
              fontSize: 18, fontWeight: FontWeight.w800, color: textPri),
        ),
        actions: [
          const AppHeaderActions(),
          BkoBounceable(
            onTap: () {
              BkoHaptics.light();
              _fetchStudioData();
            },
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: Icon(IconsaxPlusLinear.refresh, color: textPri, size: 20),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator.adaptive(
                valueColor: AlwaysStoppedAnimation(BkoTheme.goldAccent),
              ),
            )
          : RefreshIndicator(
              color: BkoTheme.goldAccent,
              onRefresh: _fetchStudioData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bgElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderSub),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  BkoTheme.goldAccent.withValues(alpha: 0.15),
                              border: Border.all(color: borderSub),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: (auth.user?['avatar'] != null &&
                                    (auth.user!['avatar'] as String)
                                        .trim()
                                        .isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl: auth.user!['avatar'] as String,
                                    memCacheWidth: 150,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Center(
                                      child: Text(
                                        _profile?['displayName']
                                                ?.toString()
                                                .substring(0, 1)
                                                .toUpperCase() ??
                                            auth.user?['fullName']
                                                ?.toString()
                                                .substring(0, 1)
                                                .toUpperCase() ??
                                            'C',
                                        style: BkoTheme.fontLato(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: BkoTheme.getAccent(context),
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      _profile?['displayName']
                                              ?.toString()
                                              .substring(0, 1)
                                              .toUpperCase() ??
                                          auth.user?['fullName']
                                              ?.toString()
                                              .substring(0, 1)
                                              .toUpperCase() ??
                                          'C',
                                      style: BkoTheme.fontLato(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: BkoTheme.getAccent(context),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profile?['displayName'] ??
                                      auth.user?['fullName'] ??
                                      'Créateur Bko',
                                  style: BkoTheme.fontLato(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: textPri),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Espace Créateur Vérifié • ${_podcasts.length} Émission(s)',
                                  style: BkoTheme.fontLato(
                                      fontSize: 12, color: textSec),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Creator KPI Cards Bar (Level 1 Metrics)
                    Row(
                      children: [
                        Expanded(
                          child: _kpiCard(
                            context,
                            title: 'Écoutes (30j)',
                            value: plays30d.toString(),
                            icon: IconsaxPlusLinear.headphones,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _kpiCard(
                            context,
                            title: 'Abonnés',
                            value: totalFollowers.toString(),
                            icon: IconsaxPlusLinear.profile_2user,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _kpiCard(
                            context,
                            title: 'Épisodes',
                            value: episodesCount.toString(),
                            icon: IconsaxPlusLinear.play,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _kpiCard(
                            context,
                            title: 'Brouillons',
                            value: draftEpisodes.toString(),
                            icon: IconsaxPlusLinear.document_text,
                          ),
                        ),
                      ],
                    ),

                    // Moderation feedback alert if any rejected episodes
                    if (rejected.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  IconsaxPlusLinear.warning_2,
                                  color: Theme.of(context).colorScheme.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ajustements requis par la modération',
                                  style: BkoTheme.fontLato(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: textPri,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...rejected.map((item) {
                              final title = item['title'] ?? 'Épisode';
                              final note = item['reviewNote'] ??
                                  'Veuillez réviser cet épisode.';
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '• $title : $note',
                                  style: BkoTheme.fontLato(
                                      fontSize: 11.5, color: textSec),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Studio Action Hub
                    Text(
                      'GESTION DU CONTENU',
                      style: BkoTheme.fontLato(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: textSec,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _actionCard(
                            context,
                            title: 'Nouvelle Émission',
                            subtitle: 'Créer une série audio/vidéo',
                            icon: IconsaxPlusLinear.add_circle,
                            color: BkoTheme.goldAccent,
                            onTap: () =>
                                context.push('/studio/podcasts/new').then((_) {
                              if (mounted) _fetchStudioData();
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _actionCard(
                            context,
                            title: 'Nouvel Épisode',
                            subtitle: 'Publier un média',
                            icon: IconsaxPlusLinear.video_play,
                            color: BkoTheme.goldAccent,
                            onTap: () =>
                                context.push('/studio/episodes/new').then((_) {
                              if (mounted) _fetchStudioData();
                            }),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _actionCard(
                      context,
                      title: 'Importer une émission via RSS',
                      subtitle:
                          'Connecter et synchroniser un flux externe (Anchor, Spotify, RSS)',
                      icon: IconsaxPlusLinear.routing,
                      color: BkoTheme.goldAccent,
                      onTap: () => context.push('/studio/import-rss').then((_) {
                        if (mounted) _fetchStudioData();
                      }),
                    ),
                    const SizedBox(height: 12),
                    _actionCard(
                      context,
                      title: 'Connecter une chaîne YouTube',
                      subtitle:
                          'Importer et synchroniser automatiquement vos vidéos officielles',
                      icon: IconsaxPlusLinear.video,
                      color: Colors.redAccent,
                      onTap: () =>
                          context.push('/studio/import-youtube').then((_) {
                        if (mounted) _fetchStudioData();
                      }),
                    ),

                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () =>
                          context.push('/studio/claims').then((_) {
                        if (mounted) _fetchStudioData();
                      }),
                      child: const Text('Revendiquer une émission existante'),
                    ),
                    // Podcasts List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MES ÉMISSIONS (${_podcasts.length})',
                          style: BkoTheme.fontLato(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: textPri,
                          ),
                        ),
                        BkoBounceable(
                          onTap: () {
                            BkoHaptics.light();
                            context.push('/studio/podcasts/new').then((_) {
                              if (mounted) _fetchStudioData();
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Text(
                              '+ CRÉER',
                              style: BkoTheme.fontLato(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: BkoTheme.getAccent(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .error
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: BkoTheme.fontLato(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      )
                    else if (_podcasts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bgElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderSub),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              IconsaxPlusLinear.radio,
                              size: 40,
                              color: textSec.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Aucune émission pour le moment',
                              style: BkoTheme.fontLato(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: textPri,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Commencez par créer votre première émission ou importez un flux RSS.',
                              textAlign: TextAlign.center,
                              style: BkoTheme.fontLato(
                                  fontSize: 12, color: textSec),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _podcasts.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final pod = Map<String, dynamic>.from(
                              _podcasts[index] as Map);
                          final name = pod['name'] ?? 'Émission';
                          final rawFormat =
                              '${pod['format'] ?? 'AUDIO_AND_VIDEO'}';
                          final formatLabel = rawFormat == 'AUDIO'
                              ? 'Audio'
                              : rawFormat == 'VIDEO'
                                  ? 'Vidéo'
                                  : 'Audio & Vidéo';
                          final cover = pod['cover'] ?? '';
                          final episodeCount = pod['_count']?['episodes'] ??
                              (pod['episodes'] as List?)?.length ??
                              0;

                          return BkoBounceable(
                            onTap: () {
                              BkoHaptics.light();
                              final id = pod['id'];
                              if (id != null) {
                                context
                                    .push('/studio/podcasts/$id')
                                    .then((_) {
                                  if (mounted) _fetchStudioData();
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: bgElevated,
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
                                            width: 48,
                                            height: 48,
                                            memCacheWidth: 144,
                                            memCacheHeight: 144,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                _coverFallback(),
                                          )
                                        : _coverFallback(),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: BkoTheme.fontLato(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: textPri,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$formatLabel • $episodeCount épisode(s)',
                                          style: BkoTheme.fontLato(
                                              fontSize: 11.5, color: textSec),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(IconsaxPlusLinear.arrow_right_3,
                                      color: textSec, size: 18),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 96),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _kpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderSub),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: BkoTheme.getAccent(context)),
          const SizedBox(height: 6),
          Text(
            value,
            style: BkoTheme.fontLato(
                fontSize: 15, fontWeight: FontWeight.w800, color: textPri),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BkoTheme.fontLato(fontSize: 10, color: textSec),
          ),
        ],
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

    return BkoBounceable(
      onTap: () {
        BkoHaptics.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderSub),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: BkoTheme.fontLato(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textPri),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: BkoTheme.fontLato(fontSize: 11, color: textSec)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback() => Container(
        width: 48,
        height: 48,
        color: BkoTheme.goldAccent.withValues(alpha: 0.15),
        child: Icon(IconsaxPlusLinear.radio,
            color: BkoTheme.getAccent(context), size: 22),
      );
}
