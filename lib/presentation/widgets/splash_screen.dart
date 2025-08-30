// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:vision_app/core/constants/app_colors.dart';
import 'package:vision_app/presentation/pages/home/tela_home.dart';
import 'package:vision_app/presentation/pages/login/tela_login.dart';
import 'package:vision_app/core/services/auth_backend_service.dart';
import 'package:vision_app/core/services/local_storage_service.dart';
import 'package:vision_app/core/services/keycloack_auth_service.dart';
import 'package:flutter/foundation.dart';
// import 'package:vision_app/core/services/keycloak_auth_service.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
void initState() {
  super.initState();
  _checkLogin();
}

Future<void> _checkLogin() async {
  final storage = LocalStorageService();
  final kc = KeycloakAuthService();

  var tokens = await storage.loadTokens();
  if (tokens != null) {
    if (kDebugMode) {
      debugPrint('[SPLASH] hasTokens=true expAt=${tokens.expiresAt} now=${DateTime.now()} expired=${tokens.isExpired}');
    }
    if (tokens.isExpired) {
      if (kDebugMode) debugPrint('[SPLASH] refreshing...');
      final refreshed = await kc.refresh(tokens.refreshToken);
      if (refreshed == null) { if (kDebugMode) debugPrint('[SPLASH] refresh.ok=false → goToLogin'); _goToLogin(); return; }
      await storage.saveTokens(refreshed);
      tokens = refreshed;
      if (kDebugMode) debugPrint('[SPLASH] refresh.ok=true');
    }
    final perfil = await getUserProfile(tokens.accessToken);
    if (perfil != null) {
      if (kDebugMode) debugPrint('[SPLASH] perfil.ok=true → goToHome');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TelaHome(perfil: perfil)),
      );
      return;
    }
  }
  if (kDebugMode) debugPrint('[SPLASH] hasTokens=false or perfil null → goToLogin');
  _goToLogin();
}

void _goToLogin() {
  if (!mounted) return;
  if (kDebugMode) debugPrint('[SPLASH] navigating → Login');
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const TelaLogin()),
    (_) => false,
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPalette.dark, // Cor de fundo da tela
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/IconApp.png', // Caminho para a imagem do logo
              width: 200, // Largura da imagem
              height: 200, // Altura da imagem
            ),
            SizedBox(height: 20), // Espaço entre o ícone e o loading
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(ColorPalette.lightbutton),
              strokeWidth: 3.0,
            ),
          ],
        ),
      ),
    );
  }
}
