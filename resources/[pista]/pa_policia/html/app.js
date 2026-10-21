// pa_policia · tablet (MDT) e radar móvel
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pa_policia';
const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];
const arr = (x) => (Array.isArray(x) ? x : Object.values(x || {}));
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const dinheiro = (v) => '$' + Number(v || 0).toLocaleString('pt-BR');

let D = null;          // dados do abrir (eu, patentes, codigo, ocorrencias, equipe)
let abaAtual = 'inicio';

// ------------------------------------------------------------------ comunicação
async function post(nome, dados) {
    const r = await fetch(`https://${RES}/${nome}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(dados || {}) });
    try { return await r.json(); } catch { return null; }
}
// chama um callback do servidor; retorna a lista de valores
async function srv(cb, ...args) {
    const r = await post('mdt', { cb, args });
    return arr(r);
}
async function acao(cb, ...args) {
    const [ok, msg, extra] = await srv(cb, ...args);
    toast(msg || (ok ? 'Feito.' : 'Não foi possível.'), ok ? 'ok' : 'erro');
    return [ok, msg, extra];
}

function toast(msg, tipo) {
    const t = $('#toast');
    t.textContent = msg;
    t.className = tipo || '';
    clearTimeout(toast._t);
    toast._t = setTimeout(() => t.classList.add('oculto'), 4200);
}

const pode = (p) => !!(D && D.eu.perms && D.eu.perms[p]);
const patente = (g) => (D && D.patentes ? (D.patentes[g] ?? D.patentes[String(g)] ?? `Grau ${g}`) : g);

// ------------------------------------------------------------------ modal
function modal(titulo, corpoHtml, botoes) {
    $('#modal-titulo').textContent = titulo;
    $('#modal-corpo').innerHTML = corpoHtml;
    const caixa = $('#modal-botoes');
    caixa.innerHTML = '';
    const fechar = { texto: 'Cancelar', fn: () => fecharModal() };
    for (const b of [...(botoes || []), fechar]) {
        const el = document.createElement('button');
        el.className = 'btn ' + (b.classe || '');
        el.textContent = b.texto;
        el.onclick = b.fn;
        caixa.appendChild(el);
    }
    $('#modal').classList.remove('oculto');
    const primeiro = $('#modal-corpo input, #modal-corpo textarea, #modal-corpo select');
    if (primeiro) primeiro.focus();
}
function fecharModal() { $('#modal').classList.add('oculto'); }

// ------------------------------------------------------------------ navegação
const TITULOS = {
    inicio: 'Início', pessoas: 'Pessoas', veiculos: 'Veículos', bos: 'Boletins de ocorrência',
    mandados: 'Mandados', codigo: 'Código penal', evidencias: 'Apreensões e perícia', equipe: 'Equipe da LSPD',
};

function irPara(aba, arg) {
    abaAtual = aba;
    $$('#abas button').forEach((b) => b.classList.toggle('ativa', b.dataset.aba === aba));
    $('#titulo-aba').textContent = TITULOS[aba] || '';
    const p = $('#pagina');
    p.innerHTML = '<div class="vazio">Carregando...</div>';
    p.scrollTop = 0;
    PAGINAS[aba](p, arg);
}

$$('#abas button').forEach((b) => (b.onclick = () => irPara(b.dataset.aba)));
$('#fechar').onclick = () => post('fechar');
document.addEventListener('keydown', (e) => {
    if (!$('#painel').classList.contains('oculto') && (e.key === 'Escape' || e.key === 'F6')) { painelAcao('fechar'); return; }
    if (e.key !== 'Escape') return;
    if (!$('#modal').classList.contains('oculto')) return fecharModal();
    if (!$('#mdt').classList.contains('oculto')) post('fechar');
});

setInterval(() => {
    const d = new Date();
    $('#relogio').textContent = d.toLocaleDateString('pt-BR') + ' ' + d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
}, 1000);

// ------------------------------------------------------------------ páginas
const PAGINAS = {};

PAGINAS.inicio = async (p) => {
    const [ocorr] = await srv('ocorrencias');
    const lista = arr(ocorr);
    const equipe = arr(D.equipe);
    p.innerHTML = `
        <div class="grade g3" style="margin-bottom:14px">
            <div class="card"><div class="numero">${equipe.length}</div><div class="rotulo">policiais em serviço</div></div>
            <div class="card"><div class="numero">${lista.length}</div><div class="rotulo">ocorrências abertas</div></div>
            <div class="card"><div class="numero" style="font-size:22px;color:var(--ouro)">${esc(D.eu.patente)}</div><div class="rotulo">multa até ${dinheiro(D.eu.teto)}</div></div>
        </div>
        <div class="grade g2">
            <div class="card"><h3>Ocorrências abertas</h3><div id="lista-ocorr"></div></div>
            <div class="card"><h3>Em serviço agora</h3>
                ${equipe.length ? `<table><tr><th>Policial</th><th>Patente</th><th>Distintivo</th></tr>
                ${equipe.map((e) => `<tr><td>${esc(e.nome)}</td><td>${esc(e.patente)}</td><td class="mono">${esc(e.distintivo)}</td></tr>`).join('')}</table>`
                : '<div class="vazio">Ninguém.</div>'}
            </div>
        </div>`;
    const caixa = $('#lista-ocorr', p);
    if (!lista.length) { caixa.innerHTML = '<div class="vazio">Nenhuma ocorrência aberta.</div>'; return; }
    for (const o of lista) {
        const el = document.createElement('div');
        el.className = `ocorrencia pri-${o.prioridade}`;
        const com = arr(o.policiais);
        el.innerHTML = `<div class="cod">${esc(o.codigo)}</div>
            <div class="info"><div class="tit">#${o.id} · ${esc(o.titulo)}</div>
            <div class="sub">${[o.descricao, com.length ? 'Com ' + com.join(', ') : 'Ninguém assumiu'].filter(Boolean).map(esc).join(' · ')}</div></div>`;
        const b1 = document.createElement('button'); b1.className = 'btn peq pri'; b1.textContent = 'Assumir';
        b1.onclick = async () => { await post('assumir', { id: o.id }); irPara('inicio'); };
        const b2 = document.createElement('button'); b2.className = 'btn peq'; b2.textContent = 'GPS';
        b2.onclick = () => post('gps', { x: o.centro.x, y: o.centro.y });
        el.append(b1, b2);
        caixa.appendChild(el);
    }
};

// ---------- PESSOAS
PAGINAS.pessoas = async (p, arg) => {
    p.innerHTML = `<div class="busca"><input id="termo" placeholder="Nome, ID do cidadão ou telefone"><button class="btn pri" id="buscar">Buscar</button>
        <button class="btn" id="proximos">Pessoas perto de mim</button></div><div id="resultado"></div>`;
    const buscar = async () => {
        const termo = $('#termo', p).value.trim();
        if (termo.length < 2) return;
        const [lista] = await srv('buscar', termo);
        mostrarLista(arr(lista));
    };
    const mostrarLista = (lista) => {
        const r = $('#resultado', p);
        if (!lista.length) { r.innerHTML = '<div class="vazio">Ninguém encontrado.</div>'; return; }
        r.innerHTML = `<div class="card"><table><tr><th>Nome</th><th>ID</th><th>Nascimento</th><th></th></tr>
            ${lista.map((c) => `<tr class="clicavel" data-cid="${esc(c.cid)}"><td>${esc(c.nome)}</td><td class="mono">${esc(c.cid)}</td>
            <td>${esc(c.nascimento || '')}</td><td>${c.online ? '<span class="etq verde">on-line</span>' : ''}${c.id ? `<span class="etq">ID ${c.id}</span>` : ''}</td></tr>`).join('')}</table></div>`;
        $$('tr[data-cid]', r).forEach((tr) => (tr.onclick = () => ficha(p, tr.dataset.cid)));
    };
    $('#buscar', p).onclick = buscar;
    $('#termo', p).onkeydown = (e) => e.key === 'Enter' && buscar();
    $('#proximos', p).onclick = async () => {
        const [lista] = await srv('proximos');
        mostrarLista(arr(lista).map((x) => ({ ...x, online: true })));
    };
    if (arg && arg.cid) return ficha(p, arg.cid);
    if (arg && arg.alvo) {
        const [lista] = await srv('proximos');
        const achou = arr(lista).find((x) => x.id === arg.alvo);
        if (achou) return ficha(p, achou.cid);
    }
    $('#termo', p).focus();
};

async function ficha(p, cid) {
    const [f] = await srv('ficha', cid);
    if (!f) { toast('Ficha não encontrada.', 'erro'); return; }
    const licencas = arr(f.licencas), multas = arr(f.multas), prisoes = arr(f.prisoes), mandados = arr(f.mandados);
    const veiculos = arr(f.veiculos), apreensoes = arr(f.apreensoes);
    const pendente = multas.filter((m) => !m.pago && !m.cancelada).reduce((s, m) => s + m.valor, 0);
    const iniciais = f.nome.split(' ').map((x) => x[0] || '').join('').slice(0, 2).toUpperCase();
    const nomeLic = { caca: 'Licença de caça', porte: 'Porte de arma' };

    p.innerHTML = `
    <button class="btn peq" id="voltar" style="margin-bottom:12px">← Voltar à busca</button>
    ${mandados.length ? `<div class="alerta-faixa">⚠ ${mandados.length} mandado(s) ativo(s): ${mandados.map((m) => esc((m.tipo === 'prisao' ? 'Prisão' : 'Busca') + ' – ' + m.motivo)).join(' · ')}</div>` : ''}
    ${f.preso ? `<div class="alerta-faixa" style="color:var(--ambar);border-color:rgba(239,159,39,.4);background:rgba(239,159,39,.1)">Cumprindo pena em Bolingbroke: faltam ${f.preso.restante} min (de ${f.preso.total} meses).</div>` : ''}
    <div class="grade g-ficha">
        <div class="grade">
            <div class="card">
                <div class="ficha-topo"><div class="avatar">${esc(iniciais)}</div>
                    <div><div class="ficha-nome">${esc(f.nome)}</div><div class="mono rotulo">${esc(f.cid)}</div>
                    ${f.online ? '<span class="etq verde">on-line</span>' : '<span class="etq">off-line</span>'}</div></div>
                <div class="dado"><b>Nascimento</b><span>${esc(f.nascimento || '-')}</span></div>
                <div class="dado"><b>Sexo</b><span>${esc(f.sexo)}</span></div>
                <div class="dado"><b>Nacionalidade</b><span>${esc(f.nacionalidade || '-')}</span></div>
                <div class="dado"><b>Telefone</b><span class="mono">${esc(f.telefone || '-')}</span></div>
                <div class="dado"><b>Emprego</b><span>${esc(f.emprego || '-')}</span></div>
                <div class="dado"><b>Digital</b><span class="mono">${esc(f.digital || '-')}</span></div>
                <div class="dado"><b>Tipo sanguíneo</b><span>${esc(f.sangue || '-')}</span></div>
                <div class="dado"><b>Habilitação</b><span>${f.habilitacao ? '<span class="etq verde">ok</span>' : '<span class="etq vermelho">cassada</span>'}</span></div>
                <div class="dado"><b>Multas pendentes</b><span style="color:${pendente ? 'var(--vermelho)' : 'inherit'}">${dinheiro(pendente)}</span></div>
            </div>
            <div class="card"><h3>Ações</h3><div class="botoes" id="acoes"></div></div>
            <div class="card"><h3>Licenças</h3>
                ${licencas.length ? licencas.map((l) => `<div class="dado"><span>${esc(nomeLic[l.tipo] || l.tipo)}<br><small class="rotulo">até ${esc(l.validade)} · ${esc(l.policial)}</small></span>
                <span>${l.ativa ? '<span class="etq verde">ativa</span>' : l.revogada ? '<span class="etq vermelho">revogada</span>' : '<span class="etq">vencida</span>'}
                ${l.ativa && pode('revogarLicenca') ? `<button class="btn peq perigo" data-revogar="${l.id}">Revogar</button>` : ''}</span></div>`).join('') : '<div class="vazio">Nenhuma.</div>'}
            </div>
        </div>
        <div class="grade">
            <div class="card"><h3>Multas</h3>
                ${multas.length ? `<table><tr><th>Data</th><th>Valor</th><th>Motivo</th><th>Situação</th><th></th></tr>
                ${multas.map((m) => `<tr><td>${esc(m.criado)}</td><td>${dinheiro(m.valor)}</td><td>${esc(m.motivo)}<br><small class="rotulo">${esc(m.policial)}</small></td>
                <td>${m.cancelada ? '<span class="etq">cancelada</span>' : m.pago ? '<span class="etq verde">paga</span>' : '<span class="etq vermelho">pendente</span>'}</td>
                <td>${!m.cancelada && pode('cancelarMulta') ? `<button class="btn peq perigo" data-cancelar="${m.id}">Cancelar</button>` : ''}</td></tr>`).join('')}</table>` : '<div class="vazio">Nenhuma multa.</div>'}
            </div>
            <div class="card"><h3>Passagens pela prisão</h3>
                ${prisoes.length ? `<table><tr><th>Data</th><th>Pena</th><th>Artigos</th><th>Policial</th></tr>
                ${prisoes.map((x) => `<tr><td>${esc(x.criado)}</td><td>${x.meses} meses<br><small class="rotulo">${dinheiro(x.multa)}</small></td>
                <td>${arr(x.artigos).map(esc).join('<br>')}</td><td>${esc(x.policial)}</td></tr>`).join('')}</table>` : '<div class="vazio">Ficha limpa.</div>'}
            </div>
            <div class="card"><h3>Veículos</h3>
                ${veiculos.length ? `<table><tr><th>Placa</th><th>Modelo</th><th></th></tr>
                ${veiculos.map((v) => `<tr class="clicavel" data-placa="${esc(v.plate)}"><td class="mono">${esc(v.plate)}</td><td>${esc(v.vehicle)}</td>
                <td>${v.procurado ? '<span class="etq vermelho">procurado</span>' : ''}</td></tr>`).join('')}</table>` : '<div class="vazio">Nenhum.</div>'}
            </div>
            <div class="card"><h3>Apreensões</h3>
                ${apreensoes.length ? `<table><tr><th>Data</th><th>Itens</th><th>Policial</th></tr>
                ${apreensoes.map((a) => `<tr><td>${esc(a.criado)}</td><td>${arr(a.itens).map((i) => `${i.qtd}x ${esc(i.label)}`).join(', ')}</td><td>${esc(a.policial)}</td></tr>`).join('')}</table>` : '<div class="vazio">Nenhuma.</div>'}
            </div>
        </div>
    </div>`;

    $('#voltar', p).onclick = () => irPara('pessoas');
    $$('[data-placa]', p).forEach((tr) => (tr.onclick = () => irPara('veiculos', { placa: tr.dataset.placa })));
    $$('[data-cancelar]', p).forEach((b) => (b.onclick = async () => { const [ok] = await acao('cancelarMulta', Number(b.dataset.cancelar)); if (ok) ficha(p, cid); }));
    $$('[data-revogar]', p).forEach((b) => (b.onclick = async () => { const [ok] = await acao('revogarLicenca', Number(b.dataset.revogar)); if (ok) ficha(p, cid); }));

    const acoes = $('#acoes', p);
    const botao = (texto, classe, fn, mostrar = true) => {
        if (!mostrar) return;
        const b = document.createElement('button');
        b.className = 'btn ' + classe; b.textContent = texto; b.onclick = fn; acoes.appendChild(b);
    };
    botao('Multar', 'pri', () => modalMulta(f, () => ficha(p, cid)), pode('multar'));
    botao('Aplicar pena', 'ouro', () => modalPena(f, () => ficha(p, cid)), pode('prender'));
    botao('Emitir licença', '', () => modalLicenca(f, () => ficha(p, cid)), pode('licencas'));
    botao('Mandado de prisão', 'perigo', () => modalMandadoPrisao(f, () => ficha(p, cid)), pode('mandado'));
    botao('Novo BO', '', () => modalBo([f.cid]), pode('bo'));
    botao('Soltar preso', 'perigo', async () => { const [ok] = await acao('soltarPreso', f.cid); if (ok) ficha(p, cid); }, !!f.preso && pode('cancelarMulta'));
    if (!acoes.children.length) acoes.innerHTML = '<div class="vazio">Sem ações para sua patente.</div>';
}

function modalMulta(f, depois) {
    modal(`Multar · ${f.nome}`, `
        <label class="campo"><span>Valor (sua patente: até ${dinheiro(D.eu.teto)})</span><input id="m-valor" type="number" min="1" max="${D.eu.teto}"></label>
        <label class="campo"><span>Motivo</span><input id="m-motivo" maxlength="200"></label>
        <div class="rotulo">Se o cidadão estiver on-line, é cobrado do banco na hora. Sem saldo, fica pendente (paga na DP).</div>`,
    [{ texto: 'Multar', classe: 'pri', fn: async () => {
        const [ok] = await acao('multar', f.cid, Number($('#m-valor').value), $('#m-motivo').value);
        if (ok) { fecharModal(); depois(); }
    } }]);
}

async function escolherProximo(cidPreferido) {
    const [lista] = await srv('proximos');
    const l = arr(lista);
    if (!l.length) return null;
    const opcoes = l.map((x) => `<option value="${x.id}" ${x.cid === cidPreferido ? 'selected' : ''}>${esc(x.nome)} (ID ${x.id})</option>`).join('');
    return opcoes;
}

async function modalPena(f, depois) {
    const opcoes = await escolherProximo(f.cid);
    if (!opcoes) return toast('O preso precisa estar perto de você (e na DP).', 'erro');
    const codigo = arr(D.codigo);
    modal('Aplicar pena', `
        <label class="campo"><span>Preso (perto de você)</span><select id="p-alvo">${opcoes}</select></label>
        <div class="artigos rolar">${codigo.map((a) => `<label class="artigo" data-id="${esc(a.id)}"><input type="checkbox">
            <span class="mono">${esc(a.id)}</span><span>${esc(a.titulo)}</span><span>${dinheiro(a.multa)}</span><span>${a.meses} m</span></label>`).join('')}</div>
        <div class="total-pena">Multa: <b id="p-multa">$0</b> Pena: <b id="p-meses">0 meses</b> <span class="rotulo" id="p-tempo"></span></div>`,
    [{ texto: 'Aplicar pena', classe: 'ouro', fn: async () => {
        const ids = $$('.artigo.marcado').map((x) => x.dataset.id);
        if (!ids.length) return toast('Marque os artigos.', 'erro');
        const [ok] = await acao('aplicarPena', Number($('#p-alvo').value), ids);
        if (ok) { fecharModal(); depois(); }
    } }]);
    const atualizar = () => {
        let multa = 0, meses = 0;
        $$('.artigo').forEach((el) => {
            const marcado = $('input', el).checked;
            el.classList.toggle('marcado', marcado);
            if (marcado) { const a = codigo.find((x) => x.id === el.dataset.id); multa += a.multa; meses += a.meses; }
        });
        $('#p-multa').textContent = dinheiro(multa);
        $('#p-meses').textContent = `${meses} meses`;
        $('#p-tempo').textContent = meses ? `(≈ ${Math.ceil(meses * D.minutosPorMes)} min on-line)` : '';
    };
    $$('.artigo input').forEach((i) => (i.onchange = atualizar));
}

async function modalLicenca(f, depois) {
    const opcoes = await escolherProximo(f.cid);
    if (!opcoes) return toast('O cidadão precisa estar perto (o documento é entregue na mão).', 'erro');
    modal('Emitir licença', `
        <label class="campo"><span>Cidadão (perto de você)</span><select id="l-alvo">${opcoes}</select></label>
        <label class="campo"><span>Licença</span><select id="l-tipo"><option value="caca">Licença de caça (30 dias)</option><option value="porte">Porte de arma</option></select></label>`,
    [{ texto: 'Emitir', classe: 'pri', fn: async () => {
        const [ok] = await acao('emitirLicenca', Number($('#l-alvo').value), $('#l-tipo').value);
        if (ok) { fecharModal(); depois(); }
    } }]);
}

function modalMandadoPrisao(f, depois) {
    modal(`Mandado de prisão · ${f.nome}`, `<label class="campo"><span>Motivo</span><input id="mp-motivo" maxlength="200"></label>`,
    [{ texto: 'Emitir mandado', classe: 'perigo', fn: async () => {
        const [ok] = await acao('mandadoPrisao', f.cid, $('#mp-motivo').value);
        if (ok) { fecharModal(); depois(); }
    } }]);
}

// ---------- VEÍCULOS
PAGINAS.veiculos = async (p, arg) => {
    p.innerHTML = `<div class="busca"><input id="placa" placeholder="Placa" style="text-transform:uppercase"><button class="btn pri" id="buscar">Consultar</button></div><div id="resultado"></div>`;
    const consultar = async (placa) => {
        placa = (placa || $('#placa', p).value).trim().toUpperCase();
        if (placa.length < 2) return;
        $('#placa', p).value = placa;
        const [v] = await srv('veiculo', placa);
        const r = $('#resultado', p);
        if (!v) { r.innerHTML = '<div class="vazio">Nada encontrado.</div>'; return; }
        const hist = arr(v.historico);
        r.innerHTML = `
        ${v.procurado ? `<div class="alerta-faixa">⚠ PLACA PROCURADA: ${esc(v.procurado)}</div>` : ''}
        ${v.patio ? `<div class="alerta-faixa" style="color:var(--ambar);border-color:rgba(239,159,39,.4);background:rgba(239,159,39,.1)">Retido no pátio desde ${esc(v.patio.criado)}: ${esc(v.patio.motivo)} (${esc(v.patio.policial)})</div>` : ''}
        <div class="grade g2">
            <div class="card"><h3>Registro</h3>
                <div class="dado"><b>Placa</b><span class="mono">${esc(v.plate)}</span></div>
                <div class="dado"><b>Modelo</b><span>${esc(v.modelo || '-')}</span></div>
                <div class="dado"><b>Dono</b><span>${v.dono ? `<a href="#" id="dono" style="color:#8DB8EE">${esc(v.dono)}</a>` : '<span class="etq ambar">sem registro</span>'}</span></div>
                <div class="dado"><b>Laudo do dinamômetro</b><span>${esc(v.laudo || 'nenhum')}</span></div>
                <div class="botoes" style="margin-top:12px" id="acoes-v"></div>
            </div>
            <div class="card"><h3>Histórico</h3>
                ${hist.length ? `<table><tr><th>Data</th><th>Tipo</th><th>Resultado</th></tr>${hist.map((h) => `<tr><td>${esc(h.criado)}</td><td><span class="etq">${esc(h.tipo)}</span></td>
                <td>${esc(h.resultado)}<br><small class="rotulo">${esc(h.policial)}</small></td></tr>`).join('')}</table>` : '<div class="vazio">Sem registros.</div>'}
            </div>
        </div>`;
        const dono = $('#dono', r);
        if (dono) dono.onclick = (e) => { e.preventDefault(); irPara('pessoas', { cid: v.donoCid }); };
        const acoes = $('#acoes-v', r);
        if (pode('marcarPlaca')) {
            const b = document.createElement('button');
            b.className = 'btn ' + (v.procurado ? '' : 'perigo');
            b.textContent = v.procurado ? 'Tirar dos procurados' : 'Marcar como procurada';
            b.onclick = () => {
                if (v.procurado) return acao('marcarPlaca', v.plate).then(() => consultar(v.plate));
                modal('Marcar placa', '<label class="campo"><span>Motivo</span><input id="pl-motivo" maxlength="200"></label>',
                    [{ texto: 'Marcar', classe: 'perigo', fn: async () => { const [ok] = await acao('marcarPlaca', v.plate, $('#pl-motivo').value); if (ok) { fecharModal(); consultar(v.plate); } } }]);
            };
            acoes.appendChild(b);
        }
        if (v.patio && pode('liberarPatio')) {
            for (const [texto, cobrar] of [['Liberar (com taxa)', true], ['Liberar sem taxa', false]]) {
                const b = document.createElement('button');
                b.className = 'btn pri'; b.textContent = texto;
                b.onclick = async () => { const [ok] = await acao('liberarPatio', v.plate, cobrar); if (ok) consultar(v.plate); };
                acoes.appendChild(b);
            }
        }
    };
    $('#buscar', p).onclick = () => consultar();
    $('#placa', p).onkeydown = (e) => e.key === 'Enter' && consultar();
    if (arg && arg.placa) consultar(arg.placa); else $('#placa', p).focus();
};

// ---------- BOs
function modalBo(envolvidos) {
    modal('Novo boletim de ocorrência', `
        <label class="campo"><span>Título</span><input id="bo-titulo" maxlength="150"></label>
        <label class="campo"><span>Relato</span><textarea id="bo-desc" maxlength="6000"></textarea></label>
        <label class="campo"><span>Envolvidos (IDs de cidadão, separados por vírgula)</span><input id="bo-env" value="${esc((envolvidos || []).join(', '))}"></label>
        <label class="campo"><span>Itens apreendidos</span><input id="bo-apr" maxlength="2000"></label>
        <label class="campo"><span>Laudos de perícia (números, ex.: 12, 15)</span><input id="bo-per"></label>`,
    [{ texto: 'Registrar BO', classe: 'pri', fn: async () => {
        const [ok] = await acao('criarBo', {
            titulo: $('#bo-titulo').value, descricao: $('#bo-desc').value,
            envolvidos: $('#bo-env').value.split(',').map((x) => x.trim()).filter(Boolean),
            apreensoes: $('#bo-apr').value, pericias: $('#bo-per').value,
        });
        if (ok) { fecharModal(); if (abaAtual === 'bos') irPara('bos'); }
    } }]);
}

PAGINAS.bos = async (p) => {
    p.innerHTML = `<div class="busca"><input id="termo" placeholder="Buscar por título, ID do cidadão ou número"><button class="btn" id="buscar">Buscar</button>
        ${pode('bo') ? '<button class="btn pri" id="novo">Novo BO</button>' : ''}</div><div id="resultado"></div>`;
    const carregar = async () => {
        const [lista] = await srv('bos', $('#termo', p).value);
        const l = arr(lista);
        const r = $('#resultado', p);
        r.innerHTML = l.length ? `<div class="card"><table><tr><th>Nº</th><th>Título</th><th>Policial</th><th>Data</th></tr>
            ${l.map((b) => `<tr class="clicavel" data-id="${b.id}"><td class="mono">#${b.id}</td><td>${esc(b.titulo)}</td><td>${esc(b.policial)}</td><td>${esc(b.criado)}</td></tr>`).join('')}</table></div>`
            : '<div class="vazio">Nenhum BO.</div>';
        $$('tr[data-id]', r).forEach((tr) => (tr.onclick = () => verBo(Number(tr.dataset.id))));
    };
    $('#buscar', p).onclick = carregar;
    $('#termo', p).onkeydown = (e) => e.key === 'Enter' && carregar();
    const novo = $('#novo', p); if (novo) novo.onclick = () => modalBo([]);
    carregar();
};

async function verBo(id) {
    const [b] = await srv('bo', id);
    if (!b) return toast('BO não encontrado.', 'erro');
    const env = arr(b.envolvidos), laudos = arr(b.laudos);
    modal(`BO #${b.id} · ${b.titulo}`, `
        <div class="rotulo" style="margin-bottom:10px">${esc(b.policial)} · ${esc(b.criado)}</div>
        <div style="white-space:pre-wrap;margin-bottom:12px">${esc(b.descricao || '')}</div>
        <div class="dado"><b>Envolvidos</b><span>${env.map((e) => `${esc(e.nome)} <small class="mono rotulo">${esc(e.cid)}</small>`).join('<br>') || '-'}</span></div>
        <div class="dado"><b>Apreensões</b><span>${esc(b.apreensoes || '-')}</span></div>
        <div class="dado"><b>Perícias</b><span>${laudos.map((l) => `#${l.id} ${esc(l.resultado)}`).join('<br>') || '-'}</span></div>`, []);
}

// ---------- MANDADOS
PAGINAS.mandados = async (p) => {
    const [lista] = await srv('mandados');
    const l = arr(lista);
    p.innerHTML = `${pode('mandado') ? '<div class="botoes" style="margin-bottom:14px"><button class="btn pri" id="busca">Mandado de busca (imóvel)</button><span class="rotulo" style="align-self:center">Mandado de prisão: abra a ficha da pessoa.</span></div>' : ''}
        <div class="card">${l.length ? `<table><tr><th>Nº</th><th>Tipo</th><th>Alvo</th><th>Motivo</th><th>Validade</th><th></th></tr>
        ${l.map((m) => `<tr><td class="mono">#${m.id}</td><td>${m.tipo === 'prisao' ? '<span class="etq vermelho">prisão</span>' : '<span class="etq azul">busca</span>'}</td>
        <td>${m.tipo === 'prisao' ? `<a href="#" data-cid="${esc(m.citizenid)}" style="color:#8DB8EE">${esc(m.nome)}</a>` : `Imóvel #${m.imovel}`}</td>
        <td>${esc(m.motivo)}<br><small class="rotulo">${esc(m.policial)}</small></td><td>${esc(m.expira)}</td>
        <td>${pode('mandado') ? `<button class="btn peq" data-encerrar="${m.id}">Encerrar</button>` : ''}</td></tr>`).join('')}</table>` : '<div class="vazio">Nenhum mandado ativo.</div>'}</div>`;
    $$('[data-cid]', p).forEach((a) => (a.onclick = (e) => { e.preventDefault(); irPara('pessoas', { cid: a.dataset.cid }); }));
    $$('[data-encerrar]', p).forEach((b) => (b.onclick = async () => { const [ok] = await acao('encerrarMandado', Number(b.dataset.encerrar)); if (ok) irPara('mandados'); }));
    const busca = $('#busca', p);
    if (busca) busca.onclick = () => modal('Mandado de busca', `
        <label class="campo"><span>Número do imóvel (aparece no menu da porta)</span><input id="mb-imovel" type="number"></label>
        <label class="campo"><span>Motivo</span><input id="mb-motivo" maxlength="200"></label>
        <div class="rotulo">O mandado vai para o seu inventário e libera a entrada na casa.</div>`,
    [{ texto: 'Emitir', classe: 'pri', fn: async () => {
        const [ok] = await acao('mandadoBusca', Number($('#mb-imovel').value), $('#mb-motivo').value);
        if (ok) { fecharModal(); irPara('mandados'); }
    } }]);
};

// ---------- CÓDIGO PENAL
PAGINAS.codigo = async (p) => {
    const codigo = arr(D.codigo);
    const editar = pode('codigoPenal');
    p.innerHTML = `${editar ? '<div class="botoes" style="margin-bottom:14px"><button class="btn pri" id="novo">Novo artigo</button></div>' : ''}
        <div class="card"><table><tr><th>Art.</th><th>Crime</th><th>Multa</th><th>Pena</th>${editar ? '<th></th>' : ''}</tr>
        ${codigo.map((a) => `<tr><td class="mono">${esc(a.id)}</td><td>${esc(a.titulo)}</td><td>${dinheiro(a.multa)}</td><td>${a.meses} meses</td>
        ${editar ? `<td><button class="btn peq" data-editar="${esc(a.id)}">Editar</button> <button class="btn peq perigo" data-remover="${esc(a.id)}">Remover</button></td>` : ''}</tr>`).join('')}</table></div>`;
    const form = (a) => modal(a ? `Editar ${a.id}` : 'Novo artigo', `
        <div class="grade g2"><label class="campo"><span>Código</span><input id="a-id" maxlength="10" value="${esc(a?.id || '')}" ${a ? 'disabled' : ''}></label>
        <label class="campo"><span>Título</span><input id="a-tit" maxlength="150" value="${esc(a?.titulo || '')}"></label>
        <label class="campo"><span>Multa ($)</span><input id="a-multa" type="number" value="${a?.multa ?? 0}"></label>
        <label class="campo"><span>Pena (meses)</span><input id="a-meses" type="number" value="${a?.meses ?? 0}"></label></div>`,
    [{ texto: 'Salvar', classe: 'pri', fn: async () => {
        const [ok, , novo] = await acao('salvarArtigo', { id: $('#a-id').value, titulo: $('#a-tit').value, multa: Number($('#a-multa').value), meses: Number($('#a-meses').value) });
        if (ok) { D.codigo = novo; fecharModal(); irPara('codigo'); }
    } }]);
    const novo = $('#novo', p); if (novo) novo.onclick = () => form(null);
    $$('[data-editar]', p).forEach((b) => (b.onclick = () => form(codigo.find((x) => x.id === b.dataset.editar))));
    $$('[data-remover]', p).forEach((b) => (b.onclick = async () => {
        const [ok, , novoCod] = await acao('removerArtigo', b.dataset.remover);
        if (ok) { D.codigo = novoCod; irPara('codigo'); }
    }));
};

// ---------- APREENSÕES E PERÍCIA
PAGINAS.evidencias = async (p) => {
    const [[apr], [per]] = await Promise.all([srv('apreensoes'), srv('pericias')]);
    const a = arr(apr), pe = arr(per);
    p.innerHTML = `<div class="grade g2">
        <div class="card"><h3>Últimas apreensões</h3>${a.length ? `<table><tr><th>Data</th><th>Cidadão</th><th>Itens</th></tr>
            ${a.map((x) => `<tr><td>${esc(x.criado)}</td><td>${esc(x.nome)}<br><small class="rotulo">${esc(x.policial)}</small></td>
            <td>${arr(x.itens).map((i) => `${i.qtd}x ${esc(i.label)}`).join(', ')}</td></tr>`).join('')}</table>` : '<div class="vazio">Nenhuma.</div>'}</div>
        <div class="card"><h3>Laudos de perícia</h3>${pe.length ? `<table><tr><th>Nº</th><th>Tipo</th><th>Resultado</th></tr>
            ${pe.map((x) => `<tr><td class="mono">#${x.id}</td><td><span class="etq">${esc(x.tipo)}</span></td><td>${esc(x.resultado)}<br><small class="rotulo">${esc(x.policial)} · ${esc(x.criado)}</small></td></tr>`).join('')}</table>` : '<div class="vazio">Nenhum.</div>'}</div>
    </div>`;
};

// ---------- EQUIPE
PAGINAS.equipe = async (p) => {
    const [e] = await srv('equipe');
    if (!e) return;
    const membros = arr(e.membros);
    const gerir = pode('contratar');
    const ate = D.promoverAte;
    const opcoesGrau = (atual) => Object.keys(D.patentes).map(Number).filter((g) => g <= ate)
        .map((g) => `<option value="${g}" ${g === atual ? 'selected' : ''}>${esc(patente(g))}</option>`).join('');

    p.innerHTML = `
        ${gerir ? `<div class="card" style="margin-bottom:14px"><h3>Contratar</h3><div class="busca" style="margin:0"><input id="c-id" type="number" placeholder="ID do jogador no servidor">
            <button class="btn pri" id="contratar">Contratar como ${esc(patente(0))}</button></div></div>` : ''}
        ${e.saldo !== undefined && e.saldo !== null ? `<div class="card" style="margin-bottom:14px"><h3>Caixa da LSPD</h3>
            <div style="display:flex;align-items:center;gap:14px"><div class="numero">${dinheiro(e.saldo)}</div>
            <input id="cx-valor" type="number" placeholder="Valor" style="max-width:160px"><button class="btn" id="sacar">Sacar</button><button class="btn" id="depositar">Depositar</button></div></div>` : ''}
        <div class="card"><table><tr><th>Policial</th><th>Patente</th><th>Situação</th>${gerir ? '<th>Gerir</th>' : ''}</tr>
        ${membros.map((m) => `<tr><td>${esc(m.nome)}<br><small class="mono rotulo">${esc(m.cid)}</small></td><td>${esc(m.patente)}</td>
        <td>${m.servico ? '<span class="etq verde">em serviço</span>' : m.online ? '<span class="etq azul">on-line</span>' : '<span class="etq">off-line</span>'}</td>
        ${gerir ? `<td>${m.grau < D.eu.grau && m.cid ? `<select data-grau="${esc(m.cid)}" style="width:auto">${opcoesGrau(m.grau)}</select>
            <button class="btn peq perigo" data-demitir="${esc(m.cid)}">Demitir</button>` : ''}</td>` : ''}</tr>`).join('')}</table></div>`;

    const c = $('#contratar', p);
    if (c) c.onclick = async () => { const [ok] = await acao('contratar', Number($('#c-id', p).value)); if (ok) irPara('equipe'); };
    $$('[data-grau]', p).forEach((s) => (s.onchange = async () => { await acao('setGrau', s.dataset.grau, Number(s.value)); irPara('equipe'); }));
    $$('[data-demitir]', p).forEach((b) => (b.onclick = () => modal('Demitir', 'Tem certeza? A pessoa sai da LSPD.',
        [{ texto: 'Demitir', classe: 'perigo', fn: async () => { const [ok] = await acao('demitir', b.dataset.demitir); if (ok) { fecharModal(); irPara('equipe'); } } }])));
    for (const tipo of ['sacar', 'depositar']) {
        const b = $('#' + tipo, p);
        if (b) b.onclick = async () => { const [ok] = await acao('caixa', tipo, Number($('#cx-valor', p).value)); if (ok) irPara('equipe'); };
    }
};

// ------------------------------------------------------------------ mensagens do jogo
window.addEventListener('message', ({ data }) => {
    if (!data || !data.acao) return;

    if (data.acao === 'abrirMdt') {
        D = data.dados;
        $('#eu-nome').textContent = D.eu.nome;
        $('#eu-patente').textContent = D.eu.patente;
        $$('#abas button[data-aba="codigo"]').forEach((b) => b.classList.remove('oculto'));
        $('#mdt').classList.remove('oculto');
        fecharModal();
        const o = data.opcoes || {};
        if (o.aba === 'pessoa') irPara('pessoas', { alvo: o.alvo });
        else if (o.aba === 'veiculo') irPara('veiculos', { placa: (o.placa || '').trim() });
        else irPara(abaAtual || 'inicio');
        return;
    }
    if (data.acao === 'fecharMdt') {
        $('#mdt').classList.add('oculto');
        return;
    }

    // radar móvel
    if (data.acao === 'radar') {
        $('#radar').classList.toggle('oculto', !data.ligado);
        return;
    }
    if (data.acao === 'radarDados') {
        $('#radar-propria').textContent = data.propria ?? 0;
        for (const [lado, info] of [['f', data.frente], ['t', data.tras]]) {
            $(`#radar-${lado}-vel`).textContent = info ? info.vel : '--';
            const pl = $(`#radar-${lado}-placa`);
            pl.textContent = info ? info.placa : '--------';
            pl.classList.toggle('procurada', !!(info && info.procurado));
            $(`#radar-${lado}-modelo`).textContent = info ? info.modelo : '';
        }
    }
});


