namespace MartVerdi.Models
{
    // Representa um pedido realizado por um usuário.
    public class Pedido
    {
        public int Id { get; set; }

        public int UsuarioId { get; set; }

        // Nome do cliente que realizou o pedido.
        public string NomeUsuario { get; set; } = string.Empty;

        public DateTime DataPedido { get; set; }

        public decimal ValorTotal { get; set; }

        public string Status { get; set; } = "Pendente";

        // Guarda os produtos que pertencem ao pedido.
        public List<ItemPedido> Itens { get; set; } = new List<ItemPedido>();
    }
}