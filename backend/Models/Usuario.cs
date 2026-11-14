namespace MartVerdi.Models
{
    public class Usuario
    {
        // Identificador único do usuário no banco.
        public int Id { get; set; }

        // Nome completo do cliente.
        public string Nome { get; set; } = string.Empty;

        // Nome de usuário utilizado no login.
        public string UsuarioNome { get; set; } = string.Empty;

        // E-mail cadastrado.
        public string Email { get; set; } = string.Empty;

        // Data de nascimento do usuário.
        public DateTime DataNascimento { get; set; }

        // CEP cadastrado.
        public string CEP { get; set; } = string.Empty;

        // Senha armazenada em formato de hash.
        public string SenhaHash { get; set; } = string.Empty;

        // Data de criação da conta.
        public DateTime DataCriacao { get; set; }

        // Perfil de acesso: Cliente ou Administrador.
        public string Perfil { get; set; } = "Cliente";
    }
}