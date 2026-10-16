import 'package:flutter/material.dart';
import '../../../core/theme/bko_theme.dart';

class AuthLegalSheets {
  static void showHelp(BuildContext context) {
    _showSheet(
      context: context,
      icon: Icons.help_outline_rounded,
      title: 'Centre d\'aide & Assistance',
      contentSections: const [
        _Section(
          title: 'Écoute libre et immédiate',
          body:
              'Vous pouvez explorer et écouter tous les podcasts sans obligation de compte. L\'écoute reste fluide et accessible.',
        ),
        _Section(
          title: 'Pourquoi créer un compte ?',
          body:
              'Un compte personnel vous permet d\'enregistrer vos épisodes favoris, de suivre des émissions et de synchroniser vos playlists entre vos appareils.',
        ),
        _Section(
          title: 'Téléchargements hors connexion',
          body:
              'Téléchargez vos épisodes avec le bouton dédié pour les écouter partout, même sans couverture réseau.',
        ),
        _Section(
          title: 'Support technique',
          body:
              'Besoin d\'aide ou suggestion ? Écrivez-nous à support@bamakopodcast.studio ou via notre site bamakopodcast.studio.',
        ),
      ],
    );
  }

  static void showTerms(BuildContext context) {
    _showSheet(
      context: context,
      icon: Icons.description_outlined,
      title: 'Conditions d\'utilisation',
      contentSections: const [
        _Section(
          title: '1. Objet du service',
          body:
              'Bamako Podcast est une plateforme de diffusion et de partage de podcasts audio et vidéo, ouverte aux voix et aux récits d\'ici et d\'ailleurs.',
        ),
        _Section(
          title: '2. Création et sécurité du compte',
          body:
              'L\'utilisateur est responsable des informations fournies lors de son inscription. Le compte doit être validé via le code de vérification envoyé à son adresse e-mail.',
        ),
        _Section(
          title: '3. Propriété intellectuelle',
          body:
              'Les créateurs et producteurs conservent l\'intégralité des droits d\'auteur sur leurs œuvres. Toute reproduction non autorisée en dehors de la plateforme est interdite.',
        ),
        _Section(
          title: '4. Respect et règles de conduite',
          body:
              'Tout usage abusif, tentative de piratage ou diffusion de contenus enfreignant les lois en vigueur entraînera la suspension immédiate du compte.',
        ),
      ],
    );
  }

  static void showPrivacy(BuildContext context) {
    _showSheet(
      context: context,
      icon: Icons.shield_outlined,
      title: 'Politique de confidentialité',
      contentSections: const [
        _Section(
          title: '1. Données personnelles collectées',
          body:
              'Nous collectons uniquement les données strictement nécessaires au fonctionnement du service : nom/pseudo, adresse e-mail et numéro de téléphone si renseigné.',
        ),
        _Section(
          title: '2. Stockage et sécurité renforcée',
          body:
              'Vos mots de passe sont hachés de manière cryptographique et ne sont jamais stockés en clair. Vos jetons de session sont chiffrés sur votre appareil via le stockage sécurisé.',
        ),
        _Section(
          title: '3. Confidentialité garantie',
          body:
              'Bamako Podcast ne revend et ne loue aucune de vos données personnelles à des tiers. Les métriques d\'écoute restent strictement anonymisées.',
        ),
        _Section(
          title: '4. Vos droits d\'accès et de suppression',
          body:
              'Vous pouvez modifier vos informations à tout moment depuis votre profil ou demander la suppression définitive de votre compte par e-mail.',
        ),
      ],
    );
  }

  static void _showSheet({
    required BuildContext context,
    required IconData icon,
    required String title,
    required List<_Section> contentSections,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BkoTheme.getBgSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: BkoTheme.getBorderSubtle(context)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: BkoTheme.getBorderSubtle(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Sheet Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: BkoTheme.getBgSurface(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                        ),
                        child: Icon(icon, color: BkoTheme.getAccent(context), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: BkoTheme.fontPoppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: BkoTheme.getTextPrimary(context),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: BkoTheme.getTextSecondary(context)),
                        tooltip: 'Fermer',
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: BkoTheme.getBorderSubtle(context)),

                // Sheet Body
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: contentSections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final section = contentSections[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: BkoTheme.getBgSurface(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: BkoTheme.fontPoppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: BkoTheme.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              section.body,
                              style: BkoTheme.fontPoppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                                color: BkoTheme.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Section {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});
}
