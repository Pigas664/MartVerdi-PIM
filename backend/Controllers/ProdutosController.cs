using Microsoft.AspNetCore.Mvc;
using MartVerdi.Services;
using MartVerdi.Models;

namespace MartVerdi.Controllers
{
    // ==================================================
    // CONTROLLER DE PRODUTOS
    // Responsável pelas requisições HTTP dos produtos.
    // ==================================================

    [ApiController]
    [Route("api/[controller]")]
    public class ProdutosController : ControllerBase
    {
        private readonly ProdutoService _produtoService;

        // Recebe o serviço de produtos pela injeção de dependência.
        public ProdutosController(ProdutoService produtoService)
        {
            _produtoService = produtoService;
        }

        // GET: /api/produtos
        // Retorna todos os produtos cadastrados.
        [HttpGet]
        public async Task<IActionResult> GetProdutos()
        {
            var produtos = await _produtoService.ObterTodosAsync();

            return Ok(produtos);
        }

        // GET: /api/produtos/1
        // Retorna um produto específico pelo ID.
        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetProduto(int id)
        {
            var produto = await _produtoService.ObterPorIdAsync(id);

            if (produto == null)
            {
                return NotFound(new
                {
                    mensagem = "Produto não encontrado."
                });
            }

            return Ok(produto);
        }

        // POST: /api/produtos
        // Cadastra um novo produto.
        [HttpPost]
        public async Task<IActionResult> CriarProduto([FromBody] Produto produto)
        {
            if (string.IsNullOrWhiteSpace(produto.Nome))
            {
                return BadRequest(new
                {
                    mensagem = "O nome do produto é obrigatório."
                });
            }

            if (produto.Preco < 0)
            {
                return BadRequest(new
                {
                    mensagem = "O preço não pode ser negativo."
                });
            }

            if (produto.PrecoPromocional.HasValue &&
                (produto.PrecoPromocional.Value < 0 ||
                 produto.PrecoPromocional.Value > produto.Preco))
            {
                return BadRequest(new
                {
                    mensagem = "O preço promocional deve ser válido e não pode superar o preço normal."
                });
            }

            int novoId = await _produtoService.AdicionarAsync(produto);

            return CreatedAtAction(
                nameof(GetProduto),
                new { id = novoId },
                new
                {
                    id = novoId,
                    mensagem = "Produto cadastrado com sucesso."
                }
            );
        }

        // PUT: /api/produtos/1
        // Atualiza um produto existente.
        [HttpPut("{id:int}")]
        public async Task<IActionResult> AtualizarProduto(
            int id,
            [FromBody] Produto produto)
        {
            if (id <= 0)
            {
                return BadRequest(new
                {
                    mensagem = "ID inválido."
                });
            }

            if (string.IsNullOrWhiteSpace(produto.Nome))
            {
                return BadRequest(new
                {
                    mensagem = "O nome do produto é obrigatório."
                });
            }

            if (produto.Preco < 0)
            {
                return BadRequest(new
                {
                    mensagem = "O preço não pode ser negativo."
                });
            }

            if (produto.PrecoPromocional.HasValue &&
                (produto.PrecoPromocional.Value < 0 ||
                 produto.PrecoPromocional.Value > produto.Preco))
            {
                return BadRequest(new
                {
                    mensagem = "O preço promocional deve ser válido e não pode superar o preço normal."
                });
            }

            bool atualizado = await _produtoService.AtualizarAsync(id, produto);

            if (!atualizado)
            {
                return NotFound(new
                {
                    mensagem = "Produto não encontrado."
                });
            }

            return Ok(new
            {
                mensagem = "Produto atualizado com sucesso."
            });
        }

        // DELETE: /api/produtos/1
        // Exclui um produto pelo ID.
        [HttpDelete("{id:int}")]
        public async Task<IActionResult> ExcluirProduto(int id)
        {
            if (id <= 0)
            {
                return BadRequest(new
                {
                    mensagem = "ID inválido."
                });
            }

            bool excluido = await _produtoService.ExcluirAsync(id);

            if (!excluido)
            {
                return NotFound(new
                {
                    mensagem = "Produto não encontrado."
                });
            }

            return Ok(new
            {
                mensagem = "Produto excluído com sucesso."
            });
        }
    }
}