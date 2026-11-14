import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../services/produto_service.dart';

// TELA DE CADASTRO E EDIÇÃO DE PRODUTOS DO MARTVERDI.
class ProdutoFormView extends StatefulWidget {
  final Produto? produto;

  const ProdutoFormView({super.key, this.produto});

  @override
  State<ProdutoFormView> createState() => _ProdutoFormViewState();
}

class _ProdutoFormViewState extends State<ProdutoFormView> {
  // Cores utilizadas na identidade visual do MartVerdi.
  static const Color verde = Color(0xFF2D6A4F);
  static const Color texto = Color(0xFF1B2A23);
  static const Color fundo = Color(0xFFF8FAF9);
  static const Color coral = Color(0xFFE76F51);

  // Controladores dos campos do formulário.
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _marcaController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _pesoController = TextEditingController();
  final _precoController = TextEditingController();
  final _precoPromocionalController = TextEditingController();
  final _imagemController = TextEditingController();
  final _descricaoController = TextEditingController();

  // Serviço responsável por enviar os dados para a API.
  final ProdutoService _produtoService = ProdutoService();

  bool _oferta = false;
  bool _salvando = false;

  // Verifica se a tela está editando um produto existente.
  bool get _editando => widget.produto != null;

  @override
  void initState() {
    super.initState();

    // Preenche os campos quando o usuário estiver editando.
    final produto = widget.produto;

    if (produto != null) {
      _nomeController.text = produto.nome;
      _marcaController.text = produto.marca;
      _categoriaController.text = produto.categoria;
      _pesoController.text = produto.peso;
      _precoController.text = produto.preco.toStringAsFixed(2);
      _precoPromocionalController.text =
          produto.precoPromocional?.toStringAsFixed(2) ?? '';
      _imagemController.text = produto.imagem;
      _descricaoController.text = produto.descricao;
      _oferta = produto.oferta;
    }
  }

  // Libera a memória utilizada pelos controladores.
  @override
  void dispose() {
    _nomeController.dispose();
    _marcaController.dispose();
    _categoriaController.dispose();
    _pesoController.dispose();
    _precoController.dispose();
    _precoPromocionalController.dispose();
    _imagemController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  // Converte valores digitados com vírgula ou ponto para número.
  double? _converterPreco(String valor) {
    return double.tryParse(valor.trim().replaceAll(',', '.'));
  }

  // Salva um produto novo ou atualiza um produto existente.
  Future<void> _salvarProduto() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final preco = _converterPreco(_precoController.text);
    final precoPromocional = _precoPromocionalController.text.trim().isEmpty
        ? null
        : _converterPreco(_precoPromocionalController.text);

    if (preco == null ||
        (_precoPromocionalController.text.trim().isNotEmpty &&
            precoPromocional == null)) {
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      // Monta o objeto com os dados preenchidos no formulário.
      final produto = Produto(
        id: widget.produto?.id,
        nome: _nomeController.text.trim(),
        marca: _marcaController.text.trim(),
        categoria: _categoriaController.text.trim(),
        peso: _pesoController.text.trim(),
        preco: preco,
        precoPromocional: precoPromocional,
        imagem: _imagemController.text.trim(),
        oferta: _oferta,
        descricao: _descricaoController.text.trim(),
      );

      // Escolhe entre cadastrar ou atualizar pela API.
      if (_editando) {
        await _produtoService.atualizarProduto(produto);
      } else {
        await _produtoService.cadastrarProduto(produto);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editando
                ? 'Produto atualizado com sucesso!'
                : 'Produto cadastrado com sucesso!',
          ),
          backgroundColor: verde,
        ),
      );

      // Retorna à lista informando que os dados foram alterados.
      Navigator.pop(context, true);
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível salvar: $erro'),
          backgroundColor: coral,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  // Cria campos padronizados para o formulário.
  Widget _campo({
    required String titulo,
    required TextEditingController controller,
    String? dica,
    TextInputType teclado = TextInputType.text,
    bool obrigatorio = false,
    int maxLinhas = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: teclado,
        maxLines: maxLinhas,
        style: const TextStyle(color: texto),
        decoration: InputDecoration(
          labelText: titulo,
          hintText: dica,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: verde, width: 2),
          ),
        ),
        validator: (valor) {
          if (obrigatorio && (valor == null || valor.trim().isEmpty)) {
            return 'Preencha este campo.';
          }

          if (titulo == 'Preço' &&
              (valor == null || _converterPreco(valor) == null)) {
            return 'Digite um preço válido.';
          }

          if (titulo == 'Preço promocional' &&
              valor != null &&
              valor.trim().isNotEmpty &&
              _converterPreco(valor) == null) {
            return 'Digite um preço válido.';
          }

          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fundo,
      appBar: AppBar(
        backgroundColor: verde,
        foregroundColor: Colors.white,
        title: Text(
          _editando ? 'Editar produto' : 'Cadastrar produto',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Informações do produto',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: texto,
              ),
            ),
            const SizedBox(height: 20),

            _campo(
              titulo: 'Nome',
              controller: _nomeController,
              obrigatorio: true,
              dica: 'Nome do produto',
            ),
            _campo(titulo: 'Marca', controller: _marcaController),
            _campo(
              titulo: 'Categoria',
              controller: _categoriaController,
              obrigatorio: true,
            ),
            _campo(
              titulo: 'Peso ou quantidade',
              controller: _pesoController,
              dica: 'Ex.: 1L, 500g, 12 unidades',
            ),

            const SizedBox(height: 8),
            const Text(
              'Preços',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: texto,
              ),
            ),
            const SizedBox(height: 16),

            _campo(
              titulo: 'Preço',
              controller: _precoController,
              obrigatorio: true,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              dica: 'Ex.: 9,99',
            ),
            _campo(
              titulo: 'Preço promocional',
              controller: _precoPromocionalController,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              dica: 'Deixe vazio se não houver promoção',
            ),

            const SizedBox(height: 8),
            const Text(
              'Outras informações',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: texto,
              ),
            ),
            const SizedBox(height: 16),

            _campo(
              titulo: 'Imagem',
              controller: _imagemController,
              dica: 'Ex.: imagens/produto.jpg',
            ),
            _campo(
              titulo: 'Descrição',
              controller: _descricaoController,
              maxLinhas: 3,
            ),

            // Permite identificar produtos que estão em oferta.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Produto em oferta',
                style: TextStyle(color: texto, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Ative se o produto estiver em promoção.'),
              activeTrackColor: verde,
              value: _oferta,
              onChanged: (valor) {
                setState(() {
                  _oferta = valor;
                });
              },
            ),

            const SizedBox(height: 24),

            // Botão principal para enviar os dados à API.
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _salvando ? null : _salvarProduto,
                icon: _salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _salvando
                      ? 'Salvando...'
                      : (_editando ? 'Salvar alterações' : 'Cadastrar produto'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: verde,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
