import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await BkoApi.post('/auth/forgot-password', {
        'email': _emailController.text.trim(),
      });
      if (mounted) setState(() { _loading = false; _sent = true; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Une erreur est survenue.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPri, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _sent
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mark_email_read_rounded, size: 54, color: BkoTheme.goldAccent),
                        const SizedBox(height: 16),
                        Text('Vérifiez votre boîte mail', style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w800, color: textPri)),
                        const SizedBox(height: 8),
                        Text(
                          'Un lien de réinitialisation vous a été envoyé si l\'adresse existe dans notre base.',
                          textAlign: TextAlign.center,
                          style: BkoTheme.fontLato(fontSize: 13, color: textSec, height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => context.go('/login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BkoTheme.goldAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('RETOUR À LA CONNEXION', style: BkoTheme.fontLato(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black)),
                        ),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Mot de passe oublié', style: BkoTheme.fontLato(fontSize: 26, fontWeight: FontWeight.w900, color: textPri)),
                      const SizedBox(height: 8),
                      Text(
                        'Saisissez l\'adresse email associée à votre compte Bamako Podcast pour recevoir un lien de réinitialisation.',
                        style: BkoTheme.fontLato(fontSize: 13, color: textSec, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: BkoTheme.fontLato(fontSize: 15, color: textPri),
                        decoration: InputDecoration(
                          hintText: 'votre.email@exemple.com',
                          hintStyle: BkoTheme.fontLato(fontSize: 14, color: textSec),
                          filled: true,
                          fillColor: surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BkoTheme.goldAccent)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty || !v.contains('@')) {
                            return 'Veuillez saisir un email valide.';
                          }
                          return null;
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!, style: BkoTheme.fontLato(fontSize: 12, color: Colors.red.shade300)),
                      ],
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BkoTheme.goldAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : Text('ENVOYER LE LIEN', style: BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black)),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
