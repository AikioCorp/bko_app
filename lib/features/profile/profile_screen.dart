import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../auth/auth_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _followingCount = 0;
  int _savedCount = 0;
  int _historyCount = 0;
  int _playlistsCount = 0;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) return;

    if (mounted) setState(() => _loadingStats = true);
    try {
      final results = await Future.wait([
        BkoApi.get('/me/following', token: auth.token).catchError((_) => []),
        BkoApi.get('/me/saved', token: auth.token).catchError((_) => []),
        BkoApi.get('/me/history', token: auth.token).catchError((_) => []),
        BkoApi.get('/me/playlists', token: auth.token).catchError((_) => []),
      ]);

      if (!mounted) return;
      setState(() {
        _followingCount = (results[0] as List?)?.length ?? 0;
        _savedCount = (results[1] as List?)?.length ?? 0;
        _historyCount = (results[2] as List?)?.length ?? 0;
        _playlistsCount = (results[3] as List?)?.length ?? 0;
        _loadingStats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final roles = auth.user?['roles'] as List?;
    final isCreator = (roles != null &&
            (roles.any((r) => r.toString().toUpperCase().contains('CREATOR')) ||
             roles.any((r) => r.toString().toUpperCase().contains('ADMIN')))) ||
        auth.user?['isCreator'] == true ||
        auth.user?['creatorProfile'] != null;
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          child: auth.isAuthenticated
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Header Card (Level 1 Identity)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              BkoBounceable(
                                onTap: () {
                                  BkoHaptics.light();
                                  context.push('/profile/edit');
                                },
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                                        border: Border.all(color: border),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: (auth.user?['avatar'] != null &&
                                              (auth.user!['avatar'] as String).trim().isNotEmpty)
                                          ? CachedNetworkImage(
                                              imageUrl: auth.user!['avatar'] as String,
                                              memCacheWidth: 150,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => Center(
                                                child: Text(
                                                  _initial(auth.user),
                                                  style: BkoTheme.fontLato(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w800,
                                                    color: BkoTheme.goldAccent,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Text(
                                                _initial(auth.user),
                                                style: BkoTheme.fontLato(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w800,
                                                  color: BkoTheme.goldAccent,
                                                ),
                                              ),
                                            ),
                                    ),
                                    Positioned(
                                      bottom: -2,
                                      right: -2,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: BkoTheme.goldAccent,
                                        ),
                                        child: const Icon(
                                          IconsaxPlusLinear.camera,
                                          size: 12,
                                          color: BkoTheme.darkBgObsidian,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${auth.user?['fullName'] ?? 'Auditeur Bko'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: BkoTheme.fontLato(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: textPri,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${auth.user?['email'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: BkoTheme.fontLato(fontSize: 12, color: textSec),
                                    ),
                                    if (_userRoleBadge(auth.user) != null) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: BkoTheme.goldAccent.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _userRoleBadge(auth.user)!,
                                          style: BkoTheme.fontLato(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: BkoTheme.goldAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              BkoBounceable(
                                onTap: () {
                                  BkoHaptics.light();
                                  context.push('/profile/edit');
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: border),
                                  ),
                                  child: Icon(IconsaxPlusLinear.edit_2, size: 18, color: textPri),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // User Activity KPIs / Stats Grid (Level 1 Activity)
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            context,
                            label: 'Suivis',
                            count: _followingCount,
                            icon: IconsaxPlusLinear.heart,
                            onTap: () => context.go('/library'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _statCard(
                            context,
                            label: 'Favoris',
                            count: _savedCount,
                            icon: IconsaxPlusLinear.bookmark,
                            onTap: () => context.go('/library'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _statCard(
                            context,
                            label: 'Historique',
                            count: _historyCount,
                            icon: IconsaxPlusLinear.clock,
                            onTap: () => context.go('/library'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _statCard(
                            context,
                            label: 'Playlists',
                            count: _playlistsCount,
                            icon: IconsaxPlusLinear.music_playlist,
                            onTap: () => context.go('/library'),
                          ),
                        ),
                      ],
                    ),

                    if (isCreator) ...[
                      const SizedBox(height: 24),

                      // Creator Studio Highlight Card (Direct Access to Creator Dashboard)
                      BkoBounceable(
                        onTap: () {
                          BkoHaptics.light();
                          context.push('/studio');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  IconsaxPlusLinear.microphone_2,
                                  color: BkoTheme.goldAccent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Espace Studio Créateur',
                                          style: BkoTheme.fontLato(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: textPri,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: BkoTheme.goldAccent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'STUDIO',
                                            style: BkoTheme.fontLato(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: BkoTheme.darkBgObsidian,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Gérez vos émissions, publiez et suivez vos écoutes',
                                      style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(IconsaxPlusLinear.arrow_right_3, color: textSec, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Navigation Category: Ma Bibliothèque & Activité
                    _sectionHeader('MA BIBLIOTHÈQUE & ACTIVITÉ', textSec),
                    const SizedBox(height: 8),
                    _tile(
                      label: 'Notifications & Alertes',
                      icon: IconsaxPlusLinear.notification,
                      surface: surfaceElevated,
                      border: border,
                      textPri: textPri,
                      onTap: () => context.push('/notifications'),
                    ),
                    const SizedBox(height: 8),
                    _tile(
                      label: 'Téléchargements hors ligne',
                      icon: IconsaxPlusLinear.folder_cloud,
                      surface: surfaceElevated,
                      border: border,
                      textPri: textPri,
                      onTap: () => context.push('/downloads'),
                    ),

                    const SizedBox(height: 24),

                    // Navigation Category: Préférences & Recommandations
                    _sectionHeader('PERSONNALISATION & RECOMMANDATIONS', textSec),
                    const SizedBox(height: 8),
                    _tile(
                      label: 'Mes préférences d\'écoute',
                      icon: IconsaxPlusLinear.music_filter,
                      surface: surfaceElevated,
                      border: border,
                      textPri: textPri,
                      onTap: () => context.push('/taste-onboarding?mode=edit'),
                    ),
                    const SizedBox(height: 8),
                    _tile(
                      label: 'Algorithme & Recommandations',
                      icon: IconsaxPlusLinear.setting_4,
                      surface: surfaceElevated,
                      border: border,
                      textPri: textPri,
                      onTap: () => _showPersonalizationSheet(context),
                    ),

                    const SizedBox(height: 24),

                    // Navigation Category: Compte & Déconnexion
                    _sectionHeader('COMPTE', textSec),
                    const SizedBox(height: 8),
                    _tile(
                      label: 'Modifier mon profil',
                      icon: IconsaxPlusLinear.user_edit,
                      surface: surfaceElevated,
                      border: border,
                      textPri: textPri,
                      onTap: () => context.push('/profile/edit'),
                    ),
                    const SizedBox(height: 16),

                    BkoBounceable(
                      onTap: () {
                        BkoHaptics.light();
                        ref.read(authProvider.notifier).logout();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              IconsaxPlusLinear.logout,
                              size: 18,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SE DÉCONNECTER',
                              style: BkoTheme.fontLato(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 64),
                    Icon(IconsaxPlusLinear.profile_circle, size: 64, color: textSec),
                    const SizedBox(height: 16),
                    Text(
                      'Connectez-vous à votre compte',
                      style: BkoTheme.fontLato(fontSize: 20, fontWeight: FontWeight.w800, color: textPri),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Retrouvez votre bibliothèque, vos favoris, vos abonnements et votre espace studio.',
                      textAlign: TextAlign.center,
                      style: BkoTheme.fontLato(fontSize: 13, color: textSec, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    BkoBounceable(
                      onTap: () {
                        BkoHaptics.light();
                        context.go('/login');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        decoration: BoxDecoration(
                          color: BkoTheme.goldAccent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'SE CONNECTER',
                          style: BkoTheme.fontLato(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: BkoTheme.darkBgObsidian,
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

  String? _userRoleBadge(Map<String, dynamic>? user) {
    final roles = user?['roles'] as List?;
    if (roles != null && roles.any((r) => r.toString().toUpperCase().contains('ADMIN'))) {
      return 'ADMINISTRATEUR';
    }
    if (roles != null && roles.any((r) => r.toString().toUpperCase().contains('CREATOR'))) {
      return 'CRÉATEUR VÉRIFIÉ';
    }
    if (user?['isCreator'] == true || user?['creatorProfile'] != null) {
      return 'CRÉATEUR VÉRIFIÉ';
    }
    return null;
  }

  String _initial(Map<String, dynamic>? user) {
    final name = user?['fullName'];
    if (name is String && name.trim().isNotEmpty) return name.trim()[0].toUpperCase();
    return 'U';
  }

  Widget _sectionHeader(String title, Color textSec) {
    return Text(
      title,
      style: BkoTheme.fontLato(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: textSec,
      ),
    );
  }

  Widget _statCard(
    BuildContext context, {
    required String label,
    required int count,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final border = BkoTheme.getBorderSubtle(context);

    return BkoBounceable(
      onTap: () {
        BkoHaptics.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: BkoTheme.goldAccent),
            const SizedBox(height: 6),
            Text(
              _loadingStats ? '-' : count.toString(),
              style: BkoTheme.fontLato(fontSize: 16, fontWeight: FontWeight.w800, color: textPri),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BkoTheme.fontLato(fontSize: 10.5, color: textSec),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required String label,
    required IconData icon,
    required Color surface,
    required Color border,
    required Color textPri,
    required VoidCallback onTap,
  }) {
    return BkoBounceable(
      onTap: () {
        BkoHaptics.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, color: BkoTheme.goldAccent, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.w700, color: textPri),
              ),
            ),
            Icon(
              IconsaxPlusLinear.arrow_right_3,
              color: textPri.withValues(alpha: 0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showPersonalizationSheet(BuildContext context) {
    final auth = ref.read(authProvider);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Personnalisation & Recommandations',
                style: BkoTheme.fontLato(fontSize: 17, fontWeight: FontWeight.w800, color: textPri),
              ),
              const SizedBox(height: 6),
              Text(
                'Gérez vos signaux d\'écoute et réinitialisez votre profil d\'affinité si souhaité.',
                style: BkoTheme.fontLato(fontSize: 12.5, color: textSec),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(IconsaxPlusLinear.refresh_2, color: BkoTheme.goldAccent, size: 22),
                title: Text(
                  'Réinitialiser mon profil de goûts',
                  style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.w700, color: textPri),
                ),
                subtitle: Text(
                  'Efface l\'historique d\'affinité pour recalculer les suggestions d\'accueil',
                  style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (auth.token != null) {
                    try {
                      await BkoApi.post('/recommendations/reset-profile', {}, token: auth.token);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profil réinitialisé avec succès.')),
                      );
                    } catch (_) {}
                  }
                },
              ),
              Divider(color: border, height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(IconsaxPlusLinear.setting_4, color: BkoTheme.goldAccent, size: 22),
                title: Text(
                  'Modifier mes centres d\'intérêt',
                  style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.w700, color: textPri),
                ),
                subtitle: Text(
                  'Mettre à jour vos thématiques favorites',
                  style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/taste-onboarding?mode=edit');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
