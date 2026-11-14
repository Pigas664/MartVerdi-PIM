import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../services/produto_service.dart';
import 'produto_form_view.dart';

// Tela responsável por exibir e administrar os produtos do MartVerdi.
class ProdutosView extends StatefulWidget {
  const ProdutosView({super.key});

  @override
  State<ProdutosView> createState() => _ProdutosViewState();
}

class _ProdutosViewState extends State<ProdutosView> {
  // Cores da identidade visual do MartVerdi.
  static const Color verde = Color(0xFF2D6A4F);
  static const Color texto = Color(0xFF1B2A23);
  static const Color coral = Color(0xFFE76F51);

  final ProdutoService _produtoService = ProdutoService();

  late Future<List<Produto>> _produtosFuture;

  // Endereço público onde estão armazenadas as imagens do site.
  static const String _baseUrlImagens = 'https://pigas664.github.io/martverdi/';

  @override
  void initState() {
    super.initState();
    _produtosFuture = _produtoService.buscarProdutos();
  }

  // Converte o caminho relativo do banco em uma URL completa.
  String? _obterUrlImagem(String caminho) {
    if (caminho.trim().isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(caminho);

    if (uri != null && uri.hasScheme) {
      return caminho;
    }

    final caminhoLimpo = caminho.replaceFirst(RegExp(r'^(\./)+'), '');

    return Uri.parse(_baseUrlImagens).resolve(caminhoLimpo).toString();
  }

  // Atualiza a consulta de produtos na API.
  void _carregarProdutos() {
    setState(() {
      _produtosFuture = _produtoService.buscarProdutos();
    });
  }

  // Abre o formulário para cadastrar ou editar um produto.
  Future<void> _abrirFormulario({Produto? produto}) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ProdutoFormView(produto: produto),
      ),
    );

    // Atualiza a lista somente quando o formulário salvar os dados.
    if (resultado == true && mounted) {
      _carregarProdutos();
    }
  }

  // Solicita confirmação antes de excluir um produto.
  Future<void> _confirmarExclusao(Produto produto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir produto'),
          content: Text(
            'Tem certeza que deseja excluir "${produto.nome}"? '
            'Essa ação não poderá ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: coral,
                foregroundColor: Colors.white,
              ),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    if (produto.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível identificar o produto.'),
        ),
      );
      return;
    }

    try {
      await _produtoService.excluirProduto(produto.id!);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produto excluído com sucesso!'),
          backgroundColor: verde,
        ),
      );

      _carregarProdutos();
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir produto: $erro'),
          backgroundColor: coral,
        ),
      );
    }
  }

  // Formata os valores para o padrão monetário brasileiro.
  String _formatarPreco(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // Monta a imagem do produto com tratamento de erro.
  Widget _imagemProduto(String caminho) {
    final url = _obterUrlImagem(caminho);

    return Container(
      width: 75,
      height: 75,
      decoration: BoxDecoration(
        color: const Color(0xFFE3F0E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: url == null
            ? const Icon(
                Icons.image_not_supported_outlined,
                color: verde,
                size: 32,
              )
            : Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.broken_image_outlined,
                    color: verde,
                    size: 32,
                  );
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;

                  return const Center(
                    child: CircularProgressIndicator(
                      color: verde,
                      strokeWidth: 2,
                    ),
                  );
                },
              ),
      ),
    );
  }

  // Monta os botões de edição e exclusão.
  Widget _acoesProduto(Produto produto) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _abrirFormulario(produto: produto),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: verde,
              side: const BorderSide(color: verde),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _confirmarExclusao(produto),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Excluir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: coral,
              side: const BorderSide(color: coral),
            ),
          ),
        ),
      ],
    );
  }

  // Monta o cartão individual de cada produto.
  Widget _cartaoProduto(Produto produto) {
    final bool temPromocao =
        produto.precoPromocional != null &&
        produto.precoPromocional! > 0 &&
        produto.precoPromocional! < produto.preco;

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exibe a foto do produto armazenada no site.
                _imagemProduto(produto.imagem),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produto.nome,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: texto,
                        ),
                      ),

                      if (produto.marca.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            produto.marca,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      const SizedBox(height: 4),

                      Text(
                        produto.categoria,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),

                      if (produto.peso.isNotEmpty)
                        Text(
                          produto.peso,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Exibe preço promocional quando disponível.
                      if (temPromocao) ...[
                        Text(
                          _formatarPreco(produto.preco),
                          style: const TextStyle(
                            color: Colors.black45,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatarPreco(produto.precoPromocional!),
                          style: const TextStyle(
                            color: coral,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ] else
                        Text(
                          _formatarPreco(produto.preco),
                          style: const TextStyle(
                            color: verde,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                      // Identifica os produtos que estão em oferta.
                      if (produto.oferta)
                        Container(
                          margin: const EdgeInsets.only(top: 7),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEAD8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'EM OFERTA',
                            style: TextStyle(
                              color: Color(0xFFB85C16),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Ações administrativas de cada produto.
            _acoesProduto(produto),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Produtos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _carregarProdutos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar produtos',
          ),
        ],
      ),

      // Botão flutuante para cadastrar novos produtos.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: verde,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo produto'),
      ),

      body: FutureBuilder<List<Produto>>(
        future: _produtosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: verde),
                  SizedBox(height: 15),
                  Text('Carregando produtos do MartVerdi...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: Colors.redAccent,
                      size: 60,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Não foi possível carregar os produtos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _carregarProdutos,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verde,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final produtos = snapshot.data ?? [];

          if (produtos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 65,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Nenhum produto encontrado.',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Use o botão abaixo para cadastrar.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Text(
                  '${produtos.length} produtos encontrados no catálogo',
                  style: const TextStyle(
                    color: texto,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  color: verde,
                  onRefresh: () async {
                    final novaConsulta = _produtoService.buscarProdutos();

                    setState(() {
                      _produtosFuture = novaConsulta;
                    });

                    await novaConsulta;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    itemCount: produtos.length,
                    itemBuilder: (context, index) {
                      return _cartaoProduto(produtos[index]);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}