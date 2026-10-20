const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pa_roubocarro';
const $ = (s) => document.querySelector(s);
let D = null;
let fimContrato = 0;
let relogio = null;

function post(nome, dados = {}) {
    return fetch(`https://${RES}/${nome}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(dados),
    }).then(r => r.json()).catch(() => ({}));
}
const acao = (nome, args = {}) => post('acao', { nome, args });

function esc(t) {
    return String(t ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
const selo = (k) => `<span class="selo" style="background:var(--${k})">${k}</span>`;

// ---------------------------------------------------------------- cabeçalho
function cabecalho() {
    const p = D.perfil;
    $('#nome').textContent = D.nome;
    $('#nivel').textContent = p.nivel;
    $('#moedas').textContent = p.moedas;
    $('#moedaNome').textContent = D.moeda.toUpperCase();
    $('#moedaRodape').textContent = D.moeda;
    $('#roubos').textContent = `${p.roubos} entrega${p.roubos === 1 ? '' : 's'}`;
    const classe = D.classes.find(c => c.chave === p.classe);
    $('#classeAtual').textContent = classe ? classe.label.split('·')[0].trim() : '';
    if (p.xpProx) {
        const pct = ((p.xp - p.xpAtual) / (p.xpProx - p.xpAtual)) * 100;
        $('#xpBarra').style.width = `${Math.max(0, Math.min(100, pct))}%`;
        $('#xpTexto').textContent = `${p.xp} / ${p.xpProx} XP`;
    } else {
        $('#xpBarra').style.width = '100%';
        $('#xpTexto').textContent = `${p.xp} XP · máximo`;
    }
}

// ---------------------------------------------------------------- contrato
function tempo(s) {
    s = Math.max(0, s);
    return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
}

function tickRelogio() {
    const el = $('#relogio');
    if (!el) return;
    const s = Math.max(0, Math.round((fimContrato - Date.now()) / 1000));
    el.textContent = tempo(s);
    el.classList.toggle('pouco', s < 180);
}

function abaContrato() {
    const ct = D.contrato;
    const el = $('#aba-contrato');
    if (ct) {
        fimContrato = Date.now() + ct.restante * 1000;
        const classe = D.classes.find(c => c.chave === ct.classe) || {};
        const etapas = [];
        if (ct.modo === 'local') {
            etapas.push(['Encontrar o carro na área do GPS', ct.pego]);
            etapas.push(['Arrombar e sair com ele', ct.pego]);
        } else {
            etapas.push(['Pegar um carro da lista na rua', ct.pego]);
        }
        if (classe.rastreador) etapas.push(['Desligar o rastreador', ct.pego && !ct.rastreador]);
        etapas.push(['Levar ao ponto de entrega', false]);
        let agora = false;
        const htmlEtapas = etapas.map(([t, feita]) => {
            let cls = feita ? 'feita' : '';
            if (!feita && !agora) { cls = 'agora'; agora = true; }
            return `<div class="etapa ${cls}"><span class="bola"></span>${esc(t)}</div>`;
        }).join('');

        el.innerHTML = `
            <div class="contrato-ativo">
                <div>
                    <div class="titulo-secao">${selo(ct.classe)} ${esc(ct.label)}</div>
                    <h2>${ct.modo === 'local' ? esc((ct.modelo || '').toUpperCase()) : 'Qualquer carro da lista'}</h2>
                    <p class="info">${ct.parceiro ? `Em dupla com <b>${esc(ct.parceiro)}</b>. Quem entregar fica com 70%.` : 'Contrato solo: tudo é seu.'}</p>
                    ${ct.modelos ? `<div class="modelos">${ct.modelos.map(m => `<span>${esc(m)}</span>`).join('')}</div>` : ''}
                    <div class="etapas">${htmlEtapas}</div>
                </div>
                <div class="lateral">
                    <div class="relogio" id="relogio">--:--</div>
                    ${ct.rastreador ? `<div class="alerta">Rastreador ligado: a polícia está vendo o carro.</div>
                        <button class="botao perigo" id="btnRastreador">Desligar rastreador</button>` : ''}
                    <button class="botao secundario" id="btnGps">Marcar GPS</button>
                    <button class="botao secundario" id="btnCancelar">Cancelar contrato</button>
                </div>
            </div>`;
        tickRelogio();
        $('#btnGps').onclick = () => post('gps');
        $('#btnCancelar').onclick = () => acao('cancelar');
        const r = $('#btnRastreador');
        if (r) r.onclick = () => post('rastreador', { etapas: D.etapasRastreador });
        return;
    }

    const lider = !D.dupla || D.dupla.souLider;
    el.innerHTML = `
        <div class="titulo-secao">Escolha a encomenda ${D.dupla && D.dupla.parceiro ? '· em dupla' : '· solo'}</div>
        ${lider ? '' : '<p class="info" style="margin-bottom:10px">Quem pede o contrato é quem montou a dupla.</p>'}
        <div class="grade">
            ${D.classes.map(c => `
                <div class="cartao ${c.liberada ? '' : 'bloqueado'}">
                    <h3>${selo(c.chave)} ${esc(c.label.split('·')[1] || c.label)}</h3>
                    <div class="linha"><span>XP</span><b>${c.xp}</b></div>
                    <div class="linha"><span>${esc(D.moeda)}</span><b>${c.moedas}</b></div>
                    <div class="linha"><span>Tempo</span><b>${c.tempo} min</b></div>
                    <p>${c.modo === 'rua' ? 'Qualquer um da lista, na rua.' : 'Carro estacionado num ponto.'}${c.rastreador ? ' Tem rastreador.' : ''}</p>
                    <button class="botao" data-classe="${c.chave}" ${c.liberada && lider ? '' : 'disabled'}>
                        ${c.liberada ? 'Pedir contrato' : `Nível ${c.nivelMin}`}
                    </button>
                </div>`).join('')}
        </div>`;
    el.querySelectorAll('[data-classe]').forEach(b => b.onclick = () => acao('pedir', { classe: b.dataset.classe }));
}

// ---------------------------------------------------------------- dupla
function abaDupla() {
    const el = $('#aba-dupla');
    const d = D.dupla;
    let html = '<div class="titulo-secao">Roubo em dupla</div><p class="info">Os dois ganham: 70% para quem entregar o carro e 30% para o parceiro (XP e moedas).</p>';
    if (d) {
        html += `<div class="cartao" style="margin-top:12px;max-width:420px">
            <div class="linha"><span>Líder</span><b>${esc(d.lider)}</b></div>
            <div class="linha"><span>Parceiro</span><b>${esc(d.parceiro || 'aguardando...')}</b></div>
            ${d.souLider && !d.parceiro ? convidarHtml() : ''}
            <button class="botao secundario" id="btnSair">Sair da dupla</button>
        </div>`;
    } else {
        html += `<div class="cartao" style="margin-top:12px;max-width:420px">
            <p>Convide alguém pelo ID. Ele também precisa ter um tablet.</p>
            ${convidarHtml()}
            <button class="botao secundario" id="btnAceitar">Aceitar convite recebido</button>
        </div>`;
    }
    el.innerHTML = html;
    const conv = $('#btnConvidar');
    if (conv) conv.onclick = () => { const id = $('#idConvite').value.trim(); if (id) acao('convidar', { id }); };
    const sair = $('#btnSair'); if (sair) sair.onclick = () => acao('sairDupla');
    const ac = $('#btnAceitar'); if (ac) ac.onclick = () => acao('aceitar');
}
const convidarHtml = () => `<div class="campo"><input id="idConvite" type="number" placeholder="ID do parceiro"><button class="botao" id="btnConvidar">Convidar</button></div>`;

// ---------------------------------------------------------------- ofertas
function abaOfertas() {
    const el = $('#aba-ofertas');
    if (!D.ofertas.length) {
        el.innerHTML = '<div class="vazio">Nenhum carro disponível.<br>Os carros que você entregar ficam aqui por 24h para comprar com chassi riscado.</div>';
        return;
    }
    el.innerHTML = `<div class="titulo-secao">Comprar com chassi riscado</div><div class="grade">
        ${D.ofertas.map(o => `
            <div class="cartao">
                <h3>${selo(o.classe)} ${esc(o.modelo.toUpperCase())}</h3>
                <div class="linha"><span>Preço</span><b>${o.preco} ${esc(D.moeda)}</b></div>
                <div class="linha"><span>Expira em</span><b>${o.horas}h</b></div>
                <button class="botao" data-oferta="${o.id}" ${D.perfil.moedas >= o.preco ? '' : 'disabled'}>Comprar</button>
            </div>`).join('')}
    </div>`;
    el.querySelectorAll('[data-oferta]').forEach(b => b.onclick = () => acao('comprar', { id: Number(b.dataset.oferta) }));
}

// ---------------------------------------------------------------- melhorias
function abaMelhorias() {
    const el = $('#aba-melhorias');
    el.innerHTML = `<div class="titulo-secao">Melhorias do tablet</div><div class="grade">
        ${D.melhorias.map(m => `
            <div class="cartao">
                <h3>${esc(m.label)}</h3>
                <p>${esc(m.descricao)}</p>
                <div class="pontos">${Array.from({ length: m.max }, (_, i) => `<i class="${i < m.nivel ? 'on' : ''}"></i>`).join('')}</div>
                <button class="botao" data-melhoria="${m.chave}" ${m.preco && D.perfil.moedas >= m.preco ? '' : 'disabled'}>
                    ${m.preco ? `${m.preco} ${esc(D.moeda)}` : 'Máximo'}
                </button>
            </div>`).join('')}
    </div>`;
    el.querySelectorAll('[data-melhoria]').forEach(b => b.onclick = () => acao('melhoria', { chave: b.dataset.melhoria }));
}

// ---------------------------------------------------------------- garagem (riscados)
function abaGaragem() {
    const el = $('#aba-garagem');
    if (!D.riscados.length) {
        el.innerHTML = '<div class="vazio">Você não tem carros de chassi riscado.</div>';
        return;
    }
    el.innerHTML = `<div class="titulo-secao">Seus carros de chassi riscado</div>
        <p class="info" style="margin-bottom:10px">Combine o preço no RP e passe o carro para o comprador (ele precisa estar do seu lado). Cuidado: a vistoria da polícia identifica o chassi.</p>
        <div class="grade">
        ${D.riscados.map(r => `
            <div class="cartao">
                <h3>${esc(String(r.modelo).toUpperCase())}</h3>
                <div class="linha"><span>Placa</span><b>${esc(r.plate)}</b></div>
                <div class="campo"><input type="number" placeholder="ID" data-id="${esc(r.plate)}"><button class="botao" data-vender="${esc(r.plate)}">Passar</button></div>
            </div>`).join('')}
    </div>`;
    el.querySelectorAll('[data-vender]').forEach(b => b.onclick = () => {
        const id = el.querySelector(`input[data-id="${b.dataset.vender}"]`).value.trim();
        if (id) acao('transferir', { placa: b.dataset.vender, id });
    });
}

function render() {
    if (!D) return;
    cabecalho();
    abaContrato();
    abaDupla();
    abaOfertas();
    abaMelhorias();
    abaGaragem();
}

// ---------------------------------------------------------------- navegação
document.querySelectorAll('nav button').forEach(b => b.onclick = () => {
    document.querySelectorAll('nav button').forEach(x => x.classList.toggle('ativa', x === b));
    document.querySelectorAll('.aba').forEach(a => a.classList.toggle('ativa', a.id === `aba-${b.dataset.aba}`));
});

$('#fechar').onclick = () => post('fechar');
document.addEventListener('keydown', e => { if (e.key === 'Escape') post('fechar'); });

window.addEventListener('message', ({ data }) => {
    if (data.acao === 'abrir') {
        D = data.dados;
        render();
        $('#tablet').classList.remove('oculto');
        clearInterval(relogio);
        relogio = setInterval(tickRelogio, 1000);
    } else if (data.acao === 'atualizar') {
        D = data.dados;
        render();
    } else if (data.acao === 'fechar') {
        $('#tablet').classList.add('oculto');
        clearInterval(relogio);
    }
});
