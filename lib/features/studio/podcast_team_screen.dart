import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_header_actions.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../auth/auth_controller.dart';

class PodcastTeamScreen extends ConsumerStatefulWidget {
  final String podcastId;
  const PodcastTeamScreen({super.key, required this.podcastId});

  @override
  ConsumerState<PodcastTeamScreen> createState() => _PodcastTeamScreenState();
}

class _PodcastTeamScreenState extends ConsumerState<PodcastTeamScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  List<dynamic> _members = [];
  List<dynamic> _invitations = [];
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        BkoApi.get('/creator/podcasts/${widget.podcastId}/members',
            token: auth.token),
        BkoApi.get('/creator/podcasts/${widget.podcastId}/invitations',
            token: auth.token),
      ]);

      if (!mounted) return;

      final membersList = (results[0] is List
          ? results[0]
          : (results[0] is Map && results[0]['data'] is List
              ? results[0]['data']
              : [])) as List;

      final invitationsList = (results[1] is List
          ? results[1]
          : (results[1] is Map && results[1]['data'] is List
              ? results[1]['data']
              : [])) as List;

      // Détecter le rôle de l'utilisateur connecté sur cette émission
      final myId = auth.user?['id'];
      final myMember = membersList.firstWhere(
        (m) => m is Map && (m['userId'] == myId || m['user']?['id'] == myId),
        orElse: () => null,
      );

      setState(() {
        _members = membersList;
        _invitations = invitationsList;
        _currentUserRole = myMember != null && myMember is Map
            ? '${myMember['role']}'.toUpperCase()
            : (auth.isCreatorOrAdmin ? 'OWNER' : 'MEMBER');
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Impossible de charger l\'équipe de cette émission.';
          _loading = false;
        });
      }
    }
  }

  bool get _canManageTeam =>
      _currentUserRole == 'OWNER' ||
      _currentUserRole == 'ADMIN' ||
      ref.read(authProvider).isCreatorOrAdmin;

  void _showAddMemberModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddDirectMemberSheet(
        podcastId: widget.podcastId,
        canAssignOwner: _currentUserRole == 'OWNER',
        onAdded: () {
          _loadAll();
        },
      ),
    );
  }

  void _showInviteModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InviteExternalMemberSheet(
        podcastId: widget.podcastId,
        onInvited: () {
          _loadAll();
        },
      ),
    );
  }

  Future<void> _changeRole(Map<String, dynamic> member) async {
    final userId = member['userId'] ?? member['user']?['id'];
    final currentRole = '${member['role']}'.toUpperCase();
    final memberName = member['user']?['fullName'] ?? 'Ce membre';

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String picked = currentRole;
        final bgElevated = BkoTheme.getBgSurfaceElevated(context);
        final textPri = BkoTheme.getTextPrimary(context);
        final textSec = BkoTheme.getTextSecondary(context);

        return StatefulBuilder(
          builder: (context, setDState) => AlertDialog(
            backgroundColor: bgElevated,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Modifier le rôle de $memberName',
              style: BkoTheme.fontLato(
                  fontSize: 16, fontWeight: FontWeight.w800, color: textPri),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _roleRadio('ADMIN', 'Administrateur',
                    'Accès complet, gestion des réglages et équipe', picked,
                    (val) => setDState(() => picked = val)),
                _roleRadio('EDITOR', 'Éditeur',
                    'Création, gestion des épisodes et médias', picked,
                    (val) => setDState(() => picked = val)),
                _roleRadio('ANALYST', 'Analyste',
                    'Consultation des statistiques en lecture seule', picked,
                    (val) => setDState(() => picked = val)),
                if (_currentUserRole == 'OWNER')
                  _roleRadio('OWNER', 'Propriétaire',
                      'Contrôle total sur l’émission et l’équipe', picked,
                      (val) => setDState(() => picked = val)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Annuler', style: TextStyle(color: textSec)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, picked),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BkoTheme.goldAccent,
                  foregroundColor: BkoTheme.darkBgObsidian,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Enregistrer',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || selected == currentRole) return;

    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    try {
      await BkoApi.patch(
        '/creator/podcasts/${widget.podcastId}/members/$userId',
        {'role': selected},
        token: auth.token,
      );
      if (mounted) {
        BkoHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rôle mis à jour : ${_roleLabel(selected)}')),
        );
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException
            ? e.message
            : 'Impossible de modifier le rôle de ce membre.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Widget _roleRadio(String value, String title, String subtitle, String current,
      ValueChanged<String> onChanged) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final isSelected = value == current;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // ignore: deprecated_member_use
            Radio<String>(
              value: value,
              groupValue: current,
              activeColor: BkoTheme.goldAccent,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: BkoTheme.fontLato(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: textPri,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final userId = member['userId'] ?? member['user']?['id'];
    final memberName = member['user']?['fullName'] ?? 'Ce membre';
    final role = '${member['role']}'.toUpperCase();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BkoTheme.getBgSurfaceElevated(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Retirer $memberName ?',
          style: BkoTheme.fontLato(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: BkoTheme.getTextPrimary(context)),
        ),
        content: Text(
          role == 'OWNER'
              ? 'Attention : ce membre est un propriétaire de l’émission. Assurez-vous qu’au moins un autre propriétaire reste actif.'
              : 'Ce collaborateur perdra immédiatement l\'accès aux fonctionnalités de gestion de cette émission.',
          style: BkoTheme.fontLato(
              fontSize: 13, color: BkoTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: TextStyle(color: BkoTheme.getTextSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Retirer',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    try {
      await BkoApi.delete(
        '/creator/podcasts/${widget.podcastId}/members/$userId',
        token: auth.token,
      );
      if (mounted) {
        BkoHaptics.medium();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membre retiré de l\'émission.')),
        );
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException
            ? e.message
            : 'Impossible de retirer ce membre.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _revokeInvitation(String invitationId) async {
    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    try {
      await BkoApi.delete(
        '/creator/podcasts/${widget.podcastId}/invitations/$invitationId',
        token: auth.token,
      );
      if (mounted) {
        BkoHaptics.light();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation révoquée avec succès.')),
        );
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException
            ? e.message
            : 'Impossible de révoquer cette invitation.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  String _roleLabel(String? role) {
    switch ('$role'.toUpperCase()) {
      case 'OWNER':
        return 'Propriétaire';
      case 'ADMIN':
        return 'Administrateur';
      case 'EDITOR':
        return 'Éditeur';
      case 'ANALYST':
        return 'Analyste';
      default:
        return role ?? 'Membre';
    }
  }

  Color _roleColor(String? role) {
    switch ('$role'.toUpperCase()) {
      case 'OWNER':
        return BkoTheme.getAccent(context);
      case 'ADMIN':
        return Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA);
      case 'EDITOR':
        return BkoTheme.getSuccess(context);
      case 'ANALYST':
        return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
      default:
        return BkoTheme.getTextSecondary(context);
    }
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
        leading: const AppBackButton(),
        actions: const [AppHeaderActions()],
        title: Text(
          'Équipe de l’émission',
          style: BkoTheme.fontLato(
              fontSize: 18, fontWeight: FontWeight.w800, color: textPri),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: BkoTheme.goldAccent,
          indicatorWeight: 3,
          labelColor: BkoTheme.goldAccent,
          unselectedLabelColor: textSec,
          labelStyle:
              BkoTheme.fontLato(fontSize: 13, fontWeight: FontWeight.w800),
          tabs: [
            Tab(text: 'Membres actifs (${_members.length})'),
            Tab(text: 'Invitations (${_invitations.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator.adaptive(
                valueColor: AlwaysStoppedAnimation(BkoTheme.goldAccent),
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: BkoTheme.fontLato(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.error)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadAll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BkoTheme.goldAccent,
                            foregroundColor: BkoTheme.darkBgObsidian,
                          ),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Onglet 1 : Membres actifs
                    RefreshIndicator(
                      color: BkoTheme.goldAccent,
                      onRefresh: _loadAll,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        children: [
                          if (_canManageTeam)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: BkoBounceable(
                                onTap: _showAddMemberModal,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: BkoTheme.goldAccent,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(IconsaxPlusLinear.user_add,
                                          size: 18,
                                          color: BkoTheme.darkBgObsidian),
                                      const SizedBox(width: 8),
                                      Text(
                                        'AJOUTER DIRECTEMENT UN MEMBRE',
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
                            ),
                          if (_members.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: bgElevated,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderSub),
                              ),
                              child: Text(
                                'Aucun membre enregistré dans cette émission.',
                                style: BkoTheme.fontLato(
                                    fontSize: 13, color: textSec),
                              ),
                            ),
                          ..._members.map((m) {
                            final member = m is Map<String, dynamic>
                                ? m
                                : Map<String, dynamic>.from(m as Map);
                            final user = member['user'] as Map? ?? {};
                            final fullName = user['fullName'] ?? 'Utilisateur';
                            final email = user['email'] ?? '';
                            final role = '${member['role']}'.toUpperCase();
                            final myId = ref.read(authProvider).user?['id'];
                            final isSelf =
                                (member['userId'] ?? user['id']) == myId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: bgElevated,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderSub),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: _roleColor(role)
                                        .withValues(alpha: 0.2),
                                    child: Text(
                                      fullName.isNotEmpty
                                          ? fullName.substring(0, 1).toUpperCase()
                                          : 'U',
                                      style: BkoTheme.fontLato(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: _roleColor(role),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                fullName,
                                                style: BkoTheme.fontLato(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: textPri,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isSelf) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: bgSurf,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Vous',
                                                  style: BkoTheme.fontLato(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: textSec),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (email.isNotEmpty)
                                          Text(
                                            email,
                                            style: BkoTheme.fontLato(
                                                fontSize: 12, color: textSec),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _roleColor(role)
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _roleLabel(role).toUpperCase(),
                                            style: BkoTheme.fontLato(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                              color: _roleColor(role),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_canManageTeam && !isSelf) ...[
                                    PopupMenuButton<String>(
                                      icon: Icon(IconsaxPlusLinear.more,
                                          size: 18, color: textSec),
                                      color: bgElevated,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      onSelected: (action) {
                                        if (action == 'role') {
                                          _changeRole(member);
                                        } else if (action == 'remove') {
                                          _removeMember(member);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'role',
                                          child: Row(
                                            children: [
                                              Icon(IconsaxPlusLinear.edit_2,
                                                  size: 16),
                                              SizedBox(width: 8),
                                              Text('Changer le rôle'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'remove',
                                          child: Row(
                                            children: [
                                              Icon(IconsaxPlusLinear.trash,
                                                  size: 16,
                                                  color: Colors.redAccent),
                                              SizedBox(width: 8),
                                              Text('Retirer de l’équipe',
                                                  style: TextStyle(
                                                      color: Colors.redAccent)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // Onglet 2 : Invitations en attente
                    RefreshIndicator(
                      color: BkoTheme.goldAccent,
                      onRefresh: _loadAll,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        children: [
                          if (_canManageTeam)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: BkoBounceable(
                                onTap: _showInviteModal,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: bgElevated,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: borderSub),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(IconsaxPlusLinear.sms,
                                          size: 18, color: BkoTheme.getAccent(context)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'ENVOYER UNE INVITATION PAR E-MAIL',
                                        style: BkoTheme.fontLato(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: textPri,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (_invitations.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: bgElevated,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderSub),
                              ),
                              child: Text(
                                'Aucune invitation externe en attente.',
                                style: BkoTheme.fontLato(
                                    fontSize: 13, color: textSec),
                              ),
                            ),
                          ..._invitations.map((inv) {
                            final invitation = inv is Map<String, dynamic>
                                ? inv
                                : Map<String, dynamic>.from(inv as Map);
                            final email = invitation['email'] ?? '';
                            final role =
                                '${invitation['role'] ?? 'MEMBER'}'.toUpperCase();
                            final invId = '${invitation['id']}';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: bgElevated,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderSub),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: BkoTheme.goldAccent
                                        .withValues(alpha: 0.15),
                                    child: Icon(IconsaxPlusLinear.sms,
                                        size: 16, color: BkoTheme.getAccent(context)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          email,
                                          style: BkoTheme.fontLato(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: textPri,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              'Rôle : ${_roleLabel(role)}',
                                              style: BkoTheme.fontLato(
                                                  fontSize: 11.5,
                                                  color: textSec),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.amber
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'En attente',
                                                style: BkoTheme.fontLato(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_canManageTeam)
                                    IconButton(
                                      icon: const Icon(IconsaxPlusLinear.close_circle,
                                          size: 18, color: Colors.redAccent),
                                      tooltip: 'Révoquer',
                                      onPressed: () =>
                                          _revokeInvitation(invId),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// Feuille modale pour l'ajout direct d'un utilisateur existant (immédiat, sans acceptation)
class _AddDirectMemberSheet extends ConsumerStatefulWidget {
  final String podcastId;
  final bool canAssignOwner;
  final VoidCallback onAdded;

  const _AddDirectMemberSheet({
    required this.podcastId,
    required this.canAssignOwner,
    required this.onAdded,
  });

  @override
  ConsumerState<_AddDirectMemberSheet> createState() =>
      _AddDirectMemberSheetState();
}

class _AddDirectMemberSheetState extends ConsumerState<_AddDirectMemberSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  List<dynamic> _searchResults = [];
  Map<String, dynamic>? _selectedUser;
  String _selectedRole = 'EDITOR';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    final auth = ref.read(authProvider);
    if (auth.token == null) return;
    setState(() => _searching = true);

    try {
      final res = await BkoApi.get(
        '/creator/users/search?q=${Uri.encodeComponent(query.trim())}',
        token: auth.token,
      );
      if (!mounted) return;
      final list = (res is List
          ? res
          : (res is Map && res['data'] is List ? res['data'] : [])) as List;
      setState(() {
        _searchResults = list;
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedUser == null) {
      setState(() => _error = 'Veuillez rechercher et sélectionner un utilisateur.');
      return;
    }

    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await BkoApi.post(
        '/creator/podcasts/${widget.podcastId}/members',
        {
          'userId': _selectedUser!['id'],
          'role': _selectedRole,
        },
        token: auth.token,
      );

      if (mounted) {
        BkoHaptics.success();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_selectedUser!['fullName']} a été ajouté(e) directement avec succès.'),
          ),
        );
        widget.onAdded();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Échec de l\'ajout du membre à l\'équipe.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return Container(
      decoration: BoxDecoration(
        color: bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ajouter directement un membre',
                  style: BkoTheme.fontLato(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textPri),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BkoTheme.goldAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: BkoTheme.goldAccent.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Règle métier : l’utilisateur sélectionné aura un accès actif immédiat à l’émission dans son Studio sans étape d\'acceptation. Une notification lui sera envoyée avec le bouton « Ouvrir l’émission ».',
                style: BkoTheme.fontLato(
                    fontSize: 12, color: BkoTheme.getAccent(context), height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: BkoTheme.fontLato(
                        fontSize: 12, color: Colors.redAccent)),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              '1. RECHERCHER UN COMPTE EXISTANT',
              style: BkoTheme.fontLato(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: textSec),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Nom ou adresse e-mail…',
                hintStyle: TextStyle(color: textSec, fontSize: 13),
                prefixIcon: const Icon(IconsaxPlusLinear.search_normal, size: 18),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2),
                      )
                    : null,
                filled: true,
                fillColor: BkoTheme.getBgSurface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderSub),
                ),
              ),
            ),
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: BkoTheme.getBgSurface(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderSub),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: borderSub),
                  itemBuilder: (ctx, i) {
                    final u = Map<String, dynamic>.from(
                        _searchResults[i] as Map);
                    final isChosen = _selectedUser?['id'] == u['id'];

                    return ListTile(
                      dense: true,
                      selected: isChosen,
                      selectedTileColor:
                          BkoTheme.goldAccent.withValues(alpha: 0.15),
                      title: Text(
                        '${u['fullName'] ?? u['email']}',
                        style: BkoTheme.fontLato(
                          fontSize: 13,
                          fontWeight:
                              isChosen ? FontWeight.w800 : FontWeight.w600,
                          color: isChosen ? BkoTheme.goldAccent : textPri,
                        ),
                      ),
                      subtitle: Text(
                        '${u['email'] ?? ''}',
                        style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                      ),
                      trailing: isChosen
                          ? Icon(Icons.check_circle,
                              color: BkoTheme.getAccent(context), size: 18)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedUser = u;
                          _searchResults = [];
                          _searchController.text =
                              '${u['fullName']} (${u['email']})';
                        });
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              '2. SÉLECTIONNER LE RÔLE',
              style: BkoTheme.fontLato(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: textSec),
            ),
            const SizedBox(height: 8),
            _roleOption(
              'EDITOR',
              'Éditeur',
              'Peut créer, téléverser et modifier les épisodes et médias.',
            ),
            _roleOption(
              'ADMIN',
              'Administrateur',
              'Accès complet à la configuration, aux intégrations et à l\'équipe.',
            ),
            _roleOption(
              'ANALYST',
              'Analyste',
              'Consultation en lecture seule des statistiques d\'audience.',
            ),
            if (widget.canAssignOwner)
              _roleOption(
                'OWNER',
                'Propriétaire',
                'Contrôle complet de l’émission avec capacité de gestion des droits.',
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BkoTheme.goldAccent,
                  foregroundColor: BkoTheme.darkBgObsidian,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const CircularProgressIndicator.adaptive()
                    : const Text(
                        'AJOUTER DIRECTEMENT À L’ÉQUIPE',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleOption(String role, String label, String desc) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final isSelected = _selectedRole == role;

    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? BkoTheme.goldAccent.withValues(alpha: 0.1)
              : BkoTheme.getBgSurface(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? BkoTheme.goldAccent : BkoTheme.getBorderSubtle(context),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: isSelected ? BkoTheme.goldAccent : textSec,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: BkoTheme.fontLato(
                      fontSize: 13.5,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: textPri,
                    ),
                  ),
                  Text(
                    desc,
                    style: BkoTheme.fontLato(fontSize: 11.5, color: textSec),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feuille modale pour inviter par e-mail un compte qui n'existe pas encore
class _InviteExternalMemberSheet extends ConsumerStatefulWidget {
  final String podcastId;
  final VoidCallback onInvited;

  const _InviteExternalMemberSheet({
    required this.podcastId,
    required this.onInvited,
  });

  @override
  ConsumerState<_InviteExternalMemberSheet> createState() =>
      _InviteExternalMemberSheetState();
}

class _InviteExternalMemberSheetState
    extends ConsumerState<_InviteExternalMemberSheet> {
  final _emailController = TextEditingController();
  String _selectedRole = 'EDITOR';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Veuillez renseigner une adresse e-mail valide.');
      return;
    }

    final auth = ref.read(authProvider);
    if (auth.token == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await BkoApi.post(
        '/creator/podcasts/${widget.podcastId}/invitations',
        {
          'email': email,
          'role': _selectedRole,
        },
        token: auth.token,
      );

      if (mounted) {
        BkoHaptics.success();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation envoyée par e-mail à $email.')),
        );
        widget.onInvited();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Impossible d\'envoyer l\'invitation.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPri = BkoTheme.getTextPrimary(context);
    final textSec = BkoTheme.getTextSecondary(context);
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSub = BkoTheme.getBorderSubtle(context);

    return Container(
      decoration: BoxDecoration(
        color: bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Inviter un collaborateur externe',
                  style: BkoTheme.fontLato(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textPri),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BkoTheme.getBgSurface(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderSub),
              ),
              child: Text(
                'Ce parcours est dédié aux personnes ne disposant pas encore d\'un compte sur Bamako Podcast. Un e-mail d\'invitation sécurisé leur sera envoyé pour créer leur profil et rejoindre l\'émission.',
                style: BkoTheme.fontLato(fontSize: 12, color: textSec, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: BkoTheme.fontLato(
                        fontSize: 12, color: Colors.redAccent)),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'ADRESSE E-MAIL DU DESTINATAIRE',
              style: BkoTheme.fontLato(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: textSec),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'exemple@domaine.com',
                hintStyle: TextStyle(color: textSec, fontSize: 13),
                prefixIcon: const Icon(IconsaxPlusLinear.sms, size: 18),
                filled: true,
                fillColor: BkoTheme.getBgSurface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderSub),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'RÔLE ATTRIBUÉ',
              style: BkoTheme.fontLato(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: textSec),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              dropdownColor: bgElevated,
              decoration: InputDecoration(
                filled: true,
                fillColor: BkoTheme.getBgSurface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderSub),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'EDITOR',
                  child: Text('Éditeur (Création et édition des épisodes)'),
                ),
                DropdownMenuItem(
                  value: 'ADMIN',
                  child: Text('Administrateur (Gestion complète de l\'émission)'),
                ),
                DropdownMenuItem(
                  value: 'ANALYST',
                  child: Text('Analyste (Lecture seule des statistiques)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BkoTheme.goldAccent,
                  foregroundColor: BkoTheme.darkBgObsidian,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const CircularProgressIndicator.adaptive()
                    : const Text(
                        'ENVOYER L’INVITATION',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
