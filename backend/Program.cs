using MartVerdi.Services;

using Microsoft.AspNetCore.Authentication.Cookies;

// ==================================================
// CONFIGURAÇÃO PRINCIPAL DA APLICAÇÃO MARTVERDI
// ==================================================

var builder = WebApplication.CreateBuilder(args);


// ==================================================
// CONTROLLERS
// Habilita os Controllers da aplicação.
// É isso que permite que o ASP.NET Core
// reconheça nosso ProdutosController.
// ==================================================

builder.Services.AddControllers();

// Configura a autenticação dos usuários por cookie.
builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.Cookie.Name = "MartVerdi.Auth";
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;

        options.ExpireTimeSpan = TimeSpan.FromHours(8);
        options.SlidingExpiration = true;

        // Retorna erro 401 em vez de redirecionar a API para uma página HTML.
        options.Events.OnRedirectToLogin = context =>
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return Task.CompletedTask;
        };

        options.Events.OnRedirectToAccessDenied = context =>
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            return Task.CompletedTask;
        };
    });

// Habilita o controle de autorização.

builder.Services.AddAuthorization();
builder.Services.AddScoped<ProdutoService>();

builder.Services.AddScoped<SqlConnectionFactory>();

// Registra o serviço responsável pelo gerenciamento dos pedidos.
builder.Services.AddScoped<PedidoService>();

// Registra o serviço responsável pelo cadastro e login dos usuários.
builder.Services.AddScoped<UsuarioService>();

// Registra o importador que transfere os produtos do JSON para o SQL Server.

builder.Services.AddScoped<ProdutoImportador>();


var app = builder.Build();


// ==================================================
// ARQUIVOS PADRÃO
// Procura arquivos como index.html
// quando acessamos a página inicial "/"
// ==================================================

app.UseDefaultFiles();


// ==================================================
// ARQUIVOS ESTÁTICOS
// Permite entregar HTML, CSS, JavaScript,
// imagens e outros arquivos do wwwroot.
// ==================================================

app.UseStaticFiles();

// Identifica o usuário por meio do cookie de autenticação.
app.UseAuthentication();

// Habilita a verificação de permissões.
app.UseAuthorization();


// ==================================================
// CONTROLLERS / API
// Ativa as rotas dos Controllers.
// ==================================================

app.MapControllers();

// ==================================================
// TESTE TEMPORÁRIO DA CONEXÃO COM O SQL SERVER
// ==================================================

app.MapGet("/api/teste-conexao", async (SqlConnectionFactory conexaoFactory) =>
{
    try
    {
        await conexaoFactory.TestarConexaoAsync();

        return Results.Ok(new
        {
            sucesso = true,
            mensagem = "Conexão com o SQL Server realizada com sucesso!"
        });
    }
    catch (Exception ex)
    {
        return Results.Problem(
            title: "Falha na conexão com o SQL Server",
            detail: ex.Message
        );
    }
});


// ==================================================
// ROTA TEMPORÁRIA PARA IMPORTAR OS PRODUTOS
// ==================================================

// Disponibiliza uma rota POST para iniciar a importação.
// Essa rota é apenas para uso durante o desenvolvimento local.
app.MapPost("/api/importar-produtos", async (ProdutoImportador importador) =>
{
    try
    {
        // Executa a importação dos produtos do JSON para o SQL Server.
        int quantidade = await importador.ImportarAsync();

        // Retorna uma resposta informando que a importação foi concluída.
        return Results.Ok(new
        {
            sucesso = true,
            mensagem = $"Importação concluída. {quantidade} produtos foram lidos do JSON."
        });
    }
    catch (Exception ex)
    {
        // Retorna os detalhes do erro caso a importação falhe.
        return Results.Problem(
            title: "Falha ao importar produtos",
            detail: ex.Message
        );
    }
      
});


// ==================================================
// INICIALIZAÇÃO DO SERVIDOR
// ==================================================

app.Run();