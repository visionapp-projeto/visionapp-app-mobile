
class ApiConstants {
  static const String baseUrl = 'https://fastapi.ajvale.com.br';


  static const String getuser = '$baseUrl/usuario/perfil';
  static const String uploadendpoint = '$baseUrl/buscar-similaridade-foto/';
  static const String fichaendpoint = '$baseUrl/buscar-ficha-criminal/';


}

class keycloakConstants {
  static const String issuer = 'https://sso.ajvale.com.br/realms/interno';
  static const String authEndpoint = '$issuer/protocol/openid-connect/auth';
  static const String tokenEndpoint = '$issuer/protocol/openid-connect/token';

  static const String clientId = 'visionapp';
  static const String redirectUri = 'com.visionapp://callback';
  static const String scopes = 'openid profile email';

}

