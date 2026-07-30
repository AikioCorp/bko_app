import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/brand/app_icon.png',
              width: 32,
              height: 32,
              errorBuilder: (context, error, stackTrace) => Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6B009),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mic, color: Colors.black, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'BKO PODCAST',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 1.1,
                color: Color(0xFFF0F6FC),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Hero Éditorial
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6B009).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6B009),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'À LA UNE AU MALI',
                      style: TextStyle(color: Color(0xFF0B0F17), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Voix de Bamako',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Entreprendre au Mali : Défis, opportunités et vision 2030',
                    style: TextStyle(fontSize: 14, color: Color(0xFF8B949E)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push('/podcasts/voix-de-bamako/episodes/entreprendre-au-mali-defis-et-opportunites');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE6B009),
                      foregroundColor: const Color(0xFF0B0F17),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('ÉCOUTER L\'ÉPISODE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Podcasts de Référence 🇲🇱',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6B009).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.graphic_eq, color: Color(0xFFE6B009)),
                ),
                title: const Text('Voix de Bamako', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC))),
                subtitle: const Text('Par Mohamed Traoré • Français / Bambara', style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFFE6B009)),
                onTap: () {
                  context.push('/podcasts/voix-de-bamako');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
