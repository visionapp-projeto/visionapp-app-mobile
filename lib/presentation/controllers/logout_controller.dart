import 'package:flutter/material.dart';
import 'package:vision_app/core/services/keycloack_auth_service.dart';
import 'package:vision_app/core/services/local_storage_service.dart';
import 'package:vision_app/presentation/pages/login/tela_login.dart';

Future<void> fazerLogout(BuildContext context) async {
  try {
    // Tenta encerrar sessão no Keycloak (não bloqueia a UI se falhar)
    await KeycloakAuthService().logout();
  } catch (_) {}

  // Limpa tokens locais
  await LocalStorageService().clear();

  // Volta para a tela de login limpando a pilha de navegação
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const TelaLogin()),
      (_) => false,
    );
  }
}

