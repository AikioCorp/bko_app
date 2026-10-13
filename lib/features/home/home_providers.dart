import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/bko_api.dart';
import '../auth/auth_controller.dart';

class HomeDataState {
  final Map<String, dynamic>? homeData;
  final List<dynamic> categories;
  final List<dynamic> historyData;
  final String selectedCategory;
  final List<dynamic> feedItems;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final String? error;
  final String? feedError;
  final DateTime? lastFetched;

  const HomeDataState({
    this.homeData,
    this.categories = const [],
    this.historyData = const [],
    this.selectedCategory = 'all',
    this.feedItems = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.error,
    this.feedError,
    this.lastFetched,
  });

  bool get hasData => homeData != null;

  HomeDataState copyWith({
    Map<String, dynamic>? homeData,
    List<dynamic>? categories,
    List<dynamic>? historyData,
    String? selectedCategory,
    List<dynamic>? feedItems,
    String? nextCursor,
    bool? hasMore,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    String? error,
    String? feedError,
    DateTime? lastFetched,
    bool clearError = false,
    bool clearFeedError = false,
    bool clearCursor = false,
    bool clearHomeData = false,
  }) {
    return HomeDataState(
      homeData: clearHomeData ? null : (homeData ?? this.homeData),
      categories: categories ?? this.categories,
      historyData: historyData ?? this.historyData,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      feedItems: feedItems ?? this.feedItems,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      feedError: clearFeedError ? null : (feedError ?? this.feedError),
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }
}

class HomeDataNotifier extends StateNotifier<HomeDataState> {
  final Ref ref;
  Future<void>? _inFlightFetch;
  int _requestGeneration = 0;
  String? _activeUserId;

  HomeDataNotifier(this.ref) : super(const HomeDataState()) {
    _activeUserId = ref.read(authProvider).user?['id'] as String?;
    fetchInitial();
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return List<dynamic>.from(value);
    if (value is Map && value['data'] is List) {
      return List<dynamic>.from(value['data'] as List);
    }
    return [];
  }

  Future<void> fetchInitial() async {
    if (state.hasData) {
      final now = DateTime.now();
      if (state.lastFetched == null ||
          now.difference(state.lastFetched!) > const Duration(minutes: 5)) {
        refresh(silent: true);
      }
      return;
    }
    await _performFetch(isInitial: true);
  }

  Future<void> refresh({bool silent = false}) async {
    if (_inFlightFetch != null) return _inFlightFetch!;
    _inFlightFetch = _performFetch(isInitial: false, silent: silent);
    try {
      await _inFlightFetch;
    } finally {
      _inFlightFetch = null;
    }
  }

  Future<void> _performFetch({required bool isInitial, bool silent = false}) async {
    final int thisGeneration = ++_requestGeneration;
    final String? thisUserId = ref.read(authProvider).user?['id'] as String?;

    if (isInitial) {
      state = state.copyWith(isLoading: true, clearError: true);
    } else if (!silent) {
      state = state.copyWith(isRefreshing: true, clearError: true);
    }

    try {
      final auth = ref.read(authProvider);

      final previousSlides = state.homeData?['heroSlides'];
      final previousIds = previousSlides is List
          ? previousSlides.map((slide) {
              if (slide is! Map || slide['episode'] is! Map) return '';
              return slide['episode']['id']?.toString() ?? '';
            }).where((id) => id.isNotEmpty).take(12).join(',')
          : '';
      final renewHero = !isInitial;
      final homeUrl = Uri(path: '/home', queryParameters: {
        'country': 'all',
        'category': state.selectedCategory,
        if (renewHero) 'refreshHero': '1',
        if (renewHero && previousIds.isNotEmpty) 'previousHeroIds': previousIds,
      }).toString();

      final homeDataRes = await BkoApi.get(
        homeUrl,
        token: auth.token,
      );
      final categoriesRes = await BkoApi.get('/categories');

      List<dynamic> history = [];
      if (auth.isAuthenticated && auth.token != null) {
        try {
          final h = await BkoApi.get('/me/continue-listening', token: auth.token);
          history = _asList(h);
        } catch (_) {}
      }

      // Vérification stricte d'identité et de génération :
      // Si l'utilisateur a changé ou qu'une nouvelle requête a été initiée entre-temps,
      // la réponse est obsolète et ne doit JAMAIS écraser l'état courant.
      if (thisGeneration != _requestGeneration || thisUserId != _activeUserId) {
        return;
      }

      final homeMap = homeDataRes is Map ? Map<String, dynamic>.from(homeDataRes) : null;
      final feedMap = homeMap?['feed'] is Map ? Map<String, dynamic>.from(homeMap!['feed'] as Map) : null;
      final initialFeedItems = feedMap != null ? _asList(feedMap['items']) : <dynamic>[];
      final nextCursor = feedMap?['nextCursor']?.toString();
      final hasMore = feedMap?['hasMore'] == true;

      state = state.copyWith(
        homeData: homeMap,
        categories: _asList(categoriesRes),
        historyData: history,
        feedItems: initialFeedItems,
        nextCursor: nextCursor,
        hasMore: hasMore,
        isLoading: false,
        isRefreshing: false,
        lastFetched: DateTime.now(),
        clearError: true,
      );
    } catch (e) {
      if (thisGeneration != _requestGeneration || thisUserId != _activeUserId) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: isInitial
            ? 'Impossible de charger le contenu d\'accueil.'
            : 'Actualisation impossible. Le contenu précédent reste disponible.',
      );
    }
  }

