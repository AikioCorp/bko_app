import '../../core/widgets/app_header_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/bko_api.dart';
import '../../core/widgets/app_back_button.dart';
import '../auth/auth_controller.dart';

class ClaimPodcastScreen extends ConsumerStatefulWidget {
  const ClaimPodcastScreen({super.key});
  @override
  ConsumerState<ClaimPodcastScreen> createState() => _ClaimPodcastScreenState();
}

class _ClaimPodcastScreenState extends ConsumerState<ClaimPodcastScreen> {
  final _form = GlobalKey<FormState>();
  final _slug = TextEditingController();
  final _proof = TextEditingController();
  List<dynamic> _claims = [];
  bool _busy = false;
  String? _error;
  String? _success;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _slug.dispose();
    _proof.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data =
          await BkoApi.get('/me/claims', token: ref.read(authProvider).token);
      if (mounted) setState(() => _claims = data is List ? data : []);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible de charger vos demandes.');
      }
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final rawInput = _slug.text.trim();
      final parsedUri = Uri.tryParse(rawInput);
      final cleanPath = parsedUri != null && parsedUri.pathSegments.isNotEmpty
          ? parsedUri.pathSegments.lastWhere((s) => s.isNotEmpty,
              orElse: () => rawInput)
          : rawInput
              .split('?')
              .first
              .split('#')
              .first
              .split('/')
              .where((part) => part.isNotEmpty)
              .last;
      final slug = cleanPath.trim();
      final token = ref.read(authProvider).token;
      final podcast = await BkoApi.get('/podcasts/${Uri.encodeComponent(slug)}',
          token: token);
      if (podcast is! Map || podcast['id'] == null) {
        throw const FormatException();
      }
      await BkoApi.post(
          '/podcasts/${podcast['id']}/claims',
          {
            'proofDescription': _proof.text.trim(),
            'verificationMethod': 'MANUAL',
          },
          token: token);
      if (!mounted) return;
      setState(() => _success =
          'Demande envoyée. Votre propriété sera vérifiée avant tout accès à l’émission.');
      _slug.clear();
      _proof.clear();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'Impossible d’envoyer la demande.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
        actions: const [AppHeaderActions()],
            leading: const AppBackButton(),
            title: const Text('Revendiquer une émission')),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 180),
            children: [
              const Text(
                  'Votre émission existe déjà ? Demandez à la gérer sans créer de doublon.'),
              const SizedBox(height: 20),
              Form(
                  key: _form,
                  child: Column(children: [
                    TextFormField(
                        controller: _slug,
                        decoration: const InputDecoration(
                            labelText: 'Lien Bamako Podcast ou identifiant'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Indiquez votre émission'
                                : null),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _proof,
                        maxLines: 4,
                        decoration: const InputDecoration(
                            labelText: 'Justificatifs de propriété'),
                        validator: (value) => (value?.trim().length ?? 0) < 10
                            ? 'Expliquez comment vérifier votre propriété'
                            : null),
                    if (_error != null)
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    if (_success != null) Text(_success!),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? 'Envoi…' : 'Envoyer ma demande')),
                  ])),
              const SizedBox(height: 24),
              const Text('Mes demandes'),
              if (_claims.isEmpty) const Text('Aucune demande.'),
              ..._claims.map((claim) => ListTile(
                  title: Text('${claim['podcast']?['name'] ?? 'Émission'}'),
                  subtitle: Text(
                      '${_status(claim['status'])}${claim['reviewNotes'] == null ? '' : '\n${claim['reviewNotes']}'}'))),
              TextButton(onPressed: _load, child: const Text('Actualiser')),
            ]),
      );
  String _status(dynamic status) =>
      const {
        'PENDING': 'En attente',
        'UNDER_REVIEW': 'En cours de vérification',
        'APPROVED': 'Approuvée',
        'REJECTED': 'Refusée'
      }[status] ??
      '$status';
}
