namespace MartVerdi.Models
{
    // Representa um produto incluído em um pedido.
    public class ItemPedido
    {
        public int Id { get; set; }

        public int PedidoId { get; set; }

        public int ProdutoId { get; set; }

        // Nome do produto para exibição na administração.
        public string NomeProduto { get; set; } = string.Empty;

        public int Quantidade { get; set; }

        public decimal PrecoUnitario { get; set; }
    }
}