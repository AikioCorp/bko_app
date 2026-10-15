library auth_navigation;

/// Moteur de décision commun pour tous les parcours d'authentification sur mobile
/// (Inscription classique, validation OTP, Google, mot de passe, OTP login, restauration de session).

class PostAuthDecision {
  final String path;
  final bool isSuspended;
  final bool needsOnboarding;

  const PostAuthDecision({
    required this.path,
    required this.isSuspended,
    required this.needsOnboarding,
  });
}

/// Nettoie et valide une URL de redirection pour éviter :
/// - Les failles Open Redirect ("//evil.com", "https://…")
/// - Les boucles infinies (/login, /register, /verify-otp, /suspended, /taste-onboarding)
String sanitizeRedirect(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final trimmed = Uri.decodeComponent(raw).trim();

  // Doit être un chemin absolu interne sans double slash ni antislash
  if (!trimmed.startsWith('/') || trimmed.startsWith('//') || trimmed.contains('\\')) {
    return '';
  }

  // Éviter les boucles
  final pathWithoutQuery = trimmed.split('?').first.toLowerCase();
  const forbiddenLoops = [
    '/login',
    '/register',
    '/verify-otp',
    '/suspended',
    '/taste-onboarding',
  ];
  if (forbiddenLoops.contains(pathWithoutQuery)) {
    return '';
  }

  return trimmed;
}

/// Calcule la destination par défaut selon les rôles de l'utilisateur
String getDestinationForRole(List<dynamic>? roles) {
  final roleList = (roles ?? []).map((r) => '$r'.toUpperCase()).toList();
  if (roleList.contains('CREATOR') || roleList.contains('EDITOR')) {
    return '/studio';
  }
  return '/';
}

/// Moteur de décision commun pour tous les modes d'authentification sur Flutter.
///
/// Priorités :
/// 1. Compte suspendu -> /suspended
/// 2. Nouveau compte ou onboarding non terminé et non refusé -> /taste-onboarding
/// 3. Compte existant avec préférences complètes ou refusées -> Destination demandée ou espace lié au rôle
PostAuthDecision resolvePostAuthDecision(
  Map<String, dynamic>? user, {
  String? explicitTarget,
  bool isNewUser = false,
}) {
  // 1. Suspension prioritaire
  if (user != null && user['isSuspended'] == true) {
    return const PostAuthDecision(
      path: '/suspended',
      isSuspended: true,
      needsOnboarding: false,
    );
  }

  final cleanTarget = sanitizeRedirect(explicitTarget);

  // 2. Détermination de la nécessité de l'onboarding initial
  final recProfile = user?['recommendationProfile'] is Map
      ? user!['recommendationProfile'] as Map<String, dynamic>
      : null;

  final onboardingState = user?['onboardingState']?.toString() ??
      recProfile?['onboardingState']?.toString() ??
      'NOT_PROMPTED';

  final onboardingCompleted = (user?['onboardingCompleted'] == true) ||
      (recProfile?['onboardingCompleted'] == true);

  final isDismissed = onboardingState == 'DISMISSED';

  final bool userIsNew = isNewUser || (user?['isNewUser'] == true);
  final needsOnboarding = userIsNew || (!onboardingCompleted && !isDismissed);

  if (needsOnboarding) {
    final query = cleanTarget.isNotEmpty
        ? '?redirect=${Uri.encodeQueryComponent(cleanTarget)}'
        : '';
    return PostAuthDecision(
      path: '/taste-onboarding$query',
      isSuspended: false,
      needsOnboarding: true,
    );
  }

  // 3. Compte existant : destination interne demandée ou accueil / studio selon le rôle
  final destination = cleanTarget.isNotEmpty
      ? cleanTarget
      : getDestinationForRole(user?['roles'] as List<dynamic>?);

  return PostAuthDecision(
    path: destination,
    isSuspended: false,
    needsOnboarding: false,
  );
}

/// Détermine si une invitation de rattrapage des préférences doit être affichée
/// pour un compte existant.
///
/// Critères stricts :
/// - Utilisateur authentifié et profil chargé avec succès
/// - Compte NON suspendu
/// - Langues OU centres d'intérêt manquants
/// - L'utilisateur n'a jamais été sollicité (onboardingState == 'NOT_PROMPTED') et n'a pas déjà complété
bool shouldShowCatchUpInvitation(Map<String, dynamic>? user) {
  if (user == null || user['id'] == null) return false;
  if (user['isSuspended'] == true) return false;

  final recProfile = user['recommendationProfile'] is Map
      ? user['recommendationProfile'] as Map<String, dynamic>
      : null;

  final onboardingCompleted = (user['onboardingCompleted'] == true) ||
      (recProfile?['onboardingCompleted'] == true);
  if (onboardingCompleted) return false;

  final onboardingState = user['onboardingState']?.toString() ??
      recProfile?['onboardingState']?.toString() ??
      'NOT_PROMPTED';

  if (onboardingState != 'NOT_PROMPTED') {
    // Si déjà présenté (PROMPTED), complété (COMPLETED) ou refusé (DISMISSED), ne plus jamais relancer automatiquement
    return false;
  }

  final hasPreferences = (user['hasPreferences'] == true) ||
      (recProfile?['hasPreferences'] == true);
  if (hasPreferences) return false;

  final langPrefs = user['languagePreferences'];
  final topicPrefs = user['topicPreferences'];
  final hasLangs = langPrefs is List && langPrefs.isNotEmpty;
  final hasTopics = topicPrefs is List && topicPrefs.isNotEmpty;
  if (hasLangs && hasTopics) return false;

  return true;
}