// ================================================================== SONS (rádio da central)
let audio;
function bip(freq, ini, dur, vol = 0.12, tipo = 'square') {
    const o = audio.createOscillator(), g = audio.createGain();
    o.type = tipo; o.frequency.value = freq;
    g.gain.setValueAtTime(0, audio.currentTime + ini);
    g.gain.linearRampToValueAtTime(vol, audio.currentTime + ini + 0.01);
    g.gain.setValueAtTime(vol, audio.currentTime + ini + dur - 0.02);
    g.gain.linearRampToValueAtTime(0, audio.currentTime + ini + dur);
    o.connect(g).connect(audio.destination);
    o.start(audio.currentTime + ini); o.stop(audio.currentTime + ini + dur + 0.02);
}
function chiado(ini, dur, vol = 0.05) {
    const n = Math.floor(audio.sampleRate * dur), buf = audio.createBuffer(1, n, audio.sampleRate), d = buf.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / n);
    const src = audio.createBufferSource(), g = audio.createGain(), f = audio.createBiquadFilter();
    f.type = 'bandpass'; f.frequency.value = 1800; g.gain.value = vol;
    src.buffer = buf; src.connect(f).connect(g).connect(audio.destination);
    src.start(audio.currentTime + ini);
}
function somAlerta(prioridade) {
    try {
        audio = audio || new (window.AudioContext || window.webkitAudioContext)();
        chiado(0, 0.12);
        if (prioridade === 'baixa') { bip(880, 0.12, 0.12, 0.08, 'sine'); }
        else if (prioridade === 'media') { bip(1000, 0.12, 0.09); bip(1350, 0.24, 0.12); }
        else if (prioridade === 'alta') { [0, 0.15, 0.3].forEach((t) => bip(1450, 0.12 + t, 0.1)); }
        else { for (let i = 0; i < 6; i++) bip(i % 2 ? 1300 : 850, 0.12 + i * 0.22, 0.2, 0.13, 'sawtooth'); }
        chiado(prioridade === 'maxima' ? 1.5 : 0.55, 0.1, 0.04);
    } catch (e) { /* sem áudio */ }
}

