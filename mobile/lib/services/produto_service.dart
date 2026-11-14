import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/produto.dart';

// Serviço responsável pela comunicação dos produtos com a API MartVerdi.
class ProdutoService {
  // Endereço da API acessada pelo emulador Android.
  static const String baseUrl = 'http://10.0.2.2:5273/api/produtos';

  // Cabeçalhos utilizados nas requisições.
  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=UTF-8',
  };

  // Busca todos os produtos cadastrados no banco de dados.
  Future<List<Produto>> buscarProdutos() async {
    final resposta = await http.get(
      Uri.parse(baseUrl),
      headers: _headers,
    );

    if (resposta.statusCode == 200) {
      final List<dynamic> dados =
          jsonDecode(utf8.decode(resposta.bodyBytes));

      return dados
          .map(
            (item) => Produto.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    throw Exception(
      'Erro ao buscar produtos. Código: ${resposta.statusCode}',
    );
  }

  // Cadastra um novo produto sem enviar o ID.
  // O backend gera automaticamente o próximo identificador.
  Future<void> cadastrarProduto(Produto produto) async {
    final dados = produto.toJson();

    // Remove o ID nulo para evitar erro de conversão no backend.
    dados.remove('id');

    final resposta = await http.post(
      Uri.parse(baseUrl),
      headers: _headers,
      body: jsonEncode(dados),
    );

    if (resposta.statusCode != 200 &&
        resposta.statusCode != 201 &&
        resposta.statusCode != 204) {
      throw Exception(
        'Erro ao cadastrar produto: ${_mensagemErro(resposta)}',
      );
    }
  }

  // Atualiza um produto existente utilizando seu ID.
  Future<void> atualizarProduto(Produto produto) async {
    if (produto.id == null) {
      throw Exception('O produto não possui um ID válido.');
    }

    final resposta = await http.put(
      Uri.parse('$baseUrl/${produto.id}'),
      headers: _headers,
      body: jsonEncode(produto.toJson()),
    );

    if (resposta.statusCode != 200 &&
        resposta.statusCode != 204) {
      throw Exception(
        'Erro ao atualizar produto: ${_mensagemErro(resposta)}',
      );
    }
  }

  // Exclui um produto pelo identificador.
  Future<void> excluirProduto(int id) async {
    final resposta = await http.delete(
      Uri.parse('$baseUrl/$id'),
      headers: _headers,
    );

    if (resposta.statusCode != 200 &&
        resposta.statusCode != 204) {
      throw Exception(
        'Erro ao excluir produto: ${_mensagemErro(resposta)}',
      );
    }
  }

  // Obtém uma mensagem mais clara quando a API retorna um erro.
  String _mensagemErro(http.Response resposta) {
    try {
      final dados = jsonDecode(utf8.decode(resposta.bodyBytes));

      if (dados is Map && dados['mensagem'] != null) {
        return dados['mensagem'].toString();
      }

      return resposta.body;
    } catch (_) {
      return 'Código HTTP ${resposta.statusCode}';
    }
  }
}