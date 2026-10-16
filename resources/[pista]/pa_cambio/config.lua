Config = {}

---------------------------------------------------------------------
-- CÂMBIO MANUAL
---------------------------------------------------------------------
-- Todo carro sai de fábrica MANUAL. Quem quiser automático leva na oficina:
-- o mecânico instala a peça "Câmbio automático" (item cambio_automatico,
-- pista_tuning) e pode tirar depois, voltando para o manual.
--
-- Como dirigir:
--   * O carro liga sempre em NEUTRO (N). Desligou ou saiu do carro, volta para N.
--   * Shift sobe a marcha e Ctrl desce. N -> Shift = 1ª | N -> Ctrl = ré (R).
--   * Em N o motor acelera mas o carro não anda.
--   * Na ré, segure S (igual ao GTA) para andar de ré.
--   * Quantidade de marchas = a do carro (handling).
-- O jogador pode trocar as teclas em Configurações > Atalhos > FiveM.

Config.ativo = true

Config.teclas = {
    subir = 'LSHIFT',
    descer = 'LCONTROL',
    -- Controle (joystick): setas do direcional. Enquanto dirige manual no controle,
    -- a troca de rádio no direcional fica desligada. false = sem atalho no controle.
    controle = { subir = 'LRIGHT_INDEX', descer = 'LLEFT_INDEX' },
}

-- Corte de aceleração durante a troca (ms). Dá a sensação de pisar na embreagem.
Config.tempoTroca = 180

-- Limitador de giro: no corte o carro "bate" no limitador por esse tempo (ms)
Config.limitador = { rpm = 0.985, corte = 90 }

-- Não deixa reduzir se o giro for passar do limite (o carro aprende a velocidade
-- máxima de cada marcha enquanto você dirige). false = deixa reduzir sempre.
Config.protegerReducao = true

-- Motor morre se tentar sair parado com marcha alta (acima de marchaMaxSaida).
-- Começa desligado para não ficar chato no teclado.
Config.morrerSaidaAlta = false
Config.marchaMaxSaida = 2

---------------------------------------------------------------------
-- QUEM CONTINUA AUTOMÁTICO
---------------------------------------------------------------------
-- Classes do GTA que nunca são manuais
-- 13 bicicleta | 14 barco | 15 helicóptero | 16 avião | 18 emergência | 21 trem
Config.classesAutomaticas = { [13] = true, [14] = true, [15] = true, [16] = true, [18] = true, [21] = true }

-- Modelos que saem automáticos (carros de emprego, guincho, etc.)
Config.modelosAutomaticos = {
    'flatbed', 'towtruck', 'towtruck2', 'taxi', 'bus', 'coach', 'trash', 'trash2',
    'boxville', 'boxville2', 'mule', 'mule2', 'pounder', 'stockade', 'rumpo', 'burrito3',
}

-- Quem está em serviço nesses empregos dirige qualquer carro como automático
-- (assim ninguém atrapalha o trabalho da polícia e do resgate)
Config.empregosAutomaticos = { police = true, ambulance = true }

-- Outros scripts podem deixar um carro automático com:
-- Entity(veh).state:set('pa_cambio_auto', true, true)
