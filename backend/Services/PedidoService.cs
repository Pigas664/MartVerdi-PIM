using Microsoft.Data.SqlClient;
using MartVerdi.Models;

namespace MartVerdi.Services
{
    public class PedidoService
    {
        private readonly SqlConnectionFactory _connectionFactory;

        // Recebe a conexão com o banco já configurada no projeto.
        public PedidoService(SqlConnectionFactory connectionFactory)
        {
            _connectionFactory = connectionFactory;
        }

        // Salva o pedido e seus produtos dentro de uma única transação.
        public async Task<int> CriarPedidoAsync(int usuarioId, List<ItemPedido> itens)
        {
            if (itens == null || itens.Count == 0)
                throw new Exception("O pedido precisa ter pelo menos um produto.");

            if (itens.Any(item => item.Quantidade <= 0))
                throw new Exception("A quantidade dos produtos deve ser maior que zero.");

            using var conexao = _connectionFactory.CriarConexao();
            await conexao.OpenAsync();

            using var transacao = conexao.BeginTransaction();

            try
            {
                decimal valorTotal = 0;

                // Busca o preço verdadeiro de cada produto no banco.
                foreach (var item in itens)
                {
                    string sqlPreco = @"
                        SELECT
                            CASE
                                WHEN Oferta = 1 AND PrecoPromocional IS NOT NULL
                                THEN PrecoPromocional
                                ELSE Preco
                            END
                        FROM Produtos
                        WHERE Id = @ProdutoId";

                    using var comandoPreco = new SqlCommand(
                        sqlPreco, conexao, transacao);

                    comandoPreco.Parameters.AddWithValue("@ProdutoId", item.ProdutoId);

                    var resultado = await comandoPreco.ExecuteScalarAsync();

                    if (resultado == null || resultado == DBNull.Value)
                        throw new Exception("Um dos produtos não foi encontrado.");

                    item.PrecoUnitario = Convert.ToDecimal(resultado);
                    valorTotal += item.PrecoUnitario * item.Quantidade;
                }

                // Cria o pedido e recupera seu ID.
                string sqlPedido = @"
                    INSERT INTO Pedidos (UsuarioId, ValorTotal, Status)
                    OUTPUT INSERTED.Id
                    VALUES (@UsuarioId, @ValorTotal, @Status)";

                using var comandoPedido = new SqlCommand(
                    sqlPedido, conexao, transacao);

                comandoPedido.Parameters.AddWithValue("@UsuarioId", usuarioId);
                comandoPedido.Parameters.AddWithValue("@ValorTotal", valorTotal);
                comandoPedido.Parameters.AddWithValue("@Status", "Pendente");

                int pedidoId = Convert.ToInt32(
                    await comandoPedido.ExecuteScalarAsync());

                // Salva os produtos relacionados ao pedido.
                foreach (var item in itens)
                {
                    string sqlItem = @"
                        INSERT INTO ItensPedido
                        (PedidoId, ProdutoId, Quantidade, PrecoUnitario)
                        VALUES
                        (@PedidoId, @ProdutoId, @Quantidade, @PrecoUnitario)";

                    using var comandoItem = new SqlCommand(
                        sqlItem, conexao, transacao);

                    comandoItem.Parameters.AddWithValue("@PedidoId", pedidoId);
                    comandoItem.Parameters.AddWithValue("@ProdutoId", item.ProdutoId);
                    comandoItem.Parameters.AddWithValue("@Quantidade", item.Quantidade);
                    comandoItem.Parameters.AddWithValue("@PrecoUnitario", item.PrecoUnitario);

                    await comandoItem.ExecuteNonQueryAsync();
                }

                transacao.Commit();

                return pedidoId;
            }
            catch
            {
                // Desfaz as alterações caso alguma operação apresente erro.
                transacao.Rollback();
                throw;
            }
        }

        // Lista todos os pedidos cadastrados, incluindo o nome do cliente.
        public async Task<List<Pedido>> ObterTodosAsync()
        {
            var pedidos = new List<Pedido>();

            using var conexao = _connectionFactory.CriarConexao();
            await conexao.OpenAsync();

            const string sql = @"
                SELECT
                    p.Id,
                    p.UsuarioId,
                    u.Nome,
                    p.DataPedido,
                    p.ValorTotal,
                    p.Status
                FROM Pedidos p
                INNER JOIN Usuarios u ON u.Id = p.UsuarioId
                ORDER BY p.DataPedido DESC";

            using var comando = new SqlCommand(sql, conexao);
            using var leitor = await comando.ExecuteReaderAsync();

            while (await leitor.ReadAsync())
            {
                pedidos.Add(new Pedido
                {
                    Id = leitor.GetInt32(0),
                    UsuarioId = leitor.GetInt32(1),
                    NomeUsuario = leitor.GetString(2),
                    DataPedido = leitor.GetDateTime(3),
                    ValorTotal = leitor.GetDecimal(4),
                    Status = leitor.GetString(5)
                });
            }

            return pedidos;
        }

