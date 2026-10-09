import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/bko_theme.dart';
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
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                    _tile('Ma bibliothèque', Icons.library_music, surface, border, textPri, () => context.go('/library')),
                    const SizedBox(height: 10),
                    _tile('Favoris', Icons.favorite_border, surface, border, textPri, () => context.go('/favorites')),
                    const SizedBox(height: 10),
                    _tile('Espace créateur', Icons.mic_none, surface, border, textPri, () => context.go('/studio')),
                    const Spacer(),
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
}
