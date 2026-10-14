import '../../core/widgets/app_header_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/bko_api.dart';
import '../../core/widgets/app_back_button.dart';
import '../auth/auth_controller.dart';

final studioAccessProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.token == null) return {'canAccess': false};
  final data = await BkoApi.get('/me/studio-access', token: auth.token);
  if (data is! Map) throw const FormatException('Réponse Studio invalide');
  return Map<String, dynamic>.from(data);
});

class StudioAccessGate extends ConsumerWidget {
  final Widget child;
  final bool requireProfile;
  const StudioAccessGate(
      {super.key, required this.child, this.requireProfile = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final access = ref.watch(studioAccessProvider);
    return access.when(
      data: (data) {
        if (auth.isAuthenticated &&
            data['canAccess'] == true &&
            (!requireProfile || data['canCreatePodcast'] == true)) {
          return child;
        }
        return Scaffold(
          appBar: AppBar(
        actions: const [AppHeaderActions()],
              leading: const AppBackButton(),
              title: const Text('Votre Studio')),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(auth.isAuthenticated
                        ? 'Activez votre Studio pour créer votre émission.'
                        : 'Connectez-vous pour accéder au Studio.'),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: () => context.push(auth.isAuthenticated
                            ? '/become-creator'
                            : '/login?redirect=%2Fstudio'),
                        child: Text(auth.isAuthenticated
                            ? 'Activer mon Studio'
                            : 'Se connecter')),
                  ]))),
        );
      },
      error: (error, stack) => Scaffold(
        appBar: AppBar(
        actions: const [AppHeaderActions()],
            leading: const AppBackButton(), title: const Text('Votre Studio')),
        body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Impossible de vérifier votre accès.'),
          TextButton(
              onPressed: () => ref.invalidate(studioAccessProvider),
              child: const Text('Réessayer')),
        ])),
      ),
      loading: () => const Scaffold(
          body: Center(child: Text('Vérification de votre Studio…'))),
    );
  }
}
