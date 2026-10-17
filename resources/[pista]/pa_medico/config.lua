Config = {}

---------------------------------------------------------------------
-- DESMAIO
---------------------------------------------------------------------
-- Quando o jogador cai (qbx_medical: caído ou morto) começa a contar o tempo.
-- Enquanto o tempo corre ele pode chamar o SAMU (tecla G ou 192 no celular).
-- Quando o tempo acaba ele pode segurar E para acordar no hospital,
-- PERDENDO TUDO (inventário limpo pelo qbx_ambulancejob) e pagando a internação.
-- Se ele não apertar nada continua desmaiado: um médico ainda pode chegar e reanimar.

Config.tempoDesmaiado = 300          -- segundos até liberar o "acordar no hospital"
Config.segurarHospital = 3           -- segundos segurando E para acordar no hospital

Config.teclas = {
    chamar = 47,    -- G  (INPUT_DETONATE)
    hospital = 38,  -- E  (INPUT_PICKUP)
}

-- Tempo mínimo entre um chamado e outro do mesmo jogador (segundos)
Config.esperaEntreChamados = 60

---------------------------------------------------------------------
-- MÉDICOS (jogadores)
---------------------------------------------------------------------
Config.tipoEmprego = 'ems'           -- tipo do emprego (qbx_core) que recebe os chamados; só quem está em serviço

Config.alerta = {
    -- Localização parcial: o médico vê uma ÁREA no mapa, não o ponto exato.
    -- O centro da área fica deslocado até "imprecisao" metros do corpo,
    -- então o corpo está sempre dentro do círculo, mas em lugar incerto.
    raio = 120.0,
    imprecisao = 80.0,
    duracao = 300,           -- segundos que o chamado fica no mapa (some antes se o paciente acordar)
    tempoAceitar = 20,       -- segundos para apertar Y e assumir o chamado direto do aviso
    teclaAceitar = 'Y',
    som = true,
}

---------------------------------------------------------------------
-- CELULAR (NPWD)
---------------------------------------------------------------------
-- O jogador liga para o número abaixo no app de telefone.
--  * Se quem liga está desmaiado: é o mesmo que apertar G.
--  * Se quem liga está bem: o chamado vai para a posição dele (ex.: amigo caído do lado).
--    Sem médico em serviço, a ambulância NPC vai até alguém desmaiado perto de quem ligou.
Config.telefone = {
    ativo = true,
    numero = '192',
    nomeContato = 'SAMU',
    raioProcurarCaido = 25.0,   -- metros em volta de quem ligou para achar alguém desmaiado
}

---------------------------------------------------------------------
-- AMBULÂNCIA NPC (só quando não tem médico em serviço)
---------------------------------------------------------------------
Config.npc = {
    ativo = true,
    preco = 500,                -- cobrado de quem foi reanimado (banco, depois dinheiro). 0 = grátis
    reanimarSemSaldo = true,    -- true: reanima mesmo sem dinheiro (fica devendo no RP)
    veiculo = 'ambulance',
    socorrista = 's_m_m_paramedic_01',
    distanciaSaida = 180.0,     -- a ambulância nasce numa rua a essa distância
    tempoMaxViagem = 90,        -- se não chegar nesse tempo, aparece perto do corpo
    tempoRCP = 10,              -- segundos de massagem cardíaca antes de reanimar
    distanciaRCP = 0.55,        -- distância do socorrista até o peito (ajuste se ficar longe ou dentro do corpo)
    sirene = true,
}

---------------------------------------------------------------------
-- ATENDIMENTO DO MÉDICO (olho no paciente > "Atender paciente")
---------------------------------------------------------------------
-- A ficha mostra estado, vida, sangramento e ferimentos de cada parte do corpo.
-- Ferimentos: 1 Leve, 2 Moderado, 3 Grave, 4 Crítico (qbx_medical).
--  * NA RUA precisa de itens e só trata ferimentos leves/moderados.
--  * NO HOSPITAL não gasta item e cura tudo (inclusive grave/crítico).
-- Vida em % (0 = quase morrendo, 100 = cheia).

Config.atendimento = {
    distancia = 3.0,        -- distância máxima do paciente
    itens = {
        desfibrilador = 'desfibrilador',  -- não gasta; precisa ter para reanimar na rua
        adrenalina = 'adrenalina',        -- gasta 1 por reanimação na rua
        bandagem = 'bandage',             -- gasta 1; estanca o sangramento
        trauma = 'kit_trauma',            -- gasta 1; tratamento na rua
    },

    reanimar = { duracao = 10, vida = 25 },          -- acorda com 25% de vida
    bandagem = { duracao = 5, vida = 10, sangramento = 1 },  -- +10% e tira 1 nível de sangramento
    trauma = { duracao = 12, vida = 100 },            -- vida até 100%, ferimentos leves/moderados e sangramento leve

    hospital = {
        locais = {  -- mesmos hospitais do qbx_ambulancejob
            { nome = 'Pillbox', coords = vec3(326.0, -585.0, 43.3), raio = 60.0 },
            { nome = 'Paleto', coords = vec3(-250.0, 6318.0, 32.4), raio = 40.0 },
        },
        reanimar = { duracao = 8, vida = 50 },
        tratamento = { duracao = 15 },   -- cura tudo e vida 100%
        preco = 0,                       -- cobrado do paciente no tratamento do hospital (0 = grátis)
    },
}

---------------------------------------------------------------------
-- TEXTOS
---------------------------------------------------------------------
Config.textos = {
    desmaiado = 'DESMAIADO',
    chamar = 'Chamar o SAMU',
    chamado = 'SAMU chamado. Aguarde.',
    medicoACaminho = 'Médico a caminho: %s',
    ambulanciaNpc = 'Ambulância a caminho',
    ambulanciaChegou = 'Socorrista fazendo o atendimento',
    acordarHospital = 'Segure para acordar no hospital (perde tudo)',
    aguardarTempo = 'Acordar no hospital libera em',
    esperaChamado = 'Espere %s s para chamar de novo.',
    semEquipe = 'Nenhuma equipe disponível no momento.',
    alertaTitulo = 'SAMU · Pessoa desmaiada',
    alertaTelefone = 'SAMU · Chamado por telefone',
    alertaAceitar = 'Aperte [%s] para assumir (%s s)',
    assumido = 'Chamado #%s assumido por %s',
    voceAssumiu = 'Você assumiu o chamado #%s. GPS marcado na área.',
    pacienteAcordou = 'Chamado #%s encerrado: o paciente foi atendido.',
    cobradoNpc = 'Atendimento do SAMU: $%s',
    semDinheiroNpc = 'Atendimento do SAMU sem pagamento (sem saldo).',
}
