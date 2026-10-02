// Painel da suspensão regulável
(() => {
    const RECURSO = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
    const tela = document.getElementById('suspensao');
    const ajustes = [...tela.querySelectorAll('.s-ajuste')];
    const CAMPOS = ajustes.map(el => el.dataset.campo);

    const FORMATO = {
        altura: v => `${v > 0 ? '+' : ''}${v.toFixed(1)} cm`,
        mola: v => `${Math.round(v)}%`,
        compressao: v => `${Math.round(v)}%`,
        retorno: v => `${Math.round(v)}%`,
        barra: v => `${Math.round(v)}%`,
        cambagem: v => `${v > 0 ? '+' : ''}${v.toFixed(1)}°`,
        bitola: v => `${v > 0 ? '+' : ''}${v.toFixed(1)} cm`,
    };

    let info = null;
    let timer = null;

    async function enviar(nome, dados = {}) {
        if (!RECURSO) return dados;
        try {
            const r = await fetch(`https://${RECURSO}/${nome}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(dados),
            });
            return await r.json();
        } catch { return null; }
    }

    const input = campo => tela.querySelector(`.s-ajuste[data-campo="${campo}"] input`);

    function valores() {
        const v = {};
        CAMPOS.forEach(c => { v[c] = parseFloat(input(c).value); });
        return v;
    }

    function pintar(el) {
        const i = el.querySelector('input');
        const v = parseFloat(i.value), min = parseFloat(i.min), max = parseFloat(i.max);
        i.style.setProperty('--p', `${max > min ? ((v - min) / (max - min)) * 100 : 0}%`);
        const out = el.querySelector('output');
        out.textContent = FORMATO[el.dataset.faixa](v);
        out.classList.toggle('mudou', info && Math.abs(v - info.padrao[el.dataset.campo]) > 1e-6);
    }

    function definir(v) {
        ajustes.forEach(el => {
            if (v[el.dataset.campo] !== undefined) el.querySelector('input').value = v[el.dataset.campo];
            pintar(el);
        });
        atualizar();
    }

    function atualizar() {
        const v = valores();
        marcarPreset(v);
        desenhar(v);
        resumo(v);
        clearTimeout(timer);
        timer = setTimeout(() => enviar('suspPrevia', v), 60);
    }

    function marcarPreset(v) {
        tela.querySelectorAll('.preset').forEach(b => {
            const p = info && info.presets[b.dataset.preset];
            b.classList.toggle('ativo', !!p && CAMPOS.every(c => Math.abs((p[c] ?? info.padrao[c]) - v[c]) < 1e-6));
        });
    }

    // ------------------------------------------------------------------
    // Abrir / fechar
    // ------------------------------------------------------------------
    // Espiar: enquanto mexe num ajuste, o painel fica transparente para
    // ver o carro; só o controle que está sendo mexido continua visível.
    // ------------------------------------------------------------------
    let timerEspiar = null;
    let focoAtual = null;

    function espiar(el, duracao) {
        clearTimeout(timerEspiar);
        if (focoAtual && focoAtual !== el) focoAtual.classList.remove('foco');
        focoAtual = el || null;
        if (focoAtual) focoAtual.classList.add('foco');
        tela.classList.add('espiando');
        if (duracao) timerEspiar = setTimeout(pararDeEspiar, duracao);
    }

    function pararDeEspiar() {
        clearTimeout(timerEspiar);
        tela.classList.remove('espiando');
        if (focoAtual) focoAtual.classList.remove('foco');
        focoAtual = null;
    }

    // soltar o mouse em qualquer lugar devolve o painel
    window.addEventListener('pointerup', () => { if (focoAtual) timerEspiar = setTimeout(pararDeEspiar, 250); });

    // ------------------------------------------------------------------
    function abrir(dados) {
        info = dados;
        document.getElementById('s-placa').textContent = dados.placa || '---';
        document.getElementById('s-modelo').textContent = dados.modelo || '';
        ajustes.forEach(el => {
            const f = dados.faixas[el.dataset.faixa];
            const i = el.querySelector('input');
            i.min = f.min; i.max = f.max; i.step = f.passo;
            i.value = dados.atual[el.dataset.campo];
            i.oninput = () => { pintar(el); atualizar(); espiar(el, 900); };
            i.onpointerdown = () => espiar(el);
            pintar(el);
        });
        tela.classList.remove('oculto');
        atualizar();
    }

    function fechar(salvar) {
        if (!info) return;
        const v = valores();
        info = null;
        pararDeEspiar();
        tela.classList.add('oculto');
        enviar(salvar ? 'suspSalvar' : 'suspFechar', v);
    }

    window.addEventListener('message', ({ data }) => {
        if (data.acao === 'abrirSusp') abrir(data);
        if (data.acao === 'fecharSusp') { info = null; tela.classList.add('oculto'); }
    });
    document.addEventListener('keydown', e => { if (e.key === 'Escape' && info) fechar(false); });

    document.getElementById('s-btn-fechar').onclick = () => fechar(false);
    document.getElementById('s-btn-salvar').onclick = () => fechar(true);
    document.getElementById('s-btn-padrao').onclick = () => {
        if (!info) return;
        definir(info.padrao);
        espiar(null, 1800);
    };
    tela.querySelectorAll('.preset').forEach(b => {
        b.onclick = () => {
            if (!info) return;
            definir({ ...info.padrao, ...info.presets[b.dataset.preset] });
            espiar(null, 1800); // some um instante para ver o carro mudar
        };
    });

    // ------------------------------------------------------------------
    // Resumo: equilíbrio, firmeza e conforto (ilustrativo)
    // ------------------------------------------------------------------
    function resumo(v) {
        // + = sai de frente (frente mais dura), - = sai de traseira
        const nota = (v.molaD - v.molaT) * 0.4 + (v.barraD - v.barraT) * 0.6 + (v.cambagemD - v.cambagemT) * 4;
        const n = Math.max(-1, Math.min(1, nota / 80));
        document.getElementById('s-eq-marca').style.left = `${50 - n * 48}%`;
        document.getElementById('s-eq-texto').textContent =
            n > 0.35 ? 'Sai bem de frente' : n > 0.1 ? 'Leve saída de frente'
                : n < -0.35 ? 'Sai bem de traseira' : n < -0.1 ? 'Leve saída de traseira' : 'Neutro';

        const media = (v.molaD + v.molaT + v.compressao + v.retorno + (v.barraD + v.barraT) / 2) / 5;
        const firmeza = Math.max(0, Math.min(100, ((media - 50) / 150) * 100));
        const conforto = Math.max(0, Math.min(100, 100 - firmeza - Math.max(0, -v.altura) * 3.5));
        const barra = (id, p) => {
            const el = document.getElementById(id);
            el.querySelector('i').style.width = `${p}%`;
            el.querySelector('b').textContent = `${Math.round(p)}%`;
        };
        barra('s-b-firmeza', firmeza);
        barra('s-b-conforto', conforto);
    }

    // ------------------------------------------------------------------
    // Silhueta: vista de frente (cambagem, bitola, altura) e de lado
    // ------------------------------------------------------------------
    function prepararCanvas(id) {
        const c = document.getElementById(id);
        const dpr = window.devicePixelRatio || 1;
        const w = c.clientWidth, h = c.clientHeight;
        c.width = w * dpr; c.height = h * dpr;
        const ctx = c.getContext('2d');
        ctx.scale(dpr, dpr);
        ctx.clearRect(0, 0, w, h);
        return { ctx, w, h };
    }

    function retArredondado(ctx, x, y, w, h, r) {
        ctx.moveTo(x + r, y);
        ctx.arcTo(x + w, y, x + w, y + h, r);
        ctx.arcTo(x + w, y + h, x, y + h, r);
        ctx.arcTo(x, y + h, x, y, r);
        ctx.arcTo(x, y, x + w, y, r);
        ctx.closePath();
    }

    function roda(ctx, x, yChao, camberGraus, lado, cor, cheia) {
        const larg = 22, alt = 54;
        ctx.save();
        ctx.translate(x, yChao - alt / 2);
        // camber negativo = topo da roda para dentro (lado: -1 esquerda, +1 direita)
        ctx.rotate((lado * camberGraus * Math.PI) / 180);
        ctx.beginPath();
        retArredondado(ctx, -larg / 2, -alt / 2, larg, alt, 5);
        if (cheia) { ctx.fillStyle = '#0b0e13'; ctx.fill(); }
        ctx.strokeStyle = cor; ctx.lineWidth = cheia ? 2.5 : 1.5; ctx.stroke();
        if (cheia) {
            ctx.beginPath(); ctx.moveTo(-larg / 2 + 4, 0); ctx.lineTo(larg / 2 - 4, 0);
            ctx.strokeStyle = 'rgba(255,255,255,.25)'; ctx.lineWidth = 1; ctx.stroke();
        }
        ctx.restore();
    }

    function vistaFrente(v, cor, cheia, g) {
        const { ctx, w, h } = g;
        const meio = w / 2, chao = h - 18;
        const meiaBitola = 112 + v.bitolaD * 3;     // exagerado para dar para ver
        const subir = v.altura * 2.6;
        const baseCarro = chao - 34 - subir;
        // carroceria
        ctx.beginPath();
        ctx.moveTo(meio - 128, baseCarro);
        ctx.lineTo(meio - 132, baseCarro - 40);
        ctx.lineTo(meio - 92, baseCarro - 52);
        ctx.lineTo(meio - 70, baseCarro - 96);
        ctx.lineTo(meio + 70, baseCarro - 96);
        ctx.lineTo(meio + 92, baseCarro - 52);
        ctx.lineTo(meio + 132, baseCarro - 40);
        ctx.lineTo(meio + 128, baseCarro);
        ctx.closePath();
        if (cheia) { ctx.fillStyle = 'rgba(241,194,50,.10)'; ctx.fill(); }
        ctx.strokeStyle = cor; ctx.lineWidth = cheia ? 2 : 1.2;
        ctx.setLineDash(cheia ? [] : [4, 4]); ctx.stroke(); ctx.setLineDash([]);
        if (cheia) { // eixo traseiro, atrás
            const tras = 112 + v.bitolaT * 3, azul = 'rgba(88,166,255,.75)';
            roda(ctx, meio - tras, chao, v.cambagemT, -1, azul, false);
            roda(ctx, meio + tras, chao, v.cambagemT, 1, azul, false);
        }
        roda(ctx, meio - meiaBitola, chao, v.cambagemD, -1, cor, cheia);
        roda(ctx, meio + meiaBitola, chao, v.cambagemD, 1, cor, cheia);
    }

    function vistaLado(v, cor, cheia, g) {
        const { ctx, w, h } = g;
        const chao = h - 10, r = 19;
        const subir = v.altura * 2.2;
        const base = chao - 22 - subir;
        const x0 = 40, x1 = w - 40;
        const rf = x1 - 62, rt = x0 + 62;  // rodas: frente à direita
        ctx.beginPath();
        ctx.moveTo(x0, base);
        ctx.lineTo(x0 + 2, base - 26);
        ctx.lineTo(x0 + 70, base - 32);
        ctx.lineTo(x0 + 120, base - 62);
        ctx.lineTo(x1 - 120, base - 62);
        ctx.lineTo(x1 - 70, base - 34);
        ctx.lineTo(x1 - 2, base - 26);
        ctx.lineTo(x1, base);
        ctx.closePath();
        if (cheia) { ctx.fillStyle = 'rgba(241,194,50,.10)'; ctx.fill(); }
        ctx.strokeStyle = cor; ctx.lineWidth = cheia ? 2 : 1.2;
        ctx.setLineDash(cheia ? [] : [4, 4]); ctx.stroke(); ctx.setLineDash([]);
        [rf, rt].forEach(x => {
            ctx.beginPath(); ctx.arc(x, chao - r, r, 0, Math.PI * 2);
            if (cheia) { ctx.fillStyle = '#0b0e13'; ctx.fill(); }
            ctx.strokeStyle = cor; ctx.lineWidth = cheia ? 2.5 : 1.2; ctx.stroke();
        });
    }

    function desenhar(v) {
        const chaoLinha = (g, y) => {
            g.ctx.strokeStyle = '#2a3340'; g.ctx.lineWidth = 1;
            g.ctx.beginPath(); g.ctx.moveTo(10, y); g.ctx.lineTo(g.w - 10, y); g.ctx.stroke();
        };
        const f = prepararCanvas('s-frente');
        chaoLinha(f, f.h - 18);
        vistaFrente(info.padrao, '#8b949e', false, f);
        vistaFrente(v, '#f1c232', true, f);
        f.ctx.fillStyle = '#6e7681'; f.ctx.font = '10px Consolas, monospace';
        f.ctx.fillText('FRENTE', 10, 14);

        const l = prepararCanvas('s-lado');
        chaoLinha(l, l.h - 10);
        vistaLado(info.padrao, '#8b949e', false, l);
        vistaLado(v, '#f1c232', true, l);
        l.ctx.fillStyle = '#6e7681'; l.ctx.font = '10px Consolas, monospace';
        l.ctx.fillText('LADO', 10, 14);
    }

    // Teste fora do jogo
    if (!RECURSO && location.hash === '#susp') {
        const padrao = { altura: 0, compressao: 100, retorno: 100, molaD: 100, molaT: 100, barraD: 100, barraT: 100, cambagemD: 0, cambagemT: 0, bitolaD: 0, bitolaT: 0 };
        document.getElementById('notebook').classList.add('oculto');
        abrir({
            placa: 'PA 2026', modelo: 'Sultan RS', padrao,
            faixas: {
                altura: { min: -12, max: 6, passo: 0.5 }, mola: { min: 60, max: 160, passo: 5 },
                compressao: { min: 50, max: 200, passo: 5 }, retorno: { min: 50, max: 200, passo: 5 },
                barra: { min: 0, max: 200, passo: 5 }, cambagem: { min: -12, max: 3, passo: 0.5 },
                bitola: { min: -4, max: 8, passo: 0.5 },
            },
            presets: {
                Rua: { altura: -2, compressao: 95, retorno: 100, molaD: 100, molaT: 95, barraD: 100, barraT: 100, cambagemD: -1, cambagemT: -0.5, bitolaD: 0, bitolaT: 0 },
                Pista: { altura: -5, compressao: 140, retorno: 150, molaD: 135, molaT: 125, barraD: 150, barraT: 130, cambagemD: -2.5, cambagemT: -1.5, bitolaD: 1, bitolaT: 1 },
                Drift: { altura: -4, compressao: 120, retorno: 110, molaD: 100, molaT: 140, barraD: 90, barraT: 170, cambagemD: -6, cambagemT: -0.5, bitolaD: 2, bitolaT: 1 },
                Stance: { altura: -11, compressao: 80, retorno: 80, molaD: 80, molaT: 80, barraD: 100, barraT: 100, cambagemD: -10, cambagemT: -11, bitolaD: 5, bitolaT: 6 },
            },
            atual: { ...padrao, altura: -4, cambagemD: -3 },
        });
    }
})();
