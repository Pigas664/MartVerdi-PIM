 // MODELO DE PRODUTO DO MARTVERDI
 // Representa os produtos recebidos da API e utilizados no aplicativo.

class Produto {
  // Identificador do produto no banco de dados.
  int? id;

  // Informações principais do produto.
  String nome;
  String marca;
  String categoria;
  String peso;

  // Informações de preço.
  double preco;
  double? precoPromocional;

  // Informações adicionais.
  String imagem;
  bool oferta;
  String descricao;

  // Construtor utilizado para criar um produto.
  Produto({
    this.id,
    required this.nome,
    this.marca = '',
    required this.categoria,
    this.peso = '',
    required this.preco,
    this.precoPromocional,
    this.imagem = '',
    this.oferta = false,
    this.descricao = '',
  });

  // Converte o produto em Map para compatibilidade com o Hive.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'marca': marca,
      'categoria': categoria,
      'peso': peso,
      'preco': preco,
      'precoPromocional': precoPromocional,
      'imagem': imagem,
      'oferta': oferta,
      'descricao': descricao,
    };
  }

  // Recupera um produto armazenado no Hive.
  factory Produto.fromMap(Map<dynamic, dynamic> dados) {
    return Produto(
      id: dados['id'] as int?,
      nome: dados['nome']?.toString() ?? '',
      marca: dados['marca']?.toString() ?? '',
      categoria: dados['categoria']?.toString() ?? '',
      peso: dados['peso']?.toString() ?? '',
      preco: (dados['preco'] as num).toDouble(),
      precoPromocional: dados['precoPromocional'] == null
          ? null
          : (dados['precoPromocional'] as num).toDouble(),
      imagem: dados['imagem']?.toString() ?? '',
      oferta: dados['oferta'] == true,
      descricao: dados['descricao']?.toString() ?? '',
    );
  }

  // Converte os dados recebidos da API JSON em um produto.
  factory Produto.fromJson(Map<String, dynamic> dados) {
    return Produto(
      id: dados['id'] as int?,
      nome: dados['nome']?.toString() ?? '',
      marca: dados['marca']?.toString() ?? '',
      categoria: dados['categoria']?.toString() ?? '',
      peso: dados['peso']?.toString() ?? '',
      preco: (dados['preco'] as num).toDouble(),
      precoPromocional: dados['precoPromocional'] == null
          ? null
          : (dados['precoPromocional'] as num).toDouble(),
      imagem: dados['imagem']?.toString() ?? '',
      oferta: dados['oferta'] == true,
      descricao: dados['descricao']?.toString() ?? '',
    );
  }

  // Converte o produto para JSON quando for enviado à API.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'marca': marca,
      'categoria': categoria,
      'peso': peso,
      'preco': preco,
      'precoPromocional': precoPromocional,
      'imagem': imagem,
      'oferta': oferta,
      'descricao': descricao,
    };
  }
}