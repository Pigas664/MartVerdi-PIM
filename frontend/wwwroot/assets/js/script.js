/* =========================================================
   MARTVERDI - JAVASCRIPT PRINCIPAL
   Este arquivo controla busca, catálogo, carrinho, CEP,
   carrossel, favoritos e navegação da página inicial.
   ========================================================= */

(() => {
  'use strict';

  // ---------- CONFIGURAÇÕES E ESTADO DO CATÁLOGO ----------
  const state = {
    produtos: [],
    categoria: 'Todos',
    favoritos: JSON.parse(localStorage.getItem('martverdiFavoritos') || '[]')
  };

  const $ = (seletor, raiz = document) => raiz.querySelector(seletor);
  const $$ = (seletor, raiz = document) => [...raiz.querySelectorAll(seletor)];
  const moeda = valor => Number(valor || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
  const escapar = valor => String(valor ?? '').replace(/[&<>'"]/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', "'":'&#39;', '"':'&quot;' }[c]));
  const toast = mensagem => { const el = $('#toast'); if (!el) return; el.textContent = mensagem; el.classList.add('show'); clearTimeout(window.mvToast); window.mvToast = setTimeout(() => el.classList.remove('show'), 2200); };
    const imagemProduto = produto => {
        if (!produto.imagem) return '';

        // Aceita tanto caminhos completos quanto apenas o nome do arquivo.
        const caminho = produto.imagem.replace(/^\.\//, '');

        if (caminho.startsWith('assets/img/produtos/')) {
            return `/${caminho}`;
        }

        return `/assets/img/produtos/${caminho}`;
    };

  // ---------- CONTA E CARRINHO ----------
    // Consulta a sessão real do usuário no ASP.NET Core.
    async function atualizarCabecalho() {
        const nome = $('#usuarioTopo');
        const linkConta = $('#linkMinhaConta');
        const btnSair = $('#btnSair');
        // Configura o botão para encerrar a sessão do usuário.
        if (btnSair) {
            btnSair.onclick = async function () {
                try {
                    // Envia a solicitação de logout para o servidor.
                    const resposta = await fetch('/api/usuarios/logout', {
                        method: 'POST',
                        credentials: 'same-origin'
                    });

                    if (!resposta.ok) {
                        throw new Error('Falha ao encerrar a sessão.');
                    }

                    // Remove o nome salvo no navegador e retorna à página inicial.
                    localStorage.removeItem('usuarioLogado');
                    window.location.href = '/';

                } catch (erro) {
                    console.error('Erro ao sair:', erro);
                    alert('Não foi possível encerrar a sessão. Tente novamente.');
                }
            };
        }

        try {
            // Verifica se existe um usuário autenticado pelo cookie.
            const resposta = await fetch('/api/usuarios/me', {
                method: 'GET',
                credentials: 'same-origin'
            });

            if (resposta.ok) {
                const usuario = await resposta.json();

                // Atualiza o cabeçalho com o usuário autenticado.
                if (nome) nome.textContent = `Olá, ${usuario.nome}`;
                // Exibe o botão Sair quando existe uma sessão ativa.
                if (btnSair) btnSair.hidden = false;
                if (linkConta) linkConta.href = './pages/painel.html';

                // Mantém o nome salvo apenas como informação visual.
                localStorage.setItem('usuarioLogado', usuario.nome);

            } else {
                // Se não houver sessão, apresenta a opção de login.
                if (nome) nome.textContent = 'Acesse ou cadastre-se';
                // Esconde o botão Sair quando não existe uma sessão ativa.
                if (btnSair) btnSair.hidden = true;
                if (linkConta) linkConta.href = './pages/login.html';

                localStorage.removeItem('usuarioLogado');
            }

        } catch (erro) {
            console.error('Erro ao verificar a sessão:', erro);
        }

        // Atualiza a quantidade de itens no carrinho.
        const itens = JSON.parse(localStorage.getItem('carrinhoItens') || '[]');
        const contador = $('#contadorCarrinho');

        if (contador) contador.textContent = itens.length;
    }

  function adicionarAoCarrinho(produto) {
    // Se não estiver logado, guardamos o produto e levamos o usuário ao login.
    if (!localStorage.getItem('usuarioLogado')) {
      localStorage.setItem('martverdiProdutoPendente', JSON.stringify({ ...produto, quantidade: 1 }));
      localStorage.setItem('martverdiDestinoLogin', window.location.href);
      window.location.href = './pages/login.html';
      return;
    }
    const itens = JSON.parse(localStorage.getItem('carrinhoItens') || '[]');
    itens.push({ id: produto.id, nome: produto.nome, marca: produto.marca, categoria: produto.categoria, preco: produto.preco, imagem: new URL(imagemProduto(produto), document.baseURI).href, quantidade: 1 });
    localStorage.setItem('carrinhoItens', JSON.stringify(itens));
    localStorage.setItem('carrinho', String(itens.length));
    atualizarCabecalho();
    toast(`${produto.nome} foi adicionado ao carrinho.`);
  }

  function alternarFavorito(id) {
    state.favoritos = state.favoritos.includes(id) ? state.favoritos.filter(item => item !== id) : [...state.favoritos, id];
    localStorage.setItem('martverdiFavoritos', JSON.stringify(state.favoritos));
    renderCatalogo();
  }

  // ---------- CARDS DE PRODUTO ----------
  function descontoFake(produto) {
    // Apenas produtos marcados como oferta recebem preço anterior no protótipo.
    return produto.oferta ? Math.round((produto.preco * 1.12) * 100) / 100 : null;
  }

  function cardProduto(produto) {
    const anterior = descontoFake(produto);
    const favorito = state.favoritos.includes(produto.id);
    const percentual = anterior ? Math.round((1 - produto.preco / anterior) * 100) : 0;
    return `<article class="produto-card" data-id="${produto.id}">
      <div class="produto-imagem">
        ${produto.oferta ? `<span class="produto-badge">OFERTA</span><span class="desconto-badge">-${percentual}%</span>` : ''}
        <button class="favorito-btn ${favorito ? 'ativo' : ''}" data-favorito="${produto.id}" aria-label="${favorito ? 'Remover dos favoritos' : 'Adicionar aos favoritos'}"><i class="fa-${favorito ? 'solid' : 'regular'} fa-heart"></i></button>
        <a href="./pages/produto.html?id=${produto.id}" class="produto-link-img"><img loading="lazy" src="${escapar(imagemProduto(produto))}" alt="${escapar(produto.nome)}"></a>
      </div>
      <div class="produto-info">
        <span class="produto-marca">${escapar(produto.marca)}</span>
        <a href="./pages/produto.html?id=${produto.id}" class="produto-nome">${escapar(produto.nome)}</a>
        <div class="stars" aria-label="5 de 5 estrelas">★★★★★ <small>5,0</small></div>
        ${anterior ? `<div class="preco-anterior">${moeda(anterior)}</div>` : ''}
        <strong class="preco-produto">${moeda(produto.preco)}</strong>
        <button class="btn-carrinho" data-add="${produto.id}"><i class="fa-solid fa-cart-plus"></i> Adicionar</button>
      </div>
    </article>`;
  }

  function ligarCards(raiz) {
    $$('[data-add]', raiz).forEach(botao => botao.addEventListener('click', () => {
      const produto = state.produtos.find(item => item.id === Number(botao.dataset.add));
      if (produto) adicionarAoCarrinho(produto);
    }));
    $$('[data-favorito]', raiz).forEach(botao => botao.addEventListener('click', e => {
      e.preventDefault(); e.stopPropagation(); alternarFavorito(Number(botao.dataset.favorito));
    }));
  }

  // ---------- FILTROS E RENDERIZAÇÃO DO CATÁLOGO ----------
  function produtosFiltrados() {
    const termo = ($('#campoBusca')?.value || '').trim().toLowerCase();
    const min = Number($('#precoMin')?.value || 0);
    const max = Number($('#precoMax')?.value || Infinity);
    const somenteOfertas = $('#somenteOfertas')?.checked;
    const categoriasMarcadas = $$('.filtro-categoria:checked').map(el => el.value);

    let lista = state.produtos.filter(produto => {
      const texto = `${produto.nome} ${produto.marca} ${produto.categoria}`.toLowerCase();
      const buscaOk = !termo || texto.includes(termo);
      const categoriaOk = state.categoria === 'Todos' || produto.categoria === state.categoria;
      const checkOk = !categoriasMarcadas.length || categoriasMarcadas.includes(produto.categoria);
      return buscaOk && categoriaOk && checkOk && produto.preco >= min && produto.preco <= max && (!somenteOfertas || produto.oferta);
    });

    const ordem = $('#ordenarProdutos')?.value || 'relevancia';
    if (ordem === 'menor-preco') lista.sort((a,b) => a.preco - b.preco);
    if (ordem === 'maior-preco') lista.sort((a,b) => b.preco - a.preco);
    if (ordem === 'az') lista.sort((a,b) => a.nome.localeCompare(b.nome, 'pt-BR'));
    return lista;
  }

  function renderCatalogo() {
    const lista = produtosFiltrados();
    const grid = $('#alimentosGrid');
    const vazio = $('#alimentosVazio');
    if (grid) grid.innerHTML = lista.map(cardProduto).join('');
    if (vazio) vazio.hidden = lista.length > 0;
    if ($('#resultadoQuantidade')) $('#resultadoQuantidade').textContent = lista.length;
    if ($('#alimentosTotal')) $('#alimentosTotal').textContent = `${lista.length} produto${lista.length === 1 ? '' : 's'}`;
    ligarCards(grid || document);
  }

  function renderDestaques() {
    const ofertas = state.produtos.filter(p => p.oferta).slice(0, 4);
    const vendidos = [...state.produtos].sort((a,b) => a.id - b.id).slice(0, 4);
    const ofertasGrid = $('#ofertasGrid');
    const vendidosGrid = $('#maisVendidosGrid');
    if (ofertasGrid) { ofertasGrid.innerHTML = ofertas.map(cardProduto).join(''); ligarCards(ofertasGrid); }
    if (vendidosGrid) { vendidosGrid.innerHTML = vendidos.map(cardProduto).join(''); ligarCards(vendidosGrid); }
  }

  function selecionarCategoria(categoria) {
    state.categoria = categoria;
    $$('.categoria-chip').forEach(chip => chip.classList.toggle('active', chip.dataset.categoria === categoria));
    $$('.filtro-categoria').forEach(check => check.checked = check.value === categoria);
    renderCatalogo();
    document.querySelector('#alimentos')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  // ---------- BUSCA INTELIGENTE ----------
  function mostrarSugestoes() {
    const campo = $('#campoBusca'); const box = $('#resultadoBusca');
    if (!campo || !box) return;
    const termo = campo.value.trim().toLowerCase();
    if (!termo) { box.classList.remove('aberto'); return; }
    const encontrados = state.produtos.filter(p => `${p.nome} ${p.marca} ${p.categoria}`.toLowerCase().includes(termo)).slice(0, 6);
    box.innerHTML = encontrados.length ? encontrados.map(p => `<button class="item-resultado" data-busca-id="${p.id}"><img src="${escapar(imagemProduto(p))}" alt=""><span><strong>${escapar(p.nome)}</strong><small>${escapar(p.marca)} · ${moeda(p.preco)}</small></span><i class="fa-solid fa-arrow-right"></i></button>`).join('') : '<div class="item-resultado vazio"><span><strong>Nenhum produto encontrado</strong><small>Tente outro nome, marca ou categoria.</small></span></div>';
    box.classList.add('aberto');
    $$('[data-busca-id]', box).forEach(btn => btn.addEventListener('click', () => window.location.href = `./pages/produto.html?id=${btn.dataset.buscaId}`));
  }

    // ---------- CEP ----------

    // Formata o CEP no padrão 00000-000.
    function formatarCep(valor) {
        const n = valor.replace(/\D/g, '').slice(0, 8);
        return n.length > 5 ? `${n.slice(0, 5)}-${n.slice(5)}` : n;
    }

    // Consulta o CEP atualizado do usuário no servidor.
    async function atualizarCep() {
        try {
            const resposta = await fetch('/api/usuarios/me', {
                method: 'GET',
                credentials: 'same-origin'
            });

            // Se estiver logado, utiliza o CEP cadastrado no banco.
            if (resposta.ok) {
                const usuario = await resposta.json();
                const cep = usuario.cep || '';

                // Atualiza o armazenamento local para manter compatibilidade.
                if (cep) {
                    localStorage.setItem('martverdiCep', cep);
                } else {
                    localStorage.removeItem('martverdiCep');
                }

                // Exibe o CEP atualizado na página inicial.
                if ($('#cepTexto')) {
                    $('#cepTexto').textContent = cep ? `CEP: ${cep}` : 'Informe seu CEP';
                }

                return;
            }

            // Para visitantes sem login, mantém o CEP local.
            const cepLocal = localStorage.getItem('martverdiCep') || '';

            if ($('#cepTexto')) {
                $('#cepTexto').textContent = cepLocal ? `CEP: ${cepLocal}` : 'Informe seu CEP';
            }

        } catch (erro) {
            console.error('Erro ao consultar CEP:', erro);
        }
    }

    // Configura o modal e o salvamento do CEP.
    function iniciarCep() {
        atualizarCep();

        // Abre o modal e preenche o CEP já salvo.
        $('#abrirCep')?.addEventListener('click', () => {
            const modal = $('#cepModal');

            if (modal) {
                modal.hidden = false;
                $('#cepInput').value = localStorage.getItem('martverdiCep') || '';
                $('#cepInput').focus();
            }
        });

        // Formata o CEP enquanto o usuário digita.
        $('#cepInput')?.addEventListener('input', e => {
            e.target.value = formatarCep(e.target.value);
        });

        // Fecha o modal quando o usuário clica em fechar.
        $$('[data-fechar-cep]').forEach(el => {
            el.addEventListener('click', () => {
                if ($('#cepModal')) $('#cepModal').hidden = true;
            });
        });

        // Valida e salva o CEP.
        $('#salvarCep')?.addEventListener('click', async () => {
            const cep = formatarCep($('#cepInput').value);
            const mensagem = $('#cepMensagem');

            if (cep.length !== 9) {
                mensagem.textContent = 'Digite um CEP válido com 8 números.';
                return;
            }

            try {
                // Verifica se existe uma sessão autenticada.
                const respostaUsuario = await fetch('/api/usuarios/me', {
                    credentials: 'same-origin'
                });

                if (respostaUsuario.ok) {
                    // Recupera os dados atuais do usuário.
                    const usuario = await respostaUsuario.json();

                    // Atualiza o CEP no banco sem alterar os outros dados.
                    const resposta = await fetch('/api/usuarios/me', {
                        method: 'PUT',
                        credentials: 'same-origin',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            nome: usuario.nome,
                            email: usuario.email,
                            dataNascimento: usuario.dataNascimento,
                            cep: cep,
                            senha: ''
                        })
                    });

                    const resultado = await resposta.json();

                    if (!resposta.ok) {
                        throw new Error(resultado.mensagem || 'Não foi possível atualizar o CEP.');
                    }
                }

                // Mantém o CEP no navegador para visitantes e compatibilidade.
                localStorage.setItem('martverdiCep', cep);

                // Atualiza o texto e informa que deu certo.
                await atualizarCep();
                mensagem.textContent = 'CEP salvo com sucesso!';

                setTimeout(() => {
                    $('#cepModal').hidden = true;
                }, 500);

            } catch (erro) {
                console.error('Erro ao salvar CEP:', erro);
                mensagem.textContent = erro.message || 'Erro ao salvar o CEP.';
            }
        });

        // Atualiza o CEP sempre que o usuário voltar para a página inicial.
        window.addEventListener('pageshow', () => {
            atualizarCep();
        });
    }

  // ---------- CARROSSEL ----------
  function iniciarCarrossel() {
    const track = $('#bannerTrack'); const slides = $$('.banner-slide'); const dots = $$('#bannerDots button'); if (!track || slides.length < 2) return;
    let atual = 0; let timer;
    const mostrar = indice => { atual = (indice + slides.length) % slides.length; track.style.transform = `translateX(-${atual * 25}%)`; dots.forEach((d,i) => d.classList.toggle('active', i === atual)); };
    const reiniciar = () => { clearInterval(timer); timer = setInterval(() => mostrar(atual + 1), 5000); };
    $('#bannerNext')?.addEventListener('click', () => { mostrar(atual + 1); reiniciar(); });
    $('.banner-next')?.addEventListener('click', () => { mostrar(atual + 1); reiniciar(); });
    $('.banner-prev')?.addEventListener('click', () => { mostrar(atual - 1); reiniciar(); });
    dots.forEach((d,i) => d.addEventListener('click', () => { mostrar(i); reiniciar(); }));
    const banner = $('.banner-carousel'); banner?.addEventListener('mouseenter', () => clearInterval(timer)); banner?.addEventListener('mouseleave', reiniciar);
    reiniciar();
  }

  // ---------- EVENTOS DA PÁGINA ----------
  function iniciarEventos() {
    $('#formBusca')?.addEventListener('submit', e => { e.preventDefault(); renderCatalogo(); $('#resultadoBusca')?.classList.remove('aberto'); document.querySelector('#alimentos')?.scrollIntoView({ behavior: 'smooth' }); });
    $('#campoBusca')?.addEventListener('input', () => { renderCatalogo(); mostrarSugestoes(); });
    document.addEventListener('click', e => { if (!e.target.closest('.busca-container')) $('#resultadoBusca')?.classList.remove('aberto'); });
    $$('.categoria-chip').forEach(btn => btn.addEventListener('click', () => selecionarCategoria(btn.dataset.categoria)));
    $$('.categoria-card').forEach(btn => btn.addEventListener('click', () => selecionarCategoria(btn.dataset.categoria)));
    $$('#departamentosMenu [data-categoria]').forEach(btn => btn.addEventListener('click', () => { selecionarCategoria(btn.dataset.categoria); $('#departamentosMenu').hidden = true; }));
    $('#btnDepartamentos')?.addEventListener('click', () => { $('#departamentosMenu').hidden = !$('#departamentosMenu').hidden; });
    $$('.filtro-categoria').forEach(check => check.addEventListener('change', renderCatalogo));
    ['precoMin','precoMax','somenteOfertas'].forEach(id => $(`#${id}`)?.addEventListener('input', renderCatalogo));
    $('#ordenarProdutos')?.addEventListener('change', renderCatalogo);
    $('#limparFiltros')?.addEventListener('click', () => { state.categoria = 'Todos'; $$('.categoria-chip').forEach((b,i) => b.classList.toggle('active', i === 0)); $$('.filtro-categoria').forEach(c => c.checked = false); $('#precoMin').value=''; $('#precoMax').value=''; $('#somenteOfertas').checked=false; $('#campoBusca').value=''; renderCatalogo(); });
  }

  // ---------- INICIALIZAÇÃO: carrega o JSON e monta a página. ----------
    fetch('/api/produtos')
    .then(res => { if (!res.ok) throw new Error('Catálogo indisponível'); return res.json(); })
    .then(produtos => { state.produtos = produtos; renderDestaques(); renderCatalogo(); iniciarEventos(); iniciarCep(); iniciarCarrossel(); atualizarCabecalho(); })
    .catch(erro => { console.error(erro); const vazio = $('#alimentosVazio'); if (vazio) { vazio.hidden = false; vazio.querySelector('h3').textContent = 'Não foi possível carregar o catálogo'; } });
})();
