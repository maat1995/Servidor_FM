Config = {}

---------------------------------------------------------------------
-- TELA
---------------------------------------------------------------------
Config.comando = 'skills'   -- /skills abre a tela
Config.tecla = 'F7'         -- o jogador pode trocar em Configurações > Atalhos > FiveM

---------------------------------------------------------------------
-- ÁRVORES DE HABILIDADE
---------------------------------------------------------------------
-- Cada árvore tem seus níveis, pontos e habilidades. Hoje só existe a de
-- Mecânica; Corrida e Crime aparecem na tela como "em breve".
--
-- niveis           = XP total necessário para cada nível (o nível 1 começa em 0)
-- pontosPorNivel   = pontos ganhos a cada nível
-- pontosExtras     = pontos a mais em níveis especiais
-- profissao        = quem tem esse emprego/cargo, em serviço, já sabe TODAS as habilidades
-- limiteDiario     = XP máximo por dia nessa árvore (0 = sem limite). Manuais não contam.
--
-- Habilidades:
-- id, ramo, label, desc   = o que aparece na tela
-- nivel                   = nível mínimo para aprender
-- custo                   = pontos gastos
-- requer                  = habilidades que precisam ser aprendidas antes
-- efeito                  = só nas passivas: multiplicador aplicado (0.7 = 30% a menos)
Config.arvores = {
    mecanica = {
        label = 'Mecânica',
        icone = 'chave',
        descricao = 'Prepare o próprio carro em casa, sem depender da oficina.',
        niveis = { 0, 500, 1200, 2200, 3500, 5200, 7500, 10500, 14500, 20000 },
        pontosPorNivel = 1,
        pontosExtras = { [5] = 1, [10] = 1 },
        profissao = { job = 'mechanic', gradeMinimo = 3, emServico = true },
        limiteDiario = 1500,

        ramos = {
            { id = 'motor',      label = 'Motor',      icone = 'engrenagens',          cor = '#f1c232' },
            { id = 'chassi',     label = 'Chassi',     icone = 'carro',      cor = '#58a6ff' },
            { id = 'eletronica', label = 'Eletrônica', icone = 'chip',      cor = '#bc8cff' },
            { id = 'passivas',   label = 'Passivas',   icone = 'estrela',           cor = '#3fb950' },
        },

        habilidades = {
            -- Base (raiz de tudo)
            { id = 'fundamentos', ramo = 'base', label = 'Fundamentos', icone = 'ferramentas',
              desc = 'Ver a preparação dos carros, tirar peças externas e ganhar XP com consertos (pneu, funilaria, kit de emergência).',
              nivel = 1, custo = 1 },

            -- Motor
            { id = 'intercooler', ramo = 'motor', label = 'Intercooler', icone = 'vento',
              desc = 'Instalar e trocar intercooler.',
              nivel = 3, custo = 1, requer = { 'fundamentos' } },
            { id = 'turbo', ramo = 'motor', label = 'Turbo', icone = 'turbina',
              desc = 'Instalar e trocar turbo.',
              nivel = 4, custo = 1, requer = { 'intercooler' } },
            { id = 'motor_bancada', ramo = 'motor', label = 'Motor na bancada', icone = 'motor',
              desc = 'Tirar e recolocar o motor, abrir na bancada, retificar, pistão taxado, junta e cabeçote retrabalhado.',
              nivel = 5, custo = 2, requer = { 'turbo' } },
            { id = 'motor_forjado', ramo = 'motor', label = 'Motor forjado', icone = 'martelo',
              desc = 'Pistão forjado, bielas forjadas e cabeçote de corrida.',
              nivel = 7, custo = 2, requer = { 'motor_bancada' } },

            -- Chassi
            { id = 'freios', ramo = 'chassi', label = 'Freios', icone = 'freio',
              desc = 'Usar o elevador e instalar kits de freio roda por roda.',
              nivel = 2, custo = 1, requer = { 'fundamentos' } },
            { id = 'cambio', ramo = 'chassi', label = 'Transmissão', icone = 'engrenagem',
              desc = 'Instalar e trocar a transmissão.',
              nivel = 4, custo = 1, requer = { 'freios' } },
            { id = 'suspensao', ramo = 'chassi', label = 'Suspensão regulável', icone = 'suspensao',
              desc = 'Instalar o kit de suspensão regulável no elevador.',
              nivel = 6, custo = 1, requer = { 'cambio' } },
            { id = 'suspensao_ajuste', ramo = 'chassi', label = 'Ajuste fino', icone = 'ajuste',
              desc = 'Regular cada item da suspensão no painel. Sem ela, o dono só escolhe os presets (Rua, Pista, Drift, Stance).',
              nivel = 8, custo = 1, requer = { 'suspensao' } },

            -- Eletrônica
            { id = 'chip1', ramo = 'eletronica', label = 'Chip Stage 1', icone = 'chip',
              desc = 'Instalar o Chip Stage 1 e usar o notebook de remap.',
              nivel = 3, custo = 1, requer = { 'fundamentos' } },
            { id = 'nitro', ramo = 'eletronica', label = 'Nitro', icone = 'chama',
              desc = 'Instalar o kit de nitro.',
              nivel = 5, custo = 1, requer = { 'chip1' } },
            { id = 'remap', ramo = 'eletronica', label = 'Remap avançado', icone = 'notebook',
              desc = 'Instalar o Chip Stage 2 e Stage 3.',
              nivel = 8, custo = 2, requer = { 'nitro' } },

            -- Passivas
            { id = 'mao_leve', ramo = 'passivas', label = 'Mão leve', icone = 'mao',
              desc = 'Ferramentas desgastam 30% menos.',
              nivel = 2, custo = 1, requer = { 'fundamentos' }, efeito = { desgaste = 0.7 } },
            { id = 'agilidade', ramo = 'passivas', label = 'Agilidade', icone = 'raio',
              desc = 'Serviços ficam 25% mais rápidos.',
              nivel = 4, custo = 1, requer = { 'fundamentos' }, efeito = { tempo = 0.75 } },
            { id = 'precisao', ramo = 'passivas', label = 'Precisão', icone = 'mira',
              desc = 'Chance de errar a instalação cai pela metade.',
              nivel = 6, custo = 1, requer = { 'fundamentos' }, efeito = { falha = 0.5 } },
        },
    },
}