// ================================================================== AVISOS (cards)
const cards = new Map(); // id -> { el, criado, timer }
const metros = (m) => (m >= 1000 ? (m / 1000).toFixed(1).replace('.', ',') + ' km' : m + ' m');
const ha = (seg) => (seg < 60 ? 'agora' : `há ${Math.floor(seg / 60)} min`);

function removerCard(id) {
    const c = cards.get(id);
    if (!c) return;
    cards.delete(id);
    clearTimeout(c.timer);
    c.el.classList.add('saindo');
    setTimeout(() => c.el.remove(), 380);
}

function novoCard(d) {
    removerCard(d.id);
    const el = document.createElement('div');
    el.className = `card-alerta pri-${d.prioridade}`;
    const local = [d.rua, d.zona].filter(Boolean).join(', ');
    const com = arr(d.policiais);
    el.innerHTML = `
        <div class="ca-topo"><span class="ca-cod">${esc(d.codigo)}</span><span class="ca-id">#${d.id}</span><span class="ca-tempo">agora</span></div>
        <div class="ca-titulo">${esc(d.titulo)}</div>
        ${d.descricao ? `<div class="ca-desc">${esc(d.descricao)}</div>` : ''}
        <div class="ca-local"><span class="rua">📍 ${esc(local)}${d.exato ? '' : ' <span class="aprox">(área aproximada)</span>'}</span><span class="dist">${metros(d.distancia)}</span></div>
        <div class="ca-rodape">${com.length ? `<span class="ca-com">Com ${esc(com.join(', '))}</span>` : `<span class="ca-tecla">${esc(d.tecla)}</span> assumir e traçar rota`}</div>
        <div class="ca-barra"></div>`;
    const caixa = $('#cards');
    caixa.prepend(el);
    const barra = $('.ca-barra', el);
    barra.style.width = '100%';
    barra.style.transition = `width ${d.duracao}s linear`;
    requestAnimationFrame(() => requestAnimationFrame(() => (barra.style.width = '0%')));
    const c = { el, criado: Date.now(), timer: setTimeout(() => removerCard(d.id), d.duracao * 1000) };
    cards.set(d.id, c);
    // limite de cards na tela
    const max = d.max || 4;
    [...cards.keys()].slice(0, Math.max(0, cards.size - max)).forEach(removerCard);
    if (d.som) somAlerta(d.prioridade);
}

