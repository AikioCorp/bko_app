import '../../core/widgets/app_header_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
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
    BkoHaptics.light();
    await context.push(path);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final bgSurf = BkoTheme.getBgSurface(context);
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      backgroundColor: bgSurf,
      appBar: AppBar(
        backgroundColor: bgSurf,
        elevation: 0,
        actions: const [AppHeaderActions()],
        leading: const AppBackButton(),
        title: Text(
          '${_podcast?['name'] ?? 'Mon émission'}',
          style: BkoTheme.fontLato(
              fontSize: 18, fontWeight: FontWeight.w800, color: textPri),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 180),
        children: [
          if (_loading)
            const LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation(BkoTheme.goldAccent),
            ),
          if (_error != null) ...[
            Text(_error!,
                style: BkoTheme.fontLato(
                    fontSize: 13, color: Theme.of(context).colorScheme.error)),
            TextButton(onPressed: _load, child: const Text('Réessayer'))
          ],
          if (_podcast != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderSub),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statut : ${_status(_podcast!['status'])}',
                    style: BkoTheme.fontLato(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: BkoTheme.goldAccent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_podcast!['description'] ?? ''}',
                    style: BkoTheme.fontLato(
                        fontSize: 13.5, color: textSec, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BkoBounceable(
              onTap: () =>
                  _open('/studio/episodes/new?podcastId=${widget.podcastId}'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BkoTheme.goldAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(IconsaxPlusLinear.add_circle,
                        size: 18, color: BkoTheme.darkBgObsidian),
                    const SizedBox(width: 8),
                    Text(
                      'AJOUTER UN ÉPISODE',
                      style: BkoTheme.fontLato(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: BkoTheme.darkBgObsidian,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: BkoBounceable(
                    onTap: () => _open(
                        '/studio/import-rss?podcastId=${widget.podcastId}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: bgElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderSub),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(IconsaxPlusLinear.routing,
                              size: 16, color: BkoTheme.goldAccent),
                          const SizedBox(width: 6),
                          Text(
                            'Flux RSS',
                            style: BkoTheme.fontLato(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: textPri,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BkoBounceable(
                    onTap: () => _open(
                        '/studio/import-youtube?podcastId=${widget.podcastId}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: bgElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderSub),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(IconsaxPlusLinear.video,
                              size: 16, color: Colors.redAccent),
                          const SizedBox(width: 6),
                          Text(
                            'Chaîne YouTube',
                            style: BkoTheme.fontLato(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: textPri,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            BkoBounceable(
              onTap: () => _open('/studio/podcasts/${widget.podcastId}/team'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderSub),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(IconsaxPlusLinear.people,
                        size: 16, color: BkoTheme.goldAccent),
                    const SizedBox(width: 6),
                    Text(
                      'Équipe & Collaborateurs',
                      style: BkoTheme.fontLato(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: textPri,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'MES ÉPISODES (${_episodes.length})',
              style: BkoTheme.fontLato(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: textSec,
              ),
            ),
            const SizedBox(height: 10),
            if (_episodes.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: bgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderSub),
                ),
                child: Text(
                  'Votre émission est prête à accueillir son premier épisode.',
                  style: BkoTheme.fontLato(fontSize: 13, color: textSec),
                ),
              ),
            ..._episodes.map((episode) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: bgElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderSub),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      title: Text(
                        '${episode['title']}',
                        style: BkoTheme.fontLato(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: textPri),
                      ),
                      subtitle: Text(
                        _status(episode['status']),
                        style: BkoTheme.fontLato(fontSize: 12, color: textSec),
                      ),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

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
