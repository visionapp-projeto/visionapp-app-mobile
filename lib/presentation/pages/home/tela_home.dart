// lib/presentation/pages/home/tela_home.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vision_app/presentation/pages/buscacpf/tela_busca_cpf.dart';
import 'package:vision_app/presentation/pages/home/drawer_perfil.dart';
import 'package:vision_app/presentation/pages/home/pop-up_facerules.dart';
import 'package:vision_app/core/services/auth_token_service.dart';
import '../../widgets/button.dart';
import 'dart:async';

class TelaHome extends StatefulWidget {
  const TelaHome({super.key, this.nomeUsuario, this.perfil});

  final String? nomeUsuario;
  final Map<String, dynamic>? perfil;

  @override
  void debugFillProperties(final DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('nomeUsuario', nomeUsuario, defaultValue: null))
      ..add(
        DiagnosticsProperty<Map<String, dynamic>?>(
          'perfil',
          perfil,
          defaultValue: null,
        ),
      );
  }

  @override
  State<TelaHome> createState() => _TelaHomeState();
}

class _TelaHomeState extends State<TelaHome> {
  String nome = 'Usuário';
  String nomeCompleto = 'Nome não informado';
  String cargo = 'Cargo não informado';
  String classe = 'Classe não informada';
  String matricula = 'Matrícula não informada';

  String? _token;
  Map<String, dynamic>? _perfil;

  @override
  void debugFillProperties(final DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('nome', nome));
    properties.add(StringProperty('nomeCompleto', nomeCompleto));
    properties.add(StringProperty('cargo', cargo));
    properties.add(StringProperty('classe', classe));
    properties.add(StringProperty('matricula', matricula));
  }

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    // 1) Garante token em cache -> habilita leitura de claims
    final String? t = await AuthTokenService().getValidAccessToken();
    if (!mounted) return;
    setState(() => _token = t);

    // 2) Perfil recebido por parâmetro (se houver)
    setState(() => _perfil = widget.perfil);

    // 3) Preenche telas com a nova ordem: TOKEN → PERFIL → DEFAULT
    _preencherCampos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preencherCampos();
  }

  // ===== Helpers de leitura segura =====

  // Placeholders que devem ser tratados como "vazios"
  bool _isPlaceholder(final String s) {
    final String x = s.trim().toLowerCase();

    return x.isEmpty ||
        x == 'não informado' ||
        x == 'nao informado' ||
        x == 'cargo não informado' ||
        x == 'cargo nao informado' ||
        x == 'classe não informada' ||
        x == 'classe nao informada' ||
        x == 'matrícula não informada' ||
        x == 'matricula nao informada' ||
        x == 'nome não informado' ||
        x == 'null' ||
        x == 'undefined';
  }

  String? _clean(final String? s) {
    if (s == null) return null;
    final String t = s.trim();
    if (_isPlaceholder(t)) return null;
    return t;
  }

  // Lê primeira chave não-vazia (ignora placeholders) e busca também níveis comuns
  String? _pickFirstNonEmpty(
    final Map<String, dynamic>? map,
    final List<String> keys,
  ) {
    if (map == null) return null;

    for (final String k in keys) {
      final Object? v = map[k];
      if (v == null) continue;

      final String t = (v is String) ? v : v.toString();
      final String? cleaned = _clean(t);
      if (cleaned != null) return cleaned;
    }

    for (final String nested in <String>['dados', 'perfil', 'user']) {
      final Object? sub = map[nested];
      if (sub is Map<String, dynamic>) {
        final String? got = _pickFirstNonEmpty(sub, keys);
        if (got != null) return got;
      }
    }

    return null;
  }

  // Escolhe na ordem: token → perfil → default
  String _chooseTPD({
    final String? tokenVal,
    final String? perfilVal,
    required final String fallback,
  }) {
    final String? t = _clean(tokenVal);
    if (t != null) return t;

    final String? p = _clean(perfilVal);
    if (p != null) return p;

    return fallback;
  }

  void _preencherCampos() {
    final Map<String, dynamic>? p = _perfil ?? widget.perfil;
    final Object? args = ModalRoute.of(context)?.settings.arguments;

    // Nome
    final String nomeBase =
        widget.nomeUsuario ??
        (args is String
            ? args
            : _pickFirstNonEmpty(p, <String>['nome', 'fullName', 'name'])) ??
        'Usuário';

    // PERFIL (mapa)
    final String? perfilCargo = _pickFirstNonEmpty(p, <String>[
      'cargo',
      'funcao',
      'role',
      'roleName',
    ]);
    final String? perfilClasse = _pickFirstNonEmpty(p, <String>[
      'nivel_classe',
      'classe',
      'nivelClasse',
    ]);
    final String? perfilMatricula = _pickFirstNonEmpty(p, <String>[
      'matricula',
      'matriculaServidor',
      'registration',
      'employeeId',
      'employeeID',
    ]);

    // TOKEN (claims)
    final String? tokenCargo = AuthTokenService().getCargo();
    final String? tokenClasse = AuthTokenService().getClasse();
    final String? tokenMatricula = AuthTokenService().getMatricula();

    // Nome completo
    final String? perfilNomeCompleto = _pickFirstNonEmpty(p, <String>[
      'nome',
      'fullName',
      'name',
    ]);

    // Aplica ordem TOKEN → PERFIL → DEFAULT
    final String novoCargo = _chooseTPD(
      tokenVal: tokenCargo,
      perfilVal: perfilCargo,
      fallback: 'Cargo não informado',
    );
    final String novaClasse = _chooseTPD(
      tokenVal: tokenClasse,
      perfilVal: perfilClasse,
      fallback: 'Classe não informada',
    );
    final String novaMatricula = _chooseTPD(
      tokenVal: tokenMatricula,
      perfilVal: perfilMatricula,
      fallback: 'Matrícula não informada',
    );

    if (kDebugMode) {
      print('Claims JWT: ${AuthTokenService().claims}');
      print(
        'perfilCargo=$perfilCargo, tokenCargo=$tokenCargo -> escolhido=$novoCargo',
      );
      print(
        'perfilClasse=$perfilClasse, tokenClasse=$tokenClasse -> escolhido=$novaClasse',
      );
      print(
        'perfilMatricula=$perfilMatricula, tokenMatricula=$tokenMatricula -> escolhido=$novaMatricula',
      );
    }

    setState(() {
      nome = nomeBase.split(' ').first;
      nomeCompleto = perfilNomeCompleto ?? 'Nome não informado';
      cargo = novoCargo;
      classe = novaClasse;
      matricula = novaMatricula;
    });
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder:
              (final BuildContext context) => IconButton(
                icon: Image.asset(
                  'assets/icon_drawer.png',
                  width: 16,
                  height: 12,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
      ),
      drawer: CustomDrawer(
        nomeCompleto: nomeCompleto,
        cargo: cargo,
        classe: classe,
        matricula: matricula,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Text(
                'Bem-Vindo(a),\n$nome!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 120),
              HomeButton(
                assetImagePath: 'assets/lupa_cpf.png',
                texto: 'Busca por CPF',
                onPressed: () async {
                  FocusScope.of(context).unfocus();
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder:
                          (final BuildContext context) => TelaBuscaCpf(
                            token: _token ?? '',
                            perfil: _perfil ?? widget.perfil,
                          ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              HomeButton(
                assetImagePath: 'assets/face_recognition.png',
                texto: 'Pesquisa Criminal',
                onPressed: () {
                  mostrarPopUpRegrasFace(
                    context: context,
                    perfil: _perfil ?? widget.perfil,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
