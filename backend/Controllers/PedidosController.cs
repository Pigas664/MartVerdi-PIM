using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using MartVerdi.Models;
using MartVerdi.Services;

namespace MartVerdi.Controllers
{
    [ApiController]
    [Route("api/pedidos")]
    [Authorize]
    public class PedidosController : ControllerBase
    {
        private readonly PedidoService _pedidoService;

        // Recebe o serviço responsável pelo gerenciamento dos pedidos.
        public PedidosController(PedidoService pedidoService)
        {
            _pedidoService = pedidoService;
        }

        // Cria um pedido para o cliente autenticado.
        [HttpPost]
        public async Task<IActionResult> CriarPedido([FromBody] CriarPedidoRequest dados)
        {
            // Obtém o ID do usuário pela sessão autenticada.
            var identificador = User.FindFirstValue(ClaimTypes.NameIdentifier);

            if (!int.TryParse(identificador, out int usuarioId))
                return Unauthorized(new { mensagem = "Usuário não identificado." });

            if (dados?.Itens == null || dados.Itens.Count == 0)
                return BadRequest(new { mensagem = "O carrinho está vazio." });

            try
            {
                // Salva o pedido e seus itens no banco de dados.
                int pedidoId = await _pedidoService.CriarPedidoAsync(
                    usuarioId, dados.Itens);

                return Ok(new
                {
                    mensagem = "Pedido realizado com sucesso!",
                    pedidoId = pedidoId
                });
            }
            catch (Exception erro)
            {
                return BadRequest(new { mensagem = erro.Message });
            }
        }

        // Lista todos os pedidos. Acesso exclusivo do administrador.
        [HttpGet]
        [Authorize(Roles = "Administrador")]
        public async Task<IActionResult> ListarPedidos()
        {
            var pedidos = await _pedidoService.ObterTodosAsync();

            return Ok(pedidos);
        }

        // Consulta os detalhes de um pedido específico.
        [HttpGet("{id:int}")]
        [Authorize(Roles = "Administrador")]
        public async Task<IActionResult> ObterPedido(int id)
        {
            var pedido = await _pedidoService.ObterPorIdAsync(id);

            if (pedido == null)
                return NotFound(new { mensagem = "Pedido não encontrado." });

            return Ok(pedido);
        }

        // Atualiza o status de um pedido. Somente administradores podem executar.
        [HttpPut("{id:int}/status")]
        [Authorize(Roles = "Administrador")]
        public async Task<IActionResult> AtualizarStatus(
            int id,
            [FromBody] AtualizarStatusRequest dados)
        {
            if (dados == null || string.IsNullOrWhiteSpace(dados.Status))
                return BadRequest(new { mensagem = "Informe o status do pedido." });

            try
            {
                bool atualizado = await _pedidoService.AtualizarStatusAsync(
                    id, dados.Status);

                if (!atualizado)
                    return NotFound(new { mensagem = "Pedido não encontrado." });

                return Ok(new { mensagem = "Status do pedido atualizado com sucesso!" });
            }
            catch (Exception erro)
            {
                return BadRequest(new { mensagem = erro.Message });
            }
        }

        // Apresenta o resumo das vendas dos pedidos concluídos.
        [HttpGet("vendas/resumo")]
        [Authorize(Roles = "Administrador")]
        public async Task<IActionResult> ObterResumoVendas()
        {
            var resumo = await _pedidoService.ObterResumoVendasAsync();

            return Ok(new
            {
                quantidadePedidosConcluidos = resumo.QuantidadePedidos,
                faturamento = resumo.Faturamento
            });
        }
    }

    // Define os dados recebidos para criar um pedido.
    public class CriarPedidoRequest
    {
        public List<ItemPedido> Itens { get; set; } = new List<ItemPedido>();
    }

    // Define o status enviado pelo administrador.
    public class AtualizarStatusRequest
    {
        public string Status { get; set; } = string.Empty;
    }
}