setInterval(() => {
    for (const c of cards.values()) $('.ca-tempo', c.el).textContent = ha((Date.now() - c.criado) / 1000);
}, 5000);

// ================================================================== PAINEL F6
let P_ = null, vista = 'inicio';
const ICONES = {
    tablet: '<svg viewBox="0 0 24 24"><rect x="4" y="2.5" width="16" height="19" rx="2.5"/><path d="M10 18.5h4"/></svg>',
    ocorr: '<svg viewBox="0 0 24 24"><path d="M12 13v8"/><circle cx="12" cy="10" r="2.5"/><path d="M7.5 5.5a6.5 6.5 0 0 0 0 9M16.5 5.5a6.5 6.5 0 0 1 0 9M4.5 2.5a11 11 0 0 0 0 15M19.5 2.5a11 11 0 0 1 0 15"/></svg>',
    blitz: '<svg viewBox="0 0 24 24"><path d="M12 3l5 16H7z"/><path d="M8.5 14h7M10 9.5h4M4 21h16"/></svg>',
    radar: '<svg viewBox="0 0 24 24"><path d="M4 16a8 8 0 1 1 16 0"/><path d="M12 16l4.5-5"/><circle cx="12" cy="16" r="1.4"/><path d="M3 20h18"/></svg>',
    pin: '<svg viewBox="0 0 24 24"><path d="M12 21s-6.5-6.2-6.5-11a6.5 6.5 0 0 1 13 0c0 4.8-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/></svg>',
    pericia: '<svg viewBox="0 0 24 24"><circle cx="10.5" cy="10.5" r="6"/><path d="M15 15l5.5 5.5"/><path d="M8 10.5h5M10.5 8v5"/></svg>',
    limpar: '<svg viewBox="0 0 24 24"><path d="M14 4l6 6M4 20l7.5-7.5M11.5 12.5l2-2 4 4-2 2a3 3 0 0 1-4 0l-.5-.5a3 3 0 0 1 0-4z"/></svg>',
    panico: '<svg viewBox="0 0 24 24"><path d="M12 3l9.5 17h-19z"/><path d="M12 10v4.5M12 17.5v.5"/></svg>',
    cone: '<svg viewBox="0 0 24 24"><path d="M12 3l5 16H7z"/><path d="M4 21h16"/></svg>',
    tapete: '<svg viewBox="0 0 24 24"><rect x="2.5" y="10" width="19" height="4" rx="1"/><path d="M5 10l1-3M9 10l1-3M13 10l1-3M17 10l1-3"/></svg>',
};

