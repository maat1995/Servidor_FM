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
    { label = 'Mecânica Pista & Asfalto (Burton)', coords = vec3(-334.85, -121.60, 38.01), raio = 35.0 },
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

    -- O motor sai do carro direto para os braços. O guincho fica desligado
    -- (o do MLO continua só de enfeite). true = volta a criar o guincho na vaga.
    usarGuincho = false,

    -- Esconde o guincho que já vem no MLO (só vale com usarGuincho = true)
    esconderGuinchoDoMapa = false,

    distanciaGuincho = 3.5,              -- guincho até a frente do carro
    distanciaBancada = 5.0,              -- guincho/motor até a bancada para descer o motor
    tempoRetirar = 20000,
    tempoRecolocar = 20000,
    tempoAbrir = 12000,
    tempoFechar = 12000,
    tempoBancada = 6000,
    xpRetirar = 15,

    -- Tempo (ms) do motor subindo/descendo no gancho
    animacao = { subir = 4500, descer = 4500 },

    -- Corda da ponta do guincho até o motor (ajuste a ponta com /ajustecorda)
    -- tipo: 1 = grossa, 4 = fina | ativa = false desliga e fica só o movimento
    corda = { ativa = true, tipo = 4, pos = vec3(0.0, -1.32, 1.95), motor = vec3(0.0, 0.0, 0.35) },

    -- Motor nos braços do mecânico (ajuste com /ajustecarregar)
    carregar = { pos = vec3(0.0, 0.55, 0.0), rot = vec3(0.0, 0.0, 90.0) },

    -- Onde o motor fica pendurado no guincho (ajuste com /ajustegancho)
    gancho = { pos = vec3(0.0, -1.5, 1.35), rot = vec3(0.0, 0.0, 0.0) },
    -- Onde o guincho fica em relação ao jogador empurrando (ajuste com /ajusteempurrar)
    empurrar = { pos = vec3(0.0, 1.25, -0.98), rot = vec3(0.0, 0.0, 180.0) },
}

-- Vagas do motor: o carro encaixa na vaga e o guincho fica fixo na frente dela.
-- carro   = centro da vaga, virado para a frente do carro
-- guincho = onde o guincho fica (fixo)
Config.vagasMotor = {
    {
        label = 'Vaga do motor',
        carro = vec4(-322.79, -133.41, 38.01, 305.2),
        guincho = vec4(-320.81, -131.15, 38.01, 329.0), -- braço virado para o carro
        raio = 3.0,
    },
}

-- O guincho de cada vaga (montado automaticamente; não mexa)
Config.guinchos = {}
for i, v in ipairs(Config.vagasMotor) do Config.guinchos[i] = v.guincho end

-- Guinchos que já vêm no MLO e devem sumir (para não ficar guincho sobrando)
Config.esconderGuinchosMLO = {
    vec3(-342.81, -127.99, 38.01),
}

-- Bancadas onde o motor é aberto (x, y, z do chão, direção)
Config.bancadas = {
    vec4(-320.87, -136.99, 38.82, 72.0), -- em cima da bancada de ferramentas
}

---------------------------------------------------------------------
-- ELEVADORES (freio e transmissão)
---------------------------------------------------------------------
-- coords = meio entre as duas colunas, virado para a frente do carro (use /pegarcoords)
Config.elevadores = {
    { label = 'Elevador 1', coords = vec4(-328.04, -130.42, 38.08, 330.7), raio = 2.5 },
}

Config.elevador = {
    job = 'mechanic',           -- qualquer cargo desse emprego pode usar (sem skill)
    precisaEstarEmServico = true,
    altura = 1.6,               -- quanto o carro sobe (metros)
    tempoSubir = 6000,
    tempoDescer = 6000,
    tempoRoda = 8000,           -- tirar ou colocar uma roda
    tempoFreio = 10000,         -- instalar o freio em uma roda
    propRoda = `prop_wheel_01`, -- roda que fica no chão enquanto está fora do carro
    distanciaTexto = 8.0,       -- distância para ver a situação de cada roda (texto em cima)
}

