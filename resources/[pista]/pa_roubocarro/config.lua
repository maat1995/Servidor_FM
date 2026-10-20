Config = {}

---------------------------------------------------------------------
-- pa_roubocarro · roubo de carros sob encomenda
-- O tablet é comprado com BTC no PC (pa_bitcoin). Cada carro entregue
-- dá XP (sobe o nível do tablet) e moedas. As moedas compram o carro
-- entregue com chassi riscado e as melhorias do tablet.
---------------------------------------------------------------------

Config.itemTablet = 'tablet_roubo'
Config.nomeMoeda  = 'moedas'

-- Ferramentas para arrombar (a primeira que o jogador tiver é usada)
Config.ferramentas = { 'advancedlockpick', 'lockpick' }

-- XP total para chegar em cada nível (nível 1 começa em 0)
Config.xpNivel = { 0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200 }

-- Dupla: quem entrega fica com 70%, o parceiro com 30% (XP e moedas)
Config.dupla = {
    entregou = 0.70,
    parceiro = 0.30,
    tempoConvite = 60,      -- segundos para aceitar o convite
}

Config.espera = {
    entregou = 5 * 60,      -- segundos até pedir outro contrato
    falhou   = 10 * 60,
}

-- Carro amassado paga menos: abaixo disso de lataria+motor (0-100) começa a cair
Config.danoSemDesconto = 85
Config.pagamentoMinimo = 0.40   -- carro destruído no limite ainda paga 40%

---------------------------------------------------------------------
-- CLASSES
-- modo 'rua'  : qualquer carro do modelo da lista que aparecer no mapa
-- modo 'local': o carro fica estacionado num ponto específico (Config.locais)
-- policiaMin  : policiais em serviço para pedir o contrato
-- alarme      : chance (0-1) do alarme disparar e avisar a polícia
-- rastreador  : o carro manda a posição para a polícia até ser desligado
---------------------------------------------------------------------
Config.classes = {
    D = {
        label = 'Classe D · compactos e velhos', niveis = { 1, 3 }, modo = 'rua',
        xp = 25, moedas = 10, precoCarro = 30, tempo = 20, policiaMin = 0,
        alarme = 0.30, rastreador = false,
        modelos = {
            'blista', 'brioso', 'dilettante', 'issi2', 'panto', 'prairie', 'rhapsody',
            'asea', 'emperor', 'emperor2', 'ingot', 'regina', 'stratum', 'primo', 'glendale',
            'warrener', 'manana', 'tornado', 'voodoo2', 'surge', 'picador', 'rebel', 'bodhi2',
            'youga', 'journey', 'journey2',
        },
    },
    C = {
        label = 'Classe C · sedãs e SUVs', niveis = { 4, 5 }, modo = 'local',
        xp = 45, moedas = 20, precoCarro = 60, tempo = 25, policiaMin = 1,
        alarme = 0.60, rastreador = false,
        modelos = {
            'asterope', 'fugitive', 'premier', 'schafter2', 'stanier', 'tailgater', 'washington',
            'intruder', 'granger', 'baller', 'cavalcade', 'fq2', 'gresley', 'landstalker',
            'radi', 'seminole', 'habanero', 'oracle', 'sentinel', 'zion', 'felon',
        },
    },
    B = {
        label = 'Classe B · muscle e esportivos', niveis = { 6, 7 }, modo = 'local',
        xp = 70, moedas = 35, precoCarro = 120, tempo = 30, policiaMin = 2,
        alarme = 1.0, rastreador = false,
        modelos = {
            'dominator', 'gauntlet', 'buffalo', 'buffalo2', 'sultan', 'kuruma', 'futo',
            'penumbra', 'elegy2', 'fusilade', 'schwarzer', 'feltzer2', 'rapidgt', 'surano', 'comet2',
        },
    },
    A = {
        label = 'Classe A · esportivos e luxo', niveis = { 8, 9 }, modo = 'local',
        xp = 100, moedas = 55, precoCarro = 220, tempo = 35, policiaMin = 3,
        alarme = 1.0, rastreador = true,
        modelos = {
            'banshee', 'jester', 'massacro', 'ninef', 'coquette', 'carbonizzare', 'seven70',
            'specter', 'lynx', 'alpha', 'furoregt', 'rapidgt2', 'huntley', 'xls', 'windsor', 'cognoscenti',
        },
    },
    S = {
        label = 'Classe S · supercarros', niveis = { 10, 10 }, modo = 'local',
        xp = 150, moedas = 90, precoCarro = 400, tempo = 40, policiaMin = 4,
        alarme = 1.0, rastreador = true,
        modelos = {
            'adder', 'zentorno', 't20', 'osiris', 'entityxf', 'turismor', 'reaper', 'cheetah',
            'infernus', 'vacca', 'fmj', 'italigtb', 'nero', 'tempesta', 'xa21', 'krieger', 'emerus',
        },
    },
}
Config.ordemClasses = { 'D', 'C', 'B', 'A', 'S' }

