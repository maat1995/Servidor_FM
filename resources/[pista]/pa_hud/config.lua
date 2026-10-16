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
