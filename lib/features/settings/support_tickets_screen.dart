import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/bko_api.dart';
import '../../core/theme/bko_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/bko_bounceable.dart';
import '../../core/widgets/bko_haptics.dart';
import '../auth/auth_controller.dart';

class SupportTicketsScreen extends ConsumerStatefulWidget {
  final String? contextMode;
  final Map<String, dynamic>? appealDetails;

  const SupportTicketsScreen({
    super.key,
    this.contextMode,
    this.appealDetails,
  });

  @override
  ConsumerState<SupportTicketsScreen> createState() =>
      _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _reply = TextEditingController();

  List<dynamic> _tickets = [];
  Map<String, dynamic>? _ticket;
  String _key = '';
  String _error = '';
  String _successMsg = '';
  bool _busy = false;
  String _selectedCategory = 'Général';

  static const _secure = FlutterSecureStorage();

  bool get _isSuspensionMode =>
      widget.contextMode == 'suspension' ||
      widget.appealDetails != null ||
      AuthNotifier.lastSuspendedDetails != null;

  Map<String, dynamic>? get _effectiveSuspendedDetails =>
      widget.appealDetails ?? AuthNotifier.lastSuspendedDetails;

  String? get _supportToken =>
      _effectiveSuspendedDetails?['supportToken']?.toString() ??
      AuthNotifier.supportToken;

  String? get _token => ref.read(authProvider).token ?? _supportToken;

  String get _scope =>
      ref.read(authProvider).user?['id']?.toString() ??
      _effectiveSuspendedDetails?['userId']?.toString() ??
      'guest';

  Options _options(String key) => Options(headers: {
        'X-Support-Key': key,
        if (_token != null) 'Authorization': 'Bearer $_token'
      });

  @override
  void initState() {
    super.initState();
    final profile = _effectiveSuspendedDetails;
    if (_isSuspensionMode && profile != null) {
      final email = profile['email']?.toString().trim();
      if (email != null && email.isNotEmpty) {
        _email.text = email;
      }
      _subject.text = 'Demande de recours suite à la suspension de mon compte';
      _selectedCategory = 'Compte et connexion';
    }
    _load();
  }

  dynamic _data(dynamic result) =>
      result is Map && result['data'] != null ? result['data'] : result;

