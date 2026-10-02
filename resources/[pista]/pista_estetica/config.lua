Config = {}

---------------------------------------------------------------------
-- QUEM OPERA
---------------------------------------------------------------------
-- O mecânico em serviço opera a cabine/oficina e cobra o cliente no fim.
Config.job = 'mechanic'
Config.precisaServico = true

---------------------------------------------------------------------
-- LOCAIS
---------------------------------------------------------------------
-- tipo = 'pintura'  -> cabine de pintura (só cores)
-- tipo = 'estetica' -> oficina de estética (peças, rodas, neon, insulfilm...)
-- coords = onde o carro fica (pare o carro, use /pegarcoords dentro dele e cole aqui)
-- raio   = distância do centro em que o carro conta como "dentro"
Config.locais = {
    { tipo = 'pintura',  label = 'Cabine de pintura 1', coords = vec4(-325.74, -144.02, 38.01, 156.3), raio = 3.5 },
    { tipo = 'pintura',  label = 'Cabine de pintura 2', coords = vec4(-332.88, -142.54, 38.01, 246.9), raio = 3.5 },
    { tipo = 'estetica', label = 'Estética Pista & Asfalto', coords = vec4(-340.79, -117.88, 38.01, 71.2), raio = 4.0 },
}

-- Blip no mapa para cada local
Config.blips = {
    pintura  = { sprite = 72, cor = 47, escala = 0.7, label = 'Cabine de pintura' },
    estetica = { sprite = 72, cor = 5,  escala = 0.7, label = 'Estética automotiva' },
}

---------------------------------------------------------------------
-- COBRANÇA
---------------------------------------------------------------------
Config.distanciaCliente = 15.0   -- o cliente precisa estar perto para ser cobrado
Config.tempoResposta = 30        -- segundos para o cliente aceitar a cobrança
-- Quem recebe o dinheiro: o mecânico que fez o serviço (na conta 'bank' ou 'cash')
Config.recebimento = { conta = 'bank' }

-- Preço de cada item mudado (agora tudo $1 para teste)
Config.precos = {
    pint = 1,        -- cada cor pintada (principal, secundária, perolado, rodas, interior, painel)
    mod = 1,         -- cada peça de lataria/interior/motor trocada
    roda = 1,        -- tipo, modelo e pneu
    fumaca = 1,
    neon = 1,
    xenon = 1,
    insulfilm = 1,
    placa = 1,
    adesivo = 1,
    extra = 1,
    buzina = 1,
}

---------------------------------------------------------------------
-- TEMPOS (ms)
---------------------------------------------------------------------
Config.tempos = {
    pintura = 15000,   -- a cabine pintando depois de pago
    estetica = 10000,  -- montando as peças depois de pago
}
