Config = {}

-- =====================================================================
-- PA_POLICIA - Pista & Asfalto RP
-- Polícia completa da LSPD: serviço, central de alertas, abordagem,
-- tablet (MDT), prisão, fiscalização veicular e perícia.
-- Substitui o qbx_police e o xt-prison (os dois ficam desligados no server.cfg).
-- =====================================================================

Config.Titulo = 'LSPD'
Config.Debug = false

-- Emprego da polícia (qbx_core/shared/jobs.lua). O tipo 'leo' continua igual:
-- o pa_cambio, a pa_hud e os roubos usam o tipo.
Config.job = 'police'
Config.tipo = 'leo'

-- Nome de cada patente (o grau vem do jobs.lua)
Config.patentes = {
    [0] = 'Cadete',
    [1] = 'Oficial 1',
    [2] = 'Oficial 2',
    [3] = 'Sargento',
    [4] = 'Tenente',
    [5] = 'Diretor',
    [6] = 'Chefe',
}

---------------------------------------------------------------------
-- PERMISSÕES: patente mínima para cada ação
---------------------------------------------------------------------
Config.permissoes = {
    servico         = 0,  -- bater ponto, receber alertas, assumir ocorrência
    algemar         = 0,  -- algemar, conduzir, colocar/tirar da viatura
    revistar        = 0,
    multar          = 0,  -- até o teto da patente (Config.tetoMulta)
    prender         = 1,  -- aplicar pena (código penal) e mandar para Bolingbroke
    apreender       = 1,  -- apreender itens ilegais, dinheiro sujo e armas sem porte
    bo              = 1,  -- registrar boletim de ocorrência
    patio           = 1,  -- mandar carro para o pátio
    pericia         = 1,  -- coletar e analisar evidências
    objetos         = 2,  -- cones, barreiras e tapete de pregos (blitz)
    radarMovel      = 2,
    vistoria        = 2,  -- vistoria veicular (peças do pista_tuning)
    marcarPlaca     = 2,  -- marcar/desmarcar placa procurada
    mandado         = 3,  -- mandado de busca (pa_casas) e de prisão
    licencas        = 3,  -- emitir licença de caça e porte de arma
    revogarLicenca  = 4,
    liberarPatio    = 4,  -- liberar carro retido no pátio (e sem cobrar)
    cancelarMulta   = 4,
    contratar       = 5,  -- contratar, promover, rebaixar e demitir
    caixa           = 6,  -- ver/sacar/depositar no caixa da LSPD
    codigoPenal     = 6,  -- editar o código penal pelo tablet
}

-- Até qual patente cada um pode promover/contratar (Diretor até Sargento, Chefe até Diretor)
Config.promoverAte = { [5] = 3, [6] = 5 }

-- Valor máximo de UMA multa por patente
Config.tetoMulta = { [0] = 2000, [1] = 10000, [2] = 20000, [3] = 50000, [4] = 100000, [5] = 250000, [6] = 500000 }

-- Para onde vai o dinheiro das multas e taxas (Renewed-Banking). nil = some do jogo
Config.contaSociedade = 'police'

---------------------------------------------------------------------
-- DP DE MISSION ROW (única DP por enquanto)
-- Ajuste as coordenadas com /pospolicia (admin): copia a posição atual.
---------------------------------------------------------------------
Config.dp = {
    nome = 'DP de Mission Row',
    centro = vec3(441.0, -982.0, 30.7),
    raio = 70.0,                                 -- área considerada "dentro da DP" (prisão, pagar multa)
    blip = { sprite = 60, cor = 29, escala = 0.85 },

    servico      = vec3(440.08, -974.92, 30.69), -- bater ponto / pagar multas
    arsenal      = vec3(453.21, -980.03, 30.68),
    armario      = vec3(451.25, -994.28, 30.69), -- armário pessoal (cada policial tem o seu)
    evidencias   = vec3(459.07, -984.07, 30.69), -- depósito de evidências (apreensões)
    laboratorio  = vec3(460.97, -989.18, 24.92), -- análise da perícia
    roupas       = vec3(461.45, -998.05, 30.69), -- vestiário (illenium-appearance)

    garagem = {
        menu = vec4(454.6, -1017.4, 28.4, 90.0),
        vagas = {
            vec4(438.4, -1018.3, 27.7, 90.0),
            vec4(438.4, -1022.0, 27.6, 90.0),
            vec4(438.4, -1025.6, 27.5, 90.0),
            vec4(446.0, -1025.0, 28.3, 0.0),
        },
        guardar = vec3(450.5, -1019.5, 28.4),   -- devolver a viatura (dentro dela, [E])
    },

    -- ponto do pátio de retenção (só o Tenente+ libera)
    patio = vec4(436.68, -1007.42, 27.32, 180.0),
}

