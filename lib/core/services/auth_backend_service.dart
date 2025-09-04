import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vision_app/core/constants/api_constants.dart';
import 'package:vision_app/core/services/auth_token_service.dart';

// -------- Helpers locais (apenas leitura do payload; assinatura é validada no backend)
Map<String, dynamic>? _decodeJwtPayload(final String token) {
  final List<String> parts = token.split('.');
  if (parts.length != 3) return null;

  try {
    final String payload =
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    return jsonDecode(payload) as Map<String, dynamic>;
  } on FormatException catch (e) {
    if (kDebugMode) debugPrint('Formato inválido ao decodificar JWT: $e');
    return null;
  } on Exception catch (e) {
    if (kDebugMode) debugPrint('Falha ao decodificar payload do JWT: $e');
    return null;
  }
}

String? _matriculaFromToken(final String accessToken) {
  final Map<String, dynamic>? claims = _decodeJwtPayload(accessToken);
  if (claims == null) return null;

  const List<String> candidates = <String>[
    'matricula',
    'matriculaServidor',
    'employeeId',
    'employeeID',
    'employee_number',
    'preferred_username',
  ];

  for (final String k in candidates) {
    final Object? v = claims[k];
    if (v == null) continue;
    final String s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

// -------- Util: pegar valor por caminho "a.b.c"
Object? _getByPath(final Map<String, dynamic> map, final String path) {
  Object? cur = map;
  for (final String part in path.split('.')) {
    if (cur is Map<String, dynamic> && cur.containsKey(part)) {
      cur = cur[part];
    } else {
      return null;
    }
  }
  return cur;
}

String? _firstNonEmptyStr(final Map<String, dynamic> map, final List<String> paths) {
  for (final String p in paths) {
    final Object? v = _getByPath(map, p);
    if (v == null) continue;
    final String s = (v is String) ? v.trim() : v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

// -------- Normalizador: garante chaves padronizadas no Map
Map<String, dynamic> _normalizePerfil(
  final Map<String, dynamic> raw, {
  final String? tokenMatricula,
}) {
  final String? nome = _firstNonEmptyStr(raw, <String>[
    'nome',
    'fullName',
    'name',
    'pessoa.nome',
    'usuario.nome',
    'dados.nome',
  ]);

  final String? cargo = _firstNonEmptyStr(raw, <String>[
    'cargo',
    'funcao',
    'role',
    'roleName',
    'lotacao.cargo.descricao',
    'cargo.descricao',
    'dados.cargo',
  ]);

  final String? nivelClasse = _firstNonEmptyStr(raw, <String>[
    'nivel_classe',
    'classe',
    'nivelClasse',
    'cargo.classe',
    'classe.nivel',
    'dados.nivel_classe',
  ]);

  final String? matricula = _firstNonEmptyStr(raw, <String>[
    'matricula',
    'matriculaServidor',
    'registration',
    'employeeId',
    'employeeID',
    'servidor.matricula',
    'dados.matricula',
  ]) ?? tokenMatricula;

  return <String, dynamic>{
    ...raw,
    if (nome != null) 'nome': nome,
    if (cargo != null) 'cargo': cargo,
    if (nivelClasse != null) 'nivel_classe': nivelClasse,
    if (matricula != null) 'matricula': matricula,
  };
}

// -------- Cliente HTTP que sempre manda Bearer (sem X-Matricula)
class _AuthHttpClient extends http.BaseClient {
  final String accessToken;
  final http.Client _inner;

  _AuthHttpClient(final String accessToken, [final http.Client? inner])
      : accessToken = accessToken,
        _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(final http.BaseRequest request) {
    request.headers['accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $accessToken';
    
    return _inner.send(request);
  }
}
/// Mantém a MESMA assinatura usada no app: getUserProfile(tokens.accessToken)
Future<Map<String, dynamic>?> getUserProfile(final String access_token) async {
  // Fallback defensivo
  String token = access_token.trim();
  if (token.isEmpty) {
    final String? t = await AuthTokenService().getValidAccessToken();
    if (t == null) {
      if (kDebugMode) debugPrint('getUserProfile: sem token válido');
      return null;
    }
    token = t;
  }

  // Se recentemente falhou, pula o backend e usa Keycloak diretamente
  // if (_skipPerfilBackendUntil != null && DateTime.now().isBefore(_skipPerfilBackendUntil!)) {
  //   if (kDebugMode) {
  //     final until = _skipPerfilBackendUntil!.toIso8601String();
  //     print('Pulando backend /usuario/perfil até $until; usando Keycloak UserInfo');
  //   }
  //   final kcInfo = await getKeycloakUserInfo(token);
  //   if (kcInfo != null) {
  //     final tokenMat = _matriculaFromToken(token);
  //     return _normalizePerfil(kcInfo, tokenMatricula: tokenMat);
  //   }
  //   return null;
  // }

  final uri = Uri.parse(ApiConstants.getuser);
  final client = _AuthHttpClient(token);

  try {
    if (kDebugMode) {
      print('Chamando perfil (backend): $uri');
    }
    final response = await client.get(uri);

    if (response.statusCode == 200) {
      final Map<String, dynamic> raw =
          jsonDecode(response.body) as Map<String, dynamic>;
      final String? tokenMat = _matriculaFromToken(token);
      final Map<String, dynamic> normalized =
          _normalizePerfil(raw, tokenMatricula: tokenMat);

      if (kDebugMode) {
        debugPrint('Perfil obtido (raw): ${response.body}');
        debugPrint('Perfil normalizado: $normalized');
      }
      return normalized;
    } else {
      // Marca backoff e faz fallback: tenta obter do Keycloak UserInfo se o endpoint do backend não existir
      if (kDebugMode) {

        if (response.statusCode == 404) {
          print('Perfil não encontrado no backend (404). Usando Keycloak UserInfo...');
        } else {
          print('Erro na requisição GET /usuario/perfil: '
              '${response.statusCode} → ${response.body}');
          print('Tentando fallback no /userinfo do Keycloak...');
        }
      }
      // evita novas tentativas por alguns minutos
      // _skipPerfilBackendUntil = DateTime.now().add(const Duration(minutes: 10));

      final kcInfo = await getKeycloakUserInfo(token);
      if (kcInfo != null) {
        final tokenMat = _matriculaFromToken(token);
        final normalized = _normalizePerfil(kcInfo, tokenMatricula: tokenMat);
        if (kDebugMode) {
          print('Perfil via Keycloak UserInfo: $kcInfo');
          print('Perfil normalizado (fallback): $normalized');
        }
        return normalized;
      }
      return null;
    }
  } on TimeoutException {
    if (kDebugMode) debugPrint('Timeout no GET /usuario/perfil');
    return null;
  } on http.ClientException catch (e) {
    if (kDebugMode) debugPrint('HTTP client error: $e');
    return null;
  } on FormatException catch (e) {
    if (kDebugMode) debugPrint('JSON inválido no perfil: $e');
    return null;

  } catch (e) {

    // if (kDebugMode) print('Exception no getUserProfile: $e');
    // _skipPerfilBackendUntil = DateTime.now().add(const Duration(minutes: 10));
    // Fallback também em caso de exceção de rede/parse
    try {
      final kcInfo = await getKeycloakUserInfo(token);
      if (kcInfo != null) {
        final tokenMat = _matriculaFromToken(token);
        final normalized = _normalizePerfil(kcInfo, tokenMatricula: tokenMat);
        if (kDebugMode) {
          print('Perfil via Keycloak UserInfo (exceção): $kcInfo');
          print('Perfil normalizado (fallback-exceção): $normalized');
        }
        return normalized;
      }
    } catch (_) {}

    return null;
  }
}

Future<Map<String, dynamic>?> getKeycloakUserInfo(final String accessToken) async {
  final Uri uri =
      Uri.parse('${keycloakConstants.issuer}/protocol/openid-connect/userinfo');
  try {
    final http.Response response = await http
        .get(
          uri,
          headers: const <String, String>{
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
