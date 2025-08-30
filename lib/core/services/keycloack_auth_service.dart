import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import 'local_storage_service.dart';

class AuthToken {
  final String accessToken;
  final String refreshToken;
  final String idToken;
  final DateTime expiresAt;

  AuthToken({
    required this.accessToken,
    required this.refreshToken,
    required this.idToken,
    required this.expiresAt,
  });

  bool get isExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));
}

class KeycloakAuthService {
  String _base64UrlNoPadding(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  String _randomString([int length = 64]) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _codeChallenge(String verifier) {
    final hash = sha256.convert(utf8.encode(verifier));
    return _base64UrlNoPadding(hash.bytes);
  }

  Future<AuthToken?> login() async {
    final verifier = _randomString(64);
    final challenge = _codeChallenge(verifier);

    if (kDebugMode) {
      debugPrint('[OIDC] clientId=${keycloakConstants.clientId}');
      debugPrint('[OIDC] redirectUri=${keycloakConstants.redirectUri}');
      debugPrint('[OIDC] issuer=${keycloakConstants.issuer}');
      debugPrint('[OIDC] tokenEndpoint=${keycloakConstants.tokenEndpoint}');
      debugPrint('[OIDC] verifier.len=${verifier.length} prefix=${verifier.substring(0, 6)}...');
      debugPrint('[OIDC] challenge.prefix=${challenge.substring(0, 12)}...');
    }

    final authUrl = Uri.parse(keycloakConstants.authEndpoint).replace(
      queryParameters: {
        'client_id': keycloakConstants.clientId,
        'redirect_uri': keycloakConstants.redirectUri,
        'response_type': 'code',
        'scope': keycloakConstants.scopes,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
    ).toString();

    if (kDebugMode) {
      debugPrint('[OIDC] authUrl=$authUrl');
      debugPrint('[OIDC] authUrl(decoded)=${Uri.decodeFull(authUrl)}');
    }

    // Abre navegador e espera callback (scheme = com.visionapp)
    final t0 = DateTime.now();
    String? callbackUrl;
    try {
      callbackUrl = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: 'com.visionapp',
      );
      final dt = DateTime.now().difference(t0);
      if (kDebugMode) {
        debugPrint('[OIDC] callbackUrl=$callbackUrl in ${dt.inMilliseconds}ms');
      }
    } on PlatformException catch (e, st) {
      if (kDebugMode) {
        debugPrint('[OIDC] authenticate error code=${e.code} message=${e.message} details=${e.details}');
        debugPrint('[OIDC] authenticate stack=${st.toString().split('\n').take(3).join(' | ')}');
      }
      return null;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[OIDC] authenticate unknown error=$e');
        debugPrint('[OIDC] stack=${st.toString().split('\n').take(3).join(' | ')}');
      }
      return null;
    }

    final uri = Uri.parse(callbackUrl);
    if (kDebugMode) {
      debugPrint('[OIDC] cb.scheme=${uri.scheme} host=${uri.host} path=${uri.path}');
      debugPrint('[OIDC] cb.query=${uri.query}');
      debugPrint('[OIDC] cb.params=${uri.queryParameters}');
    }

    final code = uri.queryParameters['code'];
    if (code == null) {
      if (kDebugMode) {
        debugPrint('[OIDC] callback sem code; params=${uri.queryParameters}');
      }
      return null;
    }
    if (kDebugMode) debugPrint('[OIDC] authCode.len=${code.length}');

    return await _exchangeCodeForTokens(code, verifier);
  }

  Future<AuthToken?> _exchangeCodeForTokens(String code, String verifier) async {
    if (kDebugMode) {
      debugPrint('[HTTP] POST token → ${keycloakConstants.tokenEndpoint}');
      debugPrint('[HTTP] body.grant=authorization_code clientId=${keycloakConstants.clientId} redirect=${keycloakConstants.redirectUri}');
      debugPrint('[HTTP] body.code.len=${code.length} verifier.len=${verifier.length}');
    }

    final resp = await http.post(
      Uri.parse(keycloakConstants.tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': keycloakConstants.clientId,
        'code': code,
        'redirect_uri': keycloakConstants.redirectUri,
        'code_verifier': verifier,
      },
    );

    if (kDebugMode) {
      debugPrint('[HTTP] token.status=${resp.statusCode}');
      debugPrint('[HTTP] token.body=${resp.body.length > 800 ? resp.body.substring(0, 800) + '...' : resp.body}');
    }
    if (resp.statusCode != 200) return null;

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final access = json['access_token'] as String;
    final refresh = json['refresh_token'] as String;
    final id = json['id_token'] as String? ?? '';
    final expIn = json['expires_in'] as int? ?? 300;

    if (kDebugMode) {
      debugPrint('[OIDC] tokens(login): access.len=${access.length} refresh.len=${refresh.length} id.len=${id.length} expIn=${expIn}s');
    }

    return AuthToken(
      accessToken: access,
      refreshToken: refresh,
      idToken: id,
      expiresAt: DateTime.now().add(Duration(seconds: expIn)),
    );
  }

  Future<AuthToken?> refresh(String refreshToken) async {
    if (kDebugMode) {
      debugPrint('[HTTP] POST refresh → ${keycloakConstants.tokenEndpoint}');
      debugPrint('[HTTP] refresh.clientId=${keycloakConstants.clientId} refresh.len=${refreshToken.length}');
    }

    final resp = await http.post(
      Uri.parse(keycloakConstants.tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'client_id': keycloakConstants.clientId,
        'refresh_token': refreshToken,
      },
    );

    if (kDebugMode) {
      debugPrint('[HTTP] refresh.status=${resp.statusCode}');
      debugPrint('[HTTP] refresh.body=${resp.body.length > 800 ? resp.body.substring(0, 800) + '...' : resp.body}');
    }
    if (resp.statusCode != 200) return null;

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final access = json['access_token'] as String;
    final refresh = json['refresh_token'] as String;
    final id = json['id_token'] as String? ?? '';
    final expIn = json['expires_in'] as int? ?? 300;

    if (kDebugMode) {
      debugPrint('[OIDC] tokens(refresh): access.len=${access.length} refresh.len=${refresh.length} id.len=${id.length} expIn=${expIn}s');
    }

    return AuthToken(
      accessToken: access,
      refreshToken: refresh,
      idToken: id,
      expiresAt: DateTime.now().add(Duration(seconds: expIn)),
    );
  }

  /// Logout "back-channel": invalida a sessão do usuário no servidor usando o refresh_token,
  /// sem abrir navegador (mais estável em apps nativos). Requer client Public.
  Future<void> logout() async {
    try {
      final storage = LocalStorageService();
      final tokens = await storage.loadTokens();
      if (tokens == null) return;

      final uri = Uri.parse('${keycloakConstants.issuer}/protocol/openid-connect/logout');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': keycloakConstants.clientId,
          'refresh_token': tokens.refreshToken,
        },
      );
      if (kDebugMode) debugPrint('[HTTP] logout.status=${resp.statusCode}');

      // Observação: Se a sua instância exigir front-channel logout, peça ao admin
      // para adicionar em "Valid Post Logout Redirect URIs" a URI com o esquema do app
      // (com.visionapp://callback) e use a versão com navegador.
    } catch (e) {
      if (kDebugMode) debugPrint('[HTTP] logout.error=$e');
    }
  }
}