  Future<void> _load() async {
    setState(() => _error = '');
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('bko_support_ids_$_scope') ?? [];
      final local = <dynamic>[];

      for (final id in ids.reversed.take(30)) {
        final key = await _secure.read(key: 'bko_support_key_$id') ?? '';
        try {
          final r = await BkoApi.dio
              .get('/support/tickets/$id', options: _options(key));
          local.add(_data(r.data));
        } catch (_) {}
      }

      if (_token != null) {
        try {
          final result =
              _data(await BkoApi.get('/me/support-tickets', token: _token));
          if (result is Map && result['items'] is List) {
            for (final item in result['items'] as List) {
              if (!local.any((t) => t['id'] == item['id'])) {
                local.add(item);
              }
            }
          }
        } catch (_) {}
      }

      if (mounted) setState(() => _tickets = local);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _open(String id) async {
    BkoHaptics.selection();
    setState(() {
      _busy = true;
      _error = '';
      _successMsg = '';
    });
    try {
      final key = await _secure.read(key: 'bko_support_key_$id') ?? '';
      final result =
          await BkoApi.dio.get('/support/tickets/$id', options: _options(key));
      if (mounted) {
        setState(() {
          _ticket = Map<String, dynamic>.from(_data(result.data));
          _key = key;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Impossible de charger le ticket : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    BkoHaptics.medium();
    setState(() {
      _busy = true;
      _error = '';
      _successMsg = '';
    });

    try {
      final payload = {
        'email': _email.text.trim(),
        'subject': _subject.text.trim(),
        'description': _description.text.trim(),
        'category': _isSuspensionMode ? 'Compte et connexion' : _selectedCategory,
        'origin': 'MOBILE',
      };

      final result = _data(await BkoApi.post(
        '/support/tickets',
        payload,
        token: _token,
      ));

      final id = result['id'] as String;
      final key = (result['accessToken'] ?? '') as String;

      final prefs = await SharedPreferences.getInstance();
      if (key.isNotEmpty) {
        await _secure.write(key: 'bko_support_key_$id', value: key);
      }
      await prefs.setStringList('bko_support_ids_$_scope',
          {...?prefs.getStringList('bko_support_ids_$_scope'), id}.toList());

      _description.clear();
      if (!_isSuspensionMode) {
        _subject.clear();
      }

      if (mounted) {
        _successMsg = 'Votre demande a bien été envoyée avec succès.';
        await _open(id);
        await _load();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Échec de l\'envoi : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty) return;
    BkoHaptics.light();
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await BkoApi.dio.post(
        '/support/tickets/${_ticket!['id']}/messages',
        data: {'body': _reply.text.trim()},
        options: _options(_key),
      );
      _reply.clear();
      if (mounted) await _open(_ticket!['id'] as String);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur lors de la réponse : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _subject.dispose();
    _description.dispose();
    _reply.dispose();
    super.dispose();
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgObsidian = BkoTheme.getBgObsidian(context);
    final bgSurface = BkoTheme.getBgSurface(context);
    final bgElevated = BkoTheme.getBgSurfaceElevated(context);
    final borderSubtle = BkoTheme.getBorderSubtle(context);
    final borderStrong = BkoTheme.getBorderStrong(context);
    final textPrimary = BkoTheme.getTextPrimary(context);
    final textSecondary = BkoTheme.getTextSecondary(context);
    final textMuted = BkoTheme.getTextMuted(context);

    final profile = _effectiveSuspendedDetails;
    final fullName = profile?['fullName']?.toString().trim();
    final email = profile?['email']?.toString().trim();
    final avatar = profile?['avatar']?.toString().trim();
    final reason = profile?['reason']?.toString().trim();

    final initials = (fullName != null && fullName.isNotEmpty)
        ? fullName
            .split(' ')
            .where((p) => p.isNotEmpty)
            .map((p) => p[0])
            .take(2)
            .join('')
            .toUpperCase()
        : (email != null && email.isNotEmpty ? email[0].toUpperCase() : 'U');

    return Scaffold(
      backgroundColor: bgObsidian,
      appBar: AppBar(
        backgroundColor: bgObsidian,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(),
        centerTitle: false,
        title: Text(
          _isSuspensionMode
              ? 'Recours & Révision'
              : 'Aide & Assistance',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _busy
                ? null
                : () async {
                    BkoHaptics.light();
                    await _load();
                    if (_ticket != null) {
                      await _open(_ticket!['id'] as String);
                    }
                  },
            icon: Icon(
              IconsaxPlusLinear.refresh_2,
              size: 20,
              color: textSecondary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_busy)
              const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: BkoTheme.goldAccent,
                minHeight: 2,
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Alerte d'erreur
                  if (_error.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x24EF4444),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x4DEF4444)),
                      ),
                      child: Row(
                        children: [
                          const Icon(IconsaxPlusLinear.warning_2,
                              color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error,
                              style: const TextStyle(
                                  color: Color(0xFFFCA5A5), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Alerte succès
                  if (_successMsg.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x2410B981),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x4D10B981)),
                      ),
                      child: Row(
                        children: [
                          const Icon(IconsaxPlusLinear.tick_circle,
                              color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _successMsg,
                              style: const TextStyle(
                                  color: Color(0xFF6EE7B7), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Profil du compte bloqué (en mode suspension)
                  if (_isSuspensionMode && profile != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bgSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderSubtle, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: bgElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderSubtle, width: 1),
                                ),
                                clipBehavior: Clip.antiAlias,
                                alignment: Alignment.center,
                                child: (avatar != null && avatar.isNotEmpty)
                                    ? Image.network(
                                        avatar,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Text(
                                          initials,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: textPrimary,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        initials,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
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
                                            fullName ?? 'Utilisateur',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0x28EF4444),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: const Color(0x45EF4444),
                                                width: 1),
                                          ),
                                          child: const Text(
                                            'Suspendu',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFEF4444),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (email != null && email.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            IconsaxPlusLinear.sms,
                                            size: 13,
                                            color: textMuted,
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              email,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: textSecondary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            IconsaxPlusLinear.verify,
                                            size: 13,
                                            color: Color(0xFF10B981),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (reason != null && reason.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: bgElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: borderSubtle, width: 1),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    IconsaxPlusLinear.info_circle,
                                    size: 14,
                                    color: BkoTheme.goldAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Motif : $reason',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Vue Détail d'un ticket sélectionné
                  if (_ticket != null) ...[
                    _buildTicketDetailView(
                      context,
                      bgSurface,
                      bgElevated,
                      borderSubtle,
                      borderStrong,
                      textPrimary,
                      textSecondary,
                      textMuted,
                    ),
                  ] else ...[
                    // Liste des tickets existants
                    if (_tickets.isNotEmpty) ...[
                      Text(
                        _isSuspensionMode
                            ? 'Mes recours en cours'
                            : 'Vos échanges avec notre équipe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._tickets.map((t) => _buildTicketCard(
                            context,
                            t,
                            bgSurface,
                            bgElevated,
                            borderSubtle,
                            textPrimary,
                            textSecondary,
                            textMuted,
                          )),
                      const SizedBox(height: 24),
                    ],

                    // Formulaire de nouvelle demande ou recours
                    Text(
                      _isSuspensionMode
                          ? 'Déposer une demande de recours'
                          : 'Nouvelle demande d\'assistance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isSuspensionMode
                          ? 'Détaillez les arguments ou clarifications justifiant un réexamen de votre compte par nos équipes.'
                          : 'Posez votre question à notre support technique.',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Champ Catégorie
                          if (_isSuspensionMode) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: bgSurface,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: borderSubtle, width: 1),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    IconsaxPlusLinear.shield_search,
                                    size: 16,
                                    color: BkoTheme.goldAccent,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Catégorie : Recours suspension de compte',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ] else ...[
                            // Choix catégorie standard
                            _buildCategorySelector(
                              context,
                              bgSurface,
                              bgElevated,
                              borderSubtle,
                              textPrimary,
                              textSecondary,
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Champ Email
                          if (_isSuspensionMode &&
                              profile?['email'] != null &&
                              profile!['email'].toString().isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: bgSurface,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: borderSubtle, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(IconsaxPlusLinear.sms,
                                      size: 16, color: textMuted),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      profile['email'].toString(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0x1F10B981),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Vérifié',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(
                                  color: textPrimary, fontSize: 14),
                              decoration: _inputDecoration(
                                label: 'Votre email de contact',
                                icon: IconsaxPlusLinear.sms,
                                bgSurface: bgSurface,
                                borderSubtle: borderSubtle,
                                textMuted: textMuted,
                              ),
                              validator: (v) => RegExp(
                                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(v?.trim() ?? '')
                                  ? null
                                  : 'Saisissez une adresse email valide.',
                            ),
                          ],
                          const SizedBox(height: 14),

                          // Champ Sujet
                          TextFormField(
                            controller: _subject,
                            maxLength: 180,
                            readOnly: _isSuspensionMode,
                            style:
                                TextStyle(color: textPrimary, fontSize: 14),
                            decoration: _inputDecoration(
                              label: 'Objet de la demande',
                              icon: IconsaxPlusLinear.document_text_1,
                              bgSurface: bgSurface,
                              borderSubtle: borderSubtle,
                              textMuted: textMuted,
                            ),
                            validator: (v) => (v?.trim().length ?? 0) >= 3
                                ? null
                                : 'Précisez le sujet (3 caractères min).',
                          ),
                          const SizedBox(height: 14),

                          // Champ Description
                          TextFormField(
                            controller: _description,
                            minLines: 5,
                            maxLines: 9,
                            maxLength: 5000,
                            style:
                                TextStyle(color: textPrimary, fontSize: 14),
                            decoration: _inputDecoration(
                              label: _isSuspensionMode
                                  ? 'Explications détaillées de votre recours'
                                  : 'Votre message ou question détaillée',
                              icon: IconsaxPlusLinear.message_text,
                              bgSurface: bgSurface,
                              borderSubtle: borderSubtle,
                              textMuted: textMuted,
                              alignLabelWithHint: true,
                            ),
                            validator: (v) => (v?.trim().length ?? 0) >= 10
                                ? null
                                : 'Décrivez votre demande (10 caractères min).',
                          ),
                          const SizedBox(height: 20),

                          // Bouton d'envoi
                          BkoBounceable(
                            onTap: _busy ? null : _create,
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                color: BkoTheme.goldAccent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    IconsaxPlusLinear.send_1,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isSuspensionMode
                                        ? 'Soumettre mon recours'
                                        : 'Envoyer ma demande',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(
    BuildContext context,
    dynamic ticket,
    Color bgSurface,
    Color bgElevated,
    Color borderSubtle,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    final status = ticket['status']?.toString();
    final isClosed = status == 'CLOSED';
    final isResolved = status == 'RESOLVED';
    final subject = ticket['subject']?.toString() ?? 'Ticket sans titre';
    final updatedAt = _formatDate(ticket['updatedAt']?.toString() ?? ticket['createdAt']?.toString());

    Color statusBg = const Color(0x1F10B981);
    Color statusFg = const Color(0xFF10B981);
    String statusLabel = 'Ouvert';

    if (isClosed) {
      statusBg = const Color(0x1F6B7280);
      statusFg = const Color(0xFF9CA3AF);
      statusLabel = 'Fermé';
    } else if (isResolved) {
      statusBg = const Color(0x1F3B82F6);
      statusFg = const Color(0xFF60A5FA);
      statusLabel = 'Résolu';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BkoBounceable(
        onTap: () => _open(ticket['id'] as String),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderSubtle, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusFg,
                            ),
                          ),
                        ),
                        if (updatedAt.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            updatedAt,
                            style: TextStyle(
                              fontSize: 11,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                IconsaxPlusLinear.arrow_right_3,
                size: 16,
                color: textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketDetailView(
    BuildContext context,
    Color bgSurface,
    Color bgElevated,
    Color borderSubtle,
    Color borderStrong,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
  ) {
    final status = _ticket!['status']?.toString();
    final isClosed = status == 'CLOSED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BkoBounceable(
          onTap: () {
            BkoHaptics.selection();
            setState(() => _ticket = null);
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                IconsaxPlusLinear.arrow_left_1,
                size: 16,
                color: BkoTheme.goldAccent,
              ),
              SizedBox(width: 6),
              Text(
                'Toutes mes demandes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BkoTheme.goldAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _ticket!['subject'] as String,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Dossier n° ${_ticket!['id']} · ${isClosed ? 'Fermé' : 'En cours de traitement'}',
          style: TextStyle(
            fontSize: 12,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 20),

        // Fil des messages
        if (_ticket!['messages'] is List)
          ...(_ticket!['messages'] as List).map((m) {
            final isStaff = m['kind'] == 'STAFF';
            final isSystem = m['kind'] == 'SYSTEM';
            final body = m['body']?.toString() ?? '';
            final createdAt = _formatDate(m['createdAt']?.toString());

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isStaff ? const Color(0x1F2A2A2A) : bgSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isStaff ? const Color(0x4DFFBF00) : borderSubtle,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isStaff
                                  ? IconsaxPlusLinear.shield_tick
                                  : isSystem
                                      ? IconsaxPlusLinear.info_circle
                                      : IconsaxPlusLinear.user,
                              size: 14,
                              color: isStaff
                                  ? BkoTheme.goldAccent
                                  : textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isStaff
                                  ? 'Équipe Bamako Podcast'
                                  : isSystem
                                      ? 'Notification système'
                                      : 'Vous',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isStaff
                                    ? BkoTheme.goldAccent
                                    : textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (createdAt.isNotEmpty)
                          Text(
                            createdAt,
                            style: TextStyle(
                              fontSize: 10,
                              color: textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

        if (!isClosed) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _reply,
            minLines: 3,
            maxLines: 6,
            maxLength: 5000,
            style: TextStyle(color: textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              label: 'Votre message de réponse',
              icon: IconsaxPlusLinear.message_edit,
              bgSurface: bgSurface,
              borderSubtle: borderSubtle,
              textMuted: textMuted,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          BkoBounceable(
            onTap: _busy ? null : _send,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: BkoTheme.goldAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    IconsaxPlusLinear.send_1,
                    color: Colors.black,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Envoyer la réponse',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderSubtle),
            ),
            child: Text(
              'Ce ticket est clôturé. Pour toute autre question, vous pouvez ouvrir une nouvelle demande.',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCategorySelector(
    BuildContext context,
    Color bgSurface,
    Color bgElevated,
    Color borderSubtle,
    Color textPrimary,
    Color textSecondary,
  ) {
    final categories = [
      'Général',
      'Compte et connexion',
      'Lecture et audio',
      'Téléchargements',
      'Studio et publication',
      'Abonnement',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(IconsaxPlusLinear.category, size: 15, color: textSecondary),
              const SizedBox(width: 8),
              Text(
                'Catégorie de la demande',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return BkoBounceable(
                onTap: () {
                  BkoHaptics.selection();
                  setState(() => _selectedCategory = cat);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0x28FFBF00)
                        : bgElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? BkoTheme.goldAccent
                          : borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? BkoTheme.goldAccent : textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required Color bgSurface,
    required Color borderSubtle,
    required Color textMuted,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: alignLabelWithHint,
      labelStyle: TextStyle(color: textMuted, fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: textMuted),
      filled: true,
      fillColor: bgSurface,
      counterStyle: TextStyle(color: textMuted, fontSize: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderSubtle, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BkoTheme.goldAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
