Config = {}

---------------------------------------------------------------------
-- QUEM PODE MEXER EM DESEMPENHO
---------------------------------------------------------------------
-- Mecânico especializado: emprego 'mechanic', em serviço, com cargo >= gradeMinimo.
-- O nível dele passa a ser o do cargo (cargo 3 = nível 3, cargo 4 = nível 4).
-- Quem não é mecânico precisa ter nível de skill (XP de preparação).
Config.mecanico = {
    job = 'mechanic',
    gradeMinimo = 3,       -- 3 = Advanced na base do Qbox
    precisaEstarEmServico = true,
}

-- XP necessário para cada nível de skill de preparação
Config.niveisXP = {
    [1] = 100,
    [2] = 300,
    [3] = 700,
    [4] = 1500,
}

---------------------------------------------------------------------
-- OFICINAS (onde dá para tirar/abrir motor)
---------------------------------------------------------------------
-- Área circular: centro + raio em metros. Quando colocar o MLO novo,
-- é só trocar/adicionar aqui.
Config.oficinas = {
    { label = 'Mecânica Pista & Asfalto', coords = vec3(-345.13, -124.37, 38.01), raio = 35.0 },
    { label = "Benny's Motorworks",    coords = vec3(-211.0, -1325.0, 31.0), raio = 25.0 },
}

-- Turbo, intercooler e kit de nitro (peças "de fora do motor"):
-- false = instala em qualquer lugar | true = só dentro de oficina
Config.pecasExternasSoNaOficina = false

---------------------------------------------------------------------
-- FERRAMENTAS (têm durabilidade; quebram ao chegar em 0)
---------------------------------------------------------------------
-- O número é quanto de durabilidade (0 a 100) cada serviço gasta.
Config.ferramentas = {
    soquetes = {
        item = 'jogo_soquetes', label = 'Jogo de soquetes',
        desgaste = { motor = 6, peca = 2 },    -- tirar/colocar motor | peças externas
    },
    torquimetro = {
        item = 'torquimetro', label = 'Torquímetro',
        desgaste = { abrir = 4, peca = 2 },    -- abrir/fechar motor | peças internas
    },
}

---------------------------------------------------------------------
-- MOTOR FORA DO CARRO (guincho da oficina + bancada)
---------------------------------------------------------------------
-- Use /pegarcoords (admin) em cada ponto e cole o resultado aqui.
Config.motor = {
    nivel = 2,                           -- nível para mexer com guincho/motor
    propGuincho = `prop_engine_hoist`,
    propMotor = `prop_car_engine_01`,

    -- Esconde o guincho que já vem no MLO nesses pontos (para não ficar dois)
    esconderGuinchoDoMapa = true,

    distanciaGuincho = 3.5,              -- guincho até a frente do carro
    distanciaBancada = 5.0,              -- guincho/motor até a bancada para descer o motor
    tempoRetirar = 20000,
    tempoRecolocar = 20000,
    tempoAbrir = 12000,
    tempoFechar = 12000,
    tempoBancada = 6000,
    xpRetirar = 15,

    -- Onde o motor fica pendurado no guincho (ajuste com /ajustegancho)
    gancho = { pos = vec3(0.0, -1.5, 1.35), rot = vec3(0.0, 0.0, 0.0) },
    -- Onde o guincho fica em relação ao jogador empurrando (ajuste com /ajusteempurrar)
    empurrar = { pos = vec3(0.0, 1.25, -0.98), rot = vec3(0.0, 0.0, 180.0) },
}

-- Guinchos que ficam na oficina (x, y, z do chão, direção)
Config.guinchos = {
    vec4(-322.68, -141.08, 38.01, 75.1),
}

-- Bancadas onde o motor é aberto (x, y, z do chão, direção)
Config.bancadas = {
    vec4(-323.82, -131.35, 37.96, 236.8),
}

---------------------------------------------------------------------
-- PEÇAS
---------------------------------------------------------------------
-- slot     = onde a peça fica no carro (uma peça por slot)
-- valor    = o que é gravado no slot (o chip guarda o stage)
-- nivel    = nível mínimo (skill ou cargo) para instalar
-- requer   = slots que precisam estar instalados antes
-- tempo    = duração da instalação em ms
-- xp       = XP ganho ao instalar
Config.itens = {
    peca_turbo = {
        label = 'Turbo', slot = 'turbo', valor = true,
        nivel = 1, tempo = 15000, xp = 20,
    },
    peca_intercooler = {
        label = 'Intercooler', slot = 'intercooler', valor = true,
        nivel = 1, tempo = 12000, xp = 15,
    },
    -- Peças internas (motor = true): só com o motor fora e aberto
    peca_pistao_forjado = {
        label = 'Pistão forjado', slot = 'pistao', valor = true, motor = true,
        nivel = 2, tempo = 25000, xp = 40,
    },
    cabecote_retrabalhado = {
        label = 'Cabeçote retrabalhado', slot = 'cabecote', valor = 1, motor = true,
        nivel = 2, tempo = 20000, xp = 35,
    },
    cabecote_competicao = {
        label = 'Cabeçote de competição', slot = 'cabecote', valor = 2, motor = true,
        nivel = 3, tempo = 25000, xp = 60,
    },
    chip_stage1 = {
        label = 'Chip Stage 1', slot = 'chip', valor = 1,
        nivel = 1, tempo = 8000, xp = 15,
    },
    chip_stage2 = {
        label = 'Chip Stage 2', slot = 'chip', valor = 2,
        nivel = 2, tempo = 10000, xp = 30, requer = { 'turbo' },
    },
    chip_stage3 = {
        label = 'Chip Stage 3', slot = 'chip', valor = 3,
        nivel = 3, tempo = 12000, xp = 50, requer = { 'turbo' },
    },
    kit_nitro = {
        label = 'Kit de nitro', slot = 'nitro', valor = true,
        nivel = 2, tempo = 20000, xp = 35,
    },
}

