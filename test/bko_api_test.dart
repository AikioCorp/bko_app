import 'package:bko_app/core/network/bko_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BkoApi media source extraction', () {
    test('prefers the primary audio source when available', () {
      final url = BkoApi.extractAudioUrl({
        'primaryAudioSource': {
          'externalUrl': 'https://cdn.example.com/episode.mp3',
        },
        'mediaSources': [
          {'type': 'AUDIO', 'externalUrl': 'https://cdn.example.com/other.mp3'},
        ],
      });

      expect(url, 'https://cdn.example.com/episode.mp3');
    });

    test('uses a media asset URL when a source has no direct URL', () {
      final url = BkoApi.extractVideoUrl({
        'mediaSources': [
          {
            'type': 'VIDEO',
            'isPrimaryVideo': true,
            'mediaAsset': {'url': 'https://cdn.example.com/episode.mp4'},
          },
        ],
      });

      expect(url, 'https://cdn.example.com/episode.mp4');
    });

    test('does not manufacture a source from cover art', () {
      const episode = <String, dynamic>{
        'cover': 'https://img.youtube.com/vi/example/maxresdefault.jpg',
      };

      expect(BkoApi.extractAudioUrl(episode), isNull);
      expect(BkoApi.extractVideoUrl(episode), isNull);
    });
  });
}
