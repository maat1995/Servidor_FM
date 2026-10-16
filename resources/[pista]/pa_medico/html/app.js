const $ = (id) => document.getElementById(id);

const formatar = (s) => {
    const m = Math.floor(s / 60);
    const r = s % 60;
    return `${m}:${String(r).padStart(2, '0')}`;
};

window.addEventListener('message', ({ data }) => {
    if (!data || !data.acao) return;

    if (data.acao === 'mostrar') {
        if (data.titulo) $('titulo-texto').textContent = data.titulo;
        $('tela').classList.remove('oculto');
        return;
    }

    if (data.acao === 'esconder') {
        $('tela').classList.add('oculto');
        return;
    }

    if (data.acao !== 'atualizar') return;

    const t = data.textos || {};
    if (t.chamar) $('texto-chamar').textContent = t.chamar;
    if (t.hospital) $('texto-hospital').textContent = t.hospital;

    // Relógio
    const relogio = $('relogio');
    relogio.textContent = formatar(data.restante);
    relogio.classList.toggle('zerado', data.liberado);
    $('relogio-legenda').classList.toggle('oculto', data.restante <= 0);
    if (t.aguardar) $('relogio-legenda').textContent = t.aguardar;

    // Status do resgate
    const status = $('status');
    if (data.status) {
        $('status-texto').textContent = data.status;
        status.classList.remove('oculto');
    } else {
        status.classList.add('oculto');
    }

    // Massagem cardíaca do socorrista NPC
    const rcp = $('rcp');
    if (typeof data.rcp === 'number') {
        rcp.classList.remove('oculto');
        $('rcp-barra').style.width = `${Math.min(100, data.rcp * 100)}%`;
    } else {
        rcp.classList.add('oculto');
    }

    // Teclas
    $('tecla-chamar').classList.toggle('oculto', !data.podeChamar);
    $('tecla-hospital').classList.toggle('bloqueada', !data.liberado);
    $('tecla-hospital').classList.toggle('oculto', data.npc);
    $('segurar-barra').style.width = `${Math.min(100, (data.segurando || 0) * 100)}%`;
});
