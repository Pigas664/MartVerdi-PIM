import 'package:flutter/material.dart';

import '../services/pedidos_service.dart';

// ==================================================
// MARTVERDI - TELA DE GERENCIAMENTO DE PEDIDOS
// Consulta pedidos e permite atualizar seus status.
// ==================================================

const Color verdePedidos = Color(0xFF2D6A4F);
const Color fundoPedidos = Color(0xFFF8FAF9);
const Color textoPedidos = Color(0xFF1B2A23);
const Color coralPedidos = Color(0xFFE76F51);

class PedidosView extends StatefulWidget {
  // Recebe o cookie da sessão administrativa.
  final String cookie;

  const PedidosView({
    super.key,
    required this.cookie,
  });

  @override
  State<PedidosView> createState() => _PedidosViewState();
}

class _PedidosViewState extends State<PedidosView> {
  // Serviço responsável pela comunicação com a API.
  final PedidosService _service = PedidosService();

  // Lista de pedidos recebidos do banco de dados.
  List<Map<String, dynamic>> pedidos = [];

  bool carregando = true;
  String? erro;

  // Status disponíveis para os pedidos.
  final List<String> statusDisponiveis = [
    'Pendente',
    'Em preparação',
    'Enviado',
    'Concluído',
    'Cancelado',
  ];

  @override
  void initState() {
    super.initState();
    carregarPedidos();
  }

  // Consulta os pedidos na API.
  Future<void> carregarPedidos() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final resultado = await _service.buscarPedidos(
        cookie: widget.cookie,
      );

      if (!mounted) return;

      setState(() {
        pedidos = resultado;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        erro = e.toString();
        carregando = false;
      });
    }
  }

  // Recupera campos mesmo quando a API utiliza PascalCase.
  dynamic obterCampo(
    Map<String, dynamic> dados,
    String nome,
  ) {
    return dados[nome] ??
        dados['${nome[0].toUpperCase()}${nome.substring(1)}'];
  }

  // Formata os valores monetários.
  String formatarPreco(dynamic valor) {
    final numero = valor is num
        ? valor.toDouble()
        : double.tryParse(valor?.toString() ?? '') ?? 0;

    return 'R\$ ${numero.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // Define uma cor para cada status.
  Color corStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pendente':
        return Colors.orange;
      case 'em preparação':
        return Colors.blue;
      case 'enviado':
        return Colors.purple;
      case 'concluído':
        return verdePedidos;
      case 'cancelado':
        return coralPedidos;
      default:
        return Colors.grey;
    }
  }

  // Busca os detalhes completos de um pedido.
  Future<void> abrirDetalhes(int id) async {
    try {
      final pedido = await _service.buscarPedidoPorId(
        id: id,
        cookie: widget.cookie,
      );

      if (!mounted) return;

      mostrarDetalhes(pedido);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar detalhes: $e'),
          backgroundColor: coralPedidos,
        ),
      );
    }
  }

  // Exibe os produtos e informações do pedido.
  void mostrarDetalhes(Map<String, dynamic> pedido) {
    final itens = obterCampo(pedido, 'itens') as List? ?? [];

    final id = obterCampo(pedido, 'id') ?? '-';
    final cliente = obterCampo(pedido, 'nomeUsuario') ?? 'Cliente';
    final valor = obterCampo(pedido, 'valorTotal');
    final status = obterCampo(pedido, 'status') ?? 'Pendente';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Pedido #$id'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Cliente: $cliente'),
                const SizedBox(height: 8),
                Text('Status: $status'),
                const SizedBox(height: 8),
                Text('Valor total: ${formatarPreco(valor)}'),
                const Divider(height: 25),
                const Text(
                  'Produtos do pedido',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),

                if (itens.isEmpty)
                  const Text('Nenhum produto encontrado.'),

                ...itens.map((item) {
                  final dados = Map<String, dynamic>.from(item);

                  final nome =
                      obterCampo(dados, 'nomeProduto') ?? 'Produto';

                  final quantidade =
                      obterCampo(dados, 'quantidade') ?? 0;

                  final preco =
                      obterCampo(dados, 'precoUnitario');

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shopping_basket_outlined,
                          color: verdePedidos,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$nome\nQuantidade: $quantidade',
                          ),
                        ),
                        Text(formatarPreco(preco)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Fechar',
                style: TextStyle(color: verdePedidos),
              ),
            ),
          ],
        );
      },
    );
  }

  // Abre a seleção e atualiza o status pela API.
  Future<void> alterarStatus(
    int id,
    String statusAtual,
  ) async {
    String statusSelecionado =
        statusDisponiveis.contains(statusAtual)
            ? statusAtual
            : 'Pendente';

    final novoStatus = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, atualizarDialogo) {
            return AlertDialog(
              title: Text('Atualizar pedido #$id'),
              content: DropdownButtonFormField<String>(
                initialValue: statusSelecionado,
                decoration: const InputDecoration(
                  labelText: 'Novo status',
                  border: OutlineInputBorder(),
                ),
                items: statusDisponiveis.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (valor) {
                  if (valor != null) {
                    atualizarDialogo(() {
                      statusSelecionado = valor;
                    });
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verdePedidos,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context, statusSelecionado);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (novoStatus == null || novoStatus == statusAtual) return;

    try {
      await _service.atualizarStatus(
        id: id,
        status: novoStatus,
        cookie: widget.cookie,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status atualizado com sucesso!'),
          backgroundColor: verdePedidos,
        ),
      );

      await carregarPedidos();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar status: $e'),
          backgroundColor: coralPedidos,
        ),
      );
    }
  }

  // Monta o cartão visual de cada pedido.
  Widget construirPedido(Map<String, dynamic> pedido) {
    final id = obterCampo(pedido, 'id');
    final cliente = obterCampo(pedido, 'nomeUsuario') ?? 'Cliente';
    final valor = obterCampo(pedido, 'valorTotal');
    final status = obterCampo(pedido, 'status') ?? 'Pendente';

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: fundoPedidos,
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color: verdePedidos,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido #${id ?? '-'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textoPedidos,
                        ),
                      ),
                      Text(
                        cliente.toString(),
                        style: const TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: corStatus(status.toString()).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toString(),
                    style: TextStyle(
                      color: corStatus(status.toString()),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Valor do pedido',
                  style: TextStyle(color: Colors.black54),
                ),
                Text(
                  formatarPreco(valor),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: verdePedidos,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: id == null
                        ? null
                        : () => abrirDetalhes(id as int),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Detalhes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: verdePedidos,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: id == null
                        ? null
                        : () => alterarStatus(
                              id as int,
                              status.toString(),
                            ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: verdePedidos,
                      foregroundColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fundoPedidos,
      appBar: AppBar(
        title: const Text(
          'Gerenciar pedidos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Atualiza a lista de pedidos.
          IconButton(
            tooltip: 'Atualizar',
            onPressed: carregarPedidos,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: carregando
          ? const Center(
              child: CircularProgressIndicator(
                color: verdePedidos,
              ),
            )
          : erro != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: coralPedidos,
                          size: 45,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Não foi possível carregar os pedidos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          erro!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton(
                          onPressed: carregarPedidos,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : pedidos.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 55,
                            color: Colors.black38,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Nenhum pedido encontrado.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: carregarPedidos,
                      color: verdePedidos,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            '${pedidos.length} pedido(s) encontrado(s)',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textoPedidos,
                            ),
                          ),
                          const SizedBox(height: 15),
                          ...pedidos.map(construirPedido),
                        ],
                      ),
                    ),
    );
  }
}