-- Arsenal (ox_inventory). grade = patente mínima. price 0 = grátis para o policial
Config.arsenal = {
    { name = 'WEAPON_FLASHLIGHT',   price = 0, grade = 0 },
    { name = 'WEAPON_NIGHTSTICK',   price = 0, grade = 0 },
    { name = 'WEAPON_STUNGUN',      price = 0, grade = 0, metadata = { registered = 'LSPD', serial = 'LSPD' } },
    { name = 'WEAPON_COMBATPISTOL', price = 0, grade = 0, metadata = { registered = 'LSPD', serial = 'LSPD' } },
    { name = 'ammo-9',              price = 0, grade = 0 },
    { name = 'handcuffs',           price = 0, grade = 0 },
    { name = 'radio',               price = 0, grade = 0 },
    { name = 'armour',              price = 0, grade = 0 },
    { name = 'empty_evidence_bag',  price = 0, grade = 1 },
    { name = 'WEAPON_PUMPSHOTGUN',  price = 0, grade = 2, metadata = { registered = 'LSPD', serial = 'LSPD' } },
    { name = 'ammo-shotgun',        price = 0, grade = 2 },
    { name = 'WEAPON_CARBINERIFLE', price = 0, grade = 3, metadata = { registered = 'LSPD', serial = 'LSPD' } },
    { name = 'ammo-rifle',          price = 0, grade = 3 },
}

-- Viaturas por patente mínima
Config.viaturas = {
    { modelo = 'police',  nome = 'Stanier (viatura)',      grade = 0 },
    { modelo = 'police2', nome = 'Buffalo (viatura)',      grade = 0 },
    { modelo = 'police3', nome = 'Interceptor',            grade = 1 },
    { modelo = 'policeb', nome = 'Moto policial',          grade = 1 },
    { modelo = 'police4', nome = 'Descaracterizada',       grade = 3 },
    { modelo = 'policet', nome = 'Transporte de presos',   grade = 2 },
    { modelo = 'fbi2',    nome = 'Granger (Tenente)',      grade = 4 },
}
Config.placaPrefixo = 'LSPD'

---------------------------------------------------------------------
-- CENTRAL DE ALERTAS
---------------------------------------------------------------------
Config.alertas = {
    duracao = 300,          -- segundos que a ocorrência fica no mapa
    tempoAceitar = 20,      -- segundos para apertar a tecla e assumir direto do aviso
    teclaAceitar = 'Y',
    som = true,
    raioPadrao = 120.0,     -- área aproximada quando o script não manda o raio
    maxCards = 4,           -- avisos empilhados na tela ao mesmo tempo
    rota = true,            -- ao assumir, traça a rota no GPS até a área
}