        // Busca um pedido específico e todos os seus produtos.
        public async Task<Pedido?> ObterPorIdAsync(int id)
        {
            using var conexao = _connectionFactory.CriarConexao();
            await conexao.OpenAsync();

            const string sqlPedido = @"
                SELECT
                    p.Id,
                    p.UsuarioId,
                    u.Nome,
                    p.DataPedido,
                    p.ValorTotal,
                    p.Status
                FROM Pedidos p
                INNER JOIN Usuarios u ON u.Id = p.UsuarioId
                WHERE p.Id = @Id";

            using var comandoPedido = new SqlCommand(sqlPedido, conexao);
            comandoPedido.Parameters.AddWithValue("@Id", id);

            Pedido pedido;

            using (var leitor = await comandoPedido.ExecuteReaderAsync())
            {
                if (!await leitor.ReadAsync())
                    return null;

                pedido = new Pedido
                {
                    Id = leitor.GetInt32(0),
                    UsuarioId = leitor.GetInt32(1),
                    NomeUsuario = leitor.GetString(2),
                    DataPedido = leitor.GetDateTime(3),
                    ValorTotal = leitor.GetDecimal(4),
                    Status = leitor.GetString(5)
                };
            }

            // Busca os produtos que pertencem ao pedido.
            const string sqlItens = @"
                SELECT
                    ip.Id,
                    ip.PedidoId,
                    ip.ProdutoId,
                    p.Nome,
                    ip.Quantidade,
                    ip.PrecoUnitario
                FROM ItensPedido ip
                INNER JOIN Produtos p ON p.Id = ip.ProdutoId
                WHERE ip.PedidoId = @PedidoId";

            using var comandoItens = new SqlCommand(sqlItens, conexao);
            comandoItens.Parameters.AddWithValue("@PedidoId", id);

            using var leitorItens = await comandoItens.ExecuteReaderAsync();

            while (await leitorItens.ReadAsync())
            {
                pedido.Itens.Add(new ItemPedido
                {
                    Id = leitorItens.GetInt32(0),
                    PedidoId = leitorItens.GetInt32(1),
                    ProdutoId = leitorItens.GetInt32(2),
                    NomeProduto = leitorItens.GetString(3),
                    Quantidade = leitorItens.GetInt32(4),
                    PrecoUnitario = leitorItens.GetDecimal(5)
                });
            }

            return pedido;
        }

        // Atualiza o status de um pedido pela administração.
        public async Task<bool> AtualizarStatusAsync(int id, string status)
        {
            // Aceita somente os status definidos pelo sistema.
            string[] statusPermitidos =
            {
                "Pendente",
                "Em preparação",
                "Enviado",
                "Concluído",
                "Cancelado"
            };

            if (!statusPermitidos.Contains(status))
                throw new Exception("Status de pedido inválido.");

            using var conexao = _connectionFactory.CriarConexao();
            await conexao.OpenAsync();

            const string sql = @"
                UPDATE Pedidos
                SET Status = @Status
                WHERE Id = @Id";

            using var comando = new SqlCommand(sql, conexao);

            comando.Parameters.AddWithValue("@Id", id);
            comando.Parameters.AddWithValue("@Status", status);

            int linhasAfetadas = await comando.ExecuteNonQueryAsync();

            return linhasAfetadas > 0;
        }

        // Calcula a quantidade de pedidos concluídos e o faturamento.
        public async Task<(int QuantidadePedidos, decimal Faturamento)> ObterResumoVendasAsync()
        {
            using var conexao = _connectionFactory.CriarConexao();
            await conexao.OpenAsync();

            const string sql = @"
                SELECT
                    COUNT(1),
                    COALESCE(SUM(ValorTotal), 0)
                FROM Pedidos
                WHERE Status = 'Concluído'";

            using var comando = new SqlCommand(sql, conexao);
            using var leitor = await comando.ExecuteReaderAsync();

            if (await leitor.ReadAsync())
            {
                return (
                    leitor.GetInt32(0),
                    leitor.GetDecimal(1)
                );
            }

            return (0, 0);
        }
    }
}