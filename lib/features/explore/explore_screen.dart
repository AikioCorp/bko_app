import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  bool _loading = true;
  List<dynamic> _categories = [];
  List<dynamic> _countries = [];
  List<dynamic> _topics = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final data = await BkoApi.get('/explore');
    if (!mounted) return;
    setState(() {
      if (data is Map) {
        _categories = (data['categories'] as List?) ?? [];
        _countries = (data['countries'] as List?) ?? [];
        _topics = (data['topics'] as List?) ?? [];
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: BkoTheme.goldAccent))
            : RefreshIndicator(
                color: BkoTheme.goldAccent,
                onRefresh: _fetch,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  children: [
                    Text('Explorer',
                        style: BkoTheme.fontLato(fontSize: 28, fontWeight: FontWeight.w800, color: textPri)),
                    const SizedBox(height: 4),
                    Text('Podcasts maliens et africains par thème',
                        style: BkoTheme.fontLato(fontSize: 13, color: textSec)),
                    const SizedBox(height: 24),

                    _sectionTitle('Catégories', textPri),
                    const SizedBox(height: 12),
                    if (_categories.isEmpty)
                      _emptyHint('Aucune catégorie disponible.', textSec)
                    else
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.4,
                        children: _categories.map((c) {
                          final map = c as Map;
                          final count = (map['_count']?['podcasts'] ?? 0).toString();
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${map['name'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: BkoTheme.fontLato(
                                        fontSize: 14, fontWeight: FontWeight.w700, color: textPri)),
                                const SizedBox(height: 4),
                                Text('$count podcasts',
                                    style: BkoTheme.fontLato(fontSize: 11, color: textSec)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 28),
                    _sectionTitle('Pays', textPri),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _countries.map((c) {
                        final map = c as Map;
                        return _chip('${map['flagEmoji'] ?? ''} ${map['name'] ?? ''}', surface, border, textPri);
                      }).toList(),
                    ),

                    const SizedBox(height: 28),
                    _sectionTitle('Thèmes', textPri),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _topics.map((t) {
                        final map = t as Map;
                        return _chip('${map['name'] ?? ''}', surface, border, textPri);
                      }).toList(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(String label, Color color) =>
      Text(label, style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w800, color: color));

  Widget _emptyHint(String text, Color color) =>
      Text(text, style: BkoTheme.fontLato(fontSize: 13, color: color));

  Widget _chip(String label, Color bg, Color border, Color text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(label, style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w600, color: text)),
      );
}
