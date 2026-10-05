-- pista_skills - servidor
-- XP, níveis, pontos e árvore de habilidades. Outros scripts usam os exports:
--   temHabilidade(source, id, arvore)       -> true/false (a profissão conta como tendo tudo)
--   exigirHabilidade(source, id, arvore)    -> nil ou mensagem de erro
--   modificador(source, efeito, arvore)     -> multiplicador das passivas (desgaste, tempo, falha)
--   ehProfissional(source, arvore)          -> mecânico especializado em serviço, por exemplo
--   darXP(source, arvore, qtd, motivo, opts)
--   darXPCorrida(source, tipo, posicao, participantes, terminou)
--   registrarTempo(source, pista, ms)

local cache = {}   -- [source] = { cid, arvores = { [id] = { xp, hab = {}, xpHoje, dia } } }
local defs = {}    -- [arvore] = { porId = { [id] = hab } }

for id, arv in pairs(Config.arvores) do
    local porId = {}
    for _, h in ipairs(arv.habilidades) do porId[h.id] = h end
    defs[id] = { porId = porId }
end

local function arvoreOu(arvore) return arvore or 'mecanica' end

local function hoje() return os.date('%Y-%m-%d') end

---------------------------------------------------------------------
-- Cálculos
---------------------------------------------------------------------
local function nivelPorXP(arvore, xp)
    local niveis = Config.arvores[arvore].niveis
    local nivel = 1
    for n = 1, #niveis do
        if xp >= niveis[n] then nivel = n end
    end
    return nivel
end

local function pontosTotais(arvore, nivel)
    local arv = Config.arvores[arvore]
    local total = nivel * (arv.pontosPorNivel or 1)
    for n, extra in pairs(arv.pontosExtras or {}) do
        if nivel >= n then total = total + extra end
    end
    return total
end

local function pontosGastos(arvore, hab)
    local gastos = 0
    for id in pairs(hab) do
        local h = defs[arvore].porId[id]
        if h then gastos = gastos + (h.custo or 1) end
    end
    return gastos
end

---------------------------------------------------------------------
-- Banco e cache
---------------------------------------------------------------------
MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `pista_skills` (
            `citizenid` VARCHAR(50) NOT NULL,
            `arvore` VARCHAR(30) NOT NULL,
            `xp` INT NOT NULL DEFAULT 0,
            `habilidades` LONGTEXT NULL,
            `xp_hoje` INT NOT NULL DEFAULT 0,
            `dia` VARCHAR(10) NULL,
            PRIMARY KEY (`citizenid`, `arvore`)
        )
    ]])
    -- Marcas anti-farm: peça já instalada naquele carro, cooldowns, manuais lidos...
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `pista_skills_marcas` (
            `citizenid` VARCHAR(50) NOT NULL,
            `chave` VARCHAR(120) NOT NULL,
            `expira` INT NULL,
            PRIMARY KEY (`citizenid`, `chave`)
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `pista_skills_recordes` (
            `citizenid` VARCHAR(50) NOT NULL,
            `pista` VARCHAR(60) NOT NULL,
            `tempo` INT NOT NULL,
            PRIMARY KEY (`citizenid`, `pista`)
        )
    ]])
    MySQL.query('DELETE FROM pista_skills_marcas WHERE expira IS NOT NULL AND expira < ?', { os.time() })
end)