  /// Change de catégorie et recharge immédiatement les sections adaptées
  Future<void> selectCategory(String category) async {
    final nextCat = category.isEmpty ? 'all' : category;
    if (nextCat == state.selectedCategory) return;

    state = state.copyWith(
      selectedCategory: nextCat,
      isLoading: true,
      feedItems: const [],
      clearCursor: true,
      clearFeedError: true,
      hasMore: false,
      isLoadingMore: false,
    );
    // Une ancienne actualisation ne doit pas absorber la nouvelle catégorie.
    await _performFetch(isInitial: true);
  }

  /// Défilement infini : charge le lot d'épisodes suivant
  Future<void> fetchMoreFeed() async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) return;

    state = state.copyWith(isLoadingMore: true, clearFeedError: true);
    final int thisGeneration = _requestGeneration;
    final String? thisUserId = ref.read(authProvider).user?['id'] as String?;

    try {
      final auth = ref.read(authProvider);
      final feedRes = await BkoApi.get(
        '/home/feed?country=all&category=${state.selectedCategory}&cursor=${state.nextCursor}&limit=12',
        token: auth.token,
      );

      if (thisGeneration != _requestGeneration || thisUserId != _activeUserId) return;

      if (feedRes is Map) {
        final newItems = _asList(feedRes['items']);
        final nextCursor = feedRes['nextCursor']?.toString();
        final hasMore = feedRes['hasMore'] == true;

        // Déduplication par identifiant d'épisode
        final seenIds = state.feedItems.map((e) {
          if (e is Map) {
            return (e['episode']?['id'] ?? e['id'])?.toString();
          }
          return null;
        }).where((id) => id != null).toSet();

        final filteredNew = newItems.where((e) {
          if (e is Map) {
            final id = (e['episode']?['id'] ?? e['id'])?.toString();
            return id != null && !seenIds.contains(id);
          }
          return true;
        }).toList();

        state = state.copyWith(
          feedItems: [...state.feedItems, ...filteredNew],
          nextCursor: nextCursor,
          hasMore: hasMore,
          isLoadingMore: false,
          clearFeedError: true,
        );
      } else {
        state = state.copyWith(isLoadingMore: false);
      }
    } catch (_) {
      if (thisGeneration == _requestGeneration && thisUserId == _activeUserId) {
        state = state.copyWith(
          isLoadingMore: false,
          feedError: 'Impossible de charger la suite du catalogue.',
        );
      }
    }
  }

  void onUserChanged(String? newUserId) {
    _activeUserId = newUserId;
    // Invalide immédiatement toute requête en vol de l'ancien compte
    _requestGeneration++;
    _inFlightFetch = null;

    if (newUserId == null) {
      // Déconnexion : efface immédiatement toutes les données personnelles (sections personnalisées, historique)
      state = state.copyWith(
        clearHomeData: true,
        historyData: const [],
        feedItems: const [],
        clearCursor: true,
        hasMore: false,
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
      );
      // Recharge l'accueil anonyme propre
      refresh(silent: false);
    } else {
      // Changement de compte : efface les données de l'ancien compte et recharge immédiatement
      state = state.copyWith(
        clearHomeData: true,
        historyData: const [],
        feedItems: const [],
        clearCursor: true,
        hasMore: false,
        isLoading: true,
        isRefreshing: false,
        isLoadingMore: false,
      );
      refresh(silent: true);
    }
  }
}

final homeDataProvider = StateNotifierProvider<HomeDataNotifier, HomeDataState>((ref) {
  final notifier = HomeDataNotifier(ref);

  ref.listen<String?>(
    authProvider.select((a) => a.user?['id'] as String?),
    (previous, next) {
      if (previous != next) {
        notifier.onUserChanged(next);
      }
    },
  );

  return notifier;
});

/// Controls whether the home top header is collapsed (on scroll down) or expanded (on scroll up).
final homeHeaderCollapsedProvider = StateProvider<bool>((ref) => false);
