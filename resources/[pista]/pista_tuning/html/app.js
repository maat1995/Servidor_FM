const RECURSO = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;

const CAMPOS = ['turbo', 'ignicao', 'limitador', 'mistura'];
const FORMATO = {
    turbo: v => `${v.toFixed(1)} bar`,
    ignicao: v => `${v > 0 ? '+' : ''}${Math.round(v)}°`,
    limitador: v => `${Math.round(v)} rpm`,
    mistura: v => v.toFixed(1),
};

let estado = null;
let timerPrevia = null;

// ---------------------------------------------------------------------
// Comunicação com o jogo
// ---------------------------------------------------------------------
async function enviar(nome, dados = {}) {
    if (!RECURSO) return previaLocal(dados); // teste fora do jogo
    const resp = await fetch(`https://${RECURSO}/${nome}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(dados),
    });
    try { return await resp.json(); } catch { return null; }
}

window.addEventListener('message', ({ data }) => {
    if (data.acao === 'abrir') abrir(data);
    if (data.acao === 'fechar') document.getElementById('notebook').classList.add('oculto');
});

document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && estado) fechar();
});

// ---------------------------------------------------------------------
// Tela
// ---------------------------------------------------------------------
function abrir(info) {
    estado = info;
    document.getElementById('placa').textContent = info.placa || '---';
    document.getElementById('modelo').textContent = info.modelo || '';
    document.getElementById('stage').textContent = `STAGE ${info.stage}`;

    document.querySelectorAll('.peca').forEach(el => {
        el.classList.toggle('tem', !!info.pecas[el.dataset.peca]);
    });

    const maximos = {
        turbo: info.limites.turboMax,
        ignicao: info.limites.ignicaoMax,
        limitador: info.limites.limitadorMax,
        mistura: info.faixas.mistura.max,
    };

    CAMPOS.forEach(campo => {
        const bloco = document.querySelector(`.ajuste[data-campo="${campo}"]`);
        const input = bloco.querySelector('input');
        input.min = info.faixas[campo].min;
        input.max = maximos[campo];
        input.step = info.faixas[campo].passo;
        input.value = info.atual[campo];

        const semTurbo = campo === 'turbo' && !info.pecas.turbo;
        input.disabled = semTurbo;
        bloco.classList.toggle('bloqueado', semTurbo);
        if (semTurbo) bloco.querySelector('.dica').textContent = 'Instale um turbo para liberar a pressão.';

        input.oninput = () => { atualizarSlider(campo); pedirPrevia(); };
        atualizarSlider(campo);
    });

    document.getElementById('notebook').classList.remove('oculto');
    mostrarPrevia(info.previa);
}

function valores() {
    const v = {};
    CAMPOS.forEach(c => { v[c] = parseFloat(document.querySelector(`.ajuste[data-campo="${c}"] input`).value); });
    return v;
}

function atualizarSlider(campo) {
    const input = document.querySelector(`.ajuste[data-campo="${campo}"] input`);
    const v = parseFloat(input.value);
    const min = parseFloat(input.min), max = parseFloat(input.max);
    const p = max > min ? ((v - min) / (max - min)) * 100 : 0;
    input.style.setProperty('--p', `${p}%`);
    document.querySelector(`.ajuste[data-campo="${campo}"] output`).textContent = FORMATO[campo](v);
}

function pedirPrevia() {
    clearTimeout(timerPrevia);
    timerPrevia = setTimeout(async () => {
        const r = await enviar('previa', valores());
        if (r) mostrarPrevia(r);
    }, 60);
}

function pct(v) {
    const n = Math.round(v * 1000) / 10;
    return `${n >= 0 ? '+' : ''}${n.toFixed(1)}%`;
}

function mostrarPrevia(r) {
    const barras = { forca: r.forca, vmax: r.vmax, giro: r.giro };
    const escala = { forca: 0.6, vmax: 0.2, giro: 0.25 };
    for (const [k, v] of Object.entries(barras)) {
        const el = document.getElementById(`b-${k}`);
        el.querySelector('i').style.width = `${Math.max(0, Math.min(100, (v / escala[k]) * 100))}%`;
        el.querySelector('b').textContent = pct(v);
    }

    const risco = Math.round(r.risco);
    const caixa = document.getElementById('risco');
    caixa.className = 'risco ' + (risco < 30 ? 'baixo' : risco < 60 ? 'medio' : 'alto');
    document.getElementById('risco-valor').textContent = `${risco}%`;
    document.getElementById('risco-barra').style.width = `${Math.max(2, risco)}%`;
    document.getElementById('risco-texto').textContent =
        risco < 30 ? 'Mapa seguro para o dia a dia'
            : risco < 60 ? 'Mapa agressivo: o motor desgasta em giro alto'
                : 'Perigo: o motor pode fundir em pouco tempo';

    desenharCurva(r);
}

// ---------------------------------------------------------------------
// Curva de potência (ilustrativa)
// ---------------------------------------------------------------------
function desenharCurva(r) {
    const canvas = document.getElementById('curva');
    const dpr = window.devicePixelRatio || 1;
    const w = canvas.clientWidth, h = canvas.clientHeight;
    canvas.width = w * dpr; canvas.height = h * dpr;
    const ctx = canvas.getContext('2d');
    ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, w, h);

    const esq = 34, dir = 8, topo = 10, base = 22;
    const rpmMin = 1000, rpmMax = 9500;
    const x = rpm => esq + ((rpm - rpmMin) / (rpmMax - rpmMin)) * (w - esq - dir);
    const potMax = 1.9;
    const y = p => h - base - (p / potMax) * (h - topo - base);

    // grade
    ctx.strokeStyle = '#232b36';
    ctx.fillStyle = '#6e7681';
    ctx.font = '10px Consolas, monospace';
    ctx.lineWidth = 1;
    for (let rpm = 2000; rpm <= 9000; rpm += 1000) {
        ctx.beginPath(); ctx.moveTo(x(rpm), topo); ctx.lineTo(x(rpm), h - base); ctx.stroke();
        ctx.fillText(`${rpm / 1000}k`, x(rpm) - 6, h - 7);
    }
    for (let p = 0.5; p < potMax; p += 0.5) {
        ctx.beginPath(); ctx.moveTo(esq, y(p)); ctx.lineTo(w - dir, y(p)); ctx.stroke();
    }
    ctx.save();
    ctx.translate(10, h / 2 + 12); ctx.rotate(-Math.PI / 2);
    ctx.fillText('potência', 0, 0);
    ctx.restore();

    const forma = rpm => {
        const t = 1 - Math.pow((rpm - 5200) / 5200, 2);
        return Math.max(0, t) * (rpm / 6000);
    };

    const turbo = (r.remap && r.remap.turbo) || 0;
    const limite = (r.remap && r.remap.limitador) || 7000;

    const curva = (fim, fator, extraTurbo, cor, largura, preencher) => {
        ctx.beginPath();
        for (let rpm = rpmMin; rpm <= fim; rpm += 50) {
            const bump = 1 + extraTurbo * 0.08 * Math.exp(-Math.pow((rpm - 4200) / 1600, 2));
            const px = x(rpm), py = y(forma(rpm) * fator * bump);
            rpm === rpmMin ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
        }
        if (preencher) {
            ctx.lineTo(x(fim), h - base); ctx.lineTo(x(rpmMin), h - base); ctx.closePath();
            const g = ctx.createLinearGradient(0, topo, 0, h - base);
            g.addColorStop(0, 'rgba(241,194,50,.28)'); g.addColorStop(1, 'rgba(241,194,50,0)');
            ctx.fillStyle = g; ctx.fill();
            return;
        }
        ctx.strokeStyle = cor; ctx.lineWidth = largura; ctx.stroke();
    };

    curva(limite, 1 + r.forca, turbo, null, 0, true);
    curva(7000, 1, 0, '#8b949e', 1.5, false);
    curva(limite, 1 + r.forca, turbo, '#f1c232', 2.5, false);

    // corte do limitador
    ctx.setLineDash([4, 4]);
    ctx.strokeStyle = 'rgba(248,81,73,.8)';
    ctx.beginPath(); ctx.moveTo(x(limite), topo); ctx.lineTo(x(limite), h - base); ctx.stroke();
    ctx.setLineDash([]);
}

// ---------------------------------------------------------------------
// Botões
// ---------------------------------------------------------------------
function fechar() {
    estado = null;
    document.getElementById('notebook').classList.add('oculto');
    enviar('fechar');
}

document.getElementById('btn-fechar').onclick = fechar;

document.getElementById('btn-original').onclick = () => {
    if (!estado) return;
    CAMPOS.forEach(c => {
        const input = document.querySelector(`.ajuste[data-campo="${c}"] input`);
        input.value = estado.padrao[c];
        atualizarSlider(c);
    });
    pedirPrevia();
};

document.getElementById('btn-gravar').onclick = () => {
    if (!estado) return;
    const v = valores();
    estado = null;
    document.getElementById('notebook').classList.add('oculto');
    enviar('gravar', v);
};

// ---------------------------------------------------------------------
// Só para testar no navegador (fora do FiveM)
// ---------------------------------------------------------------------
function previaLocal(v) {
    if (!v || v.turbo === undefined) return null;
    const p = estado ? estado.pecas : {};
    let forca = 0.15 + v.turbo * 0.10 + v.ignicao * 0.008 + (v.mistura - 12.5) * 0.03;
    let vmax = 0.04 + ((v.limitador - 7000) / 1000) * 0.03;
    let giro = 0.05 + v.turbo * 0.02 + v.ignicao * 0.004;
    let rT = v.turbo * v.turbo * 12 * (p.intercooler ? 0.5 : 1);
    let rM = (v.ignicao > 0 ? v.ignicao * v.ignicao * 0.6 : 0) + Math.max(0, v.limitador - 7500) / 100 * 1.2;
    if (p.pistao) rM *= 0.5;
    const rA = v.mistura > 12.5 ? Math.pow(v.mistura - 12.5, 2) * 6 : -(12.5 - v.mistura) * 8;
    return { remap: v, forca, vmax, giro, risco: Math.max(0, Math.min(100, rT + rM + rA)) };
}

if (!RECURSO) {
    abrir({
        placa: 'PA 2026', modelo: 'Sultan RS', stage: 2,
        pecas: { turbo: true, intercooler: false, pistao: true },
        faixas: {
            turbo: { min: 0, passo: 0.1 }, ignicao: { min: -4, passo: 1 },
            limitador: { min: 6000, passo: 100 }, mistura: { min: 11, max: 14.7, passo: 0.1 },
        },
        limites: { turboMax: 1.4, ignicaoMax: 6, limitadorMax: 8200 },
        padrao: { turbo: 0, ignicao: 0, limitador: 7000, mistura: 12.5 },
        atual: { turbo: 0.9, ignicao: 3, limitador: 7800, mistura: 13.1 },
        previa: previaLocal({ turbo: 0.9, ignicao: 3, limitador: 7800, mistura: 13.1 }),
    });
}
