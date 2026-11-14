using Microsoft.Data.SqlClient;

namespace MartVerdi.Services
{
    public class SqlConnectionFactory
    {
        private readonly IConfiguration _configuration;

        public SqlConnectionFactory(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public SqlConnection CriarConexao()
        {
            string? connectionString = _configuration
                .GetConnectionString("MartVerdiConnection");

            if (string.IsNullOrWhiteSpace(connectionString))
            {
                throw new InvalidOperationException(
                    "A conexão MartVerdiConnection não foi configurada."
                );
            }

            return new SqlConnection(connectionString);
        }

        // TESTE TEMPORÁRIO DA CONEXÃO COM O SQL SERVER
        public async Task<bool> TestarConexaoAsync()
        {
            using var conexao = CriarConexao();
            await conexao.OpenAsync();
            return true;
        }
    }

}