function painelAcao(acao, dados) { post('painel', { acao, ...(dados || {}) }); }

function botaoPainel({ id, icone, titulo, sub, desabilitado, classe, badge }) {
    return `<button class="p-btn ${classe || ''}" data-p="${id}" ${desabilitado ? 'disabled' : ''}>
        ${ICONES[icone] || ''}<b>${esc(titulo)}</b>${sub ? `<small>${esc(sub)}</small>` : ''}
        ${badge ? `<span class="badge">${badge}</span>` : ''}</button>`;
}

function desenharPainel() {
    const d = P_;
    if (!d) return;
    $('#p-patente').textContent = `LSPD · ${d.patente}`;
    $('#p-nome').textContent = d.nome;
    $('#p-ponto').classList.toggle('on', !!d.servico);
    $('#p-servico').textContent = d.servico ? 'Em serviço' : 'Fora de serviço';
    $('#p-distintivo').textContent = d.distintivo || '';
    const pd = d.perms || {};
    const ocorr = arr(d.ocorrencias);
    const corpo = $('#p-corpo');

    if (vista === 'ocorrencias') {
        corpo.innerHTML = `<div class="p-voltar"><button data-v="inicio">←</button><h4>Ocorrências abertas</h4></div>
            ${ocorr.length ? ocorr.map((o) => {
                const com = arr(o.policiais);
                return `<div class="p-oc pri-${o.prioridade}">
                    <div class="p-oc-topo"><span class="cod">${esc(o.codigo)}</span><span>#${o.id} · ${o.minutos ? 'há ' + o.minutos + ' min' : 'agora'}</span><span class="dist">${metros(o.distancia)}</span></div>
                    <b>${esc(o.titulo)}</b>
                    <div class="sub">${esc(o.local_ || '')}${o.descricao ? ' · ' + esc(o.descricao) : ''}</div>
                    <div class="sub">${com.length ? 'Com ' + esc(com.join(', ')) : 'Ninguém assumiu'}</div>
                    <div class="acoes"><button class="pri" data-oc="assumir" data-id="${o.id}">Assumir</button>
                    <button data-oc="gps" data-id="${o.id}" data-x="${o.centro.x}" data-y="${o.centro.y}">GPS</button>
                    <button data-oc="encerrar" data-id="${o.id}">Encerrar</button></div></div>`;
            }).join('') : '<div class="p-vazio">Nenhuma ocorrência aberta.</div>'}`;
    } else if (vista === 'blitz') {
        corpo.innerHTML = `<div class="p-voltar"><button data-v="inicio">←</button><h4>Blitz</h4></div>
            <div class="p-grade">${arr(d.objetos).map((o) => botaoPainel({ id: 'obj:' + o.id, icone: o.tapete ? 'tapete' : 'cone', titulo: o.label, sub: 'colocar' })).join('')}</div>`;
    } else {
        corpo.innerHTML = `
            ${d.servico ? '' : '<div class="p-aviso">Você está fora de serviço. Bata o ponto na recepção da DP de Mission Row.</div>'}
            <div class="p-numeros">
                <div class="p-num"><b>${d.colegas}</b><span>policiais em serviço</span></div>
                <div class="p-num ${ocorr.length ? 'alerta' : ''}"><b>${ocorr.length}</b><span>ocorrências abertas</span></div>
            </div>
            <div class="p-grade">
                ${botaoPainel({ id: 'tablet', icone: 'tablet', titulo: 'Tablet', sub: 'fichas, BO, mandados', desabilitado: !d.servico })}
                ${botaoPainel({ id: 'v:ocorrencias', icone: 'ocorr', titulo: 'Ocorrências', sub: 'assumir e GPS', desabilitado: !d.servico, badge: ocorr.length || '' })}
                ${botaoPainel({ id: 'v:blitz', icone: 'blitz', titulo: 'Blitz', sub: 'cones, barreira, tapete', desabilitado: !d.servico || !pd.objetos })}
                ${botaoPainel({ id: 'radar', icone: 'radar', titulo: 'Radar', sub: d.radar ? 'ligado' : 'na viatura', desabilitado: !d.servico || !pd.radarMovel, classe: d.radar ? 'ligado' : '' })}
                ${botaoPainel({ id: 'limpar', icone: 'limpar', titulo: 'Limpar cena', sub: 'perícia', desabilitado: !d.servico || !pd.pericia })}
                ${botaoPainel({ id: 'dp', icone: 'pin', titulo: 'Voltar à DP', sub: 'GPS para Mission Row' })}
                ${botaoPainel({ id: 'panico', icone: 'panico', titulo: 'PÂNICO', classe: 'panico', desabilitado: !d.servico })}
            </div>`;
    }

    $$('[data-v]', corpo).forEach((b) => (b.onclick = () => { vista = b.dataset.v; desenharPainel(); }));
    $$('[data-p]', corpo).forEach((b) => (b.onclick = () => {
        const id = b.dataset.p;
        if (id.startsWith('v:')) { vista = id.slice(2); desenharPainel(); return; }
        if (id.startsWith('obj:')) return painelAcao('objeto', { id: id.slice(4) });
        painelAcao(id);
    }));
    $$('[data-oc]', corpo).forEach((b) => (b.onclick = () => painelAcao(b.dataset.oc, {
        id: Number(b.dataset.id), x: Number(b.dataset.x), y: Number(b.dataset.y),
    })));
}
$('#p-fechar').onclick = () => painelAcao('fechar');
$('#p-mover').onclick = () => painelAcao('widgets');

