import 'package:flutter/material.dart';
import 'package:vision_app/core/constants/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vision_app/presentation/pages/resultados/image_popup.dart';
import 'package:vision_app/presentation/pages/home/tela_home.dart';
import 'package:vision_app/core/utils/vulgo.dart';
import 'package:vision_app/core/utils/formatacao.dart';
import 'package:vision_app/presentation/widgets/infotextline.dart';
import 'package:vision_app/presentation/widgets/navbar.dart';
import 'package:flutter/foundation.dart';

class FichaResultPage extends StatefulWidget {
  const FichaResultPage({
    super.key,
    this.ficha,
    this.perfil,
    required this.token,
    this.fromAmbiguity = false,
  });

  final Map<String, dynamic>? ficha;
  final Map<String, dynamic>? perfil;
  final String token;
  final bool fromAmbiguity;

  @override
  void debugFillProperties(final DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Map<String, dynamic>?>('ficha', ficha));
    properties.add(
      DiagnosticsProperty<Map<String, dynamic>?>('perfil', perfil),
    );
    properties.add(DiagnosticsProperty<String>('token', token));
    properties.add(DiagnosticsProperty<bool>('fromAmbiguity', fromAmbiguity));
  }

  @override
  State<FichaResultPage> createState() => _FichaResultPageState();
}

class _FichaResultPageState extends State<FichaResultPage> {
  @override
  void initState() {
    super.initState();
    // pega o token do widget e guarda no state
    // _verificarToken(); // atualiza se precisar
  }

  // Future<void> _verificarToken() async {
  //   final t = await AuthTokenService().getToken();
  //   setState(() {

  //   });
  // }

  @override
  Widget build(final BuildContext context) {
    final List<Map<String, dynamic>> crimes =
        (widget.ficha?['crimes'] as List<Map<String, dynamic>>?) ??
        const <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: ColorPalette.dark,
      appBar: AppBar(
        backgroundColor: ColorPalette.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () async {
            if (widget.fromAmbiguity) {
              Navigator.pop(context);
            } else {
              await Navigator.pushAndRemoveUntil<TelaHome>(
                context,
                MaterialPageRoute<TelaHome>(
                  builder:
                      (final BuildContext context) =>
                          TelaHome(perfil: widget.perfil),
                ),
                (final Route<dynamic> route) => false,
              );
            }
          },
        ),
      ),
      body:
          widget.ficha == null || widget.ficha!.isEmpty
              ? const Center(
                child: Text(
                  'Nenhuma informação encontrada.',
                  style: TextStyle(color: ColorPalette.branco),
                ),
              )
              : ListView(
                padding: const EdgeInsets.only(
                  top: 0,
                  left: 40,
                  right: 37,
                  bottom: 24,
                ),
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      // Foto, Nome, Vulgo
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: ColorPalette.dark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: <Widget>[
                            GestureDetector(
                              onTap: () async {
                                await showDialog<void>(
                                  context: context,
                                  builder:
                                      (
                                        final BuildContext context,
                                      ) => ImagePopup(
                                        imageUrl:
                                            widget.ficha?['foto_url'] ??
                                            'https://i.imgur.com/j6xgQ7D.png',
                                      ),
                                );
                              },
                              child: CircleAvatar(
                                radius: 65,
                                backgroundImage: NetworkImage(
                                  widget.ficha?['foto_url'] ??
                                      'https://i.imgur.com/j6xgQ7D.png',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                children: <InlineSpan>[
                                  TextSpan(
                                    text:
                                        widget.ficha?['nome'] ??
                                        'Nome não encontrado',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: ColorPalette.branco,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Transform.translate(
                                  offset: const Offset(1, -3),
                                  child: SvgPicture.asset(
                                    'assets/Iconperson.svg',
                                    width: 20,
                                    height: 20,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  obterVulgo(widget.ficha),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: ColorPalette.branco,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 1),

                      // Dados pessoais
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: ColorPalette.dark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _buildInfoRow(
                              'CPF',
                              formatCpf(widget.ficha?['cpf']),
                            ),
                            const SizedBox(height: 15),
                            _buildInfoRow(
                              'Data de Nascimento',
                              widget.ficha?['data_nascimento'],
                            ),
                            const SizedBox(height: 15),
                            _buildInfoRow(
                              'Nome da Mãe',
                              widget.ficha?['nome_mae'],
                            ),
                            const SizedBox(height: 15),
                            _buildInfoRow(
                              'Nome do Pai',
                              widget.ficha?['nome_pai'],
                            ),
                            const SizedBox(height: 15),
                            _buildInfoRow(
                              'Possui gêmeo(a)',
                              widget.ficha?['gemeo'] == true ? 'Sim' : 'Não',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      const Text(
                        'Resumo Criminal',
                        style: TextStyle(
                          color: ColorPalette.branco,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (crimes.isNotEmpty)
                        ...List<Widget>.generate(
                          crimes.length,
                          (final int index) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: CrimeCard(crime: crimes[index]),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      bottomNavigationBar: CustomNavbar(
        currentIndex: -1,
        perfil: widget.perfil,
        token: widget.token,
      ),
    );
  }

  Widget _buildInfoRow(final String label, final String? value) {
    return RichText(
      text: TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: ColorPalette.branco,
              fontSize: 19,
            ),
          ),
          TextSpan(
            text: value ?? 'Não informado',
            style: const TextStyle(color: ColorPalette.branco, fontSize: 19),
          ),
        ],
      ),
    );
  }
}

class CrimeCard extends StatelessWidget {
  const CrimeCard({super.key, required this.crime});

  final Map<String, dynamic>? crime;

  @override
  void debugFillProperties(final DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Map<String, dynamic>?>('crime', crime));
  }

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: ColorPalette.azulMarinho,
      margin: const EdgeInsets.symmetric(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.only(
          top: 12,
          left: 16,
          right: 16,
          bottom: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Mandato',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        crime?['status'] == 'Em Aberto'
                            ? ColorPalette.vermelhoPaleta
                            : ColorPalette.cinza,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    crime?['status'] ?? 'Desconhecido',
                    style: const TextStyle(
                      color: ColorPalette.branco,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            infoTextLine(
              'Data: ',
              crime?['data_ocorrencia'] ?? 'Não informada',
            ),
            const SizedBox(height: 6),
            infoTextLine('Artigo: ', crime?['artigo'] ?? 'Não informado'),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                SvgPicture.asset(
                  'assets/LocationMarkerOutline.svg',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '${crime?['cidade'] ?? ''}, ${crime?['estado'] ?? ''}',
                  style: const TextStyle(color: ColorPalette.branco),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
