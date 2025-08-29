import 'package:http/http.dart';

class ApiConstants {
  static const String baseUrl = 'https://fastapi.ajvale.com.br';


  static const String token = '$baseUrl/auth/firebase?token_data=';
  static const String getuser = '$baseUrl/usuario/perfil';
  static const String uploadendpoint = '$baseUrl/buscar-similaridade-foto/';
  static const String fichaendpoint = '$baseUrl/buscar-ficha-criminal/';


}

class keycloakConstants {
  static const String issuer = 'https://<sso.ajvale.com.br>/realms/<interno>';
  static const authEndpoint = '$issuer/protocol/openid-connect/auth';
  static const tokenEndpoint = '$issuer/protocol/openid-connect/token';

  static const clientId = '<visionapp>';
  static const redirectUri = 'com.visionapp://callback';
  static const scopes = 'openid profile email';
  
}