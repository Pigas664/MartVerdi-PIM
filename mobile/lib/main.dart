import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import 'views/produtos_view.dart';
import 'views/pedidos_view.dart';
import 'services/pedidos_service.dart';

// ==================================================
// MARTVERDI MOBILE - PAINEL ADMINISTRATIVO
// Cores oficiais da identidade visual do projeto.
// ==================================================

const Color verde = Color(0xFF2D6A4F);
const Color fundo = Color(0xFFF8FAF9);
const Color texto = Color(0xFF1B2A23);
const Color coral = Color(0xFFE76F51);
const Color laranja = Color(0xFFF4A261);

// Endereço da API acessível pelo emulador Android.
const String enderecoApi = 'http://10.0.2.2:5273';

// ==================================================
// CONTROLE DA SESSÃO
// Armazena temporariamente o cookie de autenticação.
// ==================================================

class SessaoService {
  // Cookie recebido após o login.
  static String? cookie;

  // Envia as credenciais para a API.
  static Future<String?> entrar(
    String identificador,
    String senha,
  ) async {
    try {
      final resposta = await http.post(
        Uri.parse('$enderecoApi/api/usuarios/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'Identificador': identificador,
          'Senha': senha,
        }),
      );

      // Verifica se o servidor autorizou o login.
      if (resposta.statusCode != 200) {
        return 'Usuário ou senha inválidos.';
      }

      // Recupera o cookie de autenticação enviado pela API.
      final cookieRecebido = resposta.headers['set-cookie'];

      if (cookieRecebido == null || cookieRecebido.isEmpty) {
        return 'Não foi possível iniciar a sessão.';
      }

      // Guarda somente o nome e o valor do cookie.
      cookie = cookieRecebido.split(';').first;

      // Consulta os dados do usuário autenticado.
      final verificacao = await http.get(
        Uri.parse('$enderecoApi/api/usuarios/me'),
        headers: {
          'Cookie': cookie!,
        },
      );

      if (verificacao.statusCode != 200) {
        cookie = null;
        return 'Não foi possível validar sua sessão.';
      }

      // Lê o perfil retornado pela API.
      final dados = jsonDecode(verificacao.body);
      final perfil = dados['perfil'] ?? dados['Perfil'];

      // Impede que clientes acessem o painel administrativo.
      if (perfil != 'Administrador') {
        cookie = null;
        return 'Acesso permitido somente para administradores.';
      }

      return null;
    } catch (erro) {
      return 'Erro ao conectar com o servidor. Verifique se a API está ligada.';
    }
  }

  // Encerra a sessão no servidor.
  static Future<void> sair() async {
    try {
      if (cookie != null) {
        await http.post(
          Uri.parse('$enderecoApi/api/usuarios/logout'),
          headers: {
            'Cookie': cookie!,
          },
        );
      }
    } catch (_) {
      // Mesmo se a API estiver indisponível, encerra a sessão local.
    }

    cookie = null;
  }
}

// ==================================================
// INICIALIZAÇÃO DO APLICATIVO
// ==================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Hive utilizado pela tela de produtos.
  await Hive.initFlutter();
  await Hive.openBox('produtos');

  runApp(const MartVerdiApp());
}

// Configuração principal do aplicativo.
class MartVerdiApp extends StatelessWidget {
  const MartVerdiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MartVerdi Admin',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: fundo,
        colorScheme: ColorScheme.fromSeed(seedColor: verde),
        appBarTheme: const AppBarTheme(
          backgroundColor: fundo,
          foregroundColor: texto,
          elevation: 0,
        ),
      ),
      // O aplicativo começa pela tela de autenticação.
      home: const TelaLogin(),
    );
  }
}