---------------------------------------------------------------------
-- CRIMES QUE AVISAM A POLÍCIA SOZINHOS (testemunha liga para o 190)
-- chance = % de alguém ver e ligar · espera = segundos entre avisos do mesmo jogador
-- raio = tamanho da área no mapa (a polícia não vê o ponto exato)
-- Policial em serviço não gera aviso.
---------------------------------------------------------------------
Config.crimes = {
    tiro = {
        ativo = true, codigo = '10-71', titulo = 'Disparo de arma de fogo', prioridade = 'alta',
        raio = 150.0, chance = 100, espera = 60, sprite = 110,
        silenciadorAvisa = 25,      -- % de chance quando a arma tem silenciador
    },
    tiroVeiculo = {
        ativo = true, codigo = '10-71', titulo = 'Disparo de dentro de veículo', prioridade = 'alta',
        raio = 150.0, chance = 100, espera = 60, sprite = 229,
    },
    rouboVeiculo = {
        ativo = true, codigo = '10-16', titulo = 'Roubo de veículo', prioridade = 'media',
        raio = 120.0, chance = 70, espera = 120, sprite = 225,
    },
    briga = {
        ativo = true, codigo = '10-10', titulo = 'Briga / agressão', prioridade = 'baixa',
        raio = 80.0, chance = 40, espera = 120, sprite = 311,
    },
    atropelamento = {
        ativo = true, codigo = '10-50', titulo = 'Atropelamento', prioridade = 'media',
        raio = 100.0, chance = 60, espera = 90, sprite = 380,
    },
    direcaoPerigosa = {
        ativo = true, codigo = '10-94', titulo = 'Direção perigosa / racha', prioridade = 'baixa',
        raio = 220.0, chance = 20, espera = 300, sprite = 227,
        velocidade = 170,           -- km/h por alguns segundos dentro da cidade
        segundos = 6,
    },
}
-- dois avisos iguais perto um do outro viram um só (gangue atirando junto)
Config.crimesAgrupar = { distancia = 80.0, segundos = 45 }

-- Botão de pânico
Config.panico = {
    tecla = '',             -- deixe '' para usar só o comando /panico (troque em Configurações > Atalhos > FiveM)
    espera = 60,            -- segundos entre um pânico e outro
    avisarSamu = true,      -- se o policial estiver desmaiado, também chama o SAMU (pa_medico)
}

-- 190 no celular (NPWD)
Config.telefone = {
    ativo = true,
    numero = '190',
    espera = 60,
    raio = 80.0,            -- área aproximada de quem ligou
}

---------------------------------------------------------------------
-- ABORDAGEM
---------------------------------------------------------------------
Config.abordagem = {
    itemAlgema = 'handcuffs',
    distancia = 2.5,
    tempoRevista = 4000,
    -- desmaiado só é algemado depois do socorro (pa_medico)
    bloquearDesmaiado = true,
}

-- Itens apreendidos na revista (além de dinheiro sujo e armas sem porte)
Config.ilegais = {
    'black_money',
    -- drogas
    'maconha', 'baseado', 'pacote_maconha', 'muda_maconha',
    'saquinho_coca', 'folha_coca', 'po_catalisador', 'agente_refino', 'galao_solvente',
    'meta', 'meth', 'cokebaggy', 'coke_brick', 'coke_small_brick', 'crack_baggy', 'xtcbaggy', 'oxy', 'joint', 'weed_brick',
    -- roubo
    'joia_roubada', 'relogio_roubado', 'celular_roubado', 'notebook_roubado', 'bilhete_cofre',
    'lockpick', 'advancedlockpick', 'drill',
}

-- Armas que nunca precisam de porte (ferramentas)
Config.armasLivres = {
    WEAPON_FLASHLIGHT = true, WEAPON_KNIFE = true, WEAPON_HATCHET = true, WEAPON_HAMMER = true,
    WEAPON_WRENCH = true, WEAPON_CROWBAR = true, WEAPON_PETROLCAN = true, WEAPON_FIREEXTINGUISHER = true,
    WEAPON_MUSKET = true, WEAPON_SNIPERRIFLE = true, -- armas de caça (pa_caca) - quem não tem licença de caça perde na revista
}
Config.armasCaca = { WEAPON_MUSKET = true, WEAPON_SNIPERRIFLE = true }

