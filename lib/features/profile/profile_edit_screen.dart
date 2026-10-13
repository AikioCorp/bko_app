import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../auth/auth_controller.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?['fullName'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final token = ref.read(authProvider).token;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final res = await BkoApi.patch(
        '/me',
        {'fullName': _nameController.text.trim()},
        token: token,
      );
      
      if (mounted) {
        final userMap = res is Map && res['data'] is Map
            ? Map<String, dynamic>.from(res['data'] as Map)
            : (res is Map ? Map<String, dynamic>.from(res) : null);
        if (userMap != null) {
          ref.read(authProvider.notifier).updateUser(userMap);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: BkoTheme.goldAccent,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour : $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Modifier mon profil',
          style: BkoTheme.fontLato(fontSize: 18, fontWeight: FontWeight.w800, color: textPri),
        ),
        backgroundColor: BkoTheme.getBgObsidian(context),
        elevation: 0,
        leading: const AppBackButton(),
      ),
      backgroundColor: BkoTheme.getBgObsidian(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nom complet',
                  style: BkoTheme.fontLato(fontSize: 13.5, fontWeight: FontWeight.w700, color: textSec),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: BkoTheme.fontLato(fontSize: 15, color: textPri),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: BkoTheme.goldAccent),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ce champ est requis';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                BkoBounceable(
                  onTap: _isLoading
                      ? null
                      : () {
                          BkoHaptics.light();
                          _save();
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _isLoading
                          ? BkoTheme.goldAccent.withValues(alpha: 0.5)
                          : BkoTheme.goldAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator.adaptive(
                              valueColor: AlwaysStoppedAnimation(BkoTheme.darkBgObsidian),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'ENREGISTRER',
                            style: BkoTheme.fontLato(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: BkoTheme.darkBgObsidian,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
