import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/settings_store.dart';
import '../core/web_link.dart';
import '../sync/api_client.dart';
import '../sync/sync_service.dart';

/// Connexion au compte en deux étapes.
///
/// 1. L'utilisateur saisit son e-mail et son mot de passe.
/// 2. Un code à 6 chiffres s'affiche dans son espace web ; il le saisit ici pour confirmer
///    que la connexion vient bien de lui. L'espace web propose aussi d'annuler la demande
///    (« Ce n'est pas moi ») : l'application en est informée et abandonne la connexion.
class LoginCard extends StatefulWidget {
  const LoginCard({super.key});

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  /// Codes d'erreur après lesquels la demande en cours ne peut plus aboutir.
  static const _terminalCodes = {
    'challenge_locked',
    'challenge_expired',
    'challenge_denied',
    'challenge_used',
    'challenge_not_found',
  };

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  LoginChallenge? _challenge;
  Timer? _statusTimer;
  Timer? _clockTimer;
  Duration _remaining = Duration.zero;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _stopTimers();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  void _stopTimers() {
    _statusTimer?.cancel();
    _clockTimer?.cancel();
    _statusTimer = null;
    _clockTimer = null;
  }

  /// Revient à la saisie des identifiants, avec un message facultatif.
  void _reset([String? message]) {
    _stopTimers();
    if (!mounted) return;
    setState(() {
      _challenge = null;
      _busy = false;
      _error = message;
      _code.clear();
    });
  }

  Future<void> _start() async {
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Saisissez votre adresse e-mail et votre mot de passe.');
      return;
    }

    final api = context.read<ApiClient>();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final challenge = await api.startLogin(email, _password.text);
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _remaining = _timeLeft(challenge);
        _busy = false;
      });
      _startTimers(challenge);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = describeSyncError(e);
      });
    }
  }

  Duration _timeLeft(LoginChallenge challenge) {
    final left = challenge.expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void _startTimers(LoginChallenge challenge) {
    _stopTimers();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final left = _timeLeft(challenge);
      if (left == Duration.zero) {
        _reset('Le code a expiré. Recommencez la connexion pour en obtenir un nouveau.');
        return;
      }
      setState(() => _remaining = left);
    });

    // Interroge le serveur pour détecter une annulation faite depuis l'espace web.
    _statusTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkStatus(challenge));
  }

  Future<void> _checkStatus(LoginChallenge challenge) async {
    try {
      final status = await context.read<ApiClient>().loginStatus(challenge.id);
      if (!mounted || _challenge?.id != challenge.id) return;

      switch (status) {
        case 'denied':
          _reset(
            'Cette connexion a été annulée depuis votre espace web. Si vous n’en êtes pas '
            'à l’origine, changez votre mot de passe.',
          );
        case 'expired':
          _reset('Le code a expiré. Recommencez la connexion pour en obtenir un nouveau.');
        case 'locked':
          _reset('Trop de codes incorrects ont été saisis. Recommencez la connexion.');
      }
    } catch (_) {
      // Réseau momentanément indisponible : le prochain passage réessaiera.
    }
  }

  Future<void> _confirm() async {
    final challenge = _challenge;
    if (challenge == null) return;

    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Saisissez les 6 chiffres affichés dans votre espace web.');
      return;
    }

    final api = context.read<ApiClient>();
    final settings = context.read<SettingsStore>();
    final sync = context.read<SyncService>();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await api.confirmLogin(challenge.id, code, _email.text.trim());
      await settings.saveSession(token: result.token, email: result.email);
      sync.syncNow(manual: true);
      if (mounted) _password.clear();
      _reset();
    } on ApiException catch (e) {
      if (_terminalCodes.contains(e.code)) {
        _reset(e.message);
      } else if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
          _code.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = describeSyncError(e);
      });
    }
  }

  String _formatRemaining() {
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return _challenge == null ? _buildCredentials(context) : _buildCode(context);
  }

  Widget _errorText(BuildContext context) {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    );
  }

  Widget _buildCredentials(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()),
          onSubmitted: (_) => _start(),
        ),
        _errorText(context),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _start,
          icon: const Icon(Icons.login),
          label: Text(_busy ? 'Vérification…' : 'Se connecter'),
        ),
        const SizedBox(height: 8),
        Text(
          'Pas encore de compte ? Créez-le sur l’espace web de Ma Caisse, puis connectez-vous ici '
          'avec les mêmes identifiants. Pour votre sécurité, un code de confirmation affiché dans '
          'votre espace web vous sera demandé.',
          style: textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildCode(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Pour votre sécurité, cette connexion doit être confirmée. Ouvrez votre espace web '
            'Ma Caisse, connecté à ce même compte : un code à 6 chiffres s’y affiche. '
            'Saisissez-le ci-dessous.\n\n'
            'Si vous n’êtes pas à l’origine de cette connexion, cliquez sur « Ce n’est pas moi » '
            'dans l’espace web, puis changez votre mot de passe.',
            style: textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => openWebSpace(context),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Ouvrir mon espace web'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(letterSpacing: 8, fontWeight: FontWeight.bold),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            labelText: 'Code de confirmation',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _confirm(),
        ),
        const SizedBox(height: 4),
        Text('Le code expire dans ${_formatRemaining()}', style: textTheme.bodySmall),
        _errorText(context),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _confirm,
          icon: const Icon(Icons.verified_user_outlined),
          label: Text(_busy ? 'Vérification…' : 'Confirmer la connexion'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : () => _reset(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
