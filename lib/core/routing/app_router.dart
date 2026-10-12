import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/user_taste_onboarding_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/podcast_details_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/verify_otp_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/profile_edit_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/home/episode_details_screen.dart';
import '../../features/studio/studio_screen.dart';
import '../../features/studio/create_podcast_screen.dart';
import '../../features/studio/create_episode_screen.dart';
import '../../features/studio/rss_import_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/library/playlist_details_screen.dart';
import '../../features/downloads/downloads_screen.dart';
import '../../features/shell/subpage_audio_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/verify-otp',
      builder: (context, state) => VerifyOtpScreen(
        email: state.uri.queryParameters['email'] ?? '',
        redirect: state.uri.queryParameters['redirect'],
        initialCode: state.uri.queryParameters['code'],
      ),
    ),
    GoRoute(
      path: '/taste-onboarding',
      builder: (context, state) => UserTasteOnboardingScreen(
        isEditing: state.uri.queryParameters['mode'] == 'edit',
        redirect: state.uri.queryParameters['redirect'],
      ),
    ),

    // Stateful branch navigation preserving tabs, scroll positions & input states
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        // Branch 0: Accueil
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        // Branch 1: Explorer & Recherche
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/explore',
              builder: (context, state) => ExploreScreen(
                initialQuery: state.uri.queryParameters['q'],
                initialCategory: state.uri.queryParameters['category'],
                initialLang: state.uri.queryParameters['lang'],
                initialDuration: state.uri.queryParameters['duration'],
                initialSort: state.uri.queryParameters['sort'],
                initialView: state.uri.queryParameters['view'],
                isStandalone: false,
              ),
            ),
          ],
        ),
        // Branch 2: Bibliothèque & Favoris
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryScreen(),
            ),
          ],
        ),
        // Branch 3: Profil
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // Sub-screens wrapped in SubpageAudioShell to keep mini-player persistent across navigation
    ShellRoute(
      builder: (context, state, child) => SubpageAudioShell(child: child),
      routes: [
        GoRoute(
          path: '/discovery',
          builder: (context, state) => ExploreScreen(
            initialQuery: state.uri.queryParameters['q'],
            initialCategory: state.uri.queryParameters['category'],
            initialLang: state.uri.queryParameters['lang'],
            initialDuration: state.uri.queryParameters['duration'],
            initialSort: state.uri.queryParameters['sort'],
            initialView: state.uri.queryParameters['view'],
            isStandalone: true,
          ),
        ),
        GoRoute(
          path: '/downloads',
          builder: (context, state) => const DownloadsScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/profile/edit',
          builder: (context, state) => const ProfileEditScreen(),
        ),
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const LibraryScreen(),
        ),
        GoRoute(
          path: '/studio',
          builder: (context, state) => const StudioScreen(),
        ),
        GoRoute(
          path: '/studio/podcasts/new',
          builder: (context, state) => const CreatePodcastScreen(),
        ),
        GoRoute(
          path: '/studio/episodes/new',
          builder: (context, state) => const CreateEpisodeScreen(),
        ),
        GoRoute(
          path: '/studio/import-rss',
          builder: (context, state) => const RssImportScreen(),
        ),
        GoRoute(
          path: '/podcasts/:slug',
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return PodcastDetailsScreen(slug: slug);
          },
        ),
        GoRoute(
          path: '/podcasts/:slug/episodes/:episodeSlug',
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            final episodeSlug = state.pathParameters['episodeSlug'] ?? '';
            return EpisodeDetailsScreen(podcastSlug: slug, episodeSlug: episodeSlug);
          },
        ),
        GoRoute(
          path: '/playlists/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return PlaylistDetailsScreen(playlistId: id);
          },
        ),
      ],
    ),
  ],
);