-- Ordem e nome dos slots no menu "Ver preparação"
Config.slots = {
    { id = 'chip',        label = 'Chip' },
    { id = 'turbo',       label = 'Turbo' },
    { id = 'intercooler', label = 'Intercooler' },
    { id = 'pistao',      label = 'Pistão' },
    { id = 'cabecote',    label = 'Cabeçote' },
    { id = 'nitro',       label = 'Nitro' },
}

---------------------------------------------------------------------
-- EFEITO DE CADA PEÇA NA HANDLING (em % sobre o carro original)
---------------------------------------------------------------------
-- forca = aceleração (fInitialDriveForce)
-- vmax  = velocidade final (fInitialDriveMaxFlatVel)
-- giro  = resposta do motor (fDriveInertia)
Config.efeitos = {
    turbo       = { forca = 0.12, vmax = 0.00, giro = 0.05 },
    intercooler = { forca = 0.05, vmax = 0.00, giro = 0.00 },
    pistao      = { forca = 0.05, vmax = 0.03, giro = 0.03 },
    cabecote = {
        [1] = { forca = 0.03, vmax = 0.03, giro = 0.06 },
        [2] = { forca = 0.06, vmax = 0.06, giro = 0.10 },
    },
    chip = {
        [1] = { forca = 0.08, vmax = 0.02, giro = 0.03 },
        [2] = { forca = 0.15, vmax = 0.04, giro = 0.05 },
        [3] = { forca = 0.25, vmax = 0.08, giro = 0.08 },
    },
}

-- Liga o turbo do próprio GTA (som de espirro/assobio) quando tem turbo instalado
Config.ativarTurboVisual = true

---------------------------------------------------------------------
-- RISCO DE QUEBRAR O MOTOR (preparação mal feita)
---------------------------------------------------------------------
-- A cada `intervalo` ms, com o giro acima de `rpmMinimo`, o motor perde vida.
Config.risco = {
    intervalo = 2000,
    rpmMinimo = 0.85,
    regras = {
        -- chip forte sem intercooler esquenta
        { chipMinimo = 2, semPeca = 'intercooler', dano = 4.0, aviso = 'Motor esquentando: falta intercooler' },
        -- stage 3 sem pistão forjado quebra rápido
        { chipMinimo = 3, semPeca = 'pistao', dano = 10.0, aviso = 'Motor sofrendo: stage 3 sem pistão forjado' },
    },
}

---------------------------------------------------------------------
-- NOTEBOOK DE REMAP (ajuste fino do chip)
---------------------------------------------------------------------
-- Quem tem skill usa o item notebook_remap em qualquer lugar: dentro do carro
-- ou do lado dele. Só funciona em carro com chip. O stage do chip define os limites.
Config.remap = {
    item = 'notebook_remap',
    nivel = 1,              -- nível mínimo para abrir o notebook
    tempoGravar = 10000,    -- ms para gravar o mapa na ECU
    xp = 10,
    danoMaximo = 12.0,      -- dano no motor a cada intervalo de risco com 100% de risco

    -- Limites por stage do chip
    limites = {
        [1] = { turboMax = 0.8, ignicaoMax = 4,  limitadorMax = 7500 },
        [2] = { turboMax = 1.4, ignicaoMax = 6,  limitadorMax = 8200 },
        [3] = { turboMax = 2.0, ignicaoMax = 8,  limitadorMax = 9000 },
    },

    -- rpm extra no limitador de acordo com o cabeçote
    limitadorExtraCabecote = { [1] = 200, [2] = 500 },

    -- Valores de fábrica (mapa original)
    padrao = { turbo = 0.0, ignicao = 0, limitador = 7000, mistura = 12.5 },

    -- Faixas dos controles
    faixas = {
        turbo     = { min = 0.0,  passo = 0.1 },        -- bar (precisa de turbo instalado)
        ignicao   = { min = -4,   passo = 1 },          -- graus de avanço
        limitador = { min = 6000, passo = 100 },        -- rpm
        mistura   = { min = 11.0, max = 14.7, passo = 0.1 }, -- AFR (menor = rica/segura, maior = pobre/forte)
    },
}

---------------------------------------------------------------------
-- NITRO
---------------------------------------------------------------------
Config.nitro = {
    tecla = 'LSHIFT',          -- o jogador pode trocar em Configurações > Atalhos > FiveM
    potencia = 2.0,            -- multiplicador de força enquanto aperta
    consumoPorSegundo = 20.0,  -- 100 de carga = 5 segundos de nitro
    cargaGarrafa = 100.0,
    itemGarrafa = 'garrafa_nitro',
    efeitoEscapamento = true,
}
