import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/bko_api.dart';
import '../../core/widgets/app_back_button.dart';
import '../auth/auth_controller.dart';

class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key});
  @override
  ConsumerState<SupportTicketsScreen> createState() =>
      _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _subject = TextEditingController();
  final _description = TextEditingController(),
      _reply = TextEditingController();
  List<dynamic> _tickets = [];
  Map<String, dynamic>? _ticket;
  String _key = '', _error = '';
  bool _busy = false;
  static const _secure = FlutterSecureStorage();
  String get _scope =>
      ref.read(authProvider).user?['id']?.toString() ?? 'guest';
  String? get token => ref.read(authProvider).token;
  Options _options(String key) => Options(headers: {
        'X-Support-Key': key,
        if (token != null) 'Authorization': 'Bearer $token'
      });
  @override
  void initState() {
    super.initState();
    _load();
  }

  dynamic _data(dynamic result) =>
      result is Map && result['data'] != null ? result['data'] : result;
  Future<void> _load() async {
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
        } catch (_) {/* Remain accessible on next refresh. */}
      }
      if (token != null) {
        final result =
            _data(await BkoApi.get('/me/support-tickets', token: token));
        for (final item in result['items'] as List) {
          if (!local.any((t) => t['id'] == item['id'])) local.add(item);
        }
      }
      if (mounted) setState(() => _tickets = local);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _open(String id) async {
    setState(() {
      _busy = true;
      _error = '';
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
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result = _data(await BkoApi.post(
          '/support/tickets',
          {
            'email': _email.text.trim(),
            'subject': _subject.text.trim(),
            'description': _description.text.trim(),
            'origin': 'MOBILE'
          },
          token: token));
      final id = result['id'] as String, key = result['accessToken'] as String;
      final prefs = await SharedPreferences.getInstance();
      await _secure.write(key: 'bko_support_key_$id', value: key);
      await prefs.setStringList('bko_support_ids_$_scope',
          {...?prefs.getStringList('bko_support_ids_$_scope'), id}.toList());
      _description.clear();
      _subject.clear();
      if (mounted) {
        await _open(id);
        await _load();
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await BkoApi.dio.post('/support/tickets/${_ticket!['id']}/messages',
          data: {'body': _reply.text.trim()}, options: _options(_key));
      _reply.clear();
      if (mounted) await _open(_ticket!['id'] as String);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
        appBar: AppBar(
            leading: const AppBackButton(),
            title: const Text('Mes demandes d’assistance'),
            actions: [
              IconButton(
                  tooltip: 'Actualiser',
                  onPressed: _busy
                      ? null
                      : () async {
                          await _load();
                          if (_ticket != null) {
                            await _open(_ticket!['id'] as String);
                          }
                        },
                  icon: const Icon(IconsaxPlusLinear.refresh))
            ]),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error.isNotEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error, style: TextStyle(color: colors.error))),
          if (_ticket == null) ...[
            const Text('Vos échanges avec notre équipe',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'Les réponses et changements de statut sont également notifiés par email.'),
            ..._tickets.map((t) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t['subject'] as String),
                subtitle: Text(t['status'] == 'CLOSED' ? 'Fermé' : 'Ouvert'),
                trailing: const Icon(IconsaxPlusLinear.arrow_right_3),
                onTap: () => _open(t['id'] as String))),
            const SizedBox(height: 24),
            const Text('Nouvelle demande',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Form(
                key: _form,
                child: Column(children: [
                  TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(labelText: 'Email de contact'),
                      validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Saisissez une adresse email valide.'),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _subject,
                      maxLength: 180,
                      decoration: const InputDecoration(labelText: 'Sujet'),
                      validator: (v) => (v?.trim().length ?? 0) >= 3
                          ? null
                          : 'Précisez le sujet (3 caractères minimum).'),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _description,
                      minLines: 5,
                      maxLines: 10,
                      maxLength: 10000,
                      decoration:
                          const InputDecoration(labelText: 'Votre demande'),
                      validator: (v) => (v?.trim().length ?? 0) >= 10
                          ? null
                          : 'Décrivez votre demande (10 caractères minimum).'),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _busy ? null : _create,
                      child: const Text('Envoyer ma demande')),
                ])),
          ] else ...[
            TextButton(
                onPressed: () => setState(() => _ticket = null),
                child: const Text('Toutes mes demandes')),
            Text(_ticket!['subject'] as String,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                '${_ticket!['id']} · ${_ticket!['status'] == 'CLOSED' ? 'Fermé' : 'Ouvert'}'),
            const SizedBox(height: 24),
            ...(_ticket!['messages'] as List).map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: m['kind'] == 'STAFF'
                            ? colors.primaryContainer
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              m['kind'] == 'STAFF'
                                  ? 'Assistance'
                                  : m['kind'] == 'SYSTEM'
                                      ? 'Statut du ticket'
                                      : 'Vous',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SelectableText(m['body'] as String)
                        ])))),
            if (_ticket!['status'] != 'CLOSED') ...[
              TextField(
                  controller: _reply,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 10000,
                  decoration:
                      const InputDecoration(labelText: 'Votre réponse')),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _busy ? null : _send,
                  child: const Text('Envoyer la réponse'))
            ] else
              const Text(
                  'Ce ticket est fermé. Vous pouvez créer une nouvelle demande.'),
          ],
          const SizedBox(height: 24),
        ])));
  }
}
