// lib/core/services/auth_token_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vision_app/core/services/local_storage_service.dart';
import 'package:vision_app/core/services/keycloack_auth_service.dart';

class AuthTokenService {
  // Singleton
  static final AuthTokenService _instance = AuthTokenService._internal();
  factory AuthTokenService() => _instance;
  AuthTokenService._internal();

  // Legado: chave antiga no SharedPreferences
  static const String _tokenKey = 'auth_token';

  // Cache em memória do access token atual
  String? _cachedToken;

  // ========= Helpers de JWT (somente leitura de payload; backend valida assinatura) =========
  Map<String, dynamic>? _decodeJwtPayload(final String token) {
    final List<String> parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final String payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return jsonDecode(payload) as Map<String, dynamic>;
    } on FormatException {
      // base64 inválido ou JSON malformado
      return null;
    } on Exception {
      // Qualquer outra exceção de decode/parse
      return null;
    }
  }

  Map<String, dynamic>? get claims =>
      _cachedToken == null ? null : _decodeJwtPayload(_cachedToken!);

  String? _firstNonEmptyClaim(final Iterable<String> keys) {
    final Map<String, dynamic>? c = claims;
    if (c == null) return null;

    for (final String k in keys) {
      final Object? v = c[k];
      if (v == null) continue;

      final String s = (v is String) ? v.trim() : v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  String? getMatricula() => _firstNonEmptyClaim(<String>[
        'matricula',
        'matriculaServidor',
        'employeeId',
        'employeeID',
        'employee_number',
        'preferred_username',
      ]);

  String? getCpf() => _firstNonEmptyClaim(<String>['cpf']);

  String? getSubject() => _firstNonEmptyClaim(<String>['sub']);

  String? getCargo() =>
      _firstNonEmptyClaim(<String>['cargo', 'funcao', 'role', 'roleName']);

  String? getClasse() =>
      _firstNonEmptyClaim(<String>['nivel_classe', 'classe', 'nivelClasse']);

  // Obter o token atual (da memória ou do armazenamento)
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;

    final LocalStorageService storage = LocalStorageService();
    final AuthToken? tokens = await storage.loadTokens();
    if (tokens?.accessToken != null) {
      _cachedToken = tokens!.accessToken;
      return _cachedToken;
    }

    // Fallback: legado em SharedPreferences (se existir)
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  String? get token => _cachedToken;

  // Legado: salva apenas no SharedPreferences
  Future<void> saveToken(final String token) async {
    _cachedToken = token;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Atualiza SOMENTE o cache em memória (use após saveTokens no storage oficial).
  void setInMemoryToken(final String? accessToken) {
    _cachedToken = accessToken;
  }

  Future<String?> getValidAccessToken() async {
    if (_cachedToken != null) {
      final Map<String, dynamic>? c = _decodeJwtPayload(_cachedToken!);
      final Object? exp = c?['exp'];
      if (exp is num) {
        final DateTime expDt =
            DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
        if (DateTime.now().isBefore(expDt.subtract(const Duration(seconds: 30)))) {
          // ainda válido
          return _cachedToken;
        }
      }
    }

    final LocalStorageService storage = LocalStorageService();
    final KeycloakAuthService kc = KeycloakAuthService();

    final AuthToken? tokens = await storage.loadTokens();
    if (tokens == null) {
      final String? legacy = await getToken(); // pode vir do legado
      _cachedToken = legacy;
      return legacy;
    }

    if (tokens.isExpired) {
      final AuthToken? refreshed = await kc.refresh(tokens.refreshToken);
      if (refreshed == null) return null;
      await storage.saveTokens(refreshed);
      _cachedToken = refreshed.accessToken;
      return _cachedToken;
    } else {
      _cachedToken = tokens.accessToken;
      return _cachedToken;
    }
  }

  Map<String, String> buildAuthHeaders({
    final String? overrideToken,
    final bool includeMatriculaHeader = false,
  }) {
    final String? tok = overrideToken ?? _cachedToken;
    final Map<String, String> headers = <String, String>{
      'accept': 'application/json',
      if (tok != null) 'Authorization': 'Bearer $tok',
    };
    if (includeMatriculaHeader) {
      final String? m = getMatricula();
      if (m != null && m.isNotEmpty) {
        headers['X-Matricula'] = m;
      }
    }
    return headers;
  }

  /// LOGOUT COMPLETO:
  /// - encerra sessão no Keycloak (SSO do usuário)
  /// - limpa storage oficial (access/refresh/id/exp)
  /// - remove legado 'auth_token'
  /// - zera cache em memória
  Future<void> logout({final bool revokeOnServer = true}) async {
    final LocalStorageService storage = LocalStorageService();

    try {
      // 1) encerra sessão do realm (SSO); usa refresh_token salvo
      if (revokeOnServer) {
        try {
          await KeycloakAuthService().logout(); // usa seu serviço de Keycloak
        } on Exception {
          // ignorar falha de logout remoto
        }
      }

      // 2) limpa storage oficial
      await storage.clear();

      // 3) remove token legado
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } finally {
    
      _cachedToken = null;
    }
  }
}