// ================================================================== mensagens novas
window.addEventListener('message', ({ data }) => {
    if (!data || !data.acao) return;
    switch (data.acao) {
        case 'cardNovo': novoCard(data.card); break;
        case 'cardRemover': removerCard(data.id); break;
        case 'cardAssumido': {
            const c = cards.get(data.id);
            if (!c) break;
            const rod = $('.ca-rodape', c.el);
            rod.innerHTML = data.eu ? '<span class="ca-meu">✓ Você assumiu · rota marcada no GPS</span>' : `<span class="ca-com">Assumida por ${esc(data.nome)}</span>`;
            clearTimeout(c.timer);
            c.timer = setTimeout(() => removerCard(data.id), data.eu ? 4000 : 6000);
            break;
        }
        case 'cardDistancias':
            for (const x of arr(data.lista)) {
                const c = cards.get(x.id);
                if (c) $('.dist', c.el).textContent = metros(x.d);
            }
            break;
        case 'painelAbrir':
            P_ = data.dados; vista = data.vista || 'inicio';
            $('#painel').classList.remove('oculto');
            document.body.classList.add('painel-aberto');
            desenharPainel();
            break;
        case 'painelDados':
            P_ = data.dados; desenharPainel();
            break;
        case 'painelFechar':
            $('#painel').classList.add('oculto');
            document.body.classList.remove('painel-aberto');
            break;
    }
});

