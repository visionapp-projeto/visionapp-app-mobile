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
  Map<String, dynamic>? _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? get claims =>
      _cachedToken == null ? null : _decodeJwtPayload(_cachedToken!);

  String? getMatricula() => claims?['matricula']?.toString();
  String? getCpf() => claims?['cpf']?.toString();
  String? getSubject() => claims?['sub']?.toString();

  // ========= API compatível com teu código atual =========

  // Obter o token atual (da memória ou do armazenamento)
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;

    // Primeiro tenta o storage “oficial” (access/refresh)
    final storage = LocalStorageService();
    final tokens = await storage.loadTokens();
    if (tokens?.accessToken != null) {
      _cachedToken = tokens!.accessToken;
      return _cachedToken;
    }

    // Fallback: legado em SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  // Getter síncrono (pode retornar null se não carregado ainda)
  String? get token => _cachedToken;

  // Salvar um novo token (compat legado)
  Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Retorna um access token válido do Keycloak (faz refresh se necessário)
  Future<String?> getValidAccessToken() async {
    // 1) cache em memória
    if (_cachedToken != null) {
      final c = _decodeJwtPayload(_cachedToken!);
      final exp = c?['exp'];
      if (exp is num) {
        final expDt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
        if (DateTime.now().isBefore(expDt.subtract(const Duration(seconds: 30)))) {
          return _cachedToken; // ainda válido
        }
      }
    }

    // 2) tokens armazenados
    final storage = LocalStorageService();
    final kc = KeycloakAuthService();

    var tokens = await storage.loadTokens();
    if (tokens == null) {
      // 3) compat com o legado (pode estar sem refreshToken)
      final legacy = await getToken();
      _cachedToken = legacy;
      return legacy;
    }

    // 4) Se expirar, tenta refresh
    if (tokens.isExpired) {
      final refreshed = await kc.refresh(tokens.refreshToken);
      if (refreshed == null) return null;
      await storage.saveTokens(refreshed);
      _cachedToken = refreshed.accessToken;
      return _cachedToken;
    } else {
      _cachedToken = tokens.accessToken;
      return _cachedToken;
    }
  }

  Map<String, String> buildAuthHeaders({String? overrideToken, bool includeMatriculaHeader = false}) {
    final tok = overrideToken ?? _cachedToken;
    final headers = <String, String>{
      'accept': 'application/json',
      if (tok != null) 'Authorization': 'Bearer $tok',
    };
    if (includeMatriculaHeader) {
      final m = getMatricula();
      if (m != null && m.isNotEmpty) {
        headers['X-Matricula'] = m;
      }
    }
    return headers;
  }
}