---------------------------------------------------------------------
-- LICENÇAS
---------------------------------------------------------------------
Config.licencas = {
    caca = { item = 'licenca_caca', dias = 30, preco = 0 },  -- mesmo formato do pa_caca
    porte = { item = 'porte_arma', dias = 30, preco = 2500 }, -- também liga licences.weapon (lojas do ox)
}

---------------------------------------------------------------------
-- CÓDIGO PENAL (padrão). O Chefe pode editar pelo tablet (fica salvo no banco).
-- meses = tempo de pena. Config.prisao.minutosPorMes converte em tempo real.
---------------------------------------------------------------------
Config.codigoPenal = {
    { id = 'A1',  titulo = 'Desacato a autoridade',             multa = 1500,  meses = 5 },
    { id = 'A2',  titulo = 'Resistência à prisão',              multa = 3000,  meses = 10 },
    { id = 'A3',  titulo = 'Fuga da abordagem',                 multa = 4000,  meses = 10 },
    { id = 'A4',  titulo = 'Falsa identidade',                  multa = 2000,  meses = 5 },
    { id = 'T1',  titulo = 'Excesso de velocidade',             multa = 800,   meses = 0 },
    { id = 'T2',  titulo = 'Direção perigosa / racha',          multa = 3000,  meses = 5 },
    { id = 'T3',  titulo = 'Veículo com peças irregulares',     multa = 2500,  meses = 0 },
    { id = 'T4',  titulo = 'Dirigir sem habilitação',           multa = 1500,  meses = 0 },
    { id = 'P1',  titulo = 'Porte ilegal de arma',              multa = 8000,  meses = 20 },
    { id = 'P2',  titulo = 'Disparo em via pública',            multa = 5000,  meses = 10 },
    { id = 'D1',  titulo = 'Posse de drogas (consumo)',         multa = 2000,  meses = 5 },
    { id = 'D2',  titulo = 'Tráfico de drogas',                 multa = 12000, meses = 30 },
    { id = 'D3',  titulo = 'Posse de dinheiro sujo',            multa = 6000,  meses = 15 },
    { id = 'R1',  titulo = 'Roubo a pessoa',                    multa = 5000,  meses = 15 },
    { id = 'R2',  titulo = 'Roubo de veículo',                  multa = 6000,  meses = 15 },
    { id = 'R3',  titulo = 'Roubo a loja / caixa eletrônico',   multa = 8000,  meses = 20 },
    { id = 'R4',  titulo = 'Roubo a banco (Fleeca)',            multa = 20000, meses = 40 },
    { id = 'R5',  titulo = 'Invasão de domicílio',              multa = 6000,  meses = 15 },
    { id = 'V1',  titulo = 'Lesão corporal',                    multa = 4000,  meses = 10 },
    { id = 'V2',  titulo = 'Tentativa de homicídio',            multa = 15000, meses = 35 },
    { id = 'V3',  titulo = 'Homicídio',                         multa = 25000, meses = 50 },
    { id = 'V4',  titulo = 'Agressão a policial',               multa = 10000, meses = 25 },
    { id = 'V5',  titulo = 'Sequestro',                         multa = 15000, meses = 35 },
}

---------------------------------------------------------------------
-- MANDADOS
---------------------------------------------------------------------
Config.mandados = {
    validadeBusca = 7200,           -- segundos (igual ao pa_casas)
    validadePrisao = 7 * 86400,     -- mandado de prisão vale 7 dias
}