-- Kits: o freio vai em cada uma das 4 rodas (1 kit = 4 rodas), com o carro no elevador:
-- [E] sobe o carro, mire na roda com o Alt para tirar, instalar e recolocar.
-- A transmissão instala igual turbo (em qualquer lugar, com jogo de soquetes).
-- nivel = nível do upgrade nativo do GTA (0, 1, 2)
Config.kitsFreio = {
    freio_rua         = { label = 'Freio de rua', nivel = 0 },
    freio_esportivo   = { label = 'Freio esportivo', nivel = 1 },
    freio_competicao  = { label = 'Freio de competição', nivel = 2 },
}
Config.kitsCambio = {
    cambio_rua        = { label = 'Transmissão de rua', nivel = 0 },
    cambio_esportivo  = { label = 'Transmissão esportiva', nivel = 1 },
    cambio_competicao = { label = 'Transmissão de competição', nivel = 2 },
}
Config.cambio = {
    tempo = 20000,   -- ms para trocar a transmissão
    xp = 20,
    -- Quem pode trocar: mecânico (qualquer cargo, em serviço) ou quem tem skill >= nivel
    nivel = 1,
}

---------------------------------------------------------------------
-- SUSPENSÃO REGULÁVEL (rosca)
---------------------------------------------------------------------
-- Instala no elevador igual o freio (1 kit = 4 rodas). Depois de instalada,
-- o dono do carro ou um mecânico regula em qualquer lugar: /suspensao
-- (dentro ou do lado do carro) ou pelo Alt no carro > "Regular suspensão".
-- A suspensão nativa do LS Customs (mod 15) deixa de existir.
Config.suspensao = {
    item = 'suspensao_regulavel',
    label = 'Suspensão regulável',
    tempo = 10000,               -- instalar em uma roda (ms)
    xp = 15,
    tempoRegular = 6000,         -- aplicar a regulagem (ms)
    mecanicoPrecisaServico = true,
    inverterCambagem = false,    -- se a cambagem negativa ficar "para fora" no seu GTA, troque para true

    -- Faixas do painel. Mola, amortecedor e barra são % do carro original (100 = original).
    faixas = {
        altura     = { min = -12, max = 6,   passo = 0.5 },  -- cm (negativo = mais baixo)
        mola       = { min = 60,  max = 160, passo = 5 },
        compressao = { min = 50,  max = 200, passo = 5 },
        retorno    = { min = 50,  max = 200, passo = 5 },
        barra      = { min = 0,   max = 200, passo = 5 },
        cambagem   = { min = -12, max = 3,   passo = 0.5 },  -- graus (negativo = topo da roda para dentro)
        bitola     = { min = -4,  max = 8,   passo = 0.5 },  -- cm por lado (positivo = roda para fora)
    },

    -- Regulagem de fábrica (quando instala)
    padrao = {
        altura = 0, compressao = 100, retorno = 100,
        molaD = 100, molaT = 100, barraD = 100, barraT = 100,
        cambagemD = 0, cambagemT = 0, bitolaD = 0, bitolaT = 0,
    },

    presets = {
        Rua    = { altura = -2,  compressao = 95,  retorno = 100, molaD = 100, molaT = 95,  barraD = 100, barraT = 100, cambagemD = -1,  cambagemT = -0.5, bitolaD = 0,   bitolaT = 0 },
        Pista  = { altura = -5,  compressao = 140, retorno = 150, molaD = 135, molaT = 125, barraD = 150, barraT = 130, cambagemD = -2.5, cambagemT = -1.5, bitolaD = 1,  bitolaT = 1 },
        Drift  = { altura = -4,  compressao = 120, retorno = 110, molaD = 100, molaT = 140, barraD = 90,  barraT = 170, cambagemD = -6,  cambagemT = -0.5, bitolaD = 2,   bitolaT = 1 },
        Stance = { altura = -11, compressao = 80,  retorno = 80,  molaD = 80,  molaT = 80,  barraD = 100, barraT = 100, cambagemD = -10, cambagemT = -11,  bitolaD = 5,   bitolaT = 6 },
    },

    -- Distância para ver a suspensão regulada dos outros carros (cambagem e bitola)
    distanciaVisual = 80.0,
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
    -- Peças internas (motor = true): só com o motor fora, na bancada e aberto
    peca_pistao_taxado = {
        label = 'Pistão taxado', slot = 'pistao', valor = 'taxado', motor = true,
        nivel = 2, tempo = 25000, xp = 40,
    },
    peca_pistao_forjado = {
        label = 'Pistão forjado', slot = 'pistao', valor = 'forjado', motor = true,
        nivel = 2, tempo = 25000, xp = 40,
    },
    cabecote_retrabalhado = {
        label = 'Cabeçote retrabalhado', slot = 'cabecote', valor = 1, motor = true,
        nivel = 2, tempo = 20000, xp = 35,
    },
    cabecote_competicao = {
        label = 'Cabeçote de corrida', slot = 'cabecote', valor = 2, motor = true,
        nivel = 3, tempo = 25000, xp = 60,
    },
    junta_reforcada = {
        label = 'Junta de cabeçote reforçada', slot = 'junta', valor = true, motor = true,
        nivel = 2, tempo = 15000, xp = 25,
    },
    bielas_forjadas = {
        label = 'Bielas forjadas', slot = 'bielas', valor = true, motor = true,
        nivel = 3, tempo = 25000, xp = 50,
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
    { id = 'junta',       label = 'Junta do cabeçote' },
    { id = 'bielas',      label = 'Bielas' },
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
    chip = {
        [1] = { forca = 0.08, vmax = 0.02, giro = 0.03 },
        [2] = { forca = 0.15, vmax = 0.04, giro = 0.05 },
        [3] = { forca = 0.25, vmax = 0.08, giro = 0.08 },
    },
}

---------------------------------------------------------------------
-- MONTAGEM DO MOTOR (pistão, cabeçote, junta, bielas)
---------------------------------------------------------------------
-- Aspirado = sem turbo. Turbo = com turbo instalado.
Config.montagem = {
    pistao = {
        -- Taxado: alta taxa de compressão. Rende no aspirado; com turbo dá batida de pino.
        taxado  = { forca = 0.08, vmax = 0.02, giro = 0.05 },
        -- Forjado: taxa baixa e resistente. Rende pouco sozinho; é o que aguenta pressão de turbo.
        forjado = { forca = 0.02, vmax = 0.01, giro = 0.02 },
    },
    taxadoComTurbo = 0.5,          -- com turbo, o pistão taxado entrega só metade do ganho

    cabecote = {
        [1] = { forca = 0.03, vmax = 0.03, giro = 0.06 },  -- retrabalhado
        [2] = { forca = 0.08, vmax = 0.06, giro = 0.10 },  -- de corrida
    },
    corridaSemPistao = 0.4,        -- cabeçote de corrida em pistão original entrega só 40%

    -- Bônus das montagens "certas"
    combos = {
        aspiradoPista = { forca = 0.05, vmax = 0.02, giro = 0.04 }, -- taxado + corrida, sem turbo
        turboPista    = { forca = 0.06, vmax = 0.03, giro = 0.02 }, -- forjado + corrida + turbo
    },

    -- Limites no notebook de remap
    turboExtraForjado = 0.4,                      -- bar a mais de pressão com pistão forjado
    limitadorExtraCabecote = { [1] = 200, [2] = 500 }, -- corrida só libera com pistão preparado
    limitadorSemBielas = 8500,                    -- teto do limitador sem bielas forjadas
    juntaLimiteBar = 1.4,                         -- acima disso, sem junta reforçada, a junta queima
}

-- Liga o turbo do próprio GTA (som de espirro/assobio) quando tem turbo instalado
Config.ativarTurboVisual = true

-- Tira o "Engine Upgrade" nativo do GTA (nível 1 a 5) dos carros quando alguém dirige.
-- A potência do motor fica só por conta do chip, pistão, cabeçote e remap.
Config.removerMotorNativo = true

-- Freio, transmissão e suspensão também saem do LS Customs: o nível do carro é o
-- que foi instalado pelos kits (sem kit = original).
Config.controlarFreioCambio = true

---------------------------------------------------------------------
-- RISCO DE QUEBRAR O MOTOR (preparação mal feita)
---------------------------------------------------------------------
-- A cada `intervalo` ms, com o giro acima de `rpmMinimo`, o motor perde vida.
Config.risco = {
    intervalo = 2000,
    rpmMinimo = 0.85,
    -- Dano no motor a cada intervalo, em giro alto, quando a montagem está errada
    danos = {
        semIntercooler   = 4.0,   -- chip Stage 2+ com turbo e sem intercooler
        stage3SemForjado = 10.0,  -- chip Stage 3 sem pistão forjado
        taxadoComTurbo   = 6.0,   -- pistão taxado com turbo (batida de pino)
        corridaSemPistao = 3.0,   -- cabeçote de corrida em pistão original
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
