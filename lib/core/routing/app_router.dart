import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/podcast_details_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/verify_otp_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/home/episode_details_screen.dart';
import '../../features/studio/studio_screen.dart';
import '../../features/studio/create_podcast_screen.dart';
import '../../features/studio/create_episode_screen.dart';
import '../../features/studio/rss_import_screen.dart';

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
      path: '/verify-otp',
      builder: (context, state) => VerifyOtpScreen(email: state.uri.queryParameters['email'] ?? ''),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return AppShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/explore',
          builder: (context, state) => const ExploreScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/library',
          builder: (context, state) => const LibraryScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
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
      ],
    ),
  ],
);
