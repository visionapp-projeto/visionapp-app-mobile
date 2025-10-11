// lib/presentation/controllers/logout_controller.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vision_app/core/services/keycloack_auth_service.dart';
import 'package:vision_app/core/services/local_storage_service.dart';
import 'package:vision_app/core/services/auth_token_service.dart';
import 'package:vision_app/presentation/pages/login/tela_login.dart';

Future<void> fazerLogout(BuildContext context) async {
  try {
    // Encerra sessão no Keycloak (se falhar, seguimos o logout local)
    await KeycloakAuthService().logout();
  } catch (_) {}

  // Limpa tokens locais (oficial)
  await LocalStorageService().clear();

  // Remove legado (se existir)
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  } catch (_) {}

  // Zera cache em memória do singleton
  AuthTokenService().setInMemoryToken(null);

  // Volta para a tela de login limpando a pilha
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const TelaLogin()),
      (_) => false,
    );
  }
}