-- Abas que aparecem na tela mas ainda não existem
Config.emBreve = {
    { label = 'Corrida', icone = 'bandeira' },
    { label = 'Crime',   icone = 'mascara' },
}

---------------------------------------------------------------------
-- FONTES DE XP (fora o pista_tuning, que manda o XP de cada peça)
---------------------------------------------------------------------
Config.xp = {
    -- Corridas: o script de corrida chama exports.pista_skills:darXPCorrida(...)
    corrida = {
        arvore = 'mecanica',
        minJogadores = 3,                 -- menos que isso não dá XP
        legal   = { participar = 20, terminar = 40, podio = { 150, 100, 60 } },
        ilegal  = { participar = 40, terminar = 80, podio = { 300, 200, 120 } },
    },

    -- Time attack: bater o próprio recorde numa pista
    -- O script de corrida chama exports.pista_skills:registrarTempo(source, 'nome_da_pista', ms)
    timeAttack = { arvore = 'mecanica', xp = 60, cooldownMin = 30 },

    -- Dinamômetro: /dyno no banco do motorista, parado, dentro de uma oficina
    dyno = {
        arvore = 'mecanica', xp = 25, cooldownMin = 60, tempo = 9000,
        locais = {
            { label = 'Mecânica Pista & Asfalto (Burton)', coords = vec3(-334.85, -121.60, 38.01), raio = 35.0 },
            { label = "Benny's Motorworks", coords = vec3(-211.0, -1325.0, 31.0), raio = 25.0 },
        },
    },

    -- Aprendiz: quem está perto de um mecânico especializado fazendo serviço
    -- ganha uma parte do XP. O mecânico ganha uma comissão em dinheiro por aprendiz.
    aprendiz = { porcentagem = 0.5, raio = 6.0, comissao = 0, conta = 'cash' },

    -- Manuais técnicos: cada um dá XP uma única vez por personagem (não conta no limite diário)
    manuais = {
        manual_motor      = { arvore = 'mecanica', xp = 150 },
        manual_chassi     = { arvore = 'mecanica', xp = 150 },
        manual_eletronica = { arvore = 'mecanica', xp = 150 },
    },
}

---------------------------------------------------------------------
-- MIGRAÇÃO DO XP ANTIGO (pista_tuning usava 4 níveis no metadata)
---------------------------------------------------------------------
-- Nível antigo -> nível novo. Os pontos ficam livres para o jogador escolher.
Config.migracao = { [1] = 2, [2] = 4, [3] = 6, [4] = 8 }
Config.migracaoXPAntigo = { 100, 300, 700, 1500 }
