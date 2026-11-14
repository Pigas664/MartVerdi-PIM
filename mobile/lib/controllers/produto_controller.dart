import 'package:hive/hive.dart';

import '../models/produto.dart';

// CONTROLLER DE PRODUTOS DO MARTVERDI
// Controla o cadastro, a edição, a exclusão e o armazenamento dos produtos.

class ProdutoController {
  // Referência à caixa do Hive que armazena os produtos.
  final Box _box;

  // Recebe a caixa aberta na inicialização do aplicativo.
  ProdutoController(this._box);

  // Recupera todos os produtos salvos no Hive.
  List<Produto> get produtos {
    return _box.values
        .map((dados) => Produto.fromMap(Map<dynamic, dynamic>.from(dados)))
        .toList();
  }

  // Cadastra um produto e salva seus dados no Hive.
  Future<void> adicionarProduto(Produto produto) async {
    // Gera um identificador único para o produto.
    produto.id = DateTime.now().microsecondsSinceEpoch;

    // Salva o produto utilizando seu identificador como chave.
    await _box.put(produto.id, produto.toMap());
  }

  // Atualiza os dados de um produto existente.
  Future<void> editarProduto(Produto produtoAtualizado) async {
    // Verifica se o produto possui um identificador.
    if (produtoAtualizado.id != null) {
      // Atualiza os dados armazenados no Hive.
      await _box.put(produtoAtualizado.id, produtoAtualizado.toMap());
    }
  }

  // Exclui um produto pelo seu identificador.
  Future<void> excluirProduto(int id) async {
    // Remove o registro do armazenamento local.
    await _box.delete(id);
  }
}
