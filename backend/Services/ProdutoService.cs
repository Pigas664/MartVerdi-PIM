using Microsoft.Data.SqlClient;
using Microsoft.Data;
using System.Data;
using MartVerdi.Models;

namespace MartVerdi.Services
{
    // Responsável por consultar e gerenciar os produtos no SQL Server.
    public class ProdutoService
    {
        // Guarda a fábrica responsável por criar conexões com o banco.
        private readonly SqlConnectionFactory _conexaoFactory;

        // Recebe a fábrica de conexões através da injeção de dependência.
        public ProdutoService(SqlConnectionFactory conexaoFactory)
        {
            _conexaoFactory = conexaoFactory;
        }

        // Converte uma linha do banco em um objeto Produto.
        private static Produto MapearProduto(SqlDataReader leitor)
        {
            return new Produto
            {
                Id = leitor.GetInt32(leitor.GetOrdinal("Id")),
                Nome = leitor.GetString(leitor.GetOrdinal("Nome")),
                Marca = leitor["Marca"] as string ?? string.Empty,
                Categoria = leitor["Categoria"] as string ?? string.Empty,
                Peso = leitor["Peso"] as string ?? string.Empty,
                Preco = leitor.GetDecimal(leitor.GetOrdinal("Preco")),

                PrecoPromocional =
                    leitor["PrecoPromocional"] == DBNull.Value
                        ? null
                        : Convert.ToDecimal(leitor["PrecoPromocional"]),

                Imagem = leitor["Imagem"] as string ?? string.Empty,
                Oferta = leitor.GetBoolean(leitor.GetOrdinal("Oferta")),
                Descricao = leitor["Descricao"] as string ?? string.Empty
            };
        }

        // Busca todos os produtos cadastrados.
        public async Task<List<Produto>> ObterTodosAsync()
        {
            var produtos = new List<Produto>();

            using var conexao = _conexaoFactory.CriarConexao();
            await conexao.OpenAsync();

            const string sql = @"
                SELECT Id, Nome, Marca, Categoria, Peso, Preco,
                       PrecoPromocional, Imagem, Oferta, Descricao
                FROM dbo.Produtos
                ORDER BY Id;";

            using var comando = new SqlCommand(sql, conexao);
            using var leitor = await comando.ExecuteReaderAsync();

            while (await leitor.ReadAsync())
            {
                produtos.Add(MapearProduto(leitor));
            }

            return produtos;
        }

        // Busca um produto específico pelo seu ID.
        public async Task<Produto?> ObterPorIdAsync(int id)
        {
            using var conexao = _conexaoFactory.CriarConexao();
            await conexao.OpenAsync();

            const string sql = @"
                SELECT Id, Nome, Marca, Categoria, Peso, Preco,
                       PrecoPromocional, Imagem, Oferta, Descricao
                FROM dbo.Produtos
                WHERE Id = @Id;";

            using var comando = new SqlCommand(sql, conexao);
            comando.Parameters.Add("@Id", SqlDbType.Int).Value = id;

            using var leitor = await comando.ExecuteReaderAsync();

            if (await leitor.ReadAsync())
            {
                return MapearProduto(leitor);
            }

            return null;
        }

        // Cadastra um produto e gera o próximo ID disponível.
        public async Task<int> AdicionarAsync(Produto produto)
        {
            using var conexao = _conexaoFactory.CriarConexao();
            await conexao.OpenAsync();

            // Impede que dois cadastros recebam o mesmo ID simultaneamente.
            using var transacao = conexao.BeginTransaction(IsolationLevel.Serializable);

            try
            {
                const string sqlId = @"
                    SELECT ISNULL(MAX(Id), 0) + 1
                    FROM dbo.Produtos WITH (UPDLOCK, HOLDLOCK);";

                using var comandoId = new SqlCommand(sqlId, conexao, transacao);

                int novoId = Convert.ToInt32(await comandoId.ExecuteScalarAsync());

                const string sql = @"
                    INSERT INTO dbo.Produtos
                    (Id, Nome, Marca, Categoria, Peso, Preco,
                     PrecoPromocional, Imagem, Oferta, Descricao)
                    VALUES
                    (@Id, @Nome, @Marca, @Categoria, @Peso, @Preco,
                     @PrecoPromocional, @Imagem, @Oferta, @Descricao);";

                using var comando = new SqlCommand(sql, conexao, transacao);

                comando.Parameters.Add("@Id", SqlDbType.Int).Value = novoId;
                comando.Parameters.Add("@Nome", SqlDbType.NVarChar, 300).Value = produto.Nome;
                comando.Parameters.Add("@Marca", SqlDbType.NVarChar, 200).Value =
                    string.IsNullOrWhiteSpace(produto.Marca) ? DBNull.Value : produto.Marca;
                comando.Parameters.Add("@Categoria", SqlDbType.NVarChar, 200).Value =
                    string.IsNullOrWhiteSpace(produto.Categoria) ? DBNull.Value : produto.Categoria;
                comando.Parameters.Add("@Peso", SqlDbType.NVarChar, 100).Value =
                    string.IsNullOrWhiteSpace(produto.Peso) ? DBNull.Value : produto.Peso;

                var preco = comando.Parameters.Add("@Preco", SqlDbType.Decimal);
                preco.Precision = 10;
                preco.Scale = 2;
                preco.Value = produto.Preco;

                var precoPromocional = comando.Parameters.Add("@PrecoPromocional", SqlDbType.Decimal);
                precoPromocional.Precision = 10;
                precoPromocional.Scale = 2;
                precoPromocional.Value = produto.PrecoPromocional.HasValue
                    ? produto.PrecoPromocional.Value
                    : DBNull.Value;

                comando.Parameters.Add("@Imagem", SqlDbType.NVarChar, 510).Value =
                    string.IsNullOrWhiteSpace(produto.Imagem) ? DBNull.Value : produto.Imagem;

                comando.Parameters.Add("@Oferta", SqlDbType.Bit).Value = produto.Oferta;

                comando.Parameters.Add("@Descricao", SqlDbType.NVarChar, 1000).Value =
                    string.IsNullOrWhiteSpace(produto.Descricao) ? DBNull.Value : produto.Descricao;

                await comando.ExecuteNonQueryAsync();

                await transacao.CommitAsync();

                return novoId;
            }
            catch
            {
                await transacao.RollbackAsync();
                throw;
            }
        }

