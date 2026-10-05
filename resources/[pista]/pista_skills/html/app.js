// Tela de habilidades (pista_skills)
(() => {
    const RECURSO = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
    const $ = id => document.getElementById(id);

    // ------------------------------------------------------------------
    // Ícones (SVG de traço, 24x24). p: = path, c: = círculo cx,cy,r
    // ------------------------------------------------------------------
    const ICONES = {
        chave: ['p:M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.5 2.5-2.4-.6-.6-2.4z'],
        ferramentas: ['p:M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.5 2.5-2.4-.6-.6-2.4z', 'p:M4 4l5 5M3 6l3-3'],
        engrenagem: ['c:12,12,3', 'c:12,12,7', 'p:M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1'],
        engrenagens: ['c:9,9,2', 'c:9,9,5', 'p:M9 2v2M9 14v2M2 9h2M14 9h2M4 4l1.5 1.5M12.5 12.5L14 14M4 14l1.5-1.5M12.5 5.5L14 4', 'c:17,17,3.5', 'p:M17 12v1.5M17 20.5V22M12 17h1.5M20.5 17H22'],
        vento: ['p:M3 8h11a3 3 0 1 0-3-3M3 12h15a3 3 0 1 1-3 3M3 16h8'],
        turbina: ['c:12,12,9', 'c:12,12,2', 'p:M12 10c0-3 1-5 4-6.5M14 12.8c2.6 1.6 4.8 1.7 7 .2M10.2 13.2c-2.6 1.4-3.8 3.4-3.4 6.2'],
        motor: ['p:M4 9h3l2-2h5l2 2h2v3h2v-2h2v6h-2v-2h-2v3h-3l-2 2H9l-2-2H4zM2 11v4'],
        martelo: ['p:M14 4l6 6-3 3-6-6zM12.5 8.5L3 18l3 3 9.5-9.5'],
        freio: ['c:12,12,9', 'c:12,12,3', 'p:M16 4.5a9 9 0 0 1 3.5 4M12 6v1M12 17v1M6 12h1M17 12h1'],
        suspensao: ['p:M12 2v3M12 19v3M8 5h8M8 19h8M9 8l6 2-6 2 6 2-6 2'],
        ajuste: ['p:M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12', 'c:16,6,2', 'c:10,12,2', 'c:18,18,2'],
        chip: ['p:M7 7h10v10H7zM10 10h4v4h-4zM9.5 3v4M14.5 3v4M9.5 17v4M14.5 17v4M3 9.5h4M3 14.5h4M17 9.5h4M17 14.5h4'],
        chama: ['p:M12 3c1 3 5 5 5 10a5 5 0 0 1-10 0c0-3 2-4 2-6 1 1 2 2 2 4 1-2 1-5 1-8z'],
        notebook: ['p:M4 5h16v10H4zM2 19h20M10 8.5l-2 2 2 2M14 8.5l2 2-2 2'],
        mao: ['p:M7 12V6a1.5 1.5 0 0 1 3 0v5M10 10V4.5a1.5 1.5 0 0 1 3 0V10M13 10.5V6a1.5 1.5 0 0 1 3 0v5M16 9a1.5 1.5 0 0 1 3 0v5a7 7 0 0 1-7 7h-.5a6 6 0 0 1-5-2.7l-3-4.6a1.5 1.5 0 0 1 2.4-1.8L7 14'],
        raio: ['p:M13 2L4 14h7l-1 8 9-12h-7z'],
        mira: ['c:12,12,8', 'c:12,12,1', 'p:M12 2v5M12 17v5M2 12h5M17 12h5'],
        estrela: ['p:M12 3l2.8 5.7 6.2.9-4.5 4.4 1 6.2L12 17.3 6.5 20.2l1-6.2L3 9.6l6.2-.9z'],
        carro: ['p:M3 16v-3l2-5h14l2 5v3zM5 13h14', 'c:7,17,2', 'c:17,17,2'],
        bandeira: ['p:M5 21V4M5 4h13l-3 4 3 4H5'],
        mascara: ['p:M3 8c3-2 6-2 9-1 3-1 6-1 9 1 0 6-3 10-6 10-1 0-2-2-3-2s-2 2-3 2c-3 0-6-4-6-10zM7 11h3M14 11h3'],
        velocimetro: ['p:M4 18a9 9 0 1 1 16 0M12 14l4-5', 'c:12,14,1'],
        aprendiz: ['p:M2 9l10-5 10 5-10 5zM6 11v5c3 2 9 2 12 0v-5M22 9v6'],
        livro: ['p:M12 7v13M4 5h5a3 3 0 0 1 3 3 3 3 0 0 1 3-3h5v13h-5a3 3 0 0 0-3 2 3 3 0 0 0-3-2H4z'],
        cronometro: ['c:12,14,7', 'p:M12 14v-4M10 3h4M12 3v4M18 7l1.5-1.5'],
        alerta: ['p:M12 3l10 18H2zM12 10v5M12 18v.5'],
        x: ['p:M6 6l12 12M18 6L6 18'],
        check: ['p:M5 12l5 5 9-10'],
        cadeado: ['p:M6 11h12v9H6zM8 11V8a4 4 0 0 1 8 0v3'],
        mais: ['p:M12 5v14M5 12h14'],
        crachá: ['p:M4 7h16v13H4zM9 7V4h6v3', 'c:12,13,2', 'p:M8 18c1-2 7-2 8 0'],
    };

    function icone(nome) {
        const partes = (ICONES[nome] || ICONES.chave).map(p => {
            const [t, d] = [p.slice(0, 1), p.slice(2)];
            if (t === 'c') { const [cx, cy, r] = d.split(','); return `<circle cx="${cx}" cy="${cy}" r="${r}"/>`; }
            return `<path d="${d}"/>`;
        }).join('');
        return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${partes}</svg>`;
    }

    function rgba(hex, a) {
        const n = parseInt(hex.replace('#', ''), 16);
        return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${a})`;
    }

    function pintarCor(el, cor) {
        el.style.setProperty('--cor', cor);
        [10, 12, 18, 45, 70].forEach(p => el.style.setProperty(`--cor-${p}`, rgba(cor, p / 100)));
    }

    const numero = n => Number(n || 0).toLocaleString('pt-BR');

    // ------------------------------------------------------------------
    // Estado
    // ------------------------------------------------------------------
    let defs = {};       // definições das árvores (vem do config.lua)
    let estado = {};     // estado do jogador por árvore
    let ativa = 'mecanica';
    let selecionada = null;
    let emBreve = [];

    async function enviar(nome, dados = {}) {
        if (!RECURSO) return previaLocal(nome, dados);
        try {
            const r = await fetch(`https://${RECURSO}/${nome}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(dados),
            });
            return await r.json();
        } catch { return null; }
    }

    const arv = () => defs[ativa];
    const est = () => estado[ativa] || { xp: 0, nivel: 1, pontos: 0, habilidades: [] };
    const hab = id => arv().habilidades.find(h => h.id === id);
    const temHab = id => est().profissional || (est().habilidades || []).includes(id);

    function situacao(h) {
        const e = est();
        if (temHab(h.id)) return 'aprendida';
        if (e.nivel < h.nivel) return 'bloqueada-nivel';
        if ((h.requer || []).some(r => !temHab(r))) return 'bloqueada';
        if (e.pontos < (h.custo || 1)) return 'sem-pontos';
        return 'disponivel';
    }

    // ------------------------------------------------------------------
    // Lateral
    // ------------------------------------------------------------------
    function desenharLateral() {
        const a = arv(), e = est();
        $('nivel').textContent = e.nivel;
        $('nivelMax').textContent = `de ${a.niveis.length}`;
        $('arvoreNome').textContent = a.label;

        const base = a.niveis[e.nivel - 1] || 0;
        const prox = a.niveis[e.nivel];
        let p = 1;
        if (prox !== undefined) {
            p = (e.xp - base) / (prox - base);
            $('xpTexto').textContent = `${numero(e.xp)} / ${numero(prox)} XP`;
            $('xpFalta').textContent = `faltam ${numero(prox - e.xp)}`;
        } else {
            $('xpTexto').textContent = `${numero(e.xp)} XP`;
            $('xpFalta').textContent = 'nível máximo';
        }
        p = Math.max(0, Math.min(1, p));
        $('barraXP').style.width = `${p * 100}%`;
        $('anelXP').style.strokeDashoffset = `${326.7 * (1 - p)}`;

        $('pontos').textContent = e.pontos;
        $('pontosLabel').textContent = e.pontos === 1 ? 'ponto livre' : 'pontos livres';
        $('pontosTotal').textContent = `${e.pontosTotais || 0} ganhos no total`;
        $('cartaoPontos').classList.toggle('tem', e.pontos > 0);

        const lim = e.limiteDiario || 0;
        $('hojeTexto').textContent = lim > 0 ? `${numero(e.xpHoje)} / ${numero(lim)}` : `${numero(e.xpHoje)} (sem limite)`;
        $('barraHoje').style.width = lim > 0 ? `${Math.min(100, (e.xpHoje / lim) * 100)}%` : '0%';
        $('barraHoje').parentElement.classList.toggle('cheia', lim > 0 && e.xpHoje >= lim);

        const prof = $('profissional');
        prof.classList.toggle('oculto', !e.profissional);
        prof.innerHTML = `${icone('crachá')}<span>Em serviço como mecânico especializado: você já sabe todas as habilidades.</span>`;
    }

    function desenharAbas() {
        const abas = $('abas');
        abas.innerHTML = '';
        Object.entries(defs).forEach(([id, a]) => {
            const b = document.createElement('button');
            b.className = 'aba' + (id === ativa ? ' ativa' : '');
            b.innerHTML = `${icone(a.icone)}${a.label}`;
            b.onclick = () => { ativa = id; selecionada = null; desenharTudo(); };
            abas.appendChild(b);
        });
        emBreve.forEach(a => {
            const b = document.createElement('button');
            b.className = 'aba';
            b.disabled = true;
            b.innerHTML = `${icone(a.icone)}${a.label}<span class="breve">EM BREVE</span>`;
            abas.appendChild(b);
        });
    }

    function desenharFontes(fontes) {
        $('fontes').innerHTML = (fontes || []).map(f =>
            `<li><div class="ic">${icone(f.icone)}</div><div><b>${f.titulo}</b><span>${f.texto}</span></div></li>`).join('');
    }

    // ------------------------------------------------------------------
    // Árvore: colunas por ramo, linhas por nível
    // ------------------------------------------------------------------
    const TOPO = 58;

    function desenharArvore() {
        const a = arv(), e = est();
        const mapa = $('mapa');
        mapa.querySelectorAll('.no, .cab-ramo').forEach(el => el.remove());

        const linhas = Math.max(...a.habilidades.map(h => h.nivel));
        const alturaUtil = mapa.clientHeight - TOPO - 6;
        const linhaH = Math.min(74, Math.floor(alturaUtil / linhas));
        document.documentElement.style.setProperty('--linha-h', `${linhaH}px`);

        const ramos = a.ramos;
        const colW = Math.min(190, Math.floor(mapa.clientWidth / ramos.length));
        document.documentElement.style.setProperty('--col-w', `${colW}px`);
        const ox = Math.floor((mapa.clientWidth - colW * ramos.length) / 2);
        const noW = colW - 14, noH = 50;
        const yNivel = n => TOPO + (n - 1) * linhaH + (linhaH - noH) / 2;

        // régua
        const regua = $('regua');
        regua.innerHTML = '<div class="cabeca">NÍVEL</div>';
        for (let n = 1; n <= linhas; n++) {
            const m = document.createElement('div');
            m.className = 'marca-nivel' + (n === e.nivel ? ' atual' : n < e.nivel ? ' alcancado' : '');
            m.style.top = `${TOPO + (n - 1) * linhaH}px`;
            m.textContent = n;
            regua.appendChild(m);
        }

        // cabeçalhos dos ramos
        ramos.forEach((r, i) => {
            const c = document.createElement('div');
            c.className = 'cab-ramo';
            pintarCor(c, r.cor);
            c.style.left = `${ox + i * colW + 4}px`;
            c.style.width = `${colW - 8}px`;
            c.innerHTML = `${icone(r.icone)}${r.label}`;
            mapa.appendChild(c);
        });

        // posições
        const pos = {};
        a.habilidades.forEach(h => {
            const i = ramos.findIndex(r => r.id === h.ramo);
            const x = i >= 0 ? ox + i * colW + 7 : ox + (colW * ramos.length - noW) / 2;
            pos[h.id] = { x, y: yNivel(h.nivel), w: noW, h: noH, col: i };
        });

        // nós
        a.habilidades.forEach(h => {
            const s = situacao(h);
            const ramo = ramos.find(r => r.id === h.ramo);
            const p = pos[h.id];
            const no = document.createElement('div');
            no.className = `no ${s}${s === 'bloqueada-nivel' ? ' bloqueada' : ''}${selecionada === h.id ? ' selecionada' : ''}`;
            pintarCor(no, ramo ? ramo.cor : '#f1c232');
            Object.assign(no.style, { left: `${p.x}px`, top: `${p.y}px` });
            const custo = h.custo || 1;
            const legenda = s === 'aprendida' ? (e.profissional && !(e.habilidades || []).includes(h.id) ? 'pela profissão' : 'aprendida')
                : `${custo} ponto${custo > 1 ? 's' : ''}`;
            const selo = { aprendida: 'check', disponivel: 'mais', 'sem-pontos': 'mais', bloqueada: 'cadeado', 'bloqueada-nivel': 'cadeado' }[s];
            no.innerHTML = `<div class="ic">${icone(h.icone)}</div><div class="txt"><b>${h.label}</b><small>${legenda}</small></div><div class="selo">${icone(selo)}</div>`;
            no.onclick = () => { selecionada = h.id; desenharArvore(); desenharDetalhe(); };
            mapa.appendChild(no);
        });

        // ligações
        const svg = $('ligacoes');
        let caminhos = '';
        a.habilidades.forEach(h => {
            (h.requer || []).forEach(req => {
                const pa = pos[req], pf = pos[h.id];
                if (!pa || !pf) return;
                const x1 = pa.x + pa.w / 2, y1 = pa.y + pa.h;
                const x2 = pf.x + pf.w / 2, y2 = pf.y;
                let d;
                if (Math.abs(x1 - x2) < 1) d = `M${x1} ${y1} V${y2}`;
                else {
                    const meio = y1 + 12;
                    d = `M${x1} ${y1} V${meio} H${x2} V${y2}`;
                }
                let cls = '';
                if (temHab(req) && temHab(h.id)) cls = 'ativa';
                else if (temHab(req) && situacao(h) === 'disponivel') cls = 'pronta';
                if (h.ramo === 'passivas' && !cls) cls = 'passiva';
                caminhos += `<path class="${cls}" d="${d}"/>`;
            });
        });
        svg.innerHTML = caminhos;

        // linha "você está aqui"
        const voce = $('voce');
        const nVoce = Math.min(e.nivel, linhas);
        voce.style.top = `${TOPO + nVoce * linhaH - 1}px`;
        voce.classList.toggle('oculto', e.nivel >= linhas);
    }

    // ------------------------------------------------------------------
    // Detalhe
    // ------------------------------------------------------------------
    function desenharDetalhe() {
        const h = selecionada && hab(selecionada);
        $('detalheVazio').classList.toggle('oculto', !!h);
        $('detalheConteudo').classList.toggle('oculto', !h);
        if (!h) return;

        const e = est();
        const ramo = arv().ramos.find(r => r.id === h.ramo);
        const cor = ramo ? ramo.cor : '#f1c232';
        pintarCor($('detalheConteudo'), cor);
        $('detIcone').innerHTML = icone(h.icone);
        $('detRamo').textContent = ramo ? ramo.label : 'Base';
        $('detNome').textContent = h.label;

        const custo = h.custo || 1;
        const nivelOk = e.nivel >= h.nivel;
        $('detNivel').textContent = `Nível ${h.nivel}`;
        $('detNivel').className = 'tag ' + (nivelOk ? 'ok' : 'ruim');
        $('detCusto').textContent = `${custo} ponto${custo > 1 ? 's' : ''}`;
        $('detCusto').className = 'tag ' + (e.pontos >= custo || temHab(h.id) ? 'ok' : 'ruim');
        $('detDesc').textContent = h.desc;

        const reqs = [`<li class="${nivelOk ? 'ok' : 'falta'}">${icone(nivelOk ? 'check' : 'x')}Nível ${h.nivel} em ${arv().label.toLowerCase()}</li>`];
        (h.requer || []).forEach(r => {
            const ok = temHab(r);
            reqs.push(`<li class="${ok ? 'ok' : 'falta'}">${icone(ok ? 'check' : 'x')}${hab(r).label}</li>`);
        });
        $('detReqs').innerHTML = reqs.join('');

        const s = situacao(h);
        const btn = $('aprender');
        btn.classList.toggle('feito', s === 'aprendida');
        btn.disabled = s !== 'disponivel';
        btn.textContent = s === 'aprendida' ? 'Aprendida' : `Aprender · ${custo} ponto${custo > 1 ? 's' : ''}`;
        $('detStatus').textContent = {
            aprendida: e.profissional && !(e.habilidades || []).includes(h.id) ? 'Liberada pela sua profissão' : 'Você já sabe fazer isso',
            disponivel: 'Pronta para aprender',
            'sem-pontos': `Faltam ${custo - e.pontos} ponto(s): suba de nível`,
            bloqueada: 'Aprenda os requisitos antes',
            'bloqueada-nivel': `Libera no nível ${h.nivel} (faltam ${numero((arv().niveis[h.nivel - 1] || 0) - e.xp)} XP)`,
        }[s];
    }

    $('aprender').onclick = async () => {
        if (!selecionada) return;
        const r = await enviar('aprender', { arvore: ativa, id: selecionada });
        if (!r) return;
        aviso(r.msg || (r.ok ? 'Aprendida!' : 'Não foi possível'), r.ok);
        if (r.estado) { estado = r.estado; desenharTudo(); }
    };

    // ------------------------------------------------------------------
    let timerAviso = null;
    function aviso(msg, ok) {
        const el = $('aviso');
        el.textContent = msg;
        el.className = 'aviso ' + (ok ? 'ok' : 'erro');
        clearTimeout(timerAviso);
        timerAviso = setTimeout(() => el.classList.add('oculto'), 2600);
    }

    function desenharTudo() {
        if (!arv()) return;
        desenharAbas();
        desenharLateral();
        desenharArvore();
        desenharDetalhe();
    }

    function escalar() {
        const s = Math.min(1.35, (window.innerWidth - 40) / 1320, (window.innerHeight - 40) / 780);
        $('janela').style.transform = `scale(${s})`;
    }
    window.addEventListener('resize', escalar);

    function abrir(d) {
        defs = d.arvores || {};
        estado = d.estado || {};
        emBreve = d.emBreve || [];
        if (!defs[ativa]) ativa = Object.keys(defs)[0];
        if (d.nome) $('nome').textContent = d.nome;
        desenharFontes(d.fontes);
        $('fechar').innerHTML = icone('x');
        document.querySelector('.vazio-icone').innerHTML = icone('ferramentas');
        $('skills').classList.remove('oculto');
        escalar();
        requestAnimationFrame(() => {
            desenharTudo();
            // abre já mostrando algo que dá para aprender
            const pronta = arv().habilidades.find(h => situacao(h) === 'disponivel');
            if (pronta && !selecionada) { selecionada = pronta.id; desenharArvore(); desenharDetalhe(); }
        });
    }

    function fechar() {
        $('skills').classList.add('oculto');
        $('subiu').classList.add('oculto');
        selecionada = null;
        enviar('fechar');
    }

    $('fechar').onclick = fechar;
    window.addEventListener('keydown', ev => { if (ev.key === 'Escape' && !$('skills').classList.contains('oculto')) fechar(); });

    window.addEventListener('message', ({ data }) => {
        if (!data) return;
        if (data.acao === 'abrir') abrir(data);
        if (data.acao === 'fechar') { $('skills').classList.add('oculto'); selecionada = null; }
        if (data.acao === 'estado') { estado = data.estado || {}; if (!$('skills').classList.contains('oculto')) desenharTudo(); }
        if (data.acao === 'subiu' && data.arvore === ativa) {
            const a = arv();
            const extra = (a.pontosExtras && a.pontosExtras[data.nivel]) || 0;
            const ganhos = (a.pontosPorNivel || 1) + extra;
            $('subiuNivel').textContent = data.nivel;
            $('subiuTexto').textContent = `+${ganhos} ponto${ganhos > 1 ? 's' : ''} de habilidade`;
            $('subiu').classList.remove('oculto');
            setTimeout(() => $('subiu').classList.add('oculto'), 2600);
        }
    });

    // ------------------------------------------------------------------
    // Fora do jogo (navegador): simula o servidor para testar a tela
    // ------------------------------------------------------------------
    function previaLocal(nome, dados) {
        if (nome !== 'aprender') return {};
        const e = est(), h = hab(dados.id);
        if (!h || situacao(h) !== 'disponivel') return { ok: false, msg: 'Não dá para aprender agora' };
        e.habilidades = [...(e.habilidades || []), h.id];
        e.pontos -= h.custo || 1;
        return { ok: true, msg: `Você aprendeu: ${h.label}`, estado };
    }
})();