---------------------------------------------------------------------
-- LOCAIS onde o carro do contrato fica estacionado (classes 'local')
-- Ajuste no jogo: pare no lugar e use /rc_ponto (admin) para copiar a posição.
---------------------------------------------------------------------
Config.locais = {
    C = {
        vec4(230.1, -796.7, 30.6, 160.5),     -- estacionamento da Legion
        vec4(273.9, -332.9, 44.9, 160.0),     -- estacionamento de Pillbox Hill
        vec4(1136.5, -653.5, 56.7, 100.0),    -- Mirror Park
        vec4(-1183.0, -1494.0, 4.4, 125.0),   -- Vespucci
        vec4(-342.5, -763.0, 33.9, 270.0),    -- Alta
    },
    B = {
        vec4(-1622.0, -890.0, 9.0, 320.0),    -- píer de Del Perro
        vec4(-1355.0, -754.0, 22.3, 37.0),    -- Del Perro
        vec4(-711.0, -918.0, 19.0, 90.0),     -- Little Seoul
        vec4(-47.0, -1115.0, 26.4, 0.0),      -- perto da concessionária
        vec4(1981.0, 3779.0, 32.2, 210.0),    -- Sandy Shores
    },
    A = {
        vec4(-811.0, 187.5, 72.5, 110.0),     -- Rockford Hills
        vec4(-1515.3, 104.8, 55.9, 220.0),    -- Richman
        vec4(-668.0, -2391.0, 13.9, 60.0),    -- aeroporto
        vec4(13.4, 549.6, 176.2, 270.0),      -- Vinewood Hills
    },
    S = {
        vec4(-103.5, 1009.1, 235.8, 110.0),   -- mansão em Vinewood Hills
        vec4(-811.0, 187.5, 72.5, 110.0),     -- Rockford Hills
        vec4(-1515.3, 104.8, 55.9, 220.0),    -- Richman
    },
}

-- Raio da área mostrada no tablet (o ponto exato fica escondido)
Config.area = {
    raio = 220.0,          -- área inicial
    raioPerto = 60.0,      -- dentro da área, encolhe para este raio
}

-- Pontos de entrega (revelados só depois do roubo); o mais longe do roubo é preferido
Config.entregas = {
    vec3(1204.6, -3115.9, 5.5),    -- porto
    vec3(-1150.5, -2015.6, 13.2),  -- galpão perto do aeroporto
    vec3(483.5, -1311.0, 29.2),    -- ferro-velho de Strawberry
    vec3(2340.4, 3053.6, 48.2),    -- ferro-velho do deserto
    vec3(-195.0, 6265.0, 31.5),    -- Paleto Bay
}
Config.raioEntrega = 6.0

-- Onde o carro comprado com chassi riscado é retirado
Config.retirada = vec4(1736.0, 3290.0, 41.1, 195.0)  -- hangar de Sandy Shores

---------------------------------------------------------------------
-- POLÍCIA (exports.pa_policia:alerta)
-- Roubo de contrato aparece diferente de um roubo comum: código e ícone próprios.
---------------------------------------------------------------------
Config.policia = {
    codigo = '10-16E',
    titulo = 'Roubo de veículo sob encomenda',
    sprite = 523,
    raio = 150.0,
    prioridade = { D = 'baixa', C = 'media', B = 'media', A = 'alta', S = 'maxima' },
}

Config.rastreador = {
    intervalo = 20,        -- segundos entre cada atualização para a polícia
    raio = 40.0,           -- área pequena: quase o ponto exato
}

---------------------------------------------------------------------
-- MELHORIAS do tablet (compradas com moedas, cada nível uma vez)
---------------------------------------------------------------------
Config.melhorias = {
    area = {
        label = 'Localizador', descricao = 'Área do contrato menor.',
        precos = { 40, 90 }, valor = { 1.0, 0.70, 0.45 },          -- multiplica o raio
    },
    rastreador = {
        label = 'Bloqueador de rastreador', descricao = 'Menos etapas para desligar o rastreador.',
        precos = { 60, 130 }, valor = { 5, 4, 3 },                 -- etapas do hack
    },
    lockpick = {
        label = 'Gazua reforçada', descricao = 'Menos chance de quebrar a ferramenta.',
        precos = { 30, 70 }, valor = { 0.40, 0.25, 0.10 },          -- chance de quebrar
    },
    tempo = {
        label = 'Contatos', descricao = 'Mais tempo para entregar o carro.',
        precos = { 35, 80 }, valor = { 0, 5, 10 },                  -- minutos a mais
    },
}

-- Transferir carro com chassi riscado para outro jogador (venda no RP)
Config.transferencia = { distancia = 5.0 }

Config.debug = false
