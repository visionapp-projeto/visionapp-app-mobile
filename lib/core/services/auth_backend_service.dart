import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vision_app/core/constants/api_constants.dart';
import 'package:vision_app/core/services/auth_token_service.dart';



// -------- Normalizador: garante chaves padronizadas no Map
Map<String, dynamic> _normalizePerfil(Map<String, dynamic> raw) {
  return <String, dynamic>{
    'name': raw['name'],
    'cargo': raw['cargo'],
    'classe': raw['classe'],
    'matricula': raw['matricula'],
  };
}


/// Mantém a MESMA assinatura usada no app: getUserProfile(tokens.accessToken)
Future<Map<String, dynamic>?> getUserProfile(final String accessToken) async {
  // Fallback defensivo
  String token = accessToken.trim();
  if (token.isEmpty) {
    final String? t = await AuthTokenService().getValidAccessToken();
    if (t == null) {
      if (kDebugMode) debugPrint('getUserProfile: sem token válido');
      return null;
    }
    token = t;
  }


  try {

      final Map<String, dynamic>? kcInfo = await getKeycloakUserInfo(token);
      if (kcInfo != null) {
        final Map<String, dynamic> normalized = _normalizePerfil(
          kcInfo,
        );

        if (kDebugMode) {
          print('Perfil via Keycloak UserInfo: $kcInfo');
          print('Perfil normalizado (fallback): $normalized');
        }
        return normalized;
      }

  } on http.ClientException catch (e) {
    if (kDebugMode) debugPrint('HTTP client error: $e');
    return null;
  } on FormatException catch (e) {
    if (kDebugMode) debugPrint('JSON inválido no perfil: $e');
    return null;
  } on Exception {
    try {
      final Map<String, dynamic>? kcInfo = await getKeycloakUserInfo(token);
      if (kcInfo != null) {
        final Map<String, dynamic> normalized = _normalizePerfil(
          kcInfo,
        );
        if (kDebugMode) {
          print('Perfil via Keycloak UserInfo (exceção): $kcInfo');
          print('Perfil normalizado (fallback-exceção): $normalized');
        }
        return normalized;
      }
    } on Exception catch (_) {
      // fallback também falhou — nada a fazer, segue para retornar null
    }
    return null;
  }
}

Future<Map<String, dynamic>?> getKeycloakUserInfo(final String accessToken) async {
  final Uri uri = Uri.parse(
    '${keycloakConstants.issuer}/protocol/openid-connect/userinfo',
  );
  try {
    final http.Response response = await http
        .get(
          uri,
          headers: <String, String>{
            'accept': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      return null;
    }
  } on TimeoutException {
    if (kDebugMode) debugPrint('Timeout no GET /userinfo');
    return null;
  } on http.ClientException catch (e) {
    if (kDebugMode) debugPrint('HTTP client error: $e');
    return null;
  } on FormatException catch (e) {
    if (kDebugMode) debugPrint('JSON inválido em /userinfo: $e');
    return null;
  } on Exception catch (e) {
    if (kDebugMode) debugPrint('Exception em getKeycloakUserInfo: $e');
    return null;
  }
}