---------------------------------------------------------------------
-- PRISÃO (Bolingbroke)
---------------------------------------------------------------------
Config.prisao = {
    minutosPorMes = 1.0,            -- 1 mês de pena = 1 minuto on-line
    maxMeses = 120,
    exigirNaDP = true,              -- o policial e o preso precisam estar na DP para aplicar a pena
    centro = vec3(1690.0, 2600.0, 45.5),
    raio = 210.0,                   -- saiu desse raio com pena = fuga
    entrada = {                     -- onde o preso aparece
        vec4(1761.37, 2540.88, 45.57, 270.0),
        vec4(1758.65, 2504.80, 45.57, 30.0),
        vec4(1688.32, 2520.43, 45.56, 90.0),
    },
    saida = vec4(1848.13, 2585.96, 45.67, 270.0),
    -- trabalhos que reduzem a pena
    trabalho = {
        reduzMeses = 1,             -- cada tarefa tira 1 mês
        tempo = 12000,
        pontos = {
            { coords = vec3(1761.5, 2540.4, 45.6), label = 'Consertar painel elétrico', anim = { 'mini@repair', 'fixing_a_ped' } },
            { coords = vec3(1718.5, 2527.8, 45.6), label = 'Varrer o pátio',          anim = { 'amb@world_human_janitor@male@idle_a', 'idle_a' } },
            { coords = vec3(1700.2, 2474.5, 45.6), label = 'Varrer o pátio',          anim = { 'amb@world_human_janitor@male@idle_a', 'idle_a' } },
            { coords = vec3(1629.2, 2564.2, 45.6), label = 'Cuidar da horta',         anim = { 'amb@world_human_gardener_plant@male@idle_a', 'idle_a' } },
            { coords = vec3(1652.3, 2564.3, 45.6), label = 'Consertar painel elétrico', anim = { 'mini@repair', 'fixing_a_ped' } },
        },
    },
    fuga = { alerta = true, mandadoAutomatico = true },
}

---------------------------------------------------------------------
-- FISCALIZAÇÃO VEICULAR
---------------------------------------------------------------------
-- Objetos de blitz (menu /blitz ou F6 > Blitz)
Config.objetos = {
    limitePorPolicial = 12,
    lista = {
        { id = 'cone',     label = 'Cone',             modelo = `prop_roadcone02a`,        congelar = false },
        { id = 'barreira', label = 'Barreira',         modelo = `prop_barrier_work06a`,    congelar = true },
        { id = 'placa',    label = 'Placa de blitz',   modelo = `prop_snow_sign_road_06g`, congelar = true },
        { id = 'luz',      label = 'Iluminação',       modelo = `prop_worklight_03b`,      congelar = true },
        { id = 'tapete',   label = 'Tapete de pregos', modelo = `p_ld_stinger_s`,          congelar = true, tapete = true },
    },
}

-- Vistoria: lê a preparação do carro no pista_tuning.
-- slot = peça do pista_tuning. acima = só é irregular quando o valor passa disso (chip/cabeçote).
-- exigeLaudo = regular se o carro tiver laudo do dinamômetro recente (pa_dinamometro).
Config.vistoria = {
    laudoDias = 15,                 -- laudo do dinamômetro vale como vistoria por X dias
    distancia = 4.0,
    regras = {
        { slot = 'nitro',    label = 'Kit de nitro (proibido na rua)', multa = 5000, apreender = true },
        { slot = 'chip',     acima = 2, label = 'Chip acima do Stage 2',  multa = 4000, apreender = true },
        { slot = 'chip',     acima = 0, exigeLaudo = true, label = 'Chip sem laudo do dinamômetro', multa = 1500 },
        { slot = 'remap',    exigeLaudo = true, label = 'Remap sem laudo do dinamômetro', multa = 1500 },
        { slot = 'cabecote', acima = 1, exigeLaudo = true, label = 'Cabeçote de corrida sem laudo', multa = 2000 },
        { slot = 'pistao',   igual = 'forjado', exigeLaudo = true, label = 'Motor forjado sem laudo', multa = 2000 },
        -- pa_roubocarro: carro comprado com chassi riscado
        { slot = 'chassi_riscado', label = 'Chassi raspado (veículo de roubo)', multa = 8000, apreender = true },
    },
}

