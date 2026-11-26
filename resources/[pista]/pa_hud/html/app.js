(() => {
    const $ = (id) => document.getElementById(id);
    const recurso = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pa_hud';

    const R = 72;
    const CIRC = 2 * Math.PI * R;
    const ARCO = CIRC * 0.75; // 270 graus

    let opcoes = { unidade: 'kmh', escala: 100, bussola: true, esconderCheio: true, oculto: false, tema: 'vice', dinheiro: true };
    let cfg = {
        rpmVermelho: 0.85, limiteCheio: 95, alertaStatus: 25,
        temperatura: { atencao: 100, perigo: 110 }, motorAlerta: 30, statusAoMudar: 5000,
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
        if (!ancora || st.classList.contains('movido')) return;
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
        const modo = Number(v.modo) || 2;
        document.querySelectorAll('.voz').forEach((el) => {
            el.classList.toggle('falando', !!v.falando);
            el.querySelectorAll('.nivel b').forEach((b, i) => b.classList.toggle('on', i < modo));
        });
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

    // ------------------------------------------------------------------
    // PA Dash (painel digital)
    // ------------------------------------------------------------------
    const NLEDS = 15;
    const leds = [];
    (function montarLeds() {
        const box = $('dash-leds');
        for (let i = 0; i < NLEDS; i++) {
            const l = document.createElement('i');
            l.className = i < 7 ? 'g' : i < 12 ? 'a' : 'r';
            box.appendChild(l); leds.push(l);
        }
    })();

    function setDash(v) {
        const el = $('dash');
        const d = v && v.dash;
        if (!d) { el.classList.add('oculto'); return; }
        el.classList.remove('oculto');
        el.classList.toggle('basico', !d.completo);

        const ini = d.troca - d.faixa;
        const f = Math.max(0, Math.min(1, (d.rpm - ini) / (d.troca - ini)));
        const pisca = d.rpm >= d.troca;
        const fase = Math.floor(Date.now() / 110) % 2 === 0;
        const acesos = Math.round(f * NLEDS);
        leds.forEach((l, i) => {
            l.classList.toggle('on', pisca ? fase : i < acesos);
            l.classList.toggle('s', pisca);
        });

        $('dash-rpm').textContent = Math.round(d.rpm / 10) * 10;
        if (d.completo) {
            const bar = v.turbo ? v.turbo.bar : 0;
            $('dash-turbo').innerHTML = `${bar.toFixed(1)}<small>bar</small>`;
            $('dash-afr').innerHTML = `${Number(d.afr).toFixed(1)}<small>λ</small>`;
        }

        // Aviso só aparece quando precisa
        const a = $('dash-alerta');
        let texto = '', classe = '';
        if (d.corte) { texto = 'CORTE'; classe = 'perigo'; }
        else if (pisca) { texto = 'TROQUE'; classe = 'atencao'; }
        a.className = texto ? classe : 'oculto';
        a.textContent = texto;
    }

    function setVeiculo(v) {
        setDash(v);
        const vel = $('velocimetro');
        if (!v) { vel.classList.add('oculto'); return; }
        vel.classList.remove('oculto');

        const cinto = $('cinto');
        const temCinto = v.tipo === 'carro' && v.cinto !== undefined;
        cinto.classList.toggle('oculto', !temCinto);
        if (temCinto) cinto.classList.toggle('preso', !!v.cinto);

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

    // ==================================================================
    // Tema Vice (estilo GTA 6)
    // ==================================================================
    const vice = () => opcoes.tema !== 'classico';

    function aplicarTema() {
        document.body.classList.toggle('tema-vice', vice());
        document.body.classList.toggle('tema-classico', !vice());
        const dash = $('dash');
        if (vice()) $('v-dash-lugar').appendChild(dash);
        else $('velocimetro').insertBefore(dash, $('velocimetro').firstChild);
        posicionarMapa();
    }

    // Moldura arredondada em volta do minimapa
    function posicionarMapa() {
        const m = $('v-mapa');
        if (!ancora || !radarVisivel || !vice()) { m.classList.add('oculto'); return; }
        const W = window.innerWidth, H = window.innerHeight;
        m.classList.remove('oculto');
        m.style.left = `${ancora.esquerda * W - 3}px`;
        m.style.top = `${ancora.topo * H - 3}px`;
        m.style.width = `${ancora.largura * W + 6}px`;
        m.style.height = `${(ancora.base - ancora.topo) * H + 6}px`;
    }

    // ---- Status: barras que aparecem quando o valor muda ou fica baixo
    const vUltimo = {};
    const vAte = {};
    function vBarra(id, valor, precisa) {
        const el = $(id);
        const agora = Date.now();
        if (vUltimo[id] !== undefined && vUltimo[id] !== valor) vAte[id] = agora + cfg.statusAoMudar;
        vUltimo[id] = valor;
        const mostrar = precisa || (vAte[id] || 0) > agora;
        el.classList.toggle('some', !mostrar);
        el.querySelector('i').style.width = `${valor}%`;
        el.classList.toggle('baixo', id !== 'vb-estresse' && id !== 'vb-colete' && valor <= cfg.alertaStatus);
    }

    function setViceStatus(s) {
        const naoCheio = (v) => !opcoes.esconderCheio || v < cfg.limiteCheio;
        vBarra('vb-vida', s.vida, naoCheio(s.vida));
        vBarra('vb-colete', s.colete, s.colete > 0 && naoCheio(s.colete));
        vBarra('vb-fome', s.fome, naoCheio(s.fome));
        vBarra('vb-sede', s.sede, naoCheio(s.sede));
        vBarra('vb-estresse', s.estresse, s.estresse > 0);
    }

    // ---- Bússola em faixa
    const CARDEAIS = [['N', 0], ['NE', 45], ['L', 90], ['SE', 135], ['S', 180], ['SO', 225], ['O', 270], ['NO', 315]];
    const CAMPO = 100; // graus visíveis para cada lado
    const relativo = (ang, graus) => ((ang - graus + 540) % 360) - 180;
    const posX = (rel) => `${50 + (rel / CAMPO) * 50}%`;
    const FORMAS = {
        chave: '<path d="M14.5 5.5a4 4 0 0 0-5 5L4 16l4 4 5.5-5.5a4 4 0 0 0 5-5l-2.5 2.5-2.5-.5-.5-2.5z"/>',
        bandeira: '<path d="M6 21V4M6 4h11l-2 4 2 4H6"/>',
        cruz: '<path d="M12 5v14M5 12h14"/>',
        estrela: '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
        ponto: '<circle cx="12" cy="12" r="5"/>',
    };

    function setViceBussola(b, pontos, perseguicao) {
        const el = $('v-bussola');
        if (!b) { el.style.display = 'none'; return; }
        el.style.display = '';
        el.classList.toggle('perseguicao', !!perseguicao);

        const partes = [];
        for (let a = 0; a < 360; a += 15) {
            const rel = relativo(a, b.graus);
            if (Math.abs(rel) > CAMPO) continue;
            const card = CARDEAIS.find((c) => c[1] === a);
            if (card) partes.push(`<span class="vm${a % 90 === 0 ? ' card' : ''}" style="left:${posX(rel)}">${card[0]}</span>`);
            else partes.push(`<span class="vm tick" style="left:${posX(rel)}"></span>`);
        }
        $('v-marcas').innerHTML = partes.join('');

        const ps = [];
        for (const p of pontos || []) {
            const rel = relativo(p.r, b.graus);
            if (Math.abs(rel) > CAMPO) continue;
            const forma = FORMAS[p.forma] ? p.forma : 'ponto';
            const cor = /^#[0-9a-fA-F]{3,8}$/.test(p.cor || '') ? p.cor : '#ffffff';
            ps.push(`<span class="vp ${forma}" style="left:${posX(rel)};color:${cor}"><svg viewBox="0 0 24 24">${FORMAS[forma]}</svg></span>`);
        }
        $('v-pontos').innerHTML = ps.join('');

        if (ultimo.vRua !== b.rua) { ultimo.vRua = b.rua; $('v-rua-nome').textContent = b.rua || ''; }
        if (ultimo.vZona !== b.zona) { ultimo.vZona = b.zona; $('v-rua-zona').textContent = b.zona || ''; }
    }

    // ---- Dinheiro
    const moeda = (v) => `$ ${Math.floor(v).toLocaleString('pt-BR')}`;
    let dinAnt = null;
    let dinAte = 0;
    function delta(el, valor, mudou) {
        el.textContent = moeda(valor);
        if (!mudou) return;
        const d = document.createElement('span');
        d.className = `delta ${mudou > 0 ? 'mais' : 'menos'}`;
        d.textContent = `${mudou > 0 ? '+' : '-'}${moeda(Math.abs(mudou)).replace('$ ', '$')}`;
        el.prepend(d);
        setTimeout(() => d.remove(), 3500);
    }
    function setDinheiro(d) {
        if (!d) return;
        const box = $('v-dinheiro');
        const agora = Date.now();
        if (!dinAnt) {
            $('v-mao').textContent = moeda(d.mao);
            $('v-banco').textContent = moeda(d.banco);
        } else {
            if (dinAnt.mao !== d.mao) { delta($('v-mao'), d.mao, d.mao - dinAnt.mao); dinAte = agora + 6000; }
            if (dinAnt.banco !== d.banco) { delta($('v-banco'), d.banco, d.banco - dinAnt.banco); dinAte = agora + 6000; }
        }
        dinAnt = d;
        box.classList.toggle('some', !opcoes.dinheiro && dinAte < agora);
    }

    // ---- GPS
    function setGps(g) {
        const el = $('v-gps');
        if (!g) { el.classList.add('oculto'); return; }
        el.classList.remove('oculto');
        el.textContent = g.dist >= 1000 ? `${(g.dist / 1000).toFixed(1).replace('.', ',')} km` : `${g.dist} m`;
    }

    // ---- Velocímetro
    const NSEG = 12;
    const segs = [];
    (function montarSegs() {
        const box = $('v-giro');
        for (let i = 0; i < NSEG; i++) { const s = document.createElement('i'); box.appendChild(s); segs.push(s); }
    })();
    function pintarSegs() {
        segs.forEach((s, i) => {
            s.classList.toggle('ver', (i + 1) / NSEG > cfg.rpmVermelho);
            s.classList.toggle('alto', (i + 1) / NSEG > cfg.rpmVermelho - 0.15);
        });
    }

    function vInfo(id, mostrar, texto, pct, classe) {
        const el = $(id);
        el.classList.toggle('oculto', !mostrar);
        if (!mostrar) return;
        el.querySelector('b').textContent = texto;
        el.querySelector('i').style.width = `${Math.max(0, Math.min(100, pct))}%`;
        el.classList.remove('atencao', 'perigo');
        if (classe) el.classList.add(classe);
    }

    function setViceVeiculo(v) {
        const el = $('v-velo');
        if (!v) { el.classList.add('oculto'); return; }
        el.classList.remove('oculto');

        const vel = Math.round(opcoes.unidade === 'mph' ? v.velocidade * 2.236936 : v.velocidade * 3.6);
        $('v-vel').textContent = Math.min(vel, 999);
        $('v-unidade').textContent = v.tipo === 'aereo' ? 'alt (m)' : (opcoes.unidade === 'mph' ? 'mph' : 'km/h');

        const m = $('v-marcha');
        m.textContent = v.marcha;
        m.classList.toggle('neutro', v.marcha === 'N' || v.marcha === '-');
        m.classList.toggle('re', v.marcha === 'R');

        const rpm = Math.max(0, Math.min(1, v.rpm || 0));
        const acesos = Math.round(rpm * NSEG);
        segs.forEach((s, i) => s.classList.toggle('on', i < acesos));
        $('v-giro').classList.toggle('corte', rpm >= 0.98);

        const temTurbo = !!v.turbo;
        vInfo('vi-turbo', temTurbo, temTurbo ? `${v.turbo.bar.toFixed(1)} bar` : '', temTurbo ? (v.turbo.bar / v.turbo.max) * 100 : 0);
        const temNitro = v.nitro !== undefined && v.nitro !== null;
        vInfo('vi-nitro', temNitro, temNitro ? `${v.nitro}%` : '', v.nitro || 0, temNitro && v.nitro === 0 ? 'perigo' : null);
        const temGas = v.gasolina !== undefined && v.gasolina !== null;
        vInfo('vi-gas', temGas, temGas ? `${v.gasolina}%` : '', v.gasolina || 0,
            temGas && v.gasolina <= 15 ? 'perigo' : temGas && v.gasolina <= 30 ? 'atencao' : null);

        const temMotor = v.temperatura !== undefined && v.temperatura !== null;
        const quente = temMotor && v.temperatura >= cfg.temperatura.atencao;
        $('vc-temp').classList.toggle('oculto', !quente);
        $('vc-temp').classList.toggle('perigo', temMotor && v.temperatura >= cfg.temperatura.perigo);
        $('vc-motor').classList.toggle('oculto', !(v.semMotor || (temMotor && v.motor <= cfg.motorAlerta)));
        const temCinto = v.tipo === 'carro' && v.cinto !== undefined;
        $('vc-cinto').classList.toggle('oculto', !temCinto);
        $('vc-cinto').classList.toggle('preso', !!v.cinto);

        const a = $('v-alerta');
        let txt = '';
        if (v.semMotor) txt = 'Motor fora ou quebrado';
        else if (temMotor && v.motor <= cfg.motorAlerta) txt = `Motor danificado ${v.motor}%`;
        else if (temMotor && v.temperatura >= cfg.temperatura.perigo) txt = 'Motor superaquecendo';
        a.textContent = txt;
        a.classList.toggle('oculto', !txt);
    }

    function setVice(data) {
        setViceStatus(data.status);
        setViceBussola(data.bussola, data.vice && data.vice.pontos, data.vice && data.vice.perseguicao);
        setDinheiro(data.vice && data.vice.dinheiro);
        setGps(data.vice && data.vice.gps);
        setViceVeiculo(data.veiculo);
        setDash(data.veiculo);
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
        document.querySelectorAll('[data-tema]').forEach((b) =>
            b.classList.toggle('ativo', b.dataset.tema === rascunho.tema));
        $('op-dinheiro').checked = rascunho.dinheiro;
        $('op-dinheiro-linha').classList.toggle('oculto', rascunho.tema === 'classico');
        document.querySelectorAll('[data-unidade]').forEach((b) =>
            b.classList.toggle('ativo', b.dataset.unidade === rascunho.unidade));
        $('op-escala').value = rascunho.escala;
        $('escala-val').textContent = `${rascunho.escala}%`;
        $('op-bussola').checked = rascunho.bussola;
        $('op-cheio').checked = rascunho.esconderCheio;
        $('op-oculto').checked = rascunho.oculto;
    }

    // ------------------------------------------------------------------
    // Mover HUD: cada parte pode ser arrastada e fica salva no PC do jogador
    // ------------------------------------------------------------------
    const MOVEIS = {
        vice: [['v-status', 'Status e voz'], ['v-bussola', 'Bússola'], ['v-dinheiro', 'Dinheiro'], ['v-velo', 'Velocímetro'], ['avisos', 'Avisos de XP']],
        classico: [['status', 'Status e voz'], ['bussola', 'Bússola'], ['velocimetro', 'Velocímetro'], ['avisos', 'Avisos de XP']],
    };
    let posicoes = { vice: {}, classico: {} };
    let editando = false;
    let arrasto = null;
    const temaAtual = () => (opcoes.tema === 'classico' ? 'classico' : 'vice');

    function limparPosicao(el) {
        el.classList.remove('movido');
        el.style.left = ''; el.style.top = ''; el.style.right = ''; el.style.bottom = '';
    }

    function aplicarPosicoes() {
        const W = window.innerWidth, H = window.innerHeight;
        for (const tema of Object.keys(MOVEIS)) {
            for (const [id] of MOVEIS[tema]) {
                const el = $(id);
                if (!el) continue;
                limparPosicao(el);
                const p = tema === temaAtual() && posicoes[tema] && posicoes[tema][id];
                if (p) {
                    el.classList.add('movido');
                    el.style.left = `${(p.x / 100) * W}px`;
                    el.style.top = `${(p.y / 100) * H}px`;
                }
            }
        }
        posicionarStatus();
    }

    function entrarEdicao() {
        editando = true;
        $('opcoes').classList.add('oculto');
        document.body.classList.add('editando');
        $('editor').classList.remove('oculto');
        for (const [id, nome] of MOVEIS[temaAtual()]) {
            const el = $(id);
            if (!el) continue;
            el.classList.add('movel');
            el.dataset.nome = nome;
            el.classList.toggle('no-topo', el.getBoundingClientRect().top < 40);
        }
    }

    function sairEdicao(salvar) {
        editando = false;
        arrasto = null;
        document.body.classList.remove('editando');
        $('editor').classList.add('oculto');
        document.querySelectorAll('.movel').forEach((el) => el.classList.remove('movel', 'arrastando', 'no-topo'));
        fetch(`https://${recurso}/salvarPosicoes`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(salvar ? { posicoes } : { cancelar: true }),
        }).catch(() => {});
    }

    document.addEventListener('mousedown', (ev) => {
        if (!editando || ev.button !== 0) return;
        const el = ev.target.closest('.movel');
        if (!el) return;
        ev.preventDefault();
        const r = el.getBoundingClientRect();
        el.classList.add('movido', 'arrastando');
        el.style.left = `${r.left}px`;
        el.style.top = `${r.top}px`;
        arrasto = { el, dx: ev.clientX - r.left, dy: ev.clientY - r.top, w: r.width, h: r.height };
    });
    document.addEventListener('mousemove', (ev) => {
        if (!arrasto) return;
        const W = window.innerWidth, H = window.innerHeight;
        const x = Math.max(0, Math.min(W - arrasto.w, ev.clientX - arrasto.dx));
        const y = Math.max(0, Math.min(H - arrasto.h, ev.clientY - arrasto.dy));
        arrasto.el.style.left = `${x}px`;
        arrasto.el.style.top = `${y}px`;
    });
    document.addEventListener('mouseup', () => {
        if (!arrasto) return;
        const { el } = arrasto;
        el.classList.remove('arrastando');
        el.classList.toggle('no-topo', el.getBoundingClientRect().top < 40);
        const W = window.innerWidth, H = window.innerHeight;
        const tema = temaAtual();
        posicoes[tema] = posicoes[tema] || {};
        posicoes[tema][el.id] = {
            x: Math.round((parseFloat(el.style.left) / W) * 10000) / 100,
            y: Math.round((parseFloat(el.style.top) / H) * 10000) / 100,
        };
        arrasto = null;
    });
    $('ed-concluir').addEventListener('click', () => sairEdicao(true));
    $('ed-restaurar').addEventListener('click', () => { posicoes[temaAtual()] = {}; aplicarPosicoes(); });
    $('op-mover').addEventListener('click', () => entrarEdicao());
    window.addEventListener('resize', aplicarPosicoes);

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
        if (salvar) { opcoes = { ...rascunho }; aplicarEscala(); aplicarTema(); aplicarPosicoes(); }
    }

    document.querySelectorAll('[data-unidade]').forEach((b) =>
        b.addEventListener('click', () => { rascunho.unidade = b.dataset.unidade; pintarOpcoes(); }));
    $('op-escala').addEventListener('input', (e) => { rascunho.escala = Number(e.target.value); pintarOpcoes(); });
    $('op-bussola').addEventListener('change', (e) => { rascunho.bussola = e.target.checked; });
    $('op-cheio').addEventListener('change', (e) => { rascunho.esconderCheio = e.target.checked; });
    document.querySelectorAll('[data-tema]').forEach((b) =>
        b.addEventListener('click', () => { rascunho.tema = b.dataset.tema; pintarOpcoes(); }));
    $('op-dinheiro').addEventListener('change', (e) => { rascunho.dinheiro = e.target.checked; });
    $('op-oculto').addEventListener('change', (e) => { rascunho.oculto = e.target.checked; });
    $('op-salvar').addEventListener('click', () => fecharOpcoes(true));
    $('op-fechar').addEventListener('click', () => fecharOpcoes(false));
    document.addEventListener('keyup', (e) => {
        if (e.key !== 'Escape') return;
        if (editando) return sairEdicao(true);
        if (!$('opcoes').classList.contains('oculto')) fecharOpcoes(false);
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
                if (data.posicoes && typeof data.posicoes === 'object') {
                    posicoes = { vice: data.posicoes.vice || {}, classico: data.posicoes.classico || {} };
                    if (Array.isArray(posicoes.vice)) posicoes.vice = {};
                    if (Array.isArray(posicoes.classico)) posicoes.classico = {};
                }
                montarGiro();
                pintarSegs();
                aplicarEscala();
                aplicarTema();
                aplicarPosicoes();
                break;
            case 'ancora':
                ancora = data.ancora;
                posicionarStatus();
                posicionarMapa();
                break;
            case 'atualizar':
                $('hud').classList.remove('oculto');
                if (radarVisivel !== !!data.radar) { radarVisivel = !!data.radar; posicionarStatus(); posicionarMapa(); }
                setVoz(data.voz || {});
                if (vice()) { setVice(data); break; }
                setBussola(data.bussola);
                setStatus(data.status);
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

    window.addEventListener('resize', posicionarMapa);

    montarGiro();
    pintarSegs();
    aplicarEscala();
    aplicarTema();
})();
