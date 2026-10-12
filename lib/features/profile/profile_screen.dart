import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/network/bko_api.dart';
import '../auth/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
          child: auth.isAuthenticated
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: BkoTheme.goldAccent.withValues(alpha: 0.15),
                        child: Text(
                          _initial(auth.user),
                          style: BkoTheme.fontLato(fontSize: 32, fontWeight: FontWeight.w800, color: BkoTheme.goldAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('${auth.user?['fullName'] ?? 'Utilisateur'}',
                        textAlign: TextAlign.center,
                        style: BkoTheme.fontLato(fontSize: 20, fontWeight: FontWeight.w800, color: textPri)),
                    const SizedBox(height: 4),
                    Text('${auth.user?['email'] ?? ''}',
                        textAlign: TextAlign.center,
                        style: BkoTheme.fontLato(fontSize: 13, color: textSec)),
                    const SizedBox(height: 16),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/profile/edit'),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Modifier mon profil'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPri,
                          side: BorderSide(color: border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _tile('Notifications', Icons.notifications_none_rounded, surface, border, textPri, () => context.push('/notifications')),
                    const SizedBox(height: 10),
                    _tile('Ma bibliothèque', Icons.library_music, surface, border, textPri, () => context.go('/library')),
                    const SizedBox(height: 10),
                    _tile('Favoris', Icons.favorite_border, surface, border, textPri, () => context.go('/favorites')),
                    const SizedBox(height: 10),
                    _tile('Personnalisation & Recommandations', Icons.tune_rounded, surface, border, textPri, () {
                      _showPersonalizationSheet(context, ref);
                    }),
                    const SizedBox(height: 10),
                    _tile('Espace créateur', Icons.mic_none, surface, border, textPri, () => context.go('/studio')),
                    const SizedBox(height: 36),
                    OutlinedButton(
                      onPressed: () => ref.read(authProvider.notifier).logout(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('SE DÉCONNECTER',
                          style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.red.shade300)),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_circle_outlined, size: 64, color: textSec),
                    const SizedBox(height: 16),
                    Text('Connectez-vous',
                        style: BkoTheme.fontLato(fontSize: 20, fontWeight: FontWeight.w800, color: textPri)),
                    const SizedBox(height: 6),
                    Text('Retrouvez votre bibliothèque, vos favoris et abonnements.',
                        textAlign: TextAlign.center,
                        style: BkoTheme.fontLato(fontSize: 13, color: textSec)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BkoTheme.goldAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('SE CONNECTER',
                          style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _initial(Map<String, dynamic>? user) {
    final name = user?['fullName'];
    if (name is String && name.trim().isNotEmpty) return name.trim()[0].toUpperCase();
    return '?';
  }

  Widget _tile(String label, IconData icon, Color bg, Color border, Color text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
        child: Row(
          children: [
            Icon(icon, color: BkoTheme.goldAccent, size: 20),
            const SizedBox(width: 12),
            Text(label, style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w600, color: text)),
            const Spacer(),
            Icon(Icons.chevron_right, color: text.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  void _showPersonalizationSheet(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authProvider);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Personnalisation & Recommandations',
                style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w800, color: textPri)),
            const SizedBox(height: 8),
            Text('Gérez vos signaux d\'écoute, activez ou réinitialisez votre profil de découverte.',
                style: BkoTheme.fontLato(fontSize: 13, color: textSec)),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.refresh_rounded, color: BkoTheme.goldAccent),
              title: Text('Réinitialiser mon profil de goûts',
                  style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w700, color: textPri)),
              subtitle: Text('Efface l\'historique d\'affinité et recalcule les suggestions',
                  style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
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
            const Divider(color: Color(0xFF262626), height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune_rounded, color: BkoTheme.goldAccent),
              title: Text('Modifier mes centres d\'intérêt',
                  style: BkoTheme.fontLato(fontSize: 14, fontWeight: FontWeight.w700, color: textPri)),
              subtitle: Text('Mettre à jour les thèmes choisis à l\'onboarding',
                  style: BkoTheme.fontLato(fontSize: 12, color: textSec)),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/onboarding');
              },
            ),
          ],
        ),
      ),
    );
  }
}