local function citizenidDe(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and player.PlayerData.citizenid, player
end

--- XP antigo do pista_tuning (metadata tuning_xp) vira nível na árvore de mecânica
local function xpMigrado(player)
    local antigo = tonumber(player.PlayerData.metadata and player.PlayerData.metadata.tuning_xp) or 0
    if antigo <= 0 then return 0 end
    local nivelAntigo = 0
    for n, xp in ipairs(Config.migracaoXPAntigo) do
        if antigo >= xp then nivelAntigo = n end
    end
    local novo = Config.migracao[nivelAntigo]
    if not novo then return 0 end
    return Config.arvores.mecanica.niveis[novo] or 0
end

local function carregar(source)
    local cid, player = citizenidDe(source)
    if not cid then return nil end
    local c = cache[source]
    if c and c.cid == cid then return c end

    c = { cid = cid, arvores = {} }
    local linhas = MySQL.query.await('SELECT arvore, xp, habilidades, xp_hoje, dia FROM pista_skills WHERE citizenid = ?', { cid }) or {}
    for _, l in ipairs(linhas) do
        local hab = {}
        for _, id in ipairs(json.decode(l.habilidades or '[]') or {}) do hab[id] = true end
        c.arvores[l.arvore] = { xp = l.xp, hab = hab, xpHoje = l.xp_hoje or 0, dia = l.dia }
    end
    for id in pairs(Config.arvores) do
        if not c.arvores[id] then
            local xp = id == 'mecanica' and xpMigrado(player) or 0
            c.arvores[id] = { xp = xp, hab = {}, xpHoje = 0, dia = hoje() }
            MySQL.insert.await('INSERT IGNORE INTO pista_skills (citizenid, arvore, xp, habilidades, xp_hoje, dia) VALUES (?, ?, ?, ?, 0, ?)',
                { cid, id, xp, '[]', hoje() })
            if xp > 0 then player.Functions.SetMetaData('tuning_xp', 0) end
        end
    end
    cache[source] = c
    return c
end

local function salvar(source, arvore)
    local c = cache[source]
    local a = c and c.arvores[arvore]
    if not a then return end
    local lista = {}
    for id in pairs(a.hab) do lista[#lista + 1] = id end
    MySQL.update('UPDATE pista_skills SET xp = ?, habilidades = ?, xp_hoje = ?, dia = ? WHERE citizenid = ? AND arvore = ?',
        { a.xp, json.encode(lista), a.xpHoje, a.dia, c.cid, arvore })
end

AddEventHandler('playerDropped', function() cache[source] = nil end)

---------------------------------------------------------------------
-- Marcas (anti-farm)
---------------------------------------------------------------------
--- true se a marca existe e não venceu
local function temMarca(cid, chave)
    local expira = MySQL.scalar.await('SELECT IFNULL(expira, -1) FROM pista_skills_marcas WHERE citizenid = ? AND chave = ?', { cid, chave })
    if expira == nil then return false end
    return expira == -1 or expira > os.time()
end

--- segundos = nil -> marca permanente
local function marcar(cid, chave, segundos)
    local expira = segundos and (os.time() + segundos) or nil
    MySQL.query.await('REPLACE INTO pista_skills_marcas (citizenid, chave, expira) VALUES (?, ?, ?)', { cid, chave, expira })
end

---------------------------------------------------------------------
-- Profissão e habilidades
---------------------------------------------------------------------
local function ehProfissional(source, arvore)
    arvore = arvoreOu(arvore)
    local prof = Config.arvores[arvore] and Config.arvores[arvore].profissao
    if not prof then return false end
    local player = exports.qbx_core:GetPlayer(source)
    local job = player and player.PlayerData.job
    if not job or job.name ~= prof.job then return false end
    if prof.emServico and not job.onduty then return false end
    return (job.grade and job.grade.level or 0) >= (prof.gradeMinimo or 0)
end

local function temHabilidade(source, id, arvore)
    arvore = arvoreOu(arvore)
    if not Config.arvores[arvore] then return false end
    if ehProfissional(source, arvore) then return true end
    local c = carregar(source)
    return c ~= nil and c.arvores[arvore].hab[id] == true
end

local function exigirHabilidade(source, id, arvore)
    arvore = arvoreOu(arvore)
    if temHabilidade(source, id, arvore) then return nil end
    local h = defs[arvore] and defs[arvore].porId[id]
    if not h then return 'Habilidade inexistente: ' .. tostring(id) end
    return ('Você precisa da habilidade "%s" (%s, nível %d). Abra com /%s')
        :format(h.label, Config.arvores[arvore].label, h.nivel, Config.comando)
end

--- Multiplicador das passivas. O profissional tem todas.
local function modificador(source, efeito, arvore)
    arvore = arvoreOu(arvore)
    local arv = Config.arvores[arvore]
    if not arv then return 1.0 end
    local prof = ehProfissional(source, arvore)
    local c = not prof and carregar(source) or nil
    local mult = 1.0
    for _, h in ipairs(arv.habilidades) do
        if h.efeito and h.efeito[efeito] and (prof or (c and c.arvores[arvore].hab[h.id])) then
            mult = mult * h.efeito[efeito]
        end
    end
    return mult
end

---------------------------------------------------------------------
-- Estado enviado para a tela / cliente
---------------------------------------------------------------------
local function estado(source)
    local c = carregar(source)
    if not c then return nil end
    local out = {}
    for id, arv in pairs(Config.arvores) do
        local a = c.arvores[id]
        if a.dia ~= hoje() then a.dia, a.xpHoje = hoje(), 0 end
        local nivel = nivelPorXP(id, a.xp)
        local lista = {}
        for hid in pairs(a.hab) do lista[#lista + 1] = hid end
        out[id] = {
            xp = a.xp,
            nivel = nivel,
            maxNivel = #arv.niveis,
            xpNivelAtual = arv.niveis[nivel],
            xpProximo = arv.niveis[nivel + 1],
            pontos = pontosTotais(id, nivel) - pontosGastos(id, a.hab),
            pontosTotais = pontosTotais(id, nivel),
            habilidades = lista,
            profissional = ehProfissional(source, id),
            xpHoje = a.xpHoje,
            limiteDiario = arv.limiteDiario or 0,
        }
    end
    return out
end

local function atualizarCliente(source)
    TriggerClientEvent('pista_skills:client:estado', source, estado(source))
end

lib.callback.register('pista_skills:server:estado', function(source)
    return estado(source)
end)

---------------------------------------------------------------------
-- XP
---------------------------------------------------------------------
local function avisar(source, msg, tipo, tempo)
    exports.qbx_core:Notify(source, msg, tipo or 'inform', tempo)
end

--- Soma XP sem nenhuma checagem de anti-farm (só limite diário). Retorna o XP dado.
local function somarXP(source, arvore, qtd, motivo, ignorarLimite)
    local c = carregar(source)
    if not c or not Config.arvores[arvore] then return 0 end
    local a = c.arvores[arvore]
    if a.dia ~= hoje() then a.dia, a.xpHoje = hoje(), 0 end

    local limite = Config.arvores[arvore].limiteDiario or 0
    if not ignorarLimite and limite > 0 then
        local resta = limite - a.xpHoje
        if resta <= 0 then
            avisar(source, ('Você já ganhou todo o XP de %s de hoje'):format(Config.arvores[arvore].label:lower()), 'error')
            return 0
        end
        qtd = math.min(qtd, resta)
    end
    qtd = math.floor(qtd)
    if qtd <= 0 then return 0 end

    local nAntes = nivelPorXP(arvore, a.xp)
    a.xp = a.xp + qtd
    if not ignorarLimite then a.xpHoje = a.xpHoje + qtd end
    local nDepois = nivelPorXP(arvore, a.xp)
    salvar(source, arvore)

    local nome = Config.arvores[arvore].label
    if nDepois > nAntes then
        local ganhos = pontosTotais(arvore, nDepois) - pontosTotais(arvore, nAntes)
        avisar(source, ('%s: nível %d! +%d ponto(s) de habilidade. Use /%s'):format(nome, nDepois, ganhos, Config.comando), 'success', 8000)
        TriggerClientEvent('pista_skills:client:subiuNivel', source, arvore, nDepois)
    else
        avisar(source, ('+%d XP de %s%s'):format(qtd, nome:lower(), motivo and (' (' .. motivo .. ')') or ''))
    end
    atualizarCliente(source)
    return qtd
end

--- Dá XP para os aprendizes perto de um profissional
local function darAprendizes(source, arvore, qtd, motivo)
    local cfg = Config.xp.aprendiz
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    local total = 0
    for _, id in ipairs(GetPlayers()) do
        local alvo = tonumber(id)
        if alvo ~= source then
            local p = GetPlayerPed(alvo)
            if p ~= 0 and #(GetEntityCoords(p) - coords) <= cfg.raio and not ehProfissional(alvo, arvore) then
                local dado = somarXP(alvo, arvore, qtd * cfg.porcentagem, 'aprendiz' .. (motivo and (': ' .. motivo) or ''))
                if dado > 0 then total = total + 1 end
            end
        end
    end
    if total > 0 and (cfg.comissao or 0) > 0 then
        local player = exports.qbx_core:GetPlayer(source)
        if player then
            player.Functions.AddMoney(cfg.conta or 'cash', cfg.comissao * total, 'pista-skills-aprendiz')
            avisar(source, ('Comissão de aprendiz: $%d'):format(cfg.comissao * total), 'success')
        end
    end
end

--- opts:
---   chave         = marca permanente: se já existe, não dá XP (ex.: peça já instalada nesse carro)
---   cooldown      = { chave = '...', segundos = 600 }: só dá XP de novo depois do tempo
---   ignorarLimite = não conta no limite diário
---   aprendizes    = se quem fez é profissional, os aprendizes por perto também ganham
local function darXP(source, arvore, qtd, motivo, opts)
    arvore = arvoreOu(arvore)
    opts = opts or {}
    if not qtd or qtd <= 0 then return 0 end
    local c = carregar(source)
    if not c then return 0 end

    if opts.chave then
        if temMarca(c.cid, opts.chave) then return 0 end
    end
    if opts.cooldown then
        if temMarca(c.cid, opts.cooldown.chave) then return 0 end
    end

    if opts.aprendizes and ehProfissional(source, arvore) then
        darAprendizes(source, arvore, qtd, motivo)
    end

    local dado = somarXP(source, arvore, qtd, motivo, opts.ignorarLimite)
    if dado > 0 then
        if opts.chave then marcar(c.cid, opts.chave) end
        if opts.cooldown then marcar(c.cid, opts.cooldown.chave, opts.cooldown.segundos) end
    end
    return dado
end

--- Para o script de corridas. tipo = 'legal' ou 'ilegal'; posicao = 1, 2, 3...
--- terminou = false para quem abandonou (ganha só o de participar)
local function darXPCorrida(source, tipo, posicao, participantes, terminou)
    local cfg = Config.xp.corrida
    local t = cfg[tipo]
    if not t then return 0 end
    if (participantes or 0) < cfg.minJogadores then
        avisar(source, ('Corrida com menos de %d pilotos não dá XP'):format(cfg.minJogadores), 'error')
        return 0
    end
    local xp = t.participar
    if terminou ~= false then
        xp = xp + t.terminar
        if posicao and t.podio[posicao] then xp = xp + t.podio[posicao] end
    end
    return darXP(source, cfg.arvore, xp, ('corrida %s'):format(tipo))
end

--- Time attack: XP só ao bater o próprio recorde
local function registrarTempo(source, pista, ms)
    local cid = citizenidDe(source)
    if not cid or not pista or not ms or ms <= 0 then return false end
    local atual = MySQL.scalar.await('SELECT tempo FROM pista_skills_recordes WHERE citizenid = ? AND pista = ?', { cid, pista })
    if atual and ms >= atual then return false end
    MySQL.query.await('REPLACE INTO pista_skills_recordes (citizenid, pista, tempo) VALUES (?, ?, ?)', { cid, pista, ms })
    if atual then
        local cfg = Config.xp.timeAttack
        avisar(source, ('Novo recorde pessoal em %s: %.3fs'):format(pista, ms / 1000), 'success')
        darXP(source, cfg.arvore, cfg.xp, 'recorde pessoal',
            { cooldown = { chave = 'timeattack:' .. pista, segundos = cfg.cooldownMin * 60 } })
    end
    return true
end

exports('temHabilidade', temHabilidade)
exports('exigirHabilidade', exigirHabilidade)
exports('modificador', modificador)
exports('ehProfissional', ehProfissional)
exports('darXP', darXP)
exports('darXPCorrida', darXPCorrida)
exports('registrarTempo', registrarTempo)
exports('nivel', function(source, arvore)
    arvore = arvoreOu(arvore)
    local c = carregar(source)
    return c and nivelPorXP(arvore, c.arvores[arvore].xp) or 0
end)
exports('estado', estado)

---------------------------------------------------------------------
-- Aprender habilidade (pela tela)
---------------------------------------------------------------------
lib.callback.register('pista_skills:server:aprender', function(source, arvore, id)
    local arv = Config.arvores[arvore]
    if not arv then return false, 'Árvore inválida' end
    local h = defs[arvore].porId[id]
    if not h then return false, 'Habilidade inválida' end
    local c = carregar(source)
    if not c then return false, 'Personagem não carregado' end
    local a = c.arvores[arvore]

    if a.hab[id] then return false, 'Você já tem essa habilidade' end
    local nivel = nivelPorXP(arvore, a.xp)
    if nivel < h.nivel then return false, ('Precisa de nível %d'):format(h.nivel) end
    for _, req in ipairs(h.requer or {}) do
        if not a.hab[req] then
            return false, ('Aprenda antes: %s'):format(defs[arvore].porId[req].label)
        end
    end
    local livres = pontosTotais(arvore, nivel) - pontosGastos(arvore, a.hab)
    if livres < (h.custo or 1) then return false, 'Pontos insuficientes' end

    a.hab[id] = true
    salvar(source, arvore)
    return true, ('Você aprendeu: %s'):format(h.label), estado(source)
end)

---------------------------------------------------------------------
-- Dinamômetro
---------------------------------------------------------------------
local function noDyno(coords)
    for _, l in ipairs(Config.xp.dyno.locais) do
        if #(coords - l.coords) <= l.raio then return l end
    end
end

lib.callback.register('pista_skills:server:podeDyno', function(source)
    local ped = GetPlayerPed(source)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return false, 'Fique no banco do motorista' end
    if not noDyno(GetEntityCoords(veh)) then return false, 'O dinamômetro fica dentro da oficina' end
    return true
end)

lib.callback.register('pista_skills:server:dynoFeito', function(source)
    local ped = GetPlayerPed(source)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return false end
    if not noDyno(GetEntityCoords(veh)) then return false end
    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local cfg = Config.xp.dyno
    darXP(source, cfg.arvore, cfg.xp, 'dinamômetro',
        { cooldown = { chave = 'dyno:' .. plate, segundos = cfg.cooldownMin * 60 } })
    return true
end)

---------------------------------------------------------------------
-- Manuais técnicos
---------------------------------------------------------------------
lib.callback.register('pista_skills:server:lerManual', function(source, item, slot)
    local cfg = Config.xp.manuais[item]
    if not cfg then return false, 'Isso não é um manual' end
    local c = carregar(source)
    if not c then return false end
    local chave = 'manual:' .. item
    if temMarca(c.cid, chave) then return false, 'Você já leu esse manual' end
    if not exports.ox_inventory:RemoveItem(source, item, 1, nil, slot) then
        return false, 'Você não tem esse manual'
    end
    darXP(source, cfg.arvore, cfg.xp, 'manual', { chave = chave, ignorarLimite = true })
    return true
end)

---------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------
lib.addCommand('minhaskill', { help = 'Mostra seu nível de mecânica' }, function(source)
    local e = estado(source)
    local m = e and e.mecanica
    if not m then return end
    local texto = m.xpProximo and ('Mecânica: nível %d (%d/%d XP) | %d ponto(s) livre(s)'):format(m.nivel, m.xp, m.xpProximo, m.pontos)
        or ('Mecânica: nível %d (máximo, %d XP) | %d ponto(s) livre(s)'):format(m.nivel, m.xp, m.pontos)
    if m.profissional then texto = texto .. ' | Mecânico especializado: sabe tudo' end
    avisar(source, texto, 'inform', 8000)
end)

lib.addCommand('setskill', {
    help = 'Define o nível de skill de um jogador (admin)',
    params = {
        { name = 'id', type = 'playerId', help = 'ID do jogador' },
        { name = 'nivel', type = 'number', help = 'Nível (1 a 10)' },
        { name = 'arvore', type = 'string', help = 'Árvore (padrão: mecanica)', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local arvore = args.arvore or 'mecanica'
    local arv = Config.arvores[arvore]
    if not arv then return avisar(source, 'Árvore inválida', 'error') end
    local c = carregar(args.id)
    if not c then return avisar(source, 'Jogador não encontrado', 'error') end
    local nivel = math.max(1, math.min(math.floor(args.nivel), #arv.niveis))
    local a = c.arvores[arvore]
    a.xp = arv.niveis[nivel]
    -- se o nível caiu, devolve as habilidades que não cabem mais
    if pontosGastos(arvore, a.hab) > pontosTotais(arvore, nivel) then a.hab = {} end
    salvar(args.id, arvore)
    atualizarCliente(args.id)
    avisar(args.id, ('Sua skill de %s agora é nível %d'):format(arv.label:lower(), nivel), 'success')
    if source > 0 then avisar(source, ('Skill do ID %d definida para nível %d'):format(args.id, nivel), 'success') end
end)

lib.addCommand('darxp', {
    help = 'Dá XP para um jogador (admin)',
    params = {
        { name = 'id', type = 'playerId', help = 'ID do jogador' },
        { name = 'xp', type = 'number', help = 'Quantidade' },
        { name = 'arvore', type = 'string', help = 'Árvore (padrão: mecanica)', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local dado = somarXP(args.id, args.arvore or 'mecanica', args.xp, 'admin', true)
    if source > 0 then avisar(source, ('%d XP dado ao ID %d'):format(dado, args.id), 'success') end
end)

lib.addCommand('resetskill', {
    help = 'Devolve os pontos de habilidade de um jogador (admin)',
    params = {
        { name = 'id', type = 'playerId', help = 'ID do jogador' },
        { name = 'arvore', type = 'string', help = 'Árvore (padrão: mecanica)', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local arvore = args.arvore or 'mecanica'
    local c = carregar(args.id)
    if not c or not c.arvores[arvore] then return avisar(source, 'Jogador ou árvore inválida', 'error') end
    c.arvores[arvore].hab = {}
    salvar(args.id, arvore)
    atualizarCliente(args.id)
    avisar(args.id, 'Seus pontos de habilidade foram devolvidos', 'inform')
    if source > 0 then avisar(source, ('Pontos do ID %d devolvidos'):format(args.id), 'success') end
end)
