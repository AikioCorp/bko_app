import '../../core/widgets/app_header_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../../core/widgets/bko_toast.dart';
import '../auth/auth_controller.dart';

/// Écran complet de sécurité et gestion des appareils connectés.
/// - Changement de mot de passe réel avec validation et bascule afficher/masquer
/// - Liste des appareils/sessions actives (GET /me/devices)
/// - Révocation unitaire ou collective des autres sessions (DELETE /me/devices)
/// - Zéro ombre, zéro dégradé, conformité mobile-designer
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isChangingPassword = false;

  bool _isLoadingDevices = false;
  bool _isRevoking = false;
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _loginHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchDevices() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    setState(() => _isLoadingDevices = true);
    try {
      final res = await BkoApi.get('/me/devices', token: token);
      if (res is Map && res['data'] is List) {
        final list = (res['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (mounted) setState(() => _devices = list);
      } else if (res is List) {
        final list = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (mounted) setState(() => _devices = list);
      }
    } catch (_) {
      // Ignorer si pas encore d'appareils enregistrés
    }
    try {
      final activityRes = await BkoApi.get('/me/activity', token: token);
      final activityMap = (activityRes is Map && activityRes['data'] is Map)
          ? Map<String, dynamic>.from(activityRes['data'] as Map)
          : (activityRes is Map
              ? Map<String, dynamic>.from(activityRes)
              : null);
      final rawHistory = activityMap?['loginHistory'];
      if (rawHistory is List && mounted) {
        final history = rawHistory
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        setState(() => _loginHistory = history);
      }
    } catch (_) {
      // Historique optionnel si endpoint indisponible
    } finally {
      if (mounted) setState(() => _isLoadingDevices = false);
    }
  }

  String _formatMethodLabel(String method) {
    switch (method.toUpperCase()) {
      case 'PASSWORD':
        return 'Mot de passe';
      case 'OTP':
        return 'Code OTP';
      case 'GOOGLE':
        return 'Google';
      case 'APPLE':
        return 'Apple';
      default:
        return 'Session';
    }
  }

  String _formatHistoryDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Date inconnue';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'Date inconnue';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} • ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _handleChangePassword(bool hasPassword) async {
    if (!_passwordFormKey.currentState!.validate()) return;
    final token = ref.read(authProvider).token;
    if (token == null) return;

    setState(() => _isChangingPassword = true);
    try {
      await BkoApi.post(
        '/me/change-password',
        {
          if (hasPassword) 'currentPassword': _currentPasswordController.text,
          'newPassword': _newPasswordController.text,
        },
        token: token,
      );

      if (mounted) {
        setState(() {
          _isChangingPassword = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });

        await ref.read(authProvider.notifier).updateUser({'hasPassword': true});
        BkoHaptics.success();
        if (mounted) {
          BkoToast.showSuccess(
            context,
            title: 'Mot de passe enregistré',
            message: hasPassword
                ? 'Mot de passe modifié avec succès !'
                : 'Mot de passe défini avec succès !',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isChangingPassword = false);
        BkoHaptics.error();
        BkoToast.showError(
          context,
          title: 'Modification impossible',
          message: '$e',
        );
      }
    }
  }

  Future<void> _revokeDevice(String deviceId, String name) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BkoTheme.getBgSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Déconnecter cet appareil ?',
          style: BkoTheme.fontLato(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'La session active sur "$name" sera immédiatement fermée.',
          style: BkoTheme.fontLato(fontSize: 13, color: BkoTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              elevation: 0,
            ),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isRevoking = true);
      try {
        await BkoApi.delete('/me/devices/$deviceId', token: token);
        await _fetchDevices();
        BkoHaptics.success();
      } catch (e) {
        BkoHaptics.error();
      } finally {
        if (mounted) setState(() => _isRevoking = false);
      }
    }
  }

  Future<void> _revokeAllOtherDevices() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BkoTheme.getBgSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Déconnecter tous les autres appareils ?',
          style: BkoTheme.fontLato(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Toutes vos sessions actives seront fermées, sauf celle sur ce téléphone.',
          style: BkoTheme.fontLato(fontSize: 13, color: BkoTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              elevation: 0,
            ),
            child: const Text('Tout déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isRevoking = true);
      try {
        await BkoApi.delete('/me/devices', token: token);
        await _fetchDevices();
        BkoHaptics.success();
        if (mounted) {
          BkoToast.showSuccess(
            context,
            title: 'Sessions révoquées',
            message: 'Toutes les autres sessions ont été déconnectées.',
          );
        }
      } catch (e) {
        BkoHaptics.error();
      } finally {
        if (mounted) setState(() => _isRevoking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BkoTheme.getBgObsidian(context),
      appBar: AppBar(
        actions: const [AppHeaderActions()],
        leading: const AppBackButton(),
        title: Text(
          'Sécurité & appareils',
          style: BkoTheme.fontLato(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: BkoTheme.getTextPrimary(context),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Section Changement de mot de passe
          Builder(
            builder: (context) {
              final authUser = ref.watch(authProvider).user;
              final hasPassword = authUser?['hasPassword'] == true;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        hasPassword ? 'MOT DE PASSE' : 'DÉFINIR UN MOT DE PASSE',
                        style: BkoTheme.fontLato(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: BkoTheme.getTextMuted(context),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: hasPassword
                              ? BkoTheme.getSuccess(context).withValues(alpha: 0.15)
                              : BkoTheme.goldAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: hasPassword
                                ? BkoTheme.getSuccess(context).withValues(alpha: 0.3)
                                : BkoTheme.goldAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          hasPassword ? 'Mot de passe actif' : 'Compte Google',
                          style: BkoTheme.fontLato(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: hasPassword ? BkoTheme.getSuccess(context) : BkoTheme.goldAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: BkoTheme.getBgSurface(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: BkoTheme.getBorderSubtle(context)),
                    ),
                    child: Form(
                      key: _passwordFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!hasPassword) ...[
                            Text(
                              'Vous êtes actuellement connecté avec Google. Définissez un mot de passe personnel pour pouvoir vous connecter directement avec votre e-mail sur tous vos appareils sans Google.',
                              style: BkoTheme.fontLato(
                                fontSize: 12,
                                height: 1.4,
                                color: BkoTheme.getTextSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (hasPassword) ...[
                            _buildPasswordField(
                              controller: _currentPasswordController,
                              label: 'Mot de passe actuel',
                              obscure: _obscureCurrent,
                              onToggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
                              validator: (v) => (v == null || v.isEmpty) ? 'Saisissez votre mot de passe actuel' : null,
                            ),
                            const SizedBox(height: 14),
                          ],
                          _buildPasswordField(
                            controller: _newPasswordController,
                            label: hasPassword ? 'Nouveau mot de passe (min. 8 caractères)' : 'Créer un mot de passe (min. 8 caractères)',
                            obscure: _obscureNew,
                            onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                            validator: (v) {
                              if (v == null || v.length < 8) {
                                return 'Le mot de passe doit comporter au moins 8 caractères';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildPasswordField(
                            controller: _confirmPasswordController,
                            label: 'Confirmer le nouveau mot de passe',
                            obscure: _obscureConfirm,
                            onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            validator: (v) {
                              if (v != _newPasswordController.text) {
                                return 'Les mots de passe ne correspondent pas';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          BkoBounceable(
                            onTap: _isChangingPassword ? null : () => _handleChangePassword(hasPassword),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: BkoTheme.goldAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: _isChangingPassword
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(Colors.black),
                                        ),
                                      )
                                    : Text(
                                        hasPassword ? 'Mettre à jour le mot de passe' : 'Enregistrer le mot de passe',
                                        style: BkoTheme.fontLato(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // Section Appareils connectés
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'APPAREILS CONNECTÉS',
                style: BkoTheme.fontLato(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: BkoTheme.getTextMuted(context),
                ),
              ),
              if (_devices.length > 1)
                BkoBounceable(
                  onTap: _isRevoking ? null : _revokeAllOtherDevices,
                  child: Text(
                    'Tout déconnecter',
                    style: BkoTheme.fontLato(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: _isLoadingDevices
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(BkoTheme.goldAccent),
                      ),
                    ),
                  )
                : _devices.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: BkoTheme.goldAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Icon(
                                  IconsaxPlusLinear.mobile,
                                  color: BkoTheme.getAccent(context),
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cet appareil (Actif)',
                                    style: BkoTheme.fontLato(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: BkoTheme.getTextPrimary(context),
                                    ),
                                  ),
                                  Text(
                                    'Session en cours d\'utilisation',
                                    style: BkoTheme.fontLato(
                                      fontSize: 11.5,
                                      color: BkoTheme.getTextSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: _devices.map((device) {
                          final name = device['deviceName'] as String? ?? 'Appareil mobile';
                          final platform = device['platform'] as String? ?? 'Mobile';
                          final id = '${device['id']}';
                          final isCurrent = device['isCurrent'] == true;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: BkoTheme.getBorderSubtle(context),
                                  width: 0.8,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  platform.toLowerCase().contains('web')
                                      ? IconsaxPlusLinear.monitor
                                      : IconsaxPlusLinear.mobile,
                                  size: 22,
                                  color: BkoTheme.getTextPrimary(context),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            name,
                                            style: BkoTheme.fontLato(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: BkoTheme.getTextPrimary(context),
                                            ),
                                          ),
                                          if (isCurrent) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: BkoTheme.goldAccent,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'ACTUEL',
                                                style: BkoTheme.fontLato(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isCurrent ? 'En ligne' : 'Dernière activité récente',
                                        style: BkoTheme.fontLato(
                                          fontSize: 11.5,
                                          color: BkoTheme.getTextSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isCurrent)
                                  BkoBounceable(
                                    onTap: () => _revokeDevice(id, name),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        IconsaxPlusLinear.logout,
                                        size: 18,
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
          ),

          const SizedBox(height: 28),

          // Section Historique des connexions récentes
          Text(
            'HISTORIQUE DES CONNEXIONS RÉCENTES',
            style: BkoTheme.fontLato(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: BkoTheme.getTextMuted(context),
            ),
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: _isLoadingDevices && _loginHistory.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(BkoTheme.goldAccent),
                      ),
                    ),
                  )
                : _loginHistory.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(
                              IconsaxPlusLinear.clock,
                              size: 20,
                              color: BkoTheme.getTextMuted(context),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Aucune connexion enregistrée pour le moment.',
                                style: BkoTheme.fontLato(
                                  fontSize: 13,
                                  color: BkoTheme.getTextSecondary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: _loginHistory.take(10).toList().asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final itemsCount = _loginHistory.take(10).length;
                          final isLast = idx == itemsCount - 1;
                          final method = '${item['method'] ?? 'SESSION'}';
                          final deviceName = (item['deviceName'] as String?)?.isNotEmpty == true
                              ? item['deviceName'] as String
                              : 'Appareil';
                          final deviceType = '${item['deviceType'] ?? ''}'.toUpperCase();
                          final ipAddress = item['ipAddress'] as String?;
                          final createdAt = _formatHistoryDate(item['createdAt']?.toString());
                          final isActive = item['isActive'] == true;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            decoration: BoxDecoration(
                              border: isLast
                                  ? null
                                  : Border(
                                      bottom: BorderSide(
                                        color: BkoTheme.getBorderSubtle(context),
                                        width: 0.8,
                                      ),
                                    ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: BkoTheme.getBgSurfaceElevated(context),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: BkoTheme.getBorderSubtle(context),
                                    ),
                                  ),
                                  child: Icon(
                                    deviceType == 'WEB'
                                        ? IconsaxPlusLinear.monitor
                                        : IconsaxPlusLinear.mobile,
                                    size: 18,
                                    color: BkoTheme.getAccent(context),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            deviceName,
                                            style: BkoTheme.fontLato(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: BkoTheme.getTextPrimary(context),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: BkoTheme.goldAccent.withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              _formatMethodLabel(method),
                                              style: BkoTheme.fontLato(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: BkoTheme.getAccent(context),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        ipAddress != null && ipAddress.isNotEmpty
                                            ? '$createdAt • IP $ipAddress'
                                            : createdAt,
                                        style: BkoTheme.fontLato(
                                          fontSize: 11.5,
                                          color: BkoTheme.getTextSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? BkoTheme.goldAccent.withValues(alpha: 0.18)
                                        : BkoTheme.getBgSurfaceElevated(context),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isActive
                                          ? BkoTheme.goldAccent.withValues(alpha: 0.45)
                                          : BkoTheme.getBorderSubtle(context),
                                    ),
                                  ),
                                  child: Text(
                                    isActive ? 'Active' : 'Terminée',
                                    style: BkoTheme.fontLato(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isActive
                                          ? BkoTheme.getAccent(context)
                                          : BkoTheme.getTextMuted(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
          ),

          const SizedBox(height: 24),

          // Note de sécurité
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BkoTheme.getBgSurfaceElevated(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BkoTheme.getBorderSubtle(context)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  IconsaxPlusLinear.shield_security,
                  size: 20,
                  color: BkoTheme.getAccent(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Toutes vos communications sont chiffrées de bout en bout via TLS/HTTPS. Bamako Podcast ne conserve jamais vos mots de passe en clair.',
                    style: BkoTheme.fontLato(
                      fontSize: 12,
                      color: BkoTheme.getTextSecondary(context),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: BkoTheme.fontLato(fontSize: 14, color: BkoTheme.getTextPrimary(context)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: BkoTheme.fontLato(fontSize: 12.5, color: BkoTheme.getTextSecondary(context)),
        filled: true,
        fillColor: BkoTheme.getBgSurfaceElevated(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: BkoTheme.getBorderSubtle(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: BkoTheme.getBorderSubtle(context)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: BkoTheme.goldAccent, width: 1.2),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? IconsaxPlusLinear.eye_slash : IconsaxPlusLinear.eye,
            size: 18,
            color: BkoTheme.getTextSecondary(context),
          ),
          onPressed: () {
            BkoHaptics.selection();
            onToggleObscure();
          },
        ),
      ),
    );
  }
}
