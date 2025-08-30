// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:vision_app/presentation/widgets/button.dart';
import 'package:vision_app/core/constants/app_colors.dart';
import '../../controllers/fazer_login_controller.dart';

class Logincontainer extends StatelessWidget {
  const Logincontainer({super.key});

  void _entrar(BuildContext context) => fazerLogin(context: context);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ColorPalette.branco,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        border: Border.all(color: ColorPalette.cinza, width: 1),
      ),
      child: Padding(
        // mantive seus paddings
        padding: const EdgeInsets.only(top: 42, right: 24, left: 25, bottom: 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, // ocupa toda a largura
          children: <Widget>[
            const SizedBox(height: 20),

            // ✅ largura fluida: nada de número mágico que estoura com o padding
            SizedBox(
              width: double.infinity,
              child: Button(text: 'Entrar', onPressed: () => _entrar(context)),
            ),

            const SizedBox(height: 8),

            // ✅ sem Row; deixa o Text receber as constraints e quebrar linha
            const Text(
              'Não possui uma conta? Contate um superior para cadastro.',
              style: TextStyle(
                color: ColorPalette.cinzaMedio,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.ellipsis, // segurança extra
            ),
          ],
        ),
      ),
    );
  }
}
