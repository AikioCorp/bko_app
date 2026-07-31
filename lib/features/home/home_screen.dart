import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/bko_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BkoTheme.bgObsidian,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: BkoTheme.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BkoTheme.borderSubtle),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/brand/app_icon.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.mic,
                    color: BkoTheme.goldAccent,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'BKO PODCAST',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
                color: BkoTheme.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: BkoTheme.textSecondary),
            onPressed: () => context.go('/search'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HERO CINÉMATOGRAPHIQUE & MINIMAL
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: BkoTheme.bgSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: BkoTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'À LA UNE AU MALI',
                    style: TextStyle(
                      color: BkoTheme.goldAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Les voix qui font bouger Bamako.',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      height: 1.15,
                      color: BkoTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Une immersion exclusive au cœur des récits et conversations du Mali.',
                    style: TextStyle(fontSize: 13, color: BkoTheme.textSecondary, height: 1.35),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push('/podcasts/voix-de-bamako/episodes/entreprendre-au-mali-defis-et-opportunites');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BkoTheme.goldAccent,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text(
                        'ÉCOUTER L\'ÉPISODE',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: -0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 2. LES INCONTOURNABLES DU MALI
            const Text(
              'Les incontournables du Mali',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: BkoTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 14),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildPodcastCard(
                    context,
                    title: 'Voix de Bamako',
                    creator: 'Studio Bamako Podcast',
                    slug: 'voix-de-bamako',
                  ),
                  const SizedBox(width: 14),
                  _buildPodcastCard(
                    context,
                    title: 'Bamako Tech Talk',
                    creator: 'Mali Digital Hub',
                    slug: 'bamako-tech-talk',
                  ),
                  const SizedBox(width: 14),
                  _buildPodcastCard(
                    context,
                    title: 'Histoires & Terroirs',
                    creator: 'Culture Mali',
                    slug: 'histoires-et-terroirs',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 3. À ÉCOUTER CETTE SEMAINE
            const Text(
              'À écouter cette semaine',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: BkoTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _buildEpisodeRow(
              index: '01',
              title: 'L\'avenir de la FinTech et des paiements mobiles',
              podcast: 'Bamako Tech Talk • 28 min',
            ),
            const Divider(color: BkoTheme.borderSubtle, height: 1),
            _buildEpisodeRow(
              index: '02',
              title: 'S\'implanter dans la sous-région : Retour d\'expérience',
              podcast: 'Voix de Bamako • 42 min',
            ),
            const Divider(color: BkoTheme.borderSubtle, height: 1),
            _buildEpisodeRow(
              index: '03',
              title: 'Récits transmis : L\'art du conte malien réinventé',
              podcast: 'Histoires & Terroirs • 35 min',
            ),

            const SizedBox(height: 32),

            // 4. EN BAMANANKAN
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: BkoTheme.bgSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: BkoTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PATRIMOINE AUDIO',
                    style: TextStyle(
                      color: BkoTheme.goldAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'En Bamanankan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: BkoTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Les histoires, les idées et les voix dans notre langue.',
                    style: TextStyle(fontSize: 12, color: BkoTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  _buildBambaraItem('Bamanankan kɔnɔ sɔrɔtan ni jɛmuw', 'Savoirs en Bamanankan • 34 min'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPodcastCard(BuildContext context, {required String title, required String creator, required String slug}) {
    return GestureDetector(
      onTap: () => context.push('/podcasts/$slug'),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: BkoTheme.bgSurfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BkoTheme.borderSubtle),
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: BkoTheme.goldAccent, size: 48),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: BkoTheme.textPrimary,
              ),
            ),
            Text(
              creator,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: BkoTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeRow({required String index, required String title, required String podcast}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(
            index,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: BkoTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BkoTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  podcast,
                  style: const TextStyle(fontSize: 11, color: BkoTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: BkoTheme.bgSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: BkoTheme.goldAccent, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildBambaraItem(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BkoTheme.bgObsidian,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BkoTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BkoTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: BkoTheme.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.play_circle_fill, color: BkoTheme.goldAccent, size: 28),
        ],
      ),
    );
  }
}