-- Radares fixos: limite em km/h. tolerancia = km/h acima do limite sem multar
Config.radares = {
    ativo = true,
    tolerancia = 7,
    raio = 22.0,
    multas = {                      -- por km/h acima do limite (maior faixa que couber)
        { ate = 20,  valor = 400 },
        { ate = 50,  valor = 900 },
        { ate = 999, valor = 2000 },
    },
    locais = {
        { coords = vec3(-623.4, -823.1, 25.3),  limite = 60 },
        { coords = vec3(406.9, -969.1, 29.4),   limite = 60 },
        { coords = vec3(-106.3, -1127.6, 25.8), limite = 60 },
        { coords = vec3(-823.4, -1147.0, 8.0),  limite = 60 },
        { coords = vec3(657.3, -218.8, 44.1),   limite = 100 },
        { coords = vec3(1623.0, 1069.0, 80.9),  limite = 110 },
        { coords = vec3(2136.7, -591.8, 94.3),  limite = 110 },
        { coords = vec3(-2604.9, 2996.3, 27.5), limite = 110 },
        { coords = vec3(2118.3, 6040.0, 50.9),  limite = 110 },
    },
    blip = false,                   -- mostrar os radares no mapa
}

-- Radar móvel na viatura (/radar)
Config.radarMovel = {
    distancia = 80.0,   -- alcance (m) para frente e para trás
}

-- Pátio
Config.patio = {
    taxa = 1500,                    -- cobrada na retirada (pátio de Impound Lot do qbx_garages)
    garagemDepot = 'impoundlot',    -- garagem DEPOT do qbx_garages onde o dono retira pagando
    garagemRetido = 'pa_patio_lspd',-- carros retidos (só sai quando um Tenente+ libera)
    -- Com mecânico em serviço, o carro espera o guincho (pista_guincho) levar até o pátio.
    -- Sem mecânico (ou depois do tempo), o carro vai sozinho.
    esperarGuincho = true,
    jobMecanico = 'mechanic',
    tempoGuincho = 900,             -- segundos esperando o guincho
    raioEntrega = 25.0,             -- distância do ponto do pátio para o guincho entregar
}

---------------------------------------------------------------------
-- PERÍCIA
---------------------------------------------------------------------
Config.pericia = {
    itemVazio = 'empty_evidence_bag',
    itemCheio = 'filled_evidence_bag',
    duracao = 3600,                 -- segundos que a evidência fica no chão
    -- evidências só aparecem no facho da lanterna (lanterna na mão mirando ou lanterna da arma ligada)
    distanciaVer = 15.0,            -- alcance da lanterna
    anguloLanterna = 22.0,          -- abertura do facho (graus)
    -- cápsulas: armas que não deixam cápsula
    semCapsula = {
        WEAPON_STUNGUN = true, WEAPON_PETROLCAN = true, WEAPON_FIREEXTINGUISHER = true, WEAPON_FLARE = true,
        WEAPON_SNOWBALL = true, WEAPON_BALL = true, WEAPON_FLAREGUN = true,
    },
    chanceSangue = 70,              -- % de deixar sangue quando leva tiro/facada
    testePolvora = 900,             -- segundos que a pólvora fica na mão
    -- mãos sem luva (componente 3 - braços). Se a luva for outro número, adicione aqui.
    semLuva = {
        male = { [0] = true, [1] = true, [2] = true, [4] = true, [5] = true, [6] = true, [8] = true, [11] = true,
                 [12] = true, [14] = true, [15] = true, [112] = true, [113] = true, [114] = true, [118] = true,
                 [125] = true, [132] = true },
        female = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true,
                   [9] = true, [11] = true, [12] = true, [14] = true, [15] = true, [129] = true, [130] = true,
                   [131] = true, [135] = true, [142] = true, [149] = true, [153] = true, [157] = true, [161] = true, [165] = true },
    },
    digitaisPorCarro = 3,           -- quantas digitais diferentes ficam no volante
}

---------------------------------------------------------------------
-- TECLAS / COMANDOS
---------------------------------------------------------------------
Config.teclas = {
    menu = 'F6',                    -- menu rápido do policial
    tablet = 'F5',                  -- tablet (MDT)
}
