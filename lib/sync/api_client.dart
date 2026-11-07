import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/settings_store.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  /// Message destiné à l'utilisateur.
  final String message;
  final int? statusCode;

  /// Identifiant stable de l'erreur (voir docs/api-contract.md), par ex. `invalid_code`.
  final String? code;

  @override
  String toString() => message;
}

/// Le serveur a refusé le jeton : il faut se reconnecter.
class ApiAuthException extends ApiException {
  ApiAuthException() : super('Session expirée, veuillez vous reconnecter.', statusCode: 401);
}

/// Demande de connexion en attente de confirmation par le code affiché dans l'espace web.
class LoginChallenge {
  const LoginChallenge({required this.id, required this.expiresAt, required this.message});

  final String id;
  final DateTime expiresAt;
  final String message;

  factory LoginChallenge.fromJson(Map<String, dynamic> json) => LoginChallenge(
        id: json['challenge_id'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        message: (json['message'] as String?) ?? '',
      );
}

class LoginResult {
  const LoginResult({required this.token, required this.email});

  final String token;
  final String email;
}

class RejectedOp {
  const RejectedOp({required this.id, required this.reason});

  final String id;
  final String reason;
}

class PushResult {
  const PushResult({required this.accepted, required this.rejected});

  final List<String> accepted;
  final List<RejectedOp> rejected;
}

class RemoteChange {
  const RemoteChange({required this.entity, required this.id, required this.data});

  final String entity;
  final String id;
  final Map<String, dynamic> data;
}

class PullResult {
  const PullResult({required this.changes, required this.cursor, required this.hasMore});

  final List<RemoteChange> changes;
  final String cursor;
  final bool hasMore;
}

/// Client HTTP du contrat décrit dans docs/api-contract.md.
class ApiClient {
  ApiClient(this._settings, {http.Client? client}) : _client = client ?? http.Client();

  final SettingsStore _settings;
  final http.Client _client;

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.apiBase}$path').replace(queryParameters: query);

  Map<String, String> get _jsonHeaders => const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Map<String, String> get _authHeaders => {
        ..._jsonHeaders,
        if (_settings.token != null) 'Authorization': 'Bearer ${_settings.token}',
      };

  Map<String, dynamic> _decode(http.Response response, {bool sessionRequest = true}) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      // Corps non JSON : on se contentera du code HTTP.
    }
    if (response.statusCode == 401 && sessionRequest) throw ApiAuthException();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        body?['message']?.toString() ?? 'Erreur serveur (${response.statusCode}).',
        statusCode: response.statusCode,
        code: body?['code']?.toString(),
      );
    }
    return body ?? <String, dynamic>{};
  }

  /// Étape 1 : vérifie les identifiants et déclenche l'affichage d'un code dans l'espace web.
  Future<LoginChallenge> startLogin(String email, String password) async {
    final response = await _client
        .post(
          _uri('/auth/login'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'email': email,
            'password': password,
            'device_name': AppConfig.deviceLabel,
          }),
        )
        .timeout(_timeout);
    return LoginChallenge.fromJson(_decode(response, sessionRequest: false));
  }

  /// Étape 2 : valide le code saisi et récupère le jeton de l'appareil.
  Future<LoginResult> confirmLogin(String challengeId, String code, String email) async {
    final response = await _client
        .post(
          _uri('/auth/login/confirm'),
          headers: _jsonHeaders,
          body: jsonEncode({'challenge_id': challengeId, 'code': code}),
        )
        .timeout(_timeout);
    final body = _decode(response, sessionRequest: false);
    final token = body['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Réponse du serveur invalide (jeton manquant).');
    }
    return LoginResult(token: token, email: email);
  }

  /// État d'une demande de connexion : pending, approved, denied, expired ou locked.
  Future<String> loginStatus(String challengeId) async {
    final response = await _client
        .get(
          _uri('/auth/login/status', {'challenge_id': challengeId}),
          headers: _jsonHeaders,
        )
        .timeout(_timeout);
    return _decode(response, sessionRequest: false)['status']?.toString() ?? 'pending';
  }

  Future<PushResult> push(List<Map<String, Object?>> operations) async {
    final response = await _client
        .post(
          _uri('/sync/push'),
          headers: _authHeaders,
          body: jsonEncode({'operations': operations}),
        )
        .timeout(_timeout);
    final body = _decode(response);

    final accepted = <String>[];
    for (final id in (body['accepted'] as List<dynamic>?) ?? const []) {
      accepted.add(id.toString());
    }
    final rejected = <RejectedOp>[];
    for (final raw in (body['rejected'] as List<dynamic>?) ?? const []) {
      final map = raw as Map<String, dynamic>;
      rejected.add(RejectedOp(
        id: map['id'].toString(),
        reason: map['reason']?.toString() ?? 'Refusé par le serveur',
      ));
    }
    return PushResult(accepted: accepted, rejected: rejected);
  }

  Future<PullResult> pull(String? since) async {
    final response = await _client
        .get(
          _uri('/sync/pull', since == null ? null : {'since': since}),
          headers: _authHeaders,
        )
        .timeout(_timeout);
    final body = _decode(response);

    final changes = <RemoteChange>[];
    for (final raw in (body['changes'] as List<dynamic>?) ?? const []) {
      final map = raw as Map<String, dynamic>;
      changes.add(RemoteChange(
        entity: map['entity'] as String,
        id: map['id'].toString(),
        data: Map<String, dynamic>.from(map['data'] as Map),
      ));
    }
    final cursor = body['cursor']?.toString();
    if (cursor == null) {
      throw ApiException('Réponse du serveur invalide (curseur manquant).');
    }
    return PullResult(
      changes: changes,
      cursor: cursor,
      hasMore: body['has_more'] == true,
    );
  }
}

/// Message lisible pour l'utilisateur à partir d'une erreur réseau ou API.
String describeSyncError(Object error) {
  if (error is ApiException) return error.message;
  if (error is TimeoutException) {
    return 'Le serveur met trop de temps à répondre. Vérifiez votre connexion Internet puis réessayez.';
  }
  if (error is http.ClientException) {
    // En développement, l'adresse visée est affichée pour repérer une faute de réglage.
    return kDebugMode
        ? 'Impossible de joindre le serveur (${AppConfig.apiBase}). Vérifiez votre connexion Internet.'
        : 'Impossible de joindre le serveur. Vérifiez votre connexion Internet : vos données restent enregistrées sur le téléphone et seront synchronisées plus tard.';
  }
  if (error is FormatException) {
    return 'Le serveur a renvoyé une réponse inattendue. Réessayez dans quelques instants.';
  }
  return 'Une erreur est survenue pendant la synchronisation. Réessayez dans quelques instants.';
}
