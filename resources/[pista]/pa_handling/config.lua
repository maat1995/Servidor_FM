Config = {}

---------------------------------------------------------------------
-- HANDLING REALISTA
---------------------------------------------------------------------
-- Cada carro tem uma ficha com os dados do carro real em que foi inspirado
-- (data/nativos.lua para os nativos do GTA, Config.fichas abaixo para addons).
-- O script transforma a ficha em handling e aplica para TODOS os carros do
-- mesmo modelo, antes de qualquer preparação. As peças do pista_tuning
-- (chip, turbo, pistão...) continuam somando em cima desse valor de fábrica.
--
-- A calibração (/calibrar) mede cada carro no jogo (0-100 e velocidade final)
-- e corrige sozinha até bater com a ficha. O resultado fica em
-- data/calibracao.json e vale para todo mundo.

Config.ativo = true
Config.debug = false

-- Escala geral. 1.0 = igual ao carro real.
-- Ex.: escalaVelocidade 0.85 deixa todo carro com 85% da velocidade final real
-- (bom se o mapa ficar pequeno para os supercarros de 400 km/h).
Config.escalaVelocidade = 1.0
Config.escalaAceleracao = 1.0 -- 1.1 = 0-100 10% mais rápido para todos

-- Aplica o peso real (fMass). Afeta batidas e empurrões entre carros.
Config.aplicarPeso = true
-- Aplica a quantidade de marchas da ficha (o câmbio manual usa essas marchas)
Config.aplicarMarchas = true
Config.maxMarchas = 6 -- limite do GTA nas builds mais antigas; suba se o seu servidor aceitar mais

---------------------------------------------------------------------
-- PNEU E FREIO POR FAIXA
---------------------------------------------------------------------
-- aderencia = fTractionCurveMax | aderenciaMin = fTractionCurveMin (derrapando)
-- freio = fBrakeForce
-- Um popular com pneu de supercarro não existe: cada ficha diz a faixa.
Config.pneus = {
    popular   = { aderencia = 1.95, aderenciaMin = 1.75, freio = 0.55 },
    classico  = { aderencia = 1.90, aderenciaMin = 1.68, freio = 0.45 },
    van       = { aderencia = 1.80, aderenciaMin = 1.62, freio = 0.45 },
    offroad   = { aderencia = 1.92, aderenciaMin = 1.72, freio = 0.50 },
    suv       = { aderencia = 2.00, aderenciaMin = 1.80, freio = 0.60 },
    medio     = { aderencia = 2.10, aderenciaMin = 1.88, freio = 0.65 },
    muscle    = { aderencia = 2.05, aderenciaMin = 1.80, freio = 0.65 },
    esportivo = { aderencia = 2.32, aderenciaMin = 2.06, freio = 0.85 },
    super     = { aderencia = 2.55, aderenciaMin = 2.30, freio = 1.00 },
}

---------------------------------------------------------------------
-- FICHAS DOS ADDONS (e para corrigir qualquer nativo)
---------------------------------------------------------------------
-- A chave é o nome do modelo (o mesmo do spawn).
-- handling = o handlingName do handling.meta do carro (se for diferente do modelo).
-- Campos: real, cv, kg, tracao ('D', 'T' ou '4x4'), marchas, zero100 (s),
--         vmax (km/h), pneu (uma das faixas acima).
-- Se o carro não chega a 100 km/h direito, use zero60 no lugar de zero100.
--
-- Uma ficha aqui com o mesmo modelo de um nativo substitui a do nativo.
Config.fichas = {
    -- Exemplos para quando os carros brasileiros chegarem:
    -- ['gol'] = { real = 'Volkswagen Gol 1.0 (G5)', cv = 76, kg = 940, tracao = 'D', marchas = 5, zero100 = 13.5, vmax = 166, pneu = 'popular' },
    -- ['onix'] = { real = 'Chevrolet Onix 1.0 Turbo', cv = 116, kg = 1090, tracao = 'D', marchas = 6, zero100 = 9.8, vmax = 190, pneu = 'popular' },
    -- ['civic'] = { handling = 'CIVICSI', real = 'Honda Civic Si', cv = 208, kg = 1300, tracao = 'D', marchas = 6, zero100 = 6.9, vmax = 220, pneu = 'medio' },
}

-- Modelos que o script nunca mexe (deixa a handling original do arquivo)
Config.ignorar = {
    -- 'meu_carro_de_evento',
}

---------------------------------------------------------------------
-- CALIBRAÇÃO AUTOMÁTICA
---------------------------------------------------------------------
-- Só quem tem a permissão ACE abaixo usa os comandos:
--   add_ace group.admin pa_handling.admin allow
Config.permissao = 'pa_handling.admin'

Config.calibracao = {
    -- Precisa de uma reta plana. Fique parado no começo da reta, olhando para
    -- onde o carro deve andar, e use /calibrar. O carro volta para o começo
    -- sozinho quando chega no fim, então basta uma reta de uns 400 m
    -- (a pista do aeroporto LSIA é perfeita).
    distancia = 400.0,       -- m andados antes de voltar ao começo da reta
    tempoMax = 75,           -- s no máximo por medição
    tentativas = 4,          -- medições por carro até acertar
    toleranciaTempo = 0.06,  -- 6% de diferença no 0-100 está bom
    toleranciaVel = 0.04,    -- 4% na velocidade final
    bucket = 4100,           -- mundo separado durante a calibração (sem trânsito)
}

-- Chute inicial antes de calibrar (o próprio /calibrar ajusta esses números):
--   fInitialDriveForce ~= kForca / 0-100
--   fInitialDriveMaxFlatVel ~= kVel * velocidade final (km/h)
Config.kForca = 1.0
Config.kVel = 0.833
