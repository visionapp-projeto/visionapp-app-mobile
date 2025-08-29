import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

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

  bool get isExpired => DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));
}

class KeycloakAuthService {
  String _base64UrlNoPadding(List<int> bytes) => base64.encode(bytes).replaceAll('=', '');

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

    final authUrl = Uri.parse(keycloakConstants.authEndpoint).replace(queryParameters: {
      'client_id' : keycloakConstants.clientId,
      'redirect_uri' : keycloakConstants.redirectUri,
      'response_type' : 'code',
      'scope' : keycloakConstants.scopes,
      'code_challenge' : challenge,
      'code_challenge_method' : 'S256',
    }).toString();

    //aqui vai ser aberto o login e também vai esperar o callback (scheme = 'com.visionapp')
    final CallbackUrl = await FlutterWebAuth2.authenticate(
      url : authUrl,
      callbackUrlScheme : 'com.visionapp'
    );
    final code = Uri.parse(CallbackUrl).queryParameters['code'];
    if (code == null) return null;

    return await _exchangeCodeForTokens(code, verifier);
  }

  Future<AuthToken?> _exchangeCodeForTokens(String code, String verifier) async {
    final resp = await http.post(
      Uri.parse(keycloakConstants.tokenEndpoint),
      headers : {'Content-Type': 'application/x-www-form-urlencoded'},
      body : {
        'grant_type' : 'authorization_code',
        'client_id' : keycloakConstants.clientId,
        'code' : code,
        'redirect_uri' : keycloakConstants.redirectUri,
        'code_verifier' : verifier,
      },
    );

    if (resp.statusCode != 200) return null;

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final access = json['access_token'] as String;
    final refresh = json['refresh_token'] as String;
    final id = json['id_token'] as String? ?? '';
    final expIn = json['expires_in'] as int? ?? 300;

    return AuthToken(
    accessToken: access, 
    refreshToken: refresh, 
    idToken: id,
    expiresAt: DateTime.now().add(Duration(seconds: expIn)),
  );
  }

  Future<AuthToken?> refresh(String refreshToken) async {
    final resp = await http.post(
      Uri.parse(keycloakConstants.tokenEndpoint),
      headers : {'Content-Type': 'application/x-www-form-urlencoded'},
      body : {
        'grant_type' : 'refresh_token',
        'client_id' : keycloakConstants.clientId,
        'refresh_token' : refreshToken,
      },
    );
    if (resp.statusCode != 200) return null;

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final access = json['access_token'] as String;
    final refresh = json['refresh_token'] as String;
    final id = json['id_token'] as String? ?? '';
    final expIn = json['expires_in'] as int? ?? 300;

    return AuthToken(
      accessToken: access,
      refreshToken: refresh,
      idToken: id,
      expiresAt: DateTime.now().add(Duration(seconds: expIn)),
    );
  }


}