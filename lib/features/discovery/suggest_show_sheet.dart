import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/bko_toast.dart';

Future<void> showSuggestShowSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: BkoTheme.getBgSurface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _SuggestShowSheet(),
  );
}

class _SuggestShowSheet extends StatefulWidget {
  const _SuggestShowSheet();

  @override
  State<_SuggestShowSheet> createState() => _SuggestShowSheetState();
}

class _SuggestShowSheetState extends State<_SuggestShowSheet> {
  final _nameCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _linkCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      BkoToast.showError(
        context,
        title: 'Nom requis',
        message: 'Veuillez indiquer le nom de l\'émission ou du créateur.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await BkoApi.post('/discovery/suggestions', {
        'name': name,
        if (_linkCtrl.text.trim().isNotEmpty) 'sourceUrl': _linkCtrl.text.trim(),
        if (_detailsCtrl.text.trim().isNotEmpty) 'details': _detailsCtrl.text.trim(),
      });
      if (!mounted) return;
      BkoHaptics.tapDown();
      Navigator.of(context).pop();
      BkoToast.showSuccess(
        context,
        title: 'Suggestion envoyée',
        message: 'Merci ! Votre proposition a été transmise à l\'équipe.',
      );
    } catch (e) {
      if (!mounted) return;
      BkoToast.showError(
        context,
        title: 'Erreur',
        message: 'Impossible d\'envoyer la suggestion pour le moment.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final textPrimary = BkoTheme.getTextPrimary(context);
    final textSecondary = BkoTheme.getTextSecondary(context);
    final border = BkoTheme.getBorderSubtle(context);
    final surfaceElevated = BkoTheme.getBgSurfaceElevated(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(IconsaxPlusLinear.radio, color: BkoTheme.goldAccent, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Proposer une émission',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Suggérez un podcast, un griot ou une émission radio à ajouter au catalogue.',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nom de l\'émission ou du créateur *',
                filled: true,
                fillColor: surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _linkCtrl,
              keyboardType: TextInputType.url,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Lien YouTube, RSS ou site web (optionnel)',
                filled: true,
                fillColor: surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsCtrl,
              maxLines: 3,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Pourquoi recommandez-vous cette voix ? (optionnel)',
                filled: true,
                fillColor: surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: border),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: BkoTheme.goldAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _submitting ? 'Envoi en cours...' : 'Envoyer ma suggestion',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
