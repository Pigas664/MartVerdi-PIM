using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using MartVerdi.Models;

namespace MartVerdi.Services
{
    public class UsuarioService
    {
        private readonly SqlConnectionFactory _conexaoFactory;
        private readonly PasswordHasher<Usuario> _passwordHasher;

        public UsuarioService(SqlConnectionFactory conexaoFactory)
        {
            _conexaoFactory = conexaoFactory;
            _passwordHasher = new PasswordHasher<Usuario>();
        }

        // Verifica se o nome de usuário ou e-mail já está cadastrado.
        public async Task<bool> UsuarioExisteAsync(string usuario, string email)
        {
            using var conexao = _conexaoFactory.CriarConexao();
            await conexao.OpenAsync();

            const string sql = @"
                SELECT COUNT(1)
                FROM dbo.Usuarios
                WHERE Usuario = @Usuario OR Email = @Email";

            using var comando = new SqlCommand(sql, conexao);

            comando.Parameters.AddWithValue("@Usuario", usuario);
            comando.Parameters.AddWithValue("@Email", email);

            int quantidade = Convert.ToInt32(
                await comando.ExecuteScalarAsync()
            );

            return quantidade > 0;
        }

        // Cadastra o usuário e armazena somente o hash da senha.
        // O banco define automaticamente o perfil inicial como Cliente.
        public async Task<int> CadastrarAsync(Usuario usuario, string senha)
        {
            usuario.SenhaHash = _passwordHasher.HashPassword(usuario, senha);

            using var conexao = _conexaoFactory.CriarConexao();
            await conexao.OpenAsync();

            const string sql = @"
                INSERT INTO dbo.Usuarios
                (
                    Nome,
                    Usuario,
                    Email,
                    DataNascimento,
                    CEP,
                    SenhaHash
                )
                OUTPUT INSERTED.Id
                VALUES
                (
                    @Nome,
                    @Usuario,
                    @Email,
                    @DataNascimento,
                    @CEP,
                    @SenhaHash
                )";

            using var comando = new SqlCommand(sql, conexao);

            comando.Parameters.AddWithValue("@Nome", usuario.Nome);
            comando.Parameters.AddWithValue("@Usuario", usuario.UsuarioNome);
            comando.Parameters.AddWithValue("@Email", usuario.Email);
            comando.Parameters.AddWithValue("@DataNascimento", usuario.DataNascimento);
            comando.Parameters.AddWithValue("@CEP", usuario.CEP);
            comando.Parameters.AddWithValue("@SenhaHash", usuario.SenhaHash);

            return Convert.ToInt32(await comando.ExecuteScalarAsync());
        }

        // Procura o usuário e verifica sua senha durante o login.
        public async Task<Usuario?> AutenticarAsync(string identificador, string senha)
        {
            using var conexao = _conexaoFactory.CriarConexao();
            await conexao.OpenAsync();

            const string sql = @"
                SELECT
                    Id,
                    Nome,
                    Usuario,
                    Email,
                    DataNascimento,
                    CEP,
                    SenhaHash,
                    DataCriacao,
                    Perfil
                FROM dbo.Usuarios
                WHERE Usuario = @Identificador
                   OR Email = @Identificador";

            using var comando = new SqlCommand(sql, conexao);

            comando.Parameters.AddWithValue("@Identificador", identificador);

            using var leitor = await comando.ExecuteReaderAsync();

            if (!await leitor.ReadAsync())
                return null;

            // Monta o usuário incluindo seu perfil de acesso.
            var usuario = new Usuario
            {
                Id = leitor.GetInt32(0),
                Nome = leitor.GetString(1),
                UsuarioNome = leitor.GetString(2),
                Email = leitor.GetString(3),
                DataNascimento = leitor.GetDateTime(4),
                CEP = leitor.GetString(5),
                SenhaHash = leitor.GetString(6),
                DataCriacao = leitor.GetDateTime(7),
                Perfil = leitor.GetString(8)
            };

            // Confere se a senha informada corresponde ao hash armazenado.
            var resultado = _passwordHasher.VerifyHashedPassword(
                usuario,
                usuario.SenhaHash,
                senha
            );

            if (resultado == PasswordVerificationResult.Failed)
                return null;

            return usuario;
        }

