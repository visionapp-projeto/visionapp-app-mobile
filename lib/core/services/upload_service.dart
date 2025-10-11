import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart' as mime;
import 'package:http_parser/http_parser.dart';
import 'package:vision_app/core/constants/api_constants.dart';

import 'dart:convert'; // Para JSON



class UploadService {


Future<Map<String, dynamic>> enviarImagem(
  File imageFile,
  String token,
  String matricula,
) async {
  try {
    final uri = Uri.parse(ApiConstants.uploadendpoint);

    final request = http.MultipartRequest('POST', uri);

    // Cabeçalhos
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'accept': 'application/json', // igual ao curl
    });

    // Campo matricula (como no -F 'matricula=333333333')
    request.fields['matricula'] = matricula;

    // Arquivo da imagem
    final mimeTypeStr = mime.lookupMimeType(imageFile.path) ?? 'application/octet-stream';
    final contentType = MediaType.parse(mimeTypeStr);
    final stream = http.ByteStream(imageFile.openRead());
    final length = await imageFile.length();

    final multipartFile = http.MultipartFile(
      'file', // tem que ser o mesmo nome que a API espera
      stream,
      length,
      filename: imageFile.path.split('/').last,
      contentType: contentType,
    );

    request.files.add(multipartFile);

    // Envia
    final response = await request.send();
    final responseData = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Falha ao enviar imagem: ${response.statusCode} -> $responseData');
    }

    if (kDebugMode) {
      print('Imagem enviada com sucesso!');
      print('Resposta: $responseData');
    }

    return json.decode(responseData);
  } catch (e) {
    if (kDebugMode) {
      print('Erro ao enviar imagem: $e');
    }
    rethrow;
  }
}



  Future<dynamic> buscarFichaPorCpf(String cpf, String token, String? matricula) async {
  final Uri uri = Uri.parse(ApiConstants.fichaendpoint);

  final Map<String, dynamic> body = {
    'cpf': cpf,
    'matricula': matricula,
  };

  final response = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Erro ao buscar ficha');
  }
}




}
