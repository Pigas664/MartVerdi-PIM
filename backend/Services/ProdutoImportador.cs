using System.Text.Json;
using Microsoft.Data.SqlClient;
using MartVerdi.Models;

namespace MartVerdi.Services
{
    // Responsável por importar os produtos do arquivo JSON
    // para a tabela Produtos do banco de dados SQL Server.
    public class ProdutoImportador
    {
        private readonly IWebHostEnvironment _ambiente;
        private readonly SqlConnectionFactory _conexaoFactory;

        // Recebe os recursos necessários para localizar o JSON
        // e abrir uma conexão com o banco de dados.
        public ProdutoImportador(
            IWebHostEnvironment ambiente,
            SqlConnectionFactory conexaoFactory)
        {
            _ambiente = ambiente;
            _conexaoFactory = conexaoFactory;
        }

        // Lê os produtos do JSON e cadastra no banco
        // somente aqueles cujos IDs ainda não existem.
        public async Task<int> ImportarAsync()
        {
            // Monta o caminho até wwwroot/data/produtos.json.
            string caminhoArquivo = Path.Combine(
                _ambiente.WebRootPath,
                "data",
                "produtos.json"
            );

            // Interrompe a importação se o arquivo não existir.
            if (!File.Exists(caminhoArquivo))
            {
                throw new FileNotFoundException(
                    "O arquivo produtos.json não foi encontrado.",
                    caminhoArquivo
                );
            }

            // Lê o conteúdo do arquivo de forma assíncrona.
            string json = await File.ReadAllTextAsync(caminhoArquivo);

            // Converte o JSON em uma lista de objetos Produto.
            // PropertyNameCaseInsensitive permite ignorar diferenças
            // entre maiúsculas e minúsculas nos nomes das propriedades.
            var produtos = JsonSerializer.Deserialize<List<Produto>>(
                json,
                new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                }
            ) ?? new List<Produto>();

            // Cria e abre a conexão com o SQL Server.
            using var conexao = _conexaoFactory.CriarConexao();
            await conexao.OpenAsync();

            // Inicia uma transação para que a importação seja confirmada
            // integralmente ou desfeita se ocorrer um erro.
            using var transacao =
                (SqlTransaction)await conexao.BeginTransactionAsync();

            try
            {
                // Percorre todos os produtos encontrados no JSON.
                foreach (var produto in produtos)
                {
                    // Verifica se o ID já existe antes de inserir.
                    // Isso evita duplicar produtos em novas importações.
                    const string sql = @"
                    IF NOT EXISTS (
                        SELECT 1 FROM Produtos WHERE Id = @Id
                    )
                    BEGIN
                        INSERT INTO Produtos
                        (
                            Id, Nome, Marca, Categoria, Peso,
                            Preco, PrecoPromocional, Imagem,
                            Oferta, Descricao
                        )
                        VALUES
                        (
                            @Id, @Nome, @Marca, @Categoria, @Peso,
                            @Preco, @PrecoPromocional, @Imagem,
                            @Oferta, @Descricao
                        )
                    END;";

                    // Prepara o comando SQL usando a conexão e a transação.
                    using var comando =
                        new SqlCommand(sql, conexao, transacao);

                    // Envia os valores do produto como parâmetros SQL.
                    // Os parâmetros evitam concatenar dados diretamente
                    // no comando SQL.
                    comando.Parameters.AddWithValue("@Id", produto.Id);
                    comando.Parameters.AddWithValue("@Nome", produto.Nome);
                    comando.Parameters.AddWithValue("@Marca",
                        (object?)produto.Marca ?? DBNull.Value);
                    comando.Parameters.AddWithValue("@Categoria",
                        (object?)produto.Categoria ?? DBNull.Value);
                    comando.Parameters.AddWithValue("@Peso",
                        (object?)produto.Peso ?? DBNull.Value);
                    comando.Parameters.AddWithValue("@Preco", produto.Preco);
                    comando.Parameters.AddWithValue("@PrecoPromocional",
                        (object?)produto.PrecoPromocional ?? DBNull.Value);
                    comando.Parameters.AddWithValue("@Imagem",
                        (object?)produto.Imagem ?? DBNull.Value);
                    comando.Parameters.AddWithValue("@Oferta", produto.Oferta);
                    comando.Parameters.AddWithValue("@Descricao",
                        (object?)produto.Descricao ?? DBNull.Value);

                    // Executa o comando. Como é um INSERT condicional,
                    // produtos que já existem não são inseridos novamente.
                    await comando.ExecuteNonQueryAsync();
                }

                // Confirma todas as inserções realizadas.
                await transacao.CommitAsync();

                // Retorna a quantidade de produtos lidos do JSON.
                return produtos.Count;
            }
            catch
            {
                // Desfaz as alterações da transação se houver uma falha.
                await transacao.RollbackAsync();

                // Repassa o erro para que possa ser tratado por quem chamou.
                throw;
            }
        }
    }

}