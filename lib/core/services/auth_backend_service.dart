import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vision_app/core/constants/api_constants.dart';
import 'package:vision_app/core/services/auth_token_service.dart';
import 'package:vision_app/core/services/keycloack_auth_service.dart'; // para keycloakConstants em /userinfo

// -------- Helpers locais (apenas leitura do payload; assinatura é validada no backend)
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

String? _matriculaFromToken(String accessToken) {
  final claims = _decodeJwtPayload(accessToken);
  final m = claims?['matricula'];
  return m?.toString();
}

// -------- Cliente HTTP que sempre manda Bearer + X-Matricula
class _AuthHttpClient extends http.BaseClient {
  final String accessToken;
  final http.Client _inner;
  _AuthHttpClient(this.accessToken, [http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $accessToken';

    final matricula = _matriculaFromToken(accessToken);
    if (matricula != null && matricula.isNotEmpty) {
      // ajuste o nome do header se teu backend espera outro
      request.headers['X-Matricula'] = matricula;
    }
    return _inner.send(request);
  }
}

/// Mantém a MESMA assinatura usada no app: getUserProfile(tokens.accessToken)
Future<Map<String, dynamic>?> getUserProfile(String access_token) async {
  // Fallback defensivo: se vier vazio por algum motivo, tenta pegar um token válido centralizado
  var token = (access_token).trim();
  if (token.isEmpty) {
    final t = await AuthTokenService().getValidAccessToken();
    if (t == null) {
      if (kDebugMode) print('getUserProfile: sem token válido');
      return null;
    }
    token = t;
  }

  final uri = Uri.parse(ApiConstants.getuser);
  final client = _AuthHttpClient(token);

  try {
    final response = await client.get(uri);
    if (response.statusCode == 200) {
      if (kDebugMode) print('Perfil obtido!: ${response.body}');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      if (kDebugMode) {
        print('Erro na requisição GET /usuario/perfil: '
            '${response.statusCode} → ${response.body}');
      }
      return null;
    }
  } catch (e) {
    if (kDebugMode) print('Exception no getUserProfile: $e');
    return null;
  }
}

/// Continua igual: pega dados no /userinfo (útil para debug)
Future<Map<String, dynamic>?> getKeycloakUserInfo(String accessToken) async {
  final uri = Uri.parse('${keycloakConstants.issuer}/protocol/openid-connect/userinfo');
  try {
    final response = await http.get(
      uri,
      headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      return null;
    }
  } catch (e) {
    return null;
  }
}
