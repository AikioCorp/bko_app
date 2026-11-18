import 'dart:async';
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

/// Droits d'administration de l'utilisateur connecté via GET /admin/access.
final adminAccessProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.token == null) {
    return {'isSuperAdmin': false, 'roles': <String>[], 'permissions': <String>[]};
  }
  try {
    final data = await BkoApi.get('/admin/access', token: auth.token);
    if (data is Map<String, dynamic>) return data;
    return {'isSuperAdmin': false, 'roles': <String>[], 'permissions': <String>[]};
  } catch (_) {
    return {'isSuperAdmin': false, 'roles': <String>[], 'permissions': <String>[]};
  }
});

bool hasAdminPermission(Map<String, dynamic>? access, String code) {
  if (access == null) return false;
  if (access['isSuperAdmin'] == true) return true;
  final perms = (access['permissions'] as List?)?.map((e) => '$e').toList() ?? [];
  return perms.contains(code);
}

/// Écran mobile de création et modification des comptes utilisateurs
/// réservé aux administrateurs et membres autorisés (users.view / users.create / users.edit).
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  List<String> _assignableRoles = ['USER', 'CREATOR'];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    await Future.wait([_fetchUsers(), _fetchAssignableRoles()]);
  }

  Future<void> _fetchAssignableRoles() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      final res = await BkoApi.get('/admin/assignable-roles', token: token);
      if (res is List && mounted) {
        final names = res
            .map((e) => (e is Map ? e['name'] : e)?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (names.isNotEmpty) {
          setState(() => _assignableRoles = names);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchUsers() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final q = _searchCtrl.text.trim();
      final query = q.isEmpty ? '' : '&search=${Uri.encodeQueryComponent(q)}';
      final res = await BkoApi.get('/admin/users?page=1&limit=40$query', token: token);
      final items = (res is Map ? res['items'] : res) as List? ?? [];
      if (mounted) {
        setState(() {
          _users = items.whereType<Map<String, dynamic>>().toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _fetchUsers);
  }

  List<String> _extractRoles(Map<String, dynamic> u) {
    final direct = (u['roles'] as List?)?.map((e) => '$e').toList();
    if (direct != null && direct.isNotEmpty) return direct;
    final userRoles = (u['userRoles'] as List?) ?? [];
    return userRoles
        .map((ur) => (ur is Map ? (ur['role'] is Map ? ur['role']['name'] : ur['role']) : ur)?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final accessAsync = ref.watch(adminAccessProvider);
    final access = accessAsync.value;
    final canCreate = hasAdminPermission(access, 'users.create');
    final canEdit = hasAdminPermission(access, 'users.edit');

    final bg = BkoTheme.getBgObsidian(context);
    final surface = BkoTheme.getBgSurface(context);
    final border = BkoTheme.getBorderSubtle(context);
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Gestion des comptes',
          style: BkoTheme.fontLato(fontSize: 17, fontWeight: FontWeight.w800, color: textPri),
        ),
        actions: [
          if (canCreate)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: BkoBounceable(
                onTap: () {
                  BkoHaptics.selection();
                  _openCreateSheet();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        IconsaxPlusLinear.user_add,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Créer',
                        style: BkoTheme.fontLato(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: BkoTheme.fontLato(fontSize: 14, color: textPri),
              decoration: InputDecoration(
                hintText: 'Rechercher nom, email ou téléphone...',
                hintStyle: BkoTheme.fontLato(fontSize: 13, color: textSec),
                prefixIcon: Icon(IconsaxPlusLinear.search_normal_1, size: 18, color: textSec),
                filled: true,
                fillColor: surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primary),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primary))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: BkoTheme.fontLato(fontSize: 13, color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      )
                    : _users.isEmpty
                        ? Center(
                            child: Text(
                              'Aucun utilisateur trouvé.',
                              style: BkoTheme.fontLato(fontSize: 14, color: textSec),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchUsers,
                            color: primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                              itemCount: _users.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final u = _users[i];
                                final roles = _extractRoles(u);
                                final isVerified = u['isVerified'] == true;
                                final isSuspended = u['isSuspended'] == true;
                                final fullName = (u['fullName'] ?? 'Sans nom').toString();
                                final email = (u['email'] ?? '').toString();

                                return BkoBounceable(
                                  onTap: canEdit
                                      ? () {
                                          BkoHaptics.selection();
                                          _openEditSheet(u);
                                        }
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: border),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 21,
                                          backgroundColor: BkoTheme.getBgSurfaceElevated(context),
                                          child: Text(
                                            fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                                            style: BkoTheme.fontLato(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      fullName,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: BkoTheme.fontLato(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w700,
                                                        color: textPri,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                    isVerified
                                                        ? IconsaxPlusBold.verify
                                                        : IconsaxPlusLinear.clock,
                                                    size: 14,
                                                    color: isVerified ? primary : textSec,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                email,
                                                overflow: TextOverflow.ellipsis,
                                                style: BkoTheme.fontLato(fontSize: 12, color: textSec),
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  if (isSuspended)
                                                    _chip(
                                                      context,
                                                      'Bloqué',
                                                      Theme.of(context).colorScheme.error,
                                                    ),
                                                  ...roles.map((r) => _chip(context, r, textSec)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (canEdit)
                                          Icon(IconsaxPlusLinear.edit_2, size: 18, color: textSec),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: BkoTheme.getBgSurfaceElevated(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: BkoTheme.getBorderSubtle(context)),
      ),
      child: Text(
        label,
        style: BkoTheme.fontLato(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Future<void> _openCreateSheet() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isVerified = true;
    final selectedRoles = <String>{'USER'};
    bool saving = false;
    String? err;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BkoTheme.getBgSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Créer un compte utilisateur',
                    style: BkoTheme.fontLato(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: BkoTheme.getTextPrimary(ctx),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (err != null) ...[
                    Text(
                      err!,
                      style: BkoTheme.fontLato(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _field(ctx, nameCtrl, 'Nom complet *', IconsaxPlusLinear.user),
                  const SizedBox(height: 10),
                  _field(ctx, emailCtrl, 'Adresse e-mail *', IconsaxPlusLinear.sms,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 10),
                  _field(ctx, passCtrl, 'Mot de passe (min 8 car.) *', IconsaxPlusLinear.lock,
                      obscure: true),
                  const SizedBox(height: 10),
                  _field(ctx, phoneCtrl, 'Téléphone (optionnel)', IconsaxPlusLinear.call,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 10),
                  _field(ctx, usernameCtrl, 'Nom d\'utilisateur (optionnel)', IconsaxPlusLinear.tag),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isVerified,
                    onChanged: (v) => setModalState(() => isVerified = v),
                    title: Text(
                      'Compte vérifié (sans OTP)',
                      style: BkoTheme.fontLato(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BkoTheme.getTextPrimary(ctx),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rôles',
                    style: BkoTheme.fontLato(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BkoTheme.getTextSecondary(ctx),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _assignableRoles.map((r) {
                      final active = selectedRoles.contains(r);
                      return FilterChip(
                        label: Text(r),
                        selected: active,
                        onSelected: (sel) {
                          setModalState(() {
                            if (sel) {
                              selectedRoles.add(r);
                            } else if (selectedRoles.length > 1) {
                              selectedRoles.remove(r);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (nameCtrl.text.trim().isEmpty ||
                                  emailCtrl.text.trim().isEmpty ||
                                  passCtrl.text.length < 8) {
                                setModalState(() => err = 'Nom, e-mail et mot de passe (8+ car.) requis.');
                                return;
                              }
                              setModalState(() {
                                saving = true;
                                err = null;
                              });
                              try {
                                final token = ref.read(authProvider).token;
                                await BkoApi.post(
                                  '/admin/users',
                                  {
                                    'fullName': nameCtrl.text.trim(),
                                    'email': emailCtrl.text.trim().toLowerCase(),
                                    'password': passCtrl.text,
                                    'phoneNumber': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                    'username': usernameCtrl.text.trim().isEmpty
                                        ? null
                                        : usernameCtrl.text.trim().toLowerCase(),
                                    'isVerified': isVerified,
                                    'roles': selectedRoles.toList(),
                                  },
                                  token: token,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  BkoHaptics.success();
                                  BkoToast.showSuccess(
                                    context,
                                    title: 'Compte créé',
                                    message: '${emailCtrl.text.trim()} est prêt à l\'emploi.',
                                  );
                                  await _fetchUsers();
                                }
                              } catch (e) {
                                setModalState(() {
                                  saving = false;
                                  err = e.toString();
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Créer le compte'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditSheet(Map<String, dynamic> user) async {
    final userId = user['id'].toString();
    final nameCtrl = TextEditingController(text: (user['fullName'] ?? '').toString());
    final emailCtrl = TextEditingController(text: (user['email'] ?? '').toString());
    final phoneCtrl = TextEditingController(text: (user['phoneNumber'] ?? '').toString());
    final usernameCtrl = TextEditingController(text: (user['username'] ?? '').toString());
    final newPassCtrl = TextEditingController();
    bool isVerified = user['isVerified'] == true;
    final initialRoles = _extractRoles(user).toSet();
    final selectedRoles = Set<String>.from(initialRoles.isEmpty ? {'USER'} : initialRoles);
    bool saving = false;
    String? err;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BkoTheme.getBgSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modifier le compte',
                    style: BkoTheme.fontLato(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: BkoTheme.getTextPrimary(ctx),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (err != null) ...[
                    Text(
                      err!,
                      style: BkoTheme.fontLato(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _field(ctx, nameCtrl, 'Nom complet', IconsaxPlusLinear.user),
                  const SizedBox(height: 10),
                  _field(ctx, emailCtrl, 'Adresse e-mail', IconsaxPlusLinear.sms,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 10),
                  _field(ctx, phoneCtrl, 'Téléphone', IconsaxPlusLinear.call,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 10),
                  _field(ctx, usernameCtrl, 'Nom d\'utilisateur', IconsaxPlusLinear.tag),
                  const SizedBox(height: 10),
                  _field(ctx, newPassCtrl, 'Nouveau mot de passe (optionnel)', IconsaxPlusLinear.lock,
                      obscure: true),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isVerified,
                    onChanged: (v) => setModalState(() => isVerified = v),
                    title: Text(
                      'Compte vérifié (e-mail / OTP)',
                      style: BkoTheme.fontLato(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BkoTheme.getTextPrimary(ctx),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rôles',
                    style: BkoTheme.fontLato(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BkoTheme.getTextSecondary(ctx),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _assignableRoles.map((r) {
                      final active = selectedRoles.contains(r);
                      return FilterChip(
                        label: Text(r),
                        selected: active,
                        onSelected: (sel) {
                          setModalState(() {
                            if (sel) {
                              selectedRoles.add(r);
                            } else if (selectedRoles.length > 1) {
                              selectedRoles.remove(r);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setModalState(() {
                                saving = true;
                                err = null;
                              });
                              try {
                                final token = ref.read(authProvider).token;
                                await BkoApi.patch(
                                  '/admin/users/$userId',
                                  {
                                    'fullName': nameCtrl.text.trim(),
                                    'email': emailCtrl.text.trim().toLowerCase(),
                                    'phoneNumber': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                    'username': usernameCtrl.text.trim().isEmpty
                                        ? null
                                        : usernameCtrl.text.trim().toLowerCase(),
                                    'isVerified': isVerified,
                                  },
                                  token: token,
                                );

                                final rolesChanged = selectedRoles.length != initialRoles.length ||
                                    !selectedRoles.every(initialRoles.contains);
                                if (rolesChanged) {
                                  await BkoApi.put(
                                    '/admin/users/$userId/roles',
                                    {'roles': selectedRoles.toList()},
                                    token: token,
                                  );
                                }

                                if (newPassCtrl.text.trim().length >= 8) {
                                  await BkoApi.post(
                                    '/admin/users/$userId/reset-password',
                                    {
                                      'mode': 'DIRECT',
                                      'password': newPassCtrl.text.trim(),
                                      'revokeSessions': true,
                                    },
                                    token: token,
                                  );
                                }

                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  BkoHaptics.success();
                                  BkoToast.showSuccess(
                                    context,
                                    title: 'Compte mis à jour',
                                    message: '${nameCtrl.text.trim()} enregistré.',
                                  );
                                  await _fetchUsers();
                                }
                              } catch (e) {
                                setModalState(() {
                                  saving = false;
                                  err = e.toString();
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Enregistrer les modifications'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _field(
    BuildContext context,
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: BkoTheme.fontLato(fontSize: 14, color: BkoTheme.getTextPrimary(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: BkoTheme.fontLato(fontSize: 13, color: BkoTheme.getTextSecondary(context)),
        prefixIcon: Icon(icon, size: 18, color: BkoTheme.getTextSecondary(context)),
        filled: true,
        fillColor: BkoTheme.getBgSurfaceElevated(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: BkoTheme.getBorderSubtle(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}