// ==================================================
// TELA DE LOGIN
// Permite a entrada somente de administradores.
// ==================================================

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  // Controladores dos campos de acesso.
  final TextEditingController identificadorController =
      TextEditingController();

  final TextEditingController senhaController =
      TextEditingController();

  // Controla a exibição da senha.
  bool mostrarSenha = false;

  // Indica se o login está sendo processado.
  bool carregando = false;

  // Realiza a autenticação na API.
  Future<void> realizarLogin() async {
    final identificador = identificadorController.text.trim();
    final senha = senhaController.text;

    if (identificador.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha o usuário e a senha.'),
          backgroundColor: coral,
        ),
      );
      return;
    }

    setState(() {
      carregando = true;
    });

    final erro = await SessaoService.entrar(
      identificador,
      senha,
    );

    if (!mounted) return;

    setState(() {
      carregando = false;
    });

    // Exibe o erro caso a autenticação não seja concluída.
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erro),
          backgroundColor: coral,
        ),
      );
      return;
    }

    // Abre o painel após validar o perfil administrativo.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const TelaInicial(),
      ),
    );
  }

  @override
  void dispose() {
    identificadorController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Identidade visual do MartVerdi.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: verde,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.storefront,
                  color: Colors.white,
                  size: 55,
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'MartVerdi Admin',
                style: TextStyle(
                  color: texto,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Acesse o painel administrativo do supermercado.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 35),

              // Campo de identificação do usuário.
              TextField(
                controller: identificadorController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Usuário ou e-mail',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Campo de senha com opção de visualização.
              TextField(
                controller: senhaController,
                obscureText: !mostrarSenha,
                onSubmitted: (_) => realizarLogin(),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        mostrarSenha = !mostrarSenha;
                      });
                    },
                    icon: Icon(
                      mostrarSenha
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // Botão de autenticação.
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: carregando ? null : realizarLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verde,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: carregando
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text(
                          'Entrar no painel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'Acesso restrito aos administradores.',
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================
// DASHBOARD ADMINISTRATIVO
// Exibe os indicadores reais de vendas e pedidos.
// ==================================================

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  // Serviço responsável pela consulta dos dados de vendas.
  final PedidosService pedidosService = PedidosService();

  // Valores iniciais dos indicadores.
  String faturamento = 'Carregando...';
  String quantidadePedidos = 'Carregando...';

  // Controla o carregamento do resumo.
  bool carregandoResumo = true;

  // Guarda possíveis erros da consulta.
  String? erroResumo;

  @override
  void initState() {
    super.initState();

    // Busca os dados assim que o painel é aberto.
    carregarResumoVendas();
  }

  // Consulta o resumo de vendas na API.
  Future<void> carregarResumoVendas() async {
    final cookie = SessaoService.cookie;

    if (cookie == null || cookie.isEmpty) {
      setState(() {
        carregandoResumo = false;
        erroResumo = 'Sessão não encontrada';
      });
      return;
    }

    try {
      final resumo = await pedidosService.buscarResumoVendas(
        cookie: cookie,
      );

      // Aceita os nomes das propriedades em camelCase ou PascalCase.
      final quantidade = resumo['quantidadePedidosConcluidos'] ??
          resumo['QuantidadePedidosConcluidos'] ??
          0;

      final valor = resumo['faturamento'] ??
          resumo['Faturamento'] ??
          0;

      // Converte os valores recebidos da API.
      final numeroPedidos = quantidade is num
          ? quantidade.toInt()
          : int.tryParse(quantidade.toString()) ?? 0;

      final valorFaturamento = valor is num
          ? valor.toDouble()
          : double.tryParse(valor.toString()) ?? 0.0;

      if (!mounted) return;

      setState(() {
        // Formata o faturamento em reais.
        faturamento = 'R\$ ${valorFaturamento.toStringAsFixed(2).replaceAll('.', ',')}';

        // Exibe a quantidade de pedidos concluídos.
        quantidadePedidos = numeroPedidos.toString();

        carregandoResumo = false;
        erroResumo = null;
      });
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        faturamento = 'Indisponível';
        quantidadePedidos = 'Indisponível';
        carregandoResumo = false;
        erroResumo = 'Não foi possível carregar as vendas.';
      });
    }
  }

  // Abre a tela de gerenciamento de produtos.
  void abrirProdutos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProdutosView(),
      ),
    );
  }

  // Abre a tela de gerenciamento de pedidos.
  void abrirPedidos(BuildContext context) {
    // Recupera o cookie da sessão administrativa.
    final cookie = SessaoService.cookie;

    // Verifica se existe uma sessão ativa.
    if (cookie == null || cookie.isEmpty) {
      mostrarAviso(context, 'Sessão administrativa não encontrada');
      return;
    }

    // Abre a tela de pedidos enviando o cookie de autenticação.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PedidosView(cookie: cookie),
      ),
    );
  }

  // Exibe aviso para funcionalidades ainda não integradas.
  void mostrarAviso(BuildContext context, String funcionalidade) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$funcionalidade estará disponível em breve.'),
        backgroundColor: verde,
      ),
    );
  }

  // Cria os cartões com indicadores administrativos.
  Widget indicador({
    required IconData icone,
    required String titulo,
    required String valor,
    required String descricao,
    required Color cor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: cor.withValues(alpha: 0.12),
            child: Icon(icone, color: cor),
          ),
          const SizedBox(height: 14),
          Text(
            titulo,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: texto,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            descricao,
            style: const TextStyle(
              color: Colors.black45,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // Cria as opções do menu administrativo.
  Widget opcaoMenu({
    required BuildContext context,
    required IconData icone,
    required String titulo,
    required String descricao,
    required Color cor,
    required VoidCallback acao,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Colors.black12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: cor.withValues(alpha: 0.12),
          child: Icon(icone, color: cor),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(descricao),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
        ),
        onTap: acao,
      ),
    );
  }

  // Encerra a sessão e retorna à tela de login.
  Future<void> realizarLogout(BuildContext context) async {
    await SessaoService.sair();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const TelaLogin(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(
              Icons.storefront,
              color: verde,
              size: 29,
            ),
            SizedBox(width: 9),
            Text(
              'MartVerdi Admin',
              style: TextStyle(
                color: texto,
                fontWeight: FontWeight.bold,
                fontSize: 21,
              ),
            ),
          ],
        ),
        actions: [
          // Atualiza os indicadores de vendas.
          IconButton(
            tooltip: 'Atualizar indicadores',
            onPressed: carregandoResumo ? null : carregarResumoVendas,
            icon: const Icon(Icons.refresh),
          ),

          // Botão para encerrar a sessão administrativa.
          IconButton(
            tooltip: 'Sair',
            onPressed: () => realizarLogout(context),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Apresentação do painel.
            const Text(
              'Painel de controle',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: texto,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'Acompanhe e gerencie a operação do MartVerdi.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 24),

            // Cartão principal do painel.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(21),
              decoration: BoxDecoration(
                color: verde,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.dashboard_customize_outlined,
                    color: Colors.white,
                    size: 35,
                  ),
                  SizedBox(height: 13),
                  Text(
                    'Gestão do supermercado',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Administre produtos, acompanhe pedidos e consulte os resultados da loja em um só lugar.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Título da área de indicadores.
            const Text(
              'Visão geral',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: texto,
              ),
            ),

            const SizedBox(height: 12),

            // Indicadores conectados aos dados reais da API.
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.18,
              children: [
                indicador(
                  icone: Icons.attach_money,
                  titulo: 'Vendas',
                  valor: faturamento,
                  descricao: 'Faturamento concluído',
                  cor: verde,
                ),
                indicador(
                  icone: Icons.shopping_bag_outlined,
                  titulo: 'Pedidos',
                  valor: quantidadePedidos,
                  descricao: 'Pedidos concluídos',
                  cor: coral,
                ),
                indicador(
                  icone: Icons.inventory_2_outlined,
                  titulo: 'Produtos',
                  valor: 'A integrar',
                  descricao: 'Catálogo do mercado',
                  cor: laranja,
                ),
                indicador(
                  icone: Icons.people_outline,
                  titulo: 'Clientes',
                  valor: 'A integrar',
                  descricao: 'Clientes cadastrados',
                  cor: Colors.blueGrey,
                ),
              ],
            ),

            // Informa se ocorreu algum problema na consulta.
            if (erroResumo != null) ...[
              const SizedBox(height: 10),
              Text(
                erroResumo!,
                style: const TextStyle(
                  color: coral,
                  fontSize: 12,
                ),
              ),
              TextButton.icon(
                onPressed: carregandoResumo
                    ? null
                    : carregarResumoVendas,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],

            const SizedBox(height: 25),

            // Menu de funcionalidades administrativas.
            const Text(
              'Administração',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: texto,
              ),
            ),

            const SizedBox(height: 12),

            opcaoMenu(
              context: context,
              icone: Icons.inventory_2_outlined,
              titulo: 'Gerenciar produtos',
              descricao: 'Consultar e administrar o catálogo',
              cor: verde,
              acao: () => abrirProdutos(context),
            ),

            opcaoMenu(
              context: context,
              icone: Icons.shopping_bag_outlined,
              titulo: 'Gerenciar pedidos',
              descricao: 'Visualizar compras e atualizar status',
              cor: coral,
              acao: () => abrirPedidos(context),
            ),

            opcaoMenu(
              context: context,
              icone: Icons.bar_chart_outlined,
              titulo: 'Relatórios de vendas',
              descricao: 'Consultar faturamento e desempenho',
              cor: laranja,
              acao: () => mostrarAviso(context, 'Relatórios'),
            ),

            opcaoMenu(
              context: context,
              icone: Icons.people_outline,
              titulo: 'Clientes',
              descricao: 'Consultar clientes cadastrados',
              cor: Colors.blueGrey,
              acao: () => mostrarAviso(context, 'Clientes'),
            ),

            const SizedBox(height: 22),

            // Identificação do aplicativo.
            const Center(
              child: Text(
                'MartVerdi • Sistema Administrativo Mobile',
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}