        // Atualiza os dados de um produto existente.
        public async Task<bool> AtualizarAsync(int id, Produto produto)
        {
            using var conexao = _conexaoFactory.CriarConexao();
            await conexao.OpenAsync();

            const string sql = @"
                UPDATE dbo.Produtos
                SET Nome = @Nome,
                    Marca = @Marca,
                    Categoria = @Categoria,
                    Peso = @Peso,
                    Preco = @Preco,
                    PrecoPromocional = @PrecoPromocional,
                    Imagem = @Imagem,
                    Oferta = @Oferta,
                    Descricao = @Descricao
                WHERE Id = @Id;";

            using var comando = new SqlCommand(sql, conexao);

            comando.Parameters.Add("@Id", SqlDbType.Int).Value = id;
            comando.Parameters.Add("@Nome", SqlDbType.NVarChar, 300).Value = produto.Nome;
            comando.Parameters.Add("@Marca", SqlDbType.NVarChar, 200).Value =
                string.IsNullOrWhiteSpace(produto.Marca) ? DBNull.Value : produto.Marca;
            comando.Parameters.Add("@Categoria", SqlDbType.NVarChar, 200).Value =
                string.IsNullOrWhiteSpace(produto.Categoria) ? DBNull.Value : produto.Categoria;
            comando.Parameters.Add("@Peso", SqlDbType.NVarChar, 100).Value =
                string.IsNullOrWhiteSpace(produto.Peso) ? DBNull.Value : produto.Peso;

            var preco = comando.Parameters.Add("@Preco", SqlDbType.Decimal);
            preco.Precision = 10;
            preco.Scale = 2;
            preco.Value = produto.Preco;

            var precoPromocional = comando.Parameters.Add("@PrecoPromocional", SqlDbType.Decimal);
            precoPromocional.Precision = 10;
            precoPromocional.Scale = 2;
            precoPromocional.Value = produto.PrecoPromocional.HasValue
                ? produto.PrecoPromocional.Value
                : DBNull.Value;

            comando.Parameters.Add("@Imagem", SqlDbType.NVarChar, 510).Value =
                string.IsNullOrWhiteSpace(produto.Imagem) ? DBNull.Value : produto.Imagem;

            comando.Parameters.Add("@Oferta", SqlDbType.Bit).Value = produto.Oferta;

            comando.Parameters.Add("@Descricao", SqlDbType.NVarChar, 1000).Value =
                string.IsNullOrWhiteSpace(produto.Descricao) ? DBNull.Value : produto.Descricao;

            int linhasAfetadas = await comando.ExecuteNonQueryAsync();

            return linhasAfetadas > 0;
        }

        // Exclui um produto pelo ID.
        public async Task<bool> ExcluirAsync(int id)
        {
            using var conexao = _conexaoFactory.CriarConexao();
            await conexao.OpenAsync();

            const string sql = "DELETE FROM dbo.Produtos WHERE Id = @Id;";

            using var comando = new SqlCommand(sql, conexao);
            comando.Parameters.Add("@Id", SqlDbType.Int).Value = id;

            int linhasAfetadas = await comando.ExecuteNonQueryAsync();

            return linhasAfetadas > 0;
        }
    }
}