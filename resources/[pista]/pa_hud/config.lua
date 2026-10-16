Config = {}

-- Comando que abre as opções da HUD (o jogador ajusta e fica salvo no PC dele)
Config.comando = 'hud'

-- Padrões das opções (cada jogador pode mudar no /hud)
Config.padrao = {
    unidade = 'kmh',        -- 'kmh' ou 'mph'
    escala = 100,           -- tamanho em % (70 a 130)
    bussola = true,         -- bússola e nome da rua no topo
    esconderCheio = true,   -- fome, sede e colete somem quando estão cheios
    oculto = false,         -- modo cinema (esconde tudo)
}

-- Minimapa a pé (false = só aparece dentro do veículo)
Config.radarAPe = false

-- Atualização da HUD em ms
Config.intervalo = { carro = 60, ape = 250 }

-- Status
Config.limiteCheio = 95     -- acima disso conta como "cheio"
Config.alertaStatus = 25    -- abaixo disso a barra pisca em vermelho

-- Velocímetro
Config.rpmVermelho = 0.85   -- onde começa a faixa vermelha do conta-giros (0 a 1)
Config.turboPadraoBar = 1.0 -- pressão máxima do turbo sem remap (com remap usa a do notebook)
Config.nitroCarga = 100.0   -- igual ao Config.nitro.cargaGarrafa do pista_tuning
Config.temperatura = {
    atencao = 100.0,        -- °C: fica laranja
    perigo = 110.0,         -- °C: fica vermelho
}
Config.motorAlerta = 30     -- vida do motor em % que acende o alerta

-- Aviso de XP do pista_skills na tela
Config.xpNaTela = true
Config.nomesArvore = {
    mecanica = 'Mecânica',
}

-- Componentes nativos do GTA escondidos (a HUD mostra no lugar)
-- 1 procurado, 3 e 4 dinheiro, 6 nome do veículo, 7 bairro, 8 classe do veículo, 9 rua, 13 troco
Config.esconderNativos = { 1, 3, 4, 6, 7, 8, 9, 13 }

-- Estresse (veio do qbx_hud). Comida/bebida/cigarro continuam usando hud:server:RelieveStress
Config.estresse = {
    ativo = true,
    policiaSemEstresse = true,     -- polícia (job type leo) não ganha estresse
    chanceTiro = 0.1,              -- chance de ganhar estresse a cada tiro (0 a 1)
    velocidade = false,            -- ex.: { semCinto = 140, comCinto = 220 } em km/h; false = não ganha correndo
    minimoEfeito = 50,             -- a partir daqui a tela começa a embaçar
    armasSemEstresse = { 'weapon_petrolcan', 'weapon_hazardcan', 'weapon_fireextinguisher' },
    embacar = {
        { min = 50, max = 60, tempo = 1500 },
        { min = 60, max = 70, tempo = 2000 },
        { min = 70, max = 80, tempo = 2500 },
        { min = 80, max = 90, tempo = 2700 },
        { min = 90, max = 100, tempo = 3000 },
    },
    intervalo = {
        { min = 50, max = 60, tempo = 55000 },
        { min = 60, max = 70, tempo = 45000 },
        { min = 70, max = 80, tempo = 35000 },
        { min = 80, max = 90, tempo = 25000 },
        { min = 90, max = 100, tempo = 17000 },
    },
}