// ================================================================== POSIÇÃO DOS WIDGETS
const WIDGETS = {
    radar: { sel: '#radar', nome: 'Radar móvel' },
    cards: { sel: '#cards', nome: 'Avisos de ocorrência' },
    painel: { sel: '#painel', nome: 'Painel F6' },
};
let posicoes = {};      // { id: { x, y, s, baixo } } x/y em % da tela
let editandoW = false;
let antesDeEditar = null;

function aplicarWidget(id) {
    const el = $(WIDGETS[id].sel);
    const p = posicoes[id];
    // volta ao padrão do CSS
    ['left', 'top', 'right', 'bottom', 'transform', 'transformOrigin', 'animation', 'flexDirection'].forEach((k) => (el.style[k] = ''));
    if (!p) return;
    el.style.left = p.x + '%';
    el.style.right = 'auto';
    el.style.transformOrigin = p.baixo ? 'bottom left' : 'top left';
    el.style.transform = `scale(${p.s || 1})`;
    el.style.animation = 'none';
    if (p.baixo) {
        el.style.top = 'auto';
        el.style.bottom = p.b + '%';
        if (id === 'cards') el.style.flexDirection = 'column-reverse';
    } else {
        el.style.top = p.y + '%';
        el.style.bottom = 'auto';
    }
}
const aplicarTodos = () => Object.keys(WIDGETS).forEach(aplicarWidget);

