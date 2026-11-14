import 'dart:convert';

import 'package:http/http.dart' as http;

// ==================================================
// MARTVERDI - SERVIÇO DE PEDIDOS
// Responsável pela comunicação com a API de pedidos.
// ==================================================

class PedidosService {
  // Endereço da API acessível pelo emulador Android.
  static const String _url = 'http://10.0.2.2:5273/api/pedidos';

  // Consulta todos os pedidos cadastrados no banco.
  Future<List<Map<String, dynamic>>> buscarPedidos({
    required String cookie,
  }) async {
    final resposta = await http.get(
      Uri.parse(_url),
      headers: {
        'Cookie': cookie,
        'Content-Type': 'application/json',
      },
    );

    if (resposta.statusCode != 200) {
      throw Exception(
        'Não foi possível carregar os pedidos: ${resposta.body}',
      );
    }

    // Converte a resposta JSON em uma lista de pedidos.
    final List<dynamic> dados = jsonDecode(resposta.body);

    return dados
        .map((pedido) => Map<String, dynamic>.from(pedido))
        .toList();
  }

  // Consulta os detalhes de um pedido específico.
  Future<Map<String, dynamic>> buscarPedidoPorId({
    required int id,
    required String cookie,
  }) async {
    final resposta = await http.get(
      Uri.parse('$_url/$id'),
      headers: {
        'Cookie': cookie,
        'Content-Type': 'application/json',
      },
    );

    if (resposta.statusCode != 200) {
      throw Exception(
        'Não foi possível carregar os detalhes: ${resposta.body}',
      );
    }

    return Map<String, dynamic>.from(
      jsonDecode(resposta.body),
    );
  }

  // Atualiza o status de um pedido pela API.
  Future<void> atualizarStatus({
    required int id,
    required String status,
    required String cookie,
  }) async {
    final resposta = await http.put(
      Uri.parse('$_url/$id/status'),
      headers: {
        'Cookie': cookie,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'status': status,
      }),
    );

    if (resposta.statusCode != 200) {
      throw Exception(
        'Não foi possível atualizar o pedido: ${resposta.body}',
      );
    }
  }

  // Consulta o resumo de vendas dos pedidos concluídos.
  Future<Map<String, dynamic>> buscarResumoVendas({
    required String cookie,
  }) async {
    final resposta = await http.get(
      Uri.parse('$_url/vendas/resumo'),
      headers: {
        'Cookie': cookie,
        'Content-Type': 'application/json',
      },
    );

    if (resposta.statusCode != 200) {
      throw Exception(
        'Não foi possível carregar o resumo de vendas: ${resposta.body}',
      );
    }

    // Converte os dados de faturamento e quantidade em um mapa.
    return Map<String, dynamic>.from(
      jsonDecode(resposta.body),
    );
  }
}