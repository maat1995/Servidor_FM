// Pista & Asfalto - tela da cabine de pintura e da oficina de estética
const RECURSO = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
const $ = id => document.getElementById(id);

let estado = null;       // dados do jogo para a sessão aberta
let alvoAtual = null;    // pintura: qual parte está sendo pintada
let abaCor = 'rgb';      // pintura: 'rgb' | 'fabrica'
let hsv = { h: 0, s: 0, v: 0 };
let acabamento = 0;
let categoriaAtual = null;
let clienteEscolhido = null;
const rolagens = {};     // posição da rolagem de cada lista, para não pular ao escolher

// ---------------------------------------------------------------------
// Comunicação com o jogo
// ---------------------------------------------------------------------
async function enviar(nome, dados = {}) {
    if (!RECURSO) return Teste.responder(nome, dados);
    try {
        const r = await fetch(`https://${RECURSO}/${nome}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(dados),
        });
        return await r.json();
    } catch { return null; }
}

window.addEventListener('message', ({ data }) => {
    if (data.acao === 'abrir') abrir(data);
    if (data.acao === 'fechar') fecharTela();
});

document.addEventListener('keydown', e => {
    if (e.key !== 'Escape' || !estado) return;
    if (!$('cobranca').classList.contains('oculto')) return fecharCobranca();
    cancelar();
});

// ---------------------------------------------------------------------
// Abrir / fechar
// ---------------------------------------------------------------------
function abrir(d) {
    estado = d;
    $('placa').textContent = d.placa || '---';
    $('modelo').textContent = d.modelo || '';
    const pintura = d.tipo === 'pintura';
    $('titulo').textContent = pintura ? 'Cabine de pintura' : 'Estética automotiva';
    $('subtitulo').textContent = pintura ? 'Escolha a cor e veja ao vivo' : 'Teste as peças antes de cobrar';
    $('modo-pintura').classList.toggle('oculto', !pintura);
    $('modo-estetica').classList.toggle('oculto', pintura);
    $('carrinho-lista').classList.add('oculto');
    fecharCobranca();
    if (pintura) {
        montarAlvos();
        escolherAlvo(d.alvos[0].id);
    } else {
        montarCategorias();
        if (d.categorias.length) escolherCategoria(d.categorias[0].id);
        else $('grupos').innerHTML = '<p class="vazio">Esse carro não tem peças de estética.</p>';
    }
    atualizarCarrinho(d.carrinho);
    $('app').classList.remove('oculto');
}

function fecharTela() {
    estado = null;
    $('app').classList.add('oculto');
}

function cancelar() {
    if (!estado) return;
    fecharTela();
    enviar('cancelar');
}

// ---------------------------------------------------------------------
// Carrinho
// ---------------------------------------------------------------------
function atualizarCarrinho(c) {
    if (!c) return;
    estado.carrinho = c;
    const n = c.itens.length;
    $('carrinho-qtd').textContent = n === 0 ? 'Nada mudado ainda' : `${n} ${n === 1 ? 'item mudado' : 'itens mudados'} · ver lista`;
    $('carrinho-total').textContent = `$${c.total}`;
    $('btn-cobrar').disabled = n === 0;
    $('carrinho-lista').innerHTML = c.itens.map(i => `<li><span>${esc(i.label)}</span><span>$${i.preco}</span></li>`).join('');
    if (n === 0) $('carrinho-lista').classList.add('oculto');
    marcarMudancas();
}

function marcarMudancas() {
    const ids = new Set((estado.carrinho?.itens || []).map(i => i.id));
    document.querySelectorAll('.alvo').forEach(b => b.classList.toggle('mudou', ids.has(b.dataset.id)));
    document.querySelectorAll('.categoria').forEach(b => {
        const pref = PREFIXOS[b.dataset.id] || [];
        b.classList.toggle('mudou', [...ids].some(id => pref.some(p => id.startsWith(p))));
    });
}

$('btn-carrinho').onclick = () => {
    if (estado?.carrinho?.itens.length) $('carrinho-lista').classList.toggle('oculto');
};

function esc(t) {
    return String(t).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
}

// ---------------------------------------------------------------------
// Pintura
// ---------------------------------------------------------------------
const NOMES_ACABAMENTO = ['Normal', 'Metálico', 'Perolado', 'Fosco', 'Metal', 'Cromado'];

function hexDaPaleta(id) {
    for (const g of estado.paleta) for (const c of g.cores) if (c.id === id) return c.hex;
    return null;
}

function corDoValor(v) {
    if (v == null) return null;
    if (typeof v === 'number') return hexDaPaleta(v);
    if (v.m === 'rgb') return rgbHex(v.r, v.g, v.b);
    return hexDaPaleta(v.id);
}

function montarAlvos() {
    $('alvos').innerHTML = estado.alvos.map(a =>
        `<button class="alvo" data-id="${a.id}"><i></i><span>${esc(a.label)}</span></button>`).join('');
    document.querySelectorAll('.alvo').forEach(b => b.onclick = () => escolherAlvo(b.dataset.id));
    pintarBolinhas();
}

function pintarBolinhas() {
    document.querySelectorAll('.alvo').forEach(b => {
        const cor = corDoValor(estado.valores[b.dataset.id]);
        b.querySelector('i').style.background = cor || '';
    });
}

function alvoInfo() { return estado.alvos.find(a => a.id === alvoAtual); }

function escolherAlvo(id) {
    alvoAtual = id;
    document.querySelectorAll('.alvo').forEach(b => b.classList.toggle('ativo', b.dataset.id === id));
    const info = alvoInfo();
    const v = estado.valores[id];
    const ehCor = info.tipo === 'cor';
    $('seg-cor').classList.toggle('oculto', !ehCor);
    if (!ehCor) abaCor = 'fabrica';
    else abaCor = v && v.m === 'rgb' ? 'rgb' : 'fabrica';
    if (ehCor && v && v.m === 'rgb') {
        hsv = rgbHsv(v.r, v.g, v.b);
        acabamento = v.f || 0;
    } else if (ehCor) {
        const h = corDoValor(v);
        if (h) hsv = rgbHsv(...hexRgb(h));
    }
    mostrarAba();
    enviar('alvo', { id });
}

function mostrarAba() {
    document.querySelectorAll('#seg-cor button').forEach(b => b.classList.toggle('ativo', b.dataset.aba === abaCor));
    $('bloco-cor').classList.toggle('oculto', alvoInfo().tipo !== 'cor');
    $('aba-rgb').classList.toggle('oculto', abaCor !== 'rgb');
    $('aba-fabrica').classList.toggle('oculto', abaCor !== 'fabrica');
    if (abaCor === 'rgb') desenharSeletor();
    else montarPaleta();
}

document.querySelectorAll('#seg-cor button').forEach(b => b.onclick = () => { abaCor = b.dataset.aba; mostrarAba(); });

function montarPaleta() {
    const v = estado.valores[alvoAtual];
    const ehCor = alvoInfo().tipo === 'cor';
    const atualId = typeof v === 'number' ? v : (v && v.m === 'cor' ? v.id : null);
    $('aba-fabrica').innerHTML = estado.paleta.map(g => `
        <div class="paleta-grupo">
            <h3>${esc(g.grupo)}</h3>
            <div class="swatches">${g.cores.map(c =>
                `<button class="swatch${c.id === atualId ? ' ativo' : ''}" data-id="${c.id}" title="${esc(c.label)}"
                    style="${c.hex ? `background:${c.hex}` : ''}"></button>`).join('')}</div>
        </div>`).join('') + '<p class="swatch-nome" id="swatch-nome"></p>';
    $('aba-fabrica').querySelectorAll('.swatch').forEach(s => {
        s.onmouseenter = () => { $('swatch-nome').textContent = s.title; };
        s.onclick = () => {
            const id = Number(s.dataset.id);
            escolher(alvoAtual, ehCor ? { m: 'cor', id } : id);
            $('aba-fabrica').querySelectorAll('.swatch').forEach(x => x.classList.toggle('ativo', x === s));
        };
    });
}

// Seletor de cor (saturação × brilho + matiz)
const sv = $('sv');
function desenharSeletor() {
    const ctx = sv.getContext('2d');
    const w = sv.width, h = sv.height;
    ctx.fillStyle = `hsl(${hsv.h}, 100%, 50%)`;
    ctx.fillRect(0, 0, w, h);
    const branco = ctx.createLinearGradient(0, 0, w, 0);
    branco.addColorStop(0, '#fff'); branco.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = branco; ctx.fillRect(0, 0, w, h);
    const preto = ctx.createLinearGradient(0, 0, 0, h);
    preto.addColorStop(0, 'rgba(0,0,0,0)'); preto.addColorStop(1, '#000');
    ctx.fillStyle = preto; ctx.fillRect(0, 0, w, h);
    $('sv-marca').style.left = `${hsv.s * 100}%`;
    $('sv-marca').style.top = `${(1 - hsv.v) * 100}%`;
    $('matiz').value = hsv.h;
    const [r, g, b] = hsvRgb(hsv.h, hsv.s, hsv.v);
    const hx = rgbHex(r, g, b);
    $('amostra').style.background = hx;
    if (document.activeElement !== $('hex')) $('hex').value = hx.toUpperCase();
    $('rgb-texto').textContent = `${r} · ${g} · ${b}`;
    document.querySelectorAll('#acabamentos button').forEach(x => x.classList.toggle('ativo', Number(x.dataset.f) === acabamento));
}

let timerCor = null;
function enviarCorRgb() {
    clearTimeout(timerCor);
    timerCor = setTimeout(() => {
        const [r, g, b] = hsvRgb(hsv.h, hsv.s, hsv.v);
        escolher(alvoAtual, { m: 'rgb', r, g, b, f: acabamento });
    }, 70);
}

function moverSV(e) {
    const rect = sv.getBoundingClientRect();
    hsv.s = Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width));
    hsv.v = Math.min(1, Math.max(0, 1 - (e.clientY - rect.top) / rect.height));
    desenharSeletor();
    enviarCorRgb();
}
sv.addEventListener('pointerdown', e => {
    sv.setPointerCapture(e.pointerId);
    moverSV(e);
    sv.onpointermove = moverSV;
});
sv.addEventListener('pointerup', () => { sv.onpointermove = null; });
$('matiz').oninput = () => { hsv.h = Number($('matiz').value); desenharSeletor(); enviarCorRgb(); };
$('hex').oninput = () => {
    const v = $('hex').value.trim();
    if (/^#?[0-9a-f]{6}$/i.test(v)) {
        hsv = rgbHsv(...hexRgb(v.startsWith('#') ? v : '#' + v));
        desenharSeletor();
        enviarCorRgb();
    }
};
document.querySelectorAll('#acabamentos button').forEach(b => b.onclick = () => {
    acabamento = Number(b.dataset.f);
    desenharSeletor();
    enviarCorRgb();
});

// ---------------------------------------------------------------------
// Estética
// ---------------------------------------------------------------------
const ICONES = {
    frente: '<path d="M3 15h18M5 15l1.5-5h11L19 15M7 15v3m10-3v3M8 12h8"/><circle cx="7.5" cy="13.2" r=".6"/><circle cx="16.5" cy="13.2" r=".6"/>',
    traseira: '<path d="M3 9h18M6 9V6h12v3M4 13h16v3H4zM7 16v2m10-2v2"/>',
    lateral: '<path d="M2 15h20M4 15l2-4 4-2h5l4 3 2 1v2"/><circle cx="7" cy="16" r="2"/><circle cx="17" cy="16" r="2"/>',
    rodas: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2.5"/><path d="M12 4v5.5M12 14.5V20M4 12h5.5M14.5 12H20"/>',
    luzes: '<path d="M10 7c-4 0-6 2.5-6 5s2 5 6 5V7z"/><path d="M14 8h6M14 12h7M14 16h6"/>',
    vidros: '<path d="M4 18l3-11h10l3 11z"/><path d="M9 9l-1.5 6M13 9l-1.5 6"/>',
    interior: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="2"/><path d="M4.5 10.5h5.5M14 10.5h5.5M12 14v6"/>',
    motor: '<path d="M4 9h3l2-2h5l2 2h2v3h2v-2h1v6h-1v-2h-2v3h-3l-2 2H9l-2-2H4z"/>',
    placa: '<rect x="3" y="7" width="18" height="10" rx="1.5"/><path d="M3 9.5h18M7 13.5h2M11 13.5h2M15 13.5h2"/>',
    adesivos: '<path d="M5 19l4-14h2L7 19zM11 19l4-14h2l-4 14z"/>',
    extras: '<path d="M12 5v14M5 12h14"/><circle cx="12" cy="12" r="8"/>',
    buzina: '<path d="M4 10h3l6-4v12l-6-4H4z"/><path d="M16 9c1 .8 1.5 1.8 1.5 3s-.5 2.2-1.5 3M18.5 7c1.6 1.3 2.5 3 2.5 5s-.9 3.7-2.5 5"/>',
};
const PREFIXOS = {
    frente: ['mod:1', 'mod:6', 'mod:7', 'mod:8', 'mod:9'],
    traseira: ['mod:2', 'mod:0', 'mod:4', 'mod:37'],
    lateral: ['mod:3', 'mod:10', 'mod:5', 'mod:42', 'mod:43', 'mod:44', 'mod:46', 'mod:47', 'mod:49'],
    rodas: ['roda:', 'fumaca:'],
    luzes: ['xenon:', 'neon:'],
    vidros: ['insulfilm'],
    interior: ['mod:27', 'mod:29', 'mod:30', 'mod:31', 'mod:32', 'mod:33', 'mod:34', 'mod:35', 'mod:36', 'mod:28'],
    motor: ['mod:39', 'mod:40', 'mod:41', 'mod:45', 'mod:38'],
    placa: ['placa', 'mod:25', 'mod:26'],
    adesivos: ['adesivo', 'mod:48'],
    extras: ['extra:'],
    buzina: ['buzina'],
};

function montarCategorias() {
    $('categorias').innerHTML = estado.categorias.map(c => `
        <button class="categoria" data-id="${c.id}">
            <svg viewBox="0 0 24 24">${ICONES[c.id] || ICONES.extras}</svg>
            <span>${esc(c.label)}</span>
        </button>`).join('');
    document.querySelectorAll('.categoria').forEach(b => b.onclick = () => escolherCategoria(b.dataset.id));
}

async function escolherCategoria(id) {
    categoriaAtual = id;
    document.querySelectorAll('.categoria').forEach(b => b.classList.toggle('ativo', b.dataset.id === id));
    const r = await enviar('categoria', { id });
    if (!r || categoriaAtual !== id) return;
    $('grupos').scrollTop = 0;
    montarGrupos(r.grupos || []);
    atualizarCarrinho(r.carrinho);
}

function igual(a, b) { return JSON.stringify(a) === JSON.stringify(b); }

function montarGrupos(grupos) {
    // guarda a rolagem das listas antes de redesenhar
    document.querySelectorAll('.lista[data-grupo]').forEach(l => { rolagens[l.dataset.grupo] = l.scrollTop; });
    const rolGeral = $('grupos').scrollTop;
    $('grupos').innerHTML = grupos.map(g => {
        if (g.tipo === 'toggle') {
            return `<div class="grupo"><button class="interruptor${g.atual ? ' ligado' : ''}" data-grupo="${g.id}">
                <span>${esc(g.label)}</span><i></i></button></div>`;
        }
        const atualNome = (g.opcoes.find(o => igual(o.v, g.atual)) || {}).label || '';
        if (g.tipo === 'cores') {
            return `<div class="grupo"><h3>${esc(g.label)}<em>${esc(atualNome)}</em></h3>
                <div class="swatches">${g.opcoes.map((o, i) => `<button class="swatch${igual(o.v, g.atual) ? ' ativo' : ''}"
                    data-grupo="${g.id}" data-i="${i}" title="${esc(o.label)}" style="background:${o.hex}"></button>`).join('')}</div></div>`;
        }
        if (g.tipo === 'chips') {
            return `<div class="grupo"><h3>${esc(g.label)}</h3><div class="chips">${g.opcoes.map((o, i) =>
                `<button class="${igual(o.v, g.atual) ? 'ativo' : ''}" data-grupo="${g.id}" data-i="${i}">${esc(o.label)}</button>`).join('')}</div></div>`;
        }
        return `<div class="grupo"><h3>${esc(g.label)}<em>${g.opcoes.length - 1} opções</em></h3>
            <div class="lista" data-grupo="${g.id}">${g.opcoes.map((o, i) =>
                `<button class="opcao${igual(o.v, g.atual) ? ' ativo' : ''}${o.v === -1 ? ' original' : ''}" data-grupo="${g.id}" data-i="${i}">${esc(o.label)}</button>`).join('')}</div></div>`;
    }).join('') || '<p class="vazio">Nada para mudar nesta parte desse carro.</p>';

    $('grupos').scrollTop = rolGeral;
    document.querySelectorAll('.lista[data-grupo]').forEach(l => { l.scrollTop = rolagens[l.dataset.grupo] || 0; });

    const porId = Object.fromEntries(grupos.map(g => [g.id, g]));
    $('grupos').querySelectorAll('[data-grupo]').forEach(el => {
        if (el.classList.contains('lista')) return;
        el.onclick = () => {
            const g = porId[el.dataset.grupo];
            const valor = g.tipo === 'toggle' ? !g.atual : g.opcoes[Number(el.dataset.i)].v;
            escolher(g.id, valor);
        };
    });
}

// ---------------------------------------------------------------------
// Escolher (pintura e estética)
// ---------------------------------------------------------------------
async function escolher(grupo, valor) {
    const r = await enviar('escolher', { grupo, valor });
    if (!r || !estado) return;
    if (r.valores) { estado.valores = r.valores; pintarBolinhas(); }
    if (r.grupos) montarGrupos(r.grupos);
    atualizarCarrinho(r.carrinho);
}

// ---------------------------------------------------------------------
// Cobrança
// ---------------------------------------------------------------------
$('btn-cancelar').onclick = cancelar;
$('btn-cobrar').onclick = async () => {
    clienteEscolhido = null;
    $('btn-enviar').disabled = true;
    $('cobranca-total').textContent = `$${estado.carrinho.total}`;
    $('cobranca-status').textContent = 'Procurando quem está perto...';
    $('cobranca-status').className = 'status-cobranca';
    $('clientes').innerHTML = '';
    $('cobranca').classList.remove('oculto');
    const lista = await enviar('clientes') || [];
    $('cobranca-status').textContent = lista.length > 1 ? '' : 'Ninguém perto: só dá para cobrar de você mesmo.';
    $('clientes').innerHTML = lista.map(c => `<button class="cliente" data-id="${c.id}">${esc(c.nome)}</button>`).join('');
    document.querySelectorAll('.cliente').forEach(b => b.onclick = () => {
        clienteEscolhido = Number(b.dataset.id);
        document.querySelectorAll('.cliente').forEach(x => x.classList.toggle('ativo', x === b));
        $('btn-enviar').disabled = false;
    });
};
function fecharCobranca() { $('cobranca').classList.add('oculto'); }
$('btn-voltar').onclick = fecharCobranca;
$('btn-enviar').onclick = async () => {
    if (clienteEscolhido == null) return;
    $('btn-enviar').disabled = true;
    $('btn-voltar').disabled = true;
    $('cobranca-status').className = 'status-cobranca espera';
    $('cobranca-status').textContent = 'Aguardando o cliente aceitar...';
    const r = await enviar('cobrar', { alvo: clienteEscolhido });
    $('btn-voltar').disabled = false;
    if (r && r.ok) return; // o jogo fecha a tela e começa o serviço
    $('btn-enviar').disabled = false;
    $('cobranca-status').className = 'status-cobranca erro';
    $('cobranca-status').textContent = (r && r.msg) || 'Não foi possível cobrar';
};

// ---------------------------------------------------------------------
// Câmera: arrastar gira, rodinha aproxima
// ---------------------------------------------------------------------
let arrasto = null;
$('palco').addEventListener('pointerdown', e => {
    arrasto = { x: e.clientX, y: e.clientY };
    $('palco').classList.add('arrastando');
    $('palco').setPointerCapture(e.pointerId);
});
$('palco').addEventListener('pointermove', e => {
    if (!arrasto) return;
    const dx = e.clientX - arrasto.x, dy = e.clientY - arrasto.y;
    arrasto = { x: e.clientX, y: e.clientY };
    enviar('camMover', { dx, dy });
});
$('palco').addEventListener('pointerup', () => { arrasto = null; $('palco').classList.remove('arrastando'); });
$('palco').addEventListener('wheel', e => enviar('camZoom', { delta: e.deltaY }), { passive: true });

// ---------------------------------------------------------------------
// Conversões de cor
// ---------------------------------------------------------------------
function rgbHex(r, g, b) { return '#' + [r, g, b].map(x => Math.round(x).toString(16).padStart(2, '0')).join(''); }
function hexRgb(h) { const n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
function hsvRgb(h, s, v) {
    const f = n => { const k = (n + h / 60) % 6; return v - v * s * Math.max(0, Math.min(k, 4 - k, 1)); };
    return [f(5), f(3), f(1)].map(x => Math.round(x * 255));
}
function rgbHsv(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
    let h = 0;
    if (d) {
        if (max === r) h = ((g - b) / d) % 6;
        else if (max === g) h = (b - r) / d + 2;
        else h = (r - g) / d + 4;
        h = (h * 60 + 360) % 360;
    }
    return { h, s: max ? d / max : 0, v: max };
}

// ---------------------------------------------------------------------
// Teste no navegador (fora do FiveM): index.html#pintura ou #estetica
// ---------------------------------------------------------------------
const Teste = {
    estado: {},
    carrinho() {
        const itens = Object.keys(this.estado).map(id => ({ id, label: this.nomes[id] || id, preco: 1 }));
        return { itens, total: itens.length };
    },
    nomes: {},
    grupos: {},
    responder(nome, d) {
        if (nome === 'categoria') return { grupos: this.grupos[d.id] || [], carrinho: this.carrinho() };
        if (nome === 'escolher') {
            this.estado[d.grupo] = d.valor;
            const r = { carrinho: this.carrinho() };
            if (estado.tipo === 'pintura') { estado.valores[d.grupo] = d.valor; r.valores = estado.valores; }
            else {
                const lista = this.grupos[categoriaAtual] || [];
                lista.forEach(g => { if (g.id === d.grupo) g.atual = d.valor; });
                r.grupos = lista;
            }
            return r;
        }
        if (nome === 'clientes') return [{ id: 1, nome: 'Eu mesmo (Maia Mateus)' }, { id: 7, nome: 'João Silva (ID 7)' }];
        if (nome === 'cobrar') return new Promise(res => setTimeout(() => res({ ok: false, msg: 'O cliente recusou a cobrança' }), 1200));
        return {};
    },
};

if (!RECURSO && (location.hash === '#pintura' || location.hash === '#estetica')) {
    const cores = n => Array.from({ length: n }, (_, i) => ({ id: i, label: `Cor ${i}`, hex: `hsl(${(i * 37) % 360},${40 + (i % 3) * 20}%,${30 + (i % 4) * 12}%)` }));
    if (location.hash === '#pintura') {
        abrir({
            tipo: 'pintura', placa: 'PA 2026', modelo: 'Sultan RS',
            alvos: [
                { id: 'pint:primaria', label: 'Cor principal', tipo: 'cor' }, { id: 'pint:secundaria', label: 'Cor secundária', tipo: 'cor' },
                { id: 'pint:perolado', label: 'Perolado', tipo: 'paleta' }, { id: 'pint:roda', label: 'Cor das rodas', tipo: 'paleta' },
                { id: 'pint:interior', label: 'Interior', tipo: 'paleta' }, { id: 'pint:painel', label: 'Painel', tipo: 'paleta' },
            ],
            valores: { 'pint:primaria': { m: 'rgb', r: 214, g: 32, b: 46, f: 1 }, 'pint:secundaria': { m: 'cor', id: 3 }, 'pint:perolado': 5, 'pint:roda': 1, 'pint:interior': 0, 'pint:painel': 0 },
            paleta: [{ grupo: 'Clássicas', cores: cores(40) }, { grupo: 'Foscas', cores: cores(20) }, { grupo: 'Metais', cores: cores(6) }],
            carrinho: { itens: [], total: 0 },
        });
    } else {
        const lista = (n, nome) => [{ v: -1, label: 'Original de fábrica' }, ...Array.from({ length: n }, (_, i) => ({ v: i, label: `${nome} ${i + 1}` }))];
        Teste.grupos = {
            frente: [
                { id: 'mod:1', label: 'Para-choque dianteiro', tipo: 'lista', opcoes: lista(6, 'Para-choque'), atual: 2 },
                { id: 'mod:7', label: 'Capô', tipo: 'lista', opcoes: lista(9, 'Capô de fibra'), atual: -1 },
                { id: 'mod:6', label: 'Grade', tipo: 'lista', opcoes: lista(3, 'Grade'), atual: -1 },
            ],
            rodas: [
                { id: 'roda:tipo', label: 'Tipo de roda', tipo: 'chips', opcoes: ['Esportiva', 'Muscle', 'Lowrider', 'SUV', 'Off-road', 'Tuner', 'Luxo', 'Rua', 'Pista'].map((l, i) => ({ v: i, label: l })), atual: 0 },
                { id: 'roda:modelo', label: 'Modelo da roda', tipo: 'lista', opcoes: lista(24, 'Roda'), atual: 3 },
                { id: 'roda:pneu', label: 'Pneu de faixa branca / personalizado', tipo: 'toggle', atual: false },
                { id: 'fumaca:cor', label: 'Cor da fumaça', tipo: 'cores', opcoes: [[254, 254, 254], [1, 1, 1], [0, 150, 255], [255, 10, 10], [10, 255, 10]].map((c, i) => ({ v: c, label: `Fumaça ${i + 1}`, hex: rgbHex(...c) })), atual: [254, 254, 254] },
            ],
        };
        abrir({
            tipo: 'estetica', placa: 'PA 2026', modelo: 'Sultan RS',
            categorias: [
                { id: 'frente', label: 'Dianteira' }, { id: 'traseira', label: 'Traseira' }, { id: 'lateral', label: 'Laterais e teto' },
                { id: 'rodas', label: 'Rodas' }, { id: 'luzes', label: 'Neon e faróis' }, { id: 'vidros', label: 'Insulfilm' },
                { id: 'interior', label: 'Interior' }, { id: 'motor', label: 'Motor (visual)' }, { id: 'placa', label: 'Placa' },
                { id: 'adesivos', label: 'Adesivos' }, { id: 'extras', label: 'Extras' }, { id: 'buzina', label: 'Buzina' },
            ],
            carrinho: { itens: [], total: 0 },
        });
    }
}
