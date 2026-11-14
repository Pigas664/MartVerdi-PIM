using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using System.Security.Claims;
using MartVerdi.Models;
using MartVerdi.Services;

namespace MartVerdi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class UsuariosController : ControllerBase
    {
        private readonly UsuarioService _usuarioService;

        public UsuariosController(UsuarioService usuarioService)
        {
            _usuarioService = usuarioService;
        }

        // Recebe os dados enviados pela página de cadastro.
        [HttpPost("cadastro")]
        public async Task<IActionResult> Cadastrar([FromBody] CadastroRequest dados)
        {
            if (string.IsNullOrWhiteSpace(dados.Nome) ||
                string.IsNullOrWhiteSpace(dados.Usuario) ||
                string.IsNullOrWhiteSpace(dados.Email) ||
                string.IsNullOrWhiteSpace(dados.Senha))
            {
                return BadRequest(new { mensagem = "Preencha todos os campos obrigatórios." });
            }

            if (dados.Senha.Length < 8)
            {
                return BadRequest(new { mensagem = "A senha deve possuir pelo menos 8 caracteres." });
            }

            // Remove os caracteres que não são números do CEP.
            string cep = new string(dados.CEP.Where(char.IsDigit).ToArray());

            if (cep.Length != 8)
            {
                return BadRequest(new { mensagem = "Digite um CEP válido." });
            }

            // Valida a data de nascimento.
            if (!DateTime.TryParse(dados.DataNascimento, out DateTime nascimento) ||
                nascimento.Date >= DateTime.Today)
            {
                return BadRequest(new { mensagem = "Informe uma data de nascimento válida." });
            }

            string usuarioNome = dados.Usuario.Trim();
            string email = dados.Email.Trim();

            // Verifica se o usuário ou e-mail já estão cadastrados.
            if (await _usuarioService.UsuarioExisteAsync(usuarioNome, email))
            {
                return Conflict(new { mensagem = "Esse usuário ou e-mail já está cadastrado." });
            }

            // Monta o objeto do novo usuário.
            var usuario = new Usuario
            {
                Nome = dados.Nome.Trim(),
                UsuarioNome = usuarioNome,
                Email = email,
                DataNascimento = nascimento,
                CEP = cep,
                Perfil = "Cliente"
            };

            try
            {
                // Salva o usuário no SQL Server.
                usuario.Id = await _usuarioService.CadastrarAsync(usuario, dados.Senha);

                // Cria a sessão automaticamente após o cadastro.
                await CriarSessao(usuario);

                return Ok(new
                {
                    mensagem = "Conta criada com sucesso!",
                    usuario = new
                    {
                        usuario.Id,
                        usuario.Nome,
                        usuario.UsuarioNome,
                        usuario.Email,
                        usuario.CEP,
                        usuario.Perfil
                    }
                });
            }
            catch (SqlException ex) when (ex.Number == 2601 || ex.Number == 2627)
            {
                return Conflict(new { mensagem = "Esse usuário ou e-mail já está cadastrado." });
            }
        }

        // Verifica os dados de acesso do usuário.
        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest dados)
        {
            if (string.IsNullOrWhiteSpace(dados.Identificador) ||
                string.IsNullOrWhiteSpace(dados.Senha))
            {
                return BadRequest(new { mensagem = "Informe usuário e senha." });
            }

            // Procura o usuário e verifica a senha no banco.
            var usuario = await _usuarioService.AutenticarAsync(
                dados.Identificador.Trim(),
                dados.Senha
            );

            if (usuario == null)
            {
                return Unauthorized(new { mensagem = "Usuário ou senha incorretos." });
            }

            // Cria o cookie de autenticação com o perfil do usuário.
            await CriarSessao(usuario);

            return Ok(new
            {
                mensagem = "Login realizado com sucesso!",
                usuario = new
                {
                    usuario.Id,
                    usuario.Nome,
                    usuario.UsuarioNome,
                    usuario.Email,
                    usuario.CEP,
                    usuario.Perfil
                }
            });
        }

        // Encerra a sessão autenticada do usuário.
        [HttpPost("logout")]
        public async Task<IActionResult> Logout()
        {
            await HttpContext.SignOutAsync(
                CookieAuthenticationDefaults.AuthenticationScheme
            );

            return Ok(new { mensagem = "Logout realizado com sucesso." });
        }

        // Consulta os dados completos do usuário autenticado no banco.
        [Authorize]
        [HttpGet("me")]
        public async Task<IActionResult> MeuUsuario()
        {
            string? idUsuario = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

            if (!int.TryParse(idUsuario, out int id))
                return Unauthorized(new { mensagem = "Sessão inválida." });

            var usuario = await _usuarioService.BuscarPorIdAsync(id);

            if (usuario == null)
                return NotFound(new { mensagem = "Usuário não encontrado." });

            return Ok(new
            {
                id = usuario.Id,
                nome = usuario.Nome,
                usuario = usuario.UsuarioNome,
                email = usuario.Email,
                dataNascimento = usuario.DataNascimento.ToString("yyyy-MM-dd"),
                cep = usuario.CEP,
                perfil = usuario.Perfil
            });
        }

        // Atualiza os dados da conta do usuário autenticado.
        [Authorize]
        [HttpPut("me")]
        public async Task<IActionResult> AtualizarMeuUsuario([FromBody] AtualizarUsuarioRequest dados)
        {
            string? idUsuario = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

            if (!int.TryParse(idUsuario, out int id))
                return Unauthorized(new { mensagem = "Sessão inválida." });

            if (string.IsNullOrWhiteSpace(dados.Nome) ||
                string.IsNullOrWhiteSpace(dados.Email) ||
                string.IsNullOrWhiteSpace(dados.CEP))
            {
                return BadRequest(new { mensagem = "Preencha todos os campos obrigatórios." });
            }

            if (!string.IsNullOrWhiteSpace(dados.Senha) && dados.Senha.Length < 8)
                return BadRequest(new { mensagem = "A nova senha deve possuir pelo menos 8 caracteres." });

            if (!DateTime.TryParse(dados.DataNascimento, out DateTime nascimento) ||
                nascimento.Date >= DateTime.Today)
            {
                return BadRequest(new { mensagem = "Informe uma data de nascimento válida." });
            }

            string cep = new string(dados.CEP.Where(char.IsDigit).ToArray());

            if (cep.Length != 8)
                return BadRequest(new { mensagem = "Digite um CEP válido." });

            string email = dados.Email.Trim();

            if (await _usuarioService.EmailExisteParaOutroUsuarioAsync(email, id))
                return Conflict(new { mensagem = "Esse e-mail já está cadastrado." });

            var usuario = await _usuarioService.BuscarPorIdAsync(id);

            if (usuario == null)
                return NotFound(new { mensagem = "Usuário não encontrado." });

            // Atualiza somente os dados pessoais, preservando o perfil administrativo.
            usuario.Nome = dados.Nome.Trim();
            usuario.Email = email;
            usuario.DataNascimento = nascimento;
            usuario.CEP = cep;

            bool atualizado = await _usuarioService.AtualizarAsync(usuario, dados.Senha);

            if (!atualizado)
                return NotFound(new { mensagem = "Não foi possível atualizar os dados." });

            // Atualiza o cookie mantendo o perfil correto.
            await CriarSessao(usuario);

            return Ok(new
            {
                mensagem = "Dados atualizados com sucesso!",
                id = usuario.Id,
                nome = usuario.Nome,
                usuario = usuario.UsuarioNome,
                email = usuario.Email,
                dataNascimento = usuario.DataNascimento.ToString("yyyy-MM-dd"),
                cep = usuario.CEP,
                perfil = usuario.Perfil
            });
        }

        // Cria uma sessão protegida com identificação e perfil do usuário.
        private async Task CriarSessao(Usuario usuario)
        {
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, usuario.Id.ToString()),
                new Claim(ClaimTypes.Name, usuario.UsuarioNome),
                new Claim(ClaimTypes.Email, usuario.Email),

                // Permite ao ASP.NET identificar Cliente ou Administrador.
                new Claim(ClaimTypes.Role, usuario.Perfil)
            };

            var identidade = new ClaimsIdentity(
                claims,
                CookieAuthenticationDefaults.AuthenticationScheme
            );

            var principal = new ClaimsPrincipal(identidade);

            await HttpContext.SignInAsync(
                CookieAuthenticationDefaults.AuthenticationScheme,
                principal,
                new AuthenticationProperties
                {
                    IsPersistent = true,
                    ExpiresUtc = DateTimeOffset.UtcNow.AddHours(8)
                }
            );
        }
    }

    // Estrutura dos dados recebidos no cadastro.
    public class CadastroRequest
    {
        public string Nome { get; set; } = string.Empty;
        public string Usuario { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string DataNascimento { get; set; } = string.Empty;
        public string CEP { get; set; } = string.Empty;
        public string Senha { get; set; } = string.Empty;
    }

    // Estrutura dos dados recebidos no login.
    public class LoginRequest
    {
        public string Identificador { get; set; } = string.Empty;
        public string Senha { get; set; } = string.Empty;
    }

    // Estrutura dos dados recebidos na atualização da conta.
    public class AtualizarUsuarioRequest
    {
        public string Nome { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string DataNascimento { get; set; } = string.Empty;
        public string CEP { get; set; } = string.Empty;
        public string Senha { get; set; } = string.Empty;
    }
}