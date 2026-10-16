(() => {
    const $ = (id) => document.getElementById(id);
    const recurso = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pa_hud';

    const R = 72;
    const CIRC = 2 * Math.PI * R;
    const ARCO = CIRC * 0.75; // 270 graus

    let opcoes = { unidade: 'kmh', escala: 100, bussola: true, esconderCheio: true, oculto: false };
    let cfg = {
        rpmVermelho: 0.85, limiteCheio: 95, alertaStatus: 25,
        temperatura: { atencao: 100, perigo: 110 }, motorAlerta: 30,
    };
    let ancora = null;
    let radarVisivel = false;
    let ultimo = {};

    // ------------------------------------------------------------------
    // Conta-giros
    // ------------------------------------------------------------------
    function montarGiro() {
        for (const id of ['giro-valor', 'giro-vermelho']) {
            $(id).setAttribute('transform', 'rotate(135 90 90)');
        }
        document.querySelector('#giro .trilha').setAttribute('stroke-dasharray', `${ARCO} ${CIRC}`);
        document.querySelector('#giro .trilha').setAttribute('transform', 'rotate(135 90 90)');

        const verm = $('giro-vermelho');
        verm.setAttribute('stroke-dasharray', `${ARCO * (1 - cfg.rpmVermelho)} ${CIRC}`);
        verm.setAttribute('stroke-dashoffset', `${-ARCO * cfg.rpmVermelho}`);

        const g = $('giro-marcas');
        g.innerHTML = '';
        const ns = 'http://www.w3.org/2000/svg';
        for (let i = 0; i <= 8; i++) {
            const ang = (135 + (i / 8) * 270) * Math.PI / 180;
            const cos = Math.cos(ang), sin = Math.sin(ang);
            const l = document.createElementNS(ns, 'line');
            l.setAttribute('x1', 90 + cos * 63); l.setAttribute('y1', 90 + sin * 63);
            l.setAttribute('x2', 90 + cos * 67); l.setAttribute('y2', 90 + sin * 67);
            g.appendChild(l);
            const t = document.createElementNS(ns, 'text');
            t.setAttribute('x', 90 + cos * 56); t.setAttribute('y', 90 + sin * 56);
            t.textContent = i;
            g.appendChild(t);
        }
        setRpm(0);
    }

    function setRpm(rpm) {
        const v = Math.max(0, Math.min(1, rpm));
        const el = $('giro-valor');
        el.setAttribute('stroke-dasharray', `${(ARCO * v).toFixed(1)} ${CIRC}`);
        el.classList.toggle('limite', v >= cfg.rpmVermelho);
    }

    function setVelocidade(ms) {
        const v = Math.round(opcoes.unidade === 'mph' ? ms * 2.236936 : ms * 3.6);
        const txt = String(Math.min(v, 999));
        const zeros = '0'.repeat(3 - txt.length);
        $('vel').innerHTML = (zeros ? `<tspan class="zero">${zeros}</tspan>` : '') + `<tspan>${txt}</tspan>`;
    }

    // ------------------------------------------------------------------
    // Escala e posições
    // ------------------------------------------------------------------
    function escala() {
        return (opcoes.escala / 100) * (window.innerHeight / 1080);
    }

    function aplicarEscala() {
        document.documentElement.style.setProperty('--s', escala().toFixed(3));
        posicionarStatus();
    }

    function posicionarStatus() {
        const st = $('status');
        if (!ancora) return;
        const W = window.innerWidth, H = window.innerHeight;
        st.style.left = `${ancora.esquerda * W}px`;
        st.style.width = `${Math.max(200, (ancora.largura * W) / escala())}px`;
        const base = radarVisivel ? (1 - ancora.topo) * H + 6 : (1 - ancora.base) * H;
        st.style.bottom = `${base}px`;
    }

    window.addEventListener('resize', aplicarEscala);

    // ------------------------------------------------------------------
    // Bússola
    // ------------------------------------------------------------------
    const DIRS = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];

    function setBussola(b) {
        const el = $('bussola');
        if (!b) { el.classList.add('oculto'); return; }
        el.classList.remove('oculto');
        if (ultimo.dir !== b.indice) {
            ultimo.dir = b.indice;
            const partes = [];
            for (let d = -2; d <= 2; d++) {
                const nome = DIRS[(b.indice + d + 8) % 8];
                if (d !== -2) partes.push('<span class="ponto">·</span>');
                partes.push(`<span class="${d === 0 ? 'atual' : ''}">${nome}</span>`);
            }
            $('direcoes').innerHTML = partes.join('');
        }
        if (ultimo.rua !== b.rua) { ultimo.rua = b.rua; $('rua-nome').textContent = b.rua || ''; }
        if (ultimo.zona !== b.zona) { ultimo.zona = b.zona; $('rua-zona').textContent = b.zona || ''; }
    }

    // ------------------------------------------------------------------
    // Status e voz
    // ------------------------------------------------------------------
    function setItem(id, valor, mostrar) {
        const el = $(id);
        el.classList.toggle('oculto', !mostrar);
        if (!mostrar) return;
        el.querySelector('i').style.width = `${valor}%`;
        el.classList.toggle('baixo', id !== 'st-estresse' && id !== 'st-colete' && valor <= cfg.alertaStatus);
    }

    function setStatus(s) {
        const cheio = (v) => opcoes.esconderCheio && v >= cfg.limiteCheio;
        setItem('st-vida', s.vida, true);
        setItem('st-colete', s.colete, s.colete > 0 && !cheio(s.colete));
        setItem('st-fome', s.fome, !cheio(s.fome));
        setItem('st-sede', s.sede, !cheio(s.sede));
        setItem('st-estresse', s.estresse, s.estresse > 0);
    }

    function setVoz(v) {
        const el = $('voz');
        el.classList.toggle('falando', !!v.falando);
        const modo = Number(v.modo) || 2;
        el.querySelectorAll('.nivel b').forEach((b, i) => b.classList.toggle('on', i < modo));
    }

    // ------------------------------------------------------------------
    // Veículo
    // ------------------------------------------------------------------
    function setInfo(id, mostrar, texto, pct, classe) {
        const el = $(id);
        el.classList.toggle('oculto', !mostrar);
        if (!mostrar) return;
        el.querySelector('.val').textContent = texto;
        el.querySelector('i').style.width = `${Math.max(0, Math.min(100, pct))}%`;
        el.classList.remove('atencao', 'perigo');
        if (classe) el.classList.add(classe);
    }

    function setVeiculo(v) {
        const vel = $('velocimetro');
        if (!v) { vel.classList.add('oculto'); return; }
        vel.classList.remove('oculto');

        setVelocidade(v.velocidade);
        setRpm(v.rpm);
        $('unidade').textContent = opcoes.unidade === 'mph' ? 'mph' : 'km/h';

        if (v.tipo === 'aereo') {
            $('marcha').textContent = v.marcha;
            $('marcha-rotulo').textContent = 'altitude (m)';
        } else {
            $('marcha').textContent = v.marcha;
            $('marcha-rotulo').textContent = 'RPM x1000';
        }

        const temTurbo = !!v.turbo;
        setInfo('in-turbo', temTurbo,
            temTurbo ? `${v.turbo.bar.toFixed(1)} bar` : '',
            temTurbo ? (v.turbo.bar / v.turbo.max) * 100 : 0);

        const temNitro = v.nitro !== undefined && v.nitro !== null;
        setInfo('in-nitro', temNitro, temNitro ? `${v.nitro}%` : '', v.nitro || 0,
            temNitro && v.nitro === 0 ? 'perigo' : null);

        const temGas = v.gasolina !== undefined && v.gasolina !== null;
        setInfo('in-gas', temGas, temGas ? `${v.gasolina}%` : '', v.gasolina || 0,
            temGas && v.gasolina <= 15 ? 'perigo' : temGas && v.gasolina <= 30 ? 'atencao' : null);

        const temMotor = v.temperatura !== undefined && v.temperatura !== null;
        let classeMotor = null;
        if (temMotor) {
            if (v.temperatura >= cfg.temperatura.perigo || v.motor <= cfg.motorAlerta) classeMotor = 'perigo';
            else if (v.temperatura >= cfg.temperatura.atencao) classeMotor = 'atencao';
        }
        setInfo('in-motor', temMotor, temMotor ? `${v.temperatura}°` : '', v.motor || 0, classeMotor);

        $('infos').classList.toggle('oculto', !(temTurbo || temNitro || temGas || temMotor));

        const alerta = $('alerta-motor');
        if (v.semMotor) {
            $('alerta-texto').textContent = 'Motor fora ou quebrado';
            alerta.classList.remove('oculto');
        } else if (temMotor && v.motor <= cfg.motorAlerta) {
            $('alerta-texto').textContent = `Motor danificado ${v.motor}%`;
            alerta.classList.remove('oculto');
        } else if (temMotor && v.temperatura >= cfg.temperatura.perigo) {
            $('alerta-texto').textContent = 'Motor superaquecendo';
            alerta.classList.remove('oculto');
        } else {
            alerta.classList.add('oculto');
        }
    }

    // ------------------------------------------------------------------
    // Avisos de XP
    // ------------------------------------------------------------------
    const ICONE_XP = '<svg viewBox="0 0 24 24"><path d="M4 17l6-6 4 4 6-7M14 8h6v6"/></svg>';
    const ICONE_NIVEL = '<svg viewBox="0 0 24 24"><path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/></svg>';

    function aviso(d) {
        const box = $('avisos');
        const el = document.createElement('div');
        el.className = `aviso ${d.tipo === 'nivel' ? 'nivel' : ''}`;
        el.innerHTML = (d.tipo === 'nivel' ? ICONE_NIVEL : ICONE_XP) + `<span></span>`;
        el.querySelector('span').textContent = d.texto;
        if (d.detalhe) {
            const sm = document.createElement('small');
            sm.textContent = d.detalhe;
            el.appendChild(sm);
        }
        box.appendChild(el);
        while (box.children.length > 4) box.firstChild.remove();
        setTimeout(() => el.remove(), 4100);
    }

    // ------------------------------------------------------------------
    // Opções (/hud)
    // ------------------------------------------------------------------
    let rascunho = null;

    function pintarOpcoes() {
        document.querySelectorAll('[data-unidade]').forEach((b) =>
            b.classList.toggle('ativo', b.dataset.unidade === rascunho.unidade));
        $('op-escala').value = rascunho.escala;
        $('escala-val').textContent = `${rascunho.escala}%`;
        $('op-bussola').checked = rascunho.bussola;
        $('op-cheio').checked = rascunho.esconderCheio;
        $('op-oculto').checked = rascunho.oculto;
    }

    function abrirOpcoes(o) {
        rascunho = { ...opcoes, ...(o || {}) };
        pintarOpcoes();
        $('opcoes').classList.remove('oculto');
    }

    function fecharOpcoes(salvar) {
        $('opcoes').classList.add('oculto');
        const rota = salvar ? 'salvarOpcoes' : 'fechar';
        fetch(`https://${recurso}/${rota}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(salvar ? rascunho : {}),
        }).catch(() => {});
        if (salvar) { opcoes = { ...rascunho }; aplicarEscala(); }
    }

    document.querySelectorAll('[data-unidade]').forEach((b) =>
        b.addEventListener('click', () => { rascunho.unidade = b.dataset.unidade; pintarOpcoes(); }));
    $('op-escala').addEventListener('input', (e) => { rascunho.escala = Number(e.target.value); pintarOpcoes(); });
    $('op-bussola').addEventListener('change', (e) => { rascunho.bussola = e.target.checked; });
    $('op-cheio').addEventListener('change', (e) => { rascunho.esconderCheio = e.target.checked; });
    $('op-oculto').addEventListener('change', (e) => { rascunho.oculto = e.target.checked; });
    $('op-salvar').addEventListener('click', () => fecharOpcoes(true));
    $('op-fechar').addEventListener('click', () => fecharOpcoes(false));
    document.addEventListener('keyup', (e) => {
        if (e.key === 'Escape' && !$('opcoes').classList.contains('oculto')) fecharOpcoes(false);
    });

    // ------------------------------------------------------------------
    // Mensagens do cliente
    // ------------------------------------------------------------------
    window.addEventListener('message', ({ data }) => {
        if (!data || !data.acao) return;
        switch (data.acao) {
            case 'config':
                if (data.opcoes) opcoes = { ...opcoes, ...data.opcoes };
                if (data.cfg) cfg = { ...cfg, ...data.cfg };
                montarGiro();
                aplicarEscala();
                break;
            case 'ancora':
                ancora = data.ancora;
                posicionarStatus();
                break;
            case 'atualizar':
                $('hud').classList.remove('oculto');
                if (radarVisivel !== !!data.radar) { radarVisivel = !!data.radar; posicionarStatus(); }
                setBussola(data.bussola);
                setStatus(data.status);
                setVoz(data.voz || {});
                setVeiculo(data.veiculo);
                break;
            case 'esconder':
                $('hud').classList.add('oculto');
                break;
            case 'aviso':
                aviso(data);
                break;
            case 'abrirOpcoes':
                abrirOpcoes(data.opcoes);
                break;
        }
    });

    montarGiro();
    aplicarEscala();
})();
