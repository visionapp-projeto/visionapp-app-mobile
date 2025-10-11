// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:vision_app/presentation/widgets/button.dart';
import 'package:vision_app/core/constants/app_colors.dart';
import '../../controllers/fazer_login_controller.dart';

class Logincontainer extends StatelessWidget {
  const Logincontainer({super.key});

  Future<void> _entrar(final BuildContext context) async {
    await fazerLogin(context: context);
  }

  @override
  Widget build(final BuildContext context) {
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
        padding: const EdgeInsets.only(
          top: 42,
          right: 24,
          left: 25,
          bottom: 64,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.stretch, // ocupa toda a largura
          children: <Widget>[
            // Botão Entrar (fluido)
            SizedBox(
              height: 48,
              child: Button(text: 'Entrar', onPressed: () => _entrar(context)),
            ),
            const SizedBox(height: 8),

            // Mensagem + Cadastrar (sem overflow)
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: <Widget>[
                const Text(
                  'Não possui uma conta?',
                  style: TextStyle(
                    color: ColorPalette.cinzaMedio,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                TextButton(
                  onPressed: () async{
                    await showDialog<void>(
                      context: context,
                      barrierColor:
                          Colors.transparent, // mantém seu fundo transparente
                      builder: (final BuildContext context) {
                        return Stack(
                          children: <Widget>[
                            // Fundo com o papel de parede
                            Positioned.fill(
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                            // Popup centralizado (seu layout original, com melhorias de responsividade)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: ColorPalette.branco,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: ColorPalette.preto.withOpacity(
                                        0.25,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: SingleChildScrollView(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 420,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        const Image(
                                          image: AssetImage(
                                            'assets/IconApp.png',
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Não tem cadastro?',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 25),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 30.0,
                                          ),
                                          child: Text(
                                            'Entre em contato com um superior para liberar seu acesso ao VisionApp.',
                                            style: TextStyle(
                                              wordSpacing: 0,
                                              letterSpacing: 0,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                              color: ColorPalette.preto,
                                            ),
                                            textAlign: TextAlign.justify,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 44,
                                          child: Button(
                                            text: 'Entendido',
                                            onPressed:
                                                () =>
                                                    Navigator.of(context).pop(),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text(
                    'Cadastrar',
                    style: TextStyle(
                      color: ColorPalette.button,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
