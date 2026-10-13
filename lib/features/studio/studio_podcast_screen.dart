import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/bko_api.dart';
import '../../core/widgets/app_back_button.dart';
import '../auth/auth_controller.dart';

class StudioPodcastScreen extends ConsumerStatefulWidget {
  final String podcastId;
  const StudioPodcastScreen({super.key, required this.podcastId});
  @override
  ConsumerState<StudioPodcastScreen> createState() =>
      _StudioPodcastScreenState();
}

class _StudioPodcastScreenState extends ConsumerState<StudioPodcastScreen> {
  Map<String, dynamic>? _podcast;
  List<dynamic> _episodes = [];
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = ref.read(authProvider).token;
      final result = await Future.wait([
        BkoApi.get('/creator/podcasts/${widget.podcastId}', token: token),
        BkoApi.get('/creator/podcasts/${widget.podcastId}/episodes',
            token: token),
      ]);
      if (!mounted) return;
      setState(() {
        _podcast = Map<String, dynamic>.from(result[0] as Map);
        _episodes = result[1] is List ? result[1] as List : [];
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error is ApiException
              ? error.message
              : 'Impossible de charger votre émission.';
        });
      }
    }
  }

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            leading: const AppBackButton(),
            title: Text('${_podcast?['name'] ?? 'Mon émission'}')),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 180),
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Réessayer'))
              ],
              if (_podcast != null) ...[
                Text('Statut : ${_status(_podcast!['status'])}'),
                const SizedBox(height: 8),
                Text('${_podcast!['description'] ?? ''}'),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: () => _open(
                        '/studio/episodes/new?podcastId=${widget.podcastId}'),
                    child: const Text('Ajouter un épisode')),
                TextButton(
                    onPressed: () => _open(
                        '/studio/import-rss?podcastId=${widget.podcastId}'),
                    child: const Text('Connecter un flux RSS')),
                const SizedBox(height: 20),
                const Text('Mes épisodes'),
                if (_episodes.isEmpty)
                  const Text(
                      'Votre émission est prête à accueillir son premier épisode.'),
                ..._episodes.map((episode) => ListTile(
                    title: Text('${episode['title']}'),
                    subtitle: Text(_status(episode['status'])))),
              ],
            ]),
      );
  String _status(dynamic status) =>
      const {
        'DRAFT': 'Brouillon',
        'PENDING_REVIEW': 'En attente de validation',
        'PUBLISHED': 'Publié',
        'SCHEDULED': 'Programmé',
        'ARCHIVED': 'Archivé'
      }[status] ??
      '$status';
}
