class YoutubeUrlParser {
  YoutubeUrlParser._();

  static const Set<String> allowedDomains = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
    'www.youtu.be',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com',
  };

  static final RegExp _videoIdRegex = RegExp(r'^[a-zA-Z0-9_-]{11}$');
  static final RegExp _channelIdRegex = RegExp(r'^UC[a-zA-Z0-9_-]{22}$');

  static Uri? _tryParseUri(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return null;
    final withScheme = trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : (trimmed.contains('.') || trimmed.contains('/'))
            ? 'https://$trimmed'
            : null;
    if (withScheme == null) return null;
    final uri = Uri.tryParse(withScheme);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    if (uri.host.isEmpty) return null;
    return uri;
  }

  /// Vrai si l'URL appartient strictement à un domaine officiel YouTube.
  static bool isYoutubeDomain(String? rawUrl) {
    final uri = _tryParseUri(rawUrl);
    if (uri == null) return false;
    return allowedDomains.contains(uri.host.toLowerCase());
  }

  /// Vrai si le domaine contient "youtube" ou "youtu.be" sans être un domaine officiel YouTube.
  static bool isDeceptiveYoutubeDomain(String? rawUrl) {
    final uri = _tryParseUri(rawUrl);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (allowedDomains.contains(host)) return false;
    return host.contains('youtube') || host.contains('youtu.be');
  }

  /// Extrait et valide un identifiant vidéo YouTube de 11 caractères.
  /// Accepte :
  /// - youtube.com/watch?v=... (quelle que soit la position de v=)
  /// - youtu.be/...
  /// - youtube.com/shorts/...
  /// - youtube.com/live/...
  /// - youtube.com/embed/...
  /// - youtube-nocookie.com/embed/...
  /// - m.youtube.com / music.youtube.com et paramètres de partage (?si=..., &t=...)
  static String? tryParseVideoId(String? rawUrl) {
    final trimmed = (rawUrl ?? '').trim();
    if (trimmed.isEmpty) return null;

    // Si on passe directement un ID brut de 11 caractères (sans slash ni point)
    if (!trimmed.contains('/') &&
        !trimmed.contains('.') &&
        !trimmed.contains(':') &&
        _videoIdRegex.hasMatch(trimmed)) {
      return trimmed;
    }

    final uri = _tryParseUri(trimmed);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    if (!allowedDomains.contains(host)) {
      return null;
    }

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    String candidate = '';

    if (host == 'youtu.be' || host == 'www.youtu.be') {
      if (segments.isNotEmpty) {
        candidate = segments.first;
      }
    } else if (segments.isNotEmpty && segments.first == 'watch') {
      candidate = uri.queryParameters['v'] ?? '';
    } else if (segments.length >= 2 &&
        (segments.first == 'shorts' ||
            segments.first == 'live' ||
            segments.first == 'embed' ||
            segments.first == 'v')) {
      candidate = segments[1];
    } else {
      candidate = uri.queryParameters['v'] ?? '';
    }

    candidate = candidate.trim();
    if (!_videoIdRegex.hasMatch(candidate)) {
      return null;
    }
    return candidate;
  }

  /// Vrai si l'entrée correspond à une chaîne YouTube (handle @..., UC..., /channel/UC..., /@..., /c/..., /user/...)
  /// et non à une vidéo isolée.
  static bool isYoutubeChannelInput(String? rawInput) {
    final trimmed = (rawInput ?? '').trim();
    if (trimmed.isEmpty) return false;
    if (_channelIdRegex.hasMatch(trimmed)) return true;
    if (RegExp(r'^@[a-zA-Z0-9_.-]+$').hasMatch(trimmed)) return true;
    if (tryParseVideoId(trimmed) != null) return false;

    final uri = _tryParseUri(trimmed);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (!allowedDomains.contains(host) || host == 'youtu.be' || host == 'www.youtu.be') {
      return false;
    }

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return false;
    final first = segments.first;
    if (first == 'watch' || first == 'shorts' || first == 'live' || first == 'embed' || first == 'v') {
      return false;
    }
    if (first.startsWith('@') && first.length > 1) return true;
    if (first == 'channel' && segments.length >= 2 && _channelIdRegex.hasMatch(segments[1])) {
      return true;
    }
    if ((first == 'c' || first == 'user') && segments.length >= 2) {
      return true;
    }
    if (segments.length == 1 && !first.contains('.')) {
      return true;
    }
    return false;
  }

  static String? normalizeWatchUrl(String? rawUrl) {
    final id = tryParseVideoId(rawUrl);
    if (id == null) return null;
    return 'https://www.youtube.com/watch?v=$id';
  }

  static String? normalizeEmbedUrl(String? rawUrl) {
    final id = tryParseVideoId(rawUrl);
    if (id == null) return null;
    return 'https://www.youtube.com/embed/$id';
  }
}
