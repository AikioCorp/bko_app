import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/bko_theme.dart';

class AuthRequiredModal extends StatelessWidget {
  final String actionTitle;
  final VoidCallback? onAuthenticated;

  const AuthRequiredModal({
    super.key,
    required this.actionTitle,
    this.onAuthenticated,
  });

  static void show(BuildContext context,
      {required String actionTitle, VoidCallback? onAuthenticated}) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      builder: (modalContext) => AuthRequiredModal(
        actionTitle: actionTitle,
        onAuthenticated: onAuthenticated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BkoTheme.goldAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border:
                  Border.all(color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: BkoTheme.goldAccent,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Connexion requise',
            style: BkoTheme.fontLato(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connectez-vous pour $actionTitle et retrouver vos préférences sur tous vos appareils.',
            textAlign: TextAlign.center,
            style: BkoTheme.fontLato(
              fontSize: 13.5,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final router = GoRouter.of(context);
                final redirect = Uri.encodeComponent(
                  GoRouterState.of(context).uri.toString(),
                );
                Navigator.pop(context);
                router.push('/login?redirect=$redirect');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BkoTheme.goldAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'SE CONNECTER',
                style: BkoTheme.fontLato(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/register');
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'CRÉER UN COMPTE',
                style: BkoTheme.fontLato(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