        // Busca os dados completos de um usuário pelo seu ID.
        public async Task<Usuario?> BuscarPorIdAsync(int id)
        {
            using var conexao = _conexaoFactory.CriarConexao();
            await conexao.OpenAsync();

            // Consulta os dados sem retornar o hash da senha.
            const string sql = @"
                SELECT
                    Id,
                    Nome,
                    Usuario,
                    Email,
                    DataNascimento,
                    CEP,
                    DataCriacao,
                    Perfil
                FROM dbo.Usuarios
                WHERE Id = @Id";

            using var comando = new SqlCommand(sql, conexao);

            comando.Parameters.AddWithValue("@Id", id);

            using var leitor = await comando.ExecuteReaderAsync();

            if (!await leitor.ReadAsync())
                return null;

            // Retorna os dados do usuário, incluindo seu perfil.
            return new Usuario
            {
                Id = leitor.GetInt32(0),
                Nome = leitor.GetString(1),
                UsuarioNome = leitor.GetString(2),
                Email = leitor.GetString(3),
                DataNascimento = leitor.GetDateTime(4),
                CEP = leitor.GetString(5),
                DataCriacao = leitor.GetDateTime(6),
                Perfil = leitor.GetString(7)
            };
        }

        // Verifica se o e-mail já pertence a outro usuário.
        public async Task<bool> EmailExisteParaOutroUsuarioAsync(string email, int idUsuario)
        {
            using var conexao = _conexaoFactory.CriarConexao();
            await conexao.OpenAsync();

            const string sql = @"
                SELECT COUNT(1)
                FROM dbo.Usuarios
                WHERE Email = @Email AND Id <> @Id";

            using var comando = new SqlCommand(sql, conexao);

            comando.Parameters.AddWithValue("@Email", email);
            comando.Parameters.AddWithValue("@Id", idUsuario);

            int quantidade = Convert.ToInt32(await comando.ExecuteScalarAsync());

            return quantidade > 0;
        }

        // Atualiza os dados da conta sem permitir alteração do perfil pelo cliente.
        public async Task<bool> AtualizarAsync(Usuario usuario, string? novaSenha)
        {
            using var conexao = _conexaoFactory.CriarConexao();
            await conexao.OpenAsync();

            // Gera um novo hash somente quando uma nova senha foi informada.
            string? senhaHash = null;

            if (!string.IsNullOrWhiteSpace(novaSenha))
            {
                senhaHash = _passwordHasher.HashPassword(usuario, novaSenha);
            }

            // Atualiza os dados pessoais e preserva o perfil existente.
            const string sql = @"
                UPDATE dbo.Usuarios
                SET
                    Nome = @Nome,
                    Email = @Email,
                    DataNascimento = @DataNascimento,
                    CEP = @CEP,
                    SenhaHash = COALESCE(@SenhaHash, SenhaHash)
                WHERE Id = @Id";

            using var comando = new SqlCommand(sql, conexao);

            comando.Parameters.AddWithValue("@Id", usuario.Id);
            comando.Parameters.AddWithValue("@Nome", usuario.Nome);
            comando.Parameters.AddWithValue("@Email", usuario.Email);
            comando.Parameters.AddWithValue("@DataNascimento", usuario.DataNascimento);
            comando.Parameters.AddWithValue("@CEP", usuario.CEP);
            comando.Parameters.AddWithValue(
                "@SenhaHash",
                (object?)senhaHash ?? DBNull.Value
            );

            int linhasAfetadas = await comando.ExecuteNonQueryAsync();

            return linhasAfetadas > 0;
        }
    }
}