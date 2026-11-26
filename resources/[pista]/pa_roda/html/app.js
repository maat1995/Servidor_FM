(() => {
    const $ = (id) => document.getElementById(id);
    const recurso = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pa_roda';

    const TIPOS = {
        longa: 'Arma longa', pistola: 'Pistola', desarmado: 'Desarmado',
        arremesso: 'Arremesso', branca: 'Arma branca', outros: 'Outros', item: 'Item',
    };
    const ICONES = {
        desarmado: '<path d="M8 13V5.5a1.5 1.5 0 0 1 3 0V12M11 11.5v-2a1.5 1.5 0 0 1 3 0V12M14 10.5a1.5 1.5 0 0 1 3 0V12M17 11.5a1.5 1.5 0 0 1 3 0V16a6 6 0 0 1-6 6h-2a6 6 0 0 1-5.2-3l-2.6-4.5a1.5 1.5 0 0 1 2.6-1.5L8 15"/>',
        vazio: '<path d="M8 12h8"/>',
    };

    let dados = null;
    let aba = 'armas';
    let sel = 4;
    let tecla = 'Z';
    let escolhido = false;
    const opcaoIdx = { armas: [0, 0, 0, 0, 0, 0, 0, 0], itens: [0, 0, 0, 0, 0, 0, 0, 0] };

    const escala = () => Math.min(window.innerHeight / 1080, window.innerWidth / 1920) * 1.0;
    function aplicarEscala() { document.documentElement.style.setProperty('--s', Math.max(0.7, escala()).toFixed(3)); }
    window.addEventListener('resize', aplicarEscala);

    // ------------------------------------------------------------------
    // Montagem dos 8 espaços
    // ------------------------------------------------------------------
    const CX = 310, CY = 280, RX = 228, RY = 196;
    const espacos = [];
    (function criar() {
        const box = $('espacos');
        for (let i = 0; i < 8; i++) {
            const a = (i * 45) * Math.PI / 180;
            const el = document.createElement('div');
            el.className = 'esp';
            el.style.left = `${CX + RX * Math.sin(a)}px`;
            el.style.top = `${CY - RY * Math.cos(a)}px`;
            box.appendChild(el);
            espacos.push(el);
        }
    })();

    // O Lua manda tabela vazia como objeto {} e listas com buraco: normaliza para array
    const lista = (v) => (Array.isArray(v) ? v : v && typeof v === 'object' ? Object.values(v) : []);
    const posicoes = () => (dados ? lista(dados[aba]) : []);
    function atual(i) {
        const p = posicoes()[i];
        if (!p) return { pos: null, e: null };
        const ops = lista(p.opcoes).filter(Boolean);
        const k = Math.min(opcaoIdx[aba][i], Math.max(0, ops.length - 1));
        return { pos: p, e: ops[k] || null, total: ops.length, k };
    }

    function svg(path) { return `<svg class="icone" viewBox="0 0 24 24">${path}</svg>`; }

    function texto(el, cls, t) {
        const s = document.createElement('span');
        s.className = cls;
        s.textContent = t;
        el.appendChild(s);
    }

    function pintarEspaco(i) {
        const el = espacos[i];
        const { pos, e, total } = atual(i);
        el.innerHTML = '';
        el.className = 'esp';
        if (i === sel) el.classList.add('sel');

        if (!e) {
            el.classList.add('vazio');
            el.innerHTML = svg(ICONES.vazio);
            texto(el, 'rot', pos ? TIPOS[pos.tipo] || '' : '');
            return;
        }
        if (e.desarmado) {
            el.innerHTML = svg(ICONES.desarmado);
            texto(el, 'rot', 'Desarmado');
            if (e.naMao) el.insertAdjacentHTML('beforeend', '<span class="mao"></span>');
            return;
        }
        const img = document.createElement('img');
        img.src = e.img;
        img.onerror = () => { img.replaceWith(Object.assign(document.createElement('span'), { innerHTML: svg(ICONES.vazio) })); };
        el.appendChild(img);
        texto(el, 'rot', e.label);
        if (e.pente !== undefined && e.pente !== null) texto(el, 'num', `${e.pente}/${e.reserva || 0}`);
        else if (e.qtd && e.qtd > 1) texto(el, 'num', `${e.qtd}x`);
        if (total > 1) texto(el, 'mais', `+${total - 1}`);
        if (e.naMao) el.insertAdjacentHTML('beforeend', '<span class="mao"></span>');
        if (typeof e.durabilidade === 'number') {
            el.insertAdjacentHTML('beforeend', `<span class="dur"><i class="${e.durabilidade < 25 ? 'baixa' : ''}" style="width:${Math.max(0, Math.min(100, e.durabilidade))}%"></i></span>`);
        }
    }

    function pintarCentro() {
        const { pos, e, total, k } = atual(sel);
        const nome = $('c-nome'), sub = $('c-sub'), mun = $('c-municao'), extra = $('c-extra');
        mun.innerHTML = ''; extra.textContent = '';

        let alvo = e;
        let subTxt = '';
        if (!alvo) {
            alvo = aba === 'armas' && dados.naMao ? dados.naMao : null;
            subTxt = alvo ? 'na mão' : (pos ? `${TIPOS[pos.tipo]} vazio` : '');
            nome.textContent = alvo ? alvo.label : 'Nada aqui';
        } else if (alvo.desarmado) {
            nome.textContent = 'Desarmado';
            subTxt = alvo.naMao ? 'na mão' : 'guardar a arma';
        } else {
            nome.textContent = alvo.label;
            subTxt = alvo.naMao ? 'na mão' : (pos ? TIPOS[pos.tipo] : '');
        }
        sub.textContent = subTxt;

        if (alvo && alvo.pente !== undefined && alvo.pente !== null) {
            mun.innerHTML = `${alvo.pente} <small>/ ${alvo.reserva || 0}</small>`;
        } else if (alvo && alvo.qtd) {
            mun.innerHTML = `<small>x</small>${alvo.qtd}`;
        }
        if (e && total > 1) extra.textContent = `${k + 1} de ${total} · role para trocar`;
    }

    function pintar() {
        document.querySelectorAll('#abas span').forEach((s) => s.classList.toggle('ativa', s.dataset.aba === aba));
        for (let i = 0; i < 8; i++) pintarEspaco(i);
        pintarCentro();
    }

    // ------------------------------------------------------------------
    // Mouse
    // ------------------------------------------------------------------
    document.addEventListener('mousemove', (ev) => {
        if (!dados) return;
        const dx = ev.clientX - window.innerWidth / 2;
        const dy = ev.clientY - window.innerHeight / 2;
        if (Math.hypot(dx, dy) < 45 * escala()) return;
        let ang = Math.atan2(dx, -dy) * 180 / Math.PI;
        if (ang < 0) ang += 360;
        $('ponteiro').style.transform = `rotate(${ang}deg)`;
        const i = Math.round(ang / 45) % 8;
        if (i !== sel) { sel = i; pintar(); }
    });

    document.addEventListener('wheel', (ev) => {
        if (!dados) return;
        const { total } = atual(sel);
        if (total > 1) {
            const n = opcaoIdx[aba][sel] + (ev.deltaY > 0 ? 1 : -1);
            opcaoIdx[aba][sel] = (n + total) % total;
            pintar();
        }
    }, { passive: true });

    function trocarAba(nova) {
        aba = nova || (aba === 'armas' ? 'itens' : 'armas');
        pintar();
    }

    document.addEventListener('contextmenu', (ev) => { ev.preventDefault(); if (dados) trocarAba(); });
    document.querySelectorAll('#abas span').forEach((s) => s.addEventListener('mousedown', (ev) => {
        ev.stopPropagation(); trocarAba(s.dataset.aba);
    }));
    document.addEventListener('mousedown', (ev) => { if (dados && ev.button === 0) confirmar(); });

    document.addEventListener('keyup', (ev) => {
        if (!dados) return;
        if (ev.key === 'Escape') return cancelar();
        if (ev.key && ev.key.toUpperCase() === tecla) confirmar();
    });

    // ------------------------------------------------------------------
    // Confirmar / cancelar
    // ------------------------------------------------------------------
    function post(rota, corpo) {
        return fetch(`https://${recurso}/${rota}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(corpo || {}),
        }).catch(() => {});
    }

    function esconder() {
        dados = null;
        $('roda').classList.add('oculto');
    }

    function confirmar() {
        if (!dados || escolhido) return;
        escolhido = true;
        const { e } = atual(sel);
        esconder();
        if (!e) return post('cancelar');
        if (e.desarmado) return post('escolher', { desarmado: true });
        post('escolher', { slot: e.slot, nome: e.nome });
    }

    function cancelar() {
        if (!dados) return;
        escolhido = true;
        esconder();
        post('cancelar');
    }

    // ------------------------------------------------------------------
    // Mensagens do jogo
    // ------------------------------------------------------------------
    window.addEventListener('message', ({ data }) => {
        if (!data || !data.acao) return;
        if (data.acao === 'abrir') {
            dados = data.dados || { armas: [], itens: [] };
            tecla = String(data.tecla || 'Z').toUpperCase();
            escolhido = false;
            aba = 'armas';
            opcaoIdx.armas.fill(0); opcaoIdx.itens.fill(0);
            sel = 4;
            lista(dados.armas).forEach((p, i) => {
                lista(p.opcoes).filter(Boolean).forEach((o, k) => { if (o && o.naMao) { sel = i; opcaoIdx.armas[i] = k; } });
            });
            $('ponteiro').style.transform = `rotate(${sel * 45}deg)`;
            aplicarEscala();
            pintar();
            $('roda').classList.remove('oculto');
        } else if (data.acao === 'soltar') {
            confirmar();
        } else if (data.acao === 'fechar') {
            esconder();
        }
    });

    aplicarEscala();
})();