// carrega o que o jogador salvou
post('widgetsPedir').then((txt) => {
    try { posicoes = typeof txt === 'string' ? JSON.parse(txt) : (txt || {}); } catch { posicoes = {}; }
    aplicarTodos();
});

// conteúdo de exemplo enquanto edita
const EXEMPLO_CARD = { id: -1, codigo: '10-71', titulo: 'Exemplo de ocorrência', descricao: 'Sultan prata · placa 45A*** · Suspeito: homem',
    prioridade: 'alta', rua: 'Grove St', zona: 'Davis', distancia: 840, tecla: 'Y', duracao: 9999, som: false, max: 4, policiais: [] };

function prepararExemplos(ligar) {
    const radar = $('#radar'), painel = $('#painel');
    if (ligar) {
        antesDeEditar = { radar: radar.classList.contains('oculto'), painel: painel.classList.contains('oculto'), P: P_ };
        radar.classList.remove('oculto');
        painel.classList.remove('oculto');
        if (!P_) { P_ = { nome: 'Seu nome', patente: 'Patente', servico: true, colegas: 0, ocorrencias: [], perms: {}, objetos: [] }; vista = 'inicio'; desenharPainel(); }
        if (!cards.size) novoCard(EXEMPLO_CARD);
    } else if (antesDeEditar) {
        radar.classList.toggle('oculto', antesDeEditar.radar);
        painel.classList.toggle('oculto', antesDeEditar.painel);
        P_ = antesDeEditar.P;
        removerCard(-1);
    }
}

function lerPosicao(id) {
    const el = $(WIDGETS[id].sel);
    const r = el.getBoundingClientRect();
    const W = window.innerWidth, H = window.innerHeight;
    const s = posicoes[id]?.s || 1;
    const baixo = (r.top + r.height / 2) > H / 2;
    return { x: +(r.left / W * 100).toFixed(2), y: +(r.top / H * 100).toFixed(2), b: +((H - r.bottom) / H * 100).toFixed(2), s, baixo };
}

function iniciarEdicao() {
    editandoW = true;
    const salvo = JSON.parse(JSON.stringify(posicoes));
    $('#editor').classList.remove('oculto');
    prepararExemplos(true);
    for (const [id, w] of Object.entries(WIDGETS)) {
        const el = $(w.sel);
        el.classList.add('editavel');
        el.dataset.nome = w.nome;
        el.onmousedown = (e) => {
            e.preventDefault();
            const r = el.getBoundingClientRect();
            const dx = e.clientX - r.left, dy = e.clientY - r.top;
            // fixa pelo topo/esquerda durante o arraste
            posicoes[id] = { ...lerPosicao(id), baixo: false };
            aplicarWidget(id);
            el.classList.add('arrastando');
            const mover = (ev) => {
                const W = window.innerWidth, H = window.innerHeight;
                const x = Math.min(Math.max(ev.clientX - dx, 0), W - 40);
                const y = Math.min(Math.max(ev.clientY - dy, 0), H - 30);
                posicoes[id].x = +(x / W * 100).toFixed(2);
                posicoes[id].y = +(y / H * 100).toFixed(2);
                aplicarWidget(id);
            };
            const soltar = () => {
                document.removeEventListener('mousemove', mover);
                document.removeEventListener('mouseup', soltar);
                el.classList.remove('arrastando');
                posicoes[id] = lerPosicao(id);
                aplicarWidget(id);
            };
            document.addEventListener('mousemove', mover);
            document.addEventListener('mouseup', soltar);
        };
        el.onwheel = (e) => {
            e.preventDefault();
            const atual = posicoes[id] || lerPosicao(id);
            atual.s = Math.min(1.6, Math.max(0.6, +((atual.s || 1) + (e.deltaY < 0 ? 0.05 : -0.05)).toFixed(2)));
            posicoes[id] = atual;
            aplicarWidget(id);
        };
    }
    const terminar = (salvar) => {
        editandoW = false;
        $('#editor').classList.add('oculto');
        for (const w of Object.values(WIDGETS)) {
            const el = $(w.sel);
            el.classList.remove('editavel', 'arrastando');
            el.onmousedown = null; el.onwheel = null;
        }
        if (!salvar) posicoes = salvo;
        aplicarTodos();
        prepararExemplos(false);
        post(salvar ? 'widgetsSalvar' : 'widgetsCancelar', salvar ? posicoes : {});
    };
    $('#ed-salvar').onclick = () => terminar(true);
    $('#ed-cancelar').onclick = () => terminar(false);
    $('#ed-padrao').onclick = () => { posicoes = {}; aplicarTodos(); };
}

document.addEventListener('keydown', (e) => { if (editandoW && e.key === 'Escape') $('#ed-cancelar').click(); });
window.addEventListener('message', ({ data }) => { if (data && data.acao === 'widgetsEditar' && !editandoW) iniciarEdicao(); });
