-- pa_medico · servidor
-- Controla o tempo de desmaio, os chamados para os médicos, a ambulância NPC,
-- o 192 do celular (NPWD) e quando o jogador pode acordar no hospital.

local BAG = 'qbx_medical:deathState'
local VIVO, CAIDO, MORTO = 1, 2, 3

---@type table<number, {fim: number, ultimoChamado: number, chamado?: number, npc?: {inicio: number}}>
local desmaiados = {}
---@type table<number, {id: number, paciente?: number, centro: vector3, origem: string, criado: number, medico?: number, medicoNome?: string}>
local chamados = {}
local proxId = 0
local ultimaLigacao = {}

local function estado(src)
    return Player(src).state[BAG]
end

local function estaDesmaiado(src)
    local e = estado(src)
    return e == CAIDO or e == MORTO
end

local function notificar(src, texto, tipo)
    exports.qbx_core:Notify(src, texto, tipo or 'inform')
end

local function nomeDe(src)
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return ('ID %s'):format(src) end
    local c = p.PlayerData.charinfo
    return ('%s %s'):format(c.firstname, c.lastname)
end

local function medicoEmServico(src)
    local p = exports.qbx_core:GetPlayer(src)
    return p and p.PlayerData.job.type == Config.tipoEmprego and p.PlayerData.job.onduty
end

---Registra o desmaio (uma vez por queda: passar de caído para morto não reinicia o tempo)
local function garantir(src)
    if not desmaiados[src] then
        desmaiados[src] = { fim = os.time() + Config.tempoDesmaiado, ultimoChamado = 0 }
    end
    return desmaiados[src]
end

---------------------------------------------------------------------
-- CHAMADOS
---------------------------------------------------------------------
local function fecharChamado(id, motivo)
    if not chamados[id] then return end
    chamados[id] = nil
    TriggerClientEvent('pa_medico:client:fecharAlerta', -1, id, motivo)
end

---Ponto aleatório dentro de um círculo (distribuição uniforme)
local function deslocar(coords, raio)
    local ang = math.random() * math.pi * 2
    local dist = math.sqrt(math.random()) * raio
    return vec3(coords.x + math.cos(ang) * dist, coords.y + math.sin(ang) * dist, coords.z)
end

local function criarChamado(paciente, coords, origem)
    proxId += 1
    local id = proxId
    local centro = deslocar(coords, math.min(Config.alerta.imprecisao, Config.alerta.raio - 5.0))
    chamados[id] = { id = id, paciente = paciente, centro = centro, origem = origem, criado = os.time() }

    local _, medicos = exports.qbx_core:GetDutyCountType(Config.tipoEmprego)
    for _, m in ipairs(medicos or {}) do
        TriggerClientEvent('pa_medico:client:alerta', m, {
            id = id,
            centro = centro,
            origem = origem,
        })
    end

    SetTimeout(Config.alerta.duracao * 1000, function()
        if chamados[id] then fecharChamado(id, 'expirou') end
    end)
    return id
end

local function despacharNpc(paciente)
    local d = garantir(paciente)
    if d.npc then return false end
    d.npc = { inicio = os.time() }
    TriggerClientEvent('pa_medico:client:npcDespachado', paciente)
    return true
end

---Chamado de quem está desmaiado (tecla G ou 192 desmaiado)
---@return boolean ok, string tipo, any extra
local function chamarPorDesmaiado(src)
    if not estaDesmaiado(src) then return false, 'vivo' end
    local d = garantir(src)
    if d.npc then return false, 'npc' end

    local espera = Config.esperaEntreChamados - (os.time() - d.ultimoChamado)
    if espera > 0 then return false, 'espera', espera end

    local qtd = exports.qbx_core:GetDutyCountType(Config.tipoEmprego)
    if qtd > 0 then
        d.ultimoChamado = os.time()
        if d.chamado then fecharChamado(d.chamado, 'novo') end
        d.chamado = criarChamado(src, GetEntityCoords(GetPlayerPed(src)), 'desmaio')
        return true, 'medico'
    end

    if Config.npc.ativo and despacharNpc(src) then
        d.ultimoChamado = os.time()
        return true, 'npc'
    end
    return false, 'semEquipe'
end

---Quando o jogador volta a ficar bem (médico, NPC, hospital, admin)
local function acordou(src)
    local d = desmaiados[src]
    desmaiados[src] = nil
    if d and d.chamado then fecharChamado(d.chamado, 'atendido') end
end

AddStateBagChangeHandler(BAG, nil, function(bagName, _, valor)
    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 then return end
    if valor == CAIDO or valor == MORTO then
        garantir(src)
    else
        acordou(src)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    acordou(src)
    ultimaLigacao[src] = nil
end)

---------------------------------------------------------------------
-- CALLBACKS DO PACIENTE
---------------------------------------------------------------------
lib.callback.register('pa_medico:server:estado', function(src)
    if not estaDesmaiado(src) then return nil end
    local d = garantir(src)
    local medico
    if d.chamado and chamados[d.chamado] then medico = chamados[d.chamado].medicoNome end
    return {
        restante = math.max(0, d.fim - os.time()),
        chamou = d.chamado ~= nil and chamados[d.chamado] ~= nil,
        medico = medico,
        npc = d.npc ~= nil,
    }
end)

lib.callback.register('pa_medico:server:chamar', function(src)
    return chamarPorDesmaiado(src)
end)

lib.callback.register('pa_medico:server:podeAcordar', function(src)
    local d = desmaiados[src]
    return d ~= nil and os.time() >= d.fim and not d.npc
end)

-- O hospital (qbx_medical) só deixa acordar depois que o tempo acabou
CreateThread(function()
    local ok = pcall(function()
        exports.qbx_medical:registerHook('respawn', function(dados)
            local d = desmaiados[dados.source]
            if d and os.time() < d.fim then return false end
            return true
        end)
    end)
    if not ok then
        lib.print.warn('Não deu para registrar o bloqueio de respawn no qbx_medical; o tempo só é checado no cliente.')
    end
end)

---------------------------------------------------------------------
-- AMBULÂNCIA NPC
---------------------------------------------------------------------
lib.callback.register('pa_medico:server:npcConcluir', function(src)
    local d = desmaiados[src]
    if not d or not d.npc or not estaDesmaiado(src) then return false end
    if os.time() - d.npc.inicio < Config.npc.tempoRCP then return false end

    local preco = Config.npc.preco
    if preco > 0 then
        local p = exports.qbx_core:GetPlayer(src)
        local pago = p and (p.Functions.RemoveMoney('bank', preco, 'samu-npc') or p.Functions.RemoveMoney('cash', preco, 'samu-npc'))
        if pago then
            notificar(src, Config.textos.cobradoNpc:format(preco), 'inform')
        elseif Config.npc.reanimarSemSaldo then
            notificar(src, Config.textos.semDinheiroNpc, 'error')
        else
            d.npc = nil
            return false
        end
    end

    exports.qbx_medical:Revive(src)
    return true
end)

lib.callback.register('pa_medico:server:npcCancelar', function(src)
    local d = desmaiados[src]
    if d then
        d.npc = nil
        d.ultimoChamado = 0
    end
    return true
end)

---------------------------------------------------------------------
-- CALLBACKS DO MÉDICO
---------------------------------------------------------------------
lib.callback.register('pa_medico:server:aceitar', function(src, id)
    if not medicoEmServico(src) then return false end
    local c = chamados[id]
    if not c or c.medico then return false end

    c.medico = src
    c.medicoNome = nomeDe(src)

    local _, medicos = exports.qbx_core:GetDutyCountType(Config.tipoEmprego)
    for _, m in ipairs(medicos or {}) do
        TriggerClientEvent('pa_medico:client:chamadoAssumido', m, id, c.medicoNome, src)
    end
    if c.paciente then
        TriggerClientEvent('pa_medico:client:medicoACaminho', c.paciente, c.medicoNome)
    end
    return true, c.centro
end)

lib.callback.register('pa_medico:server:listar', function(src)
    if not medicoEmServico(src) then return {} end
    local lista = {}
    for _, c in pairs(chamados) do
        lista[#lista + 1] = {
            id = c.id,
            centro = c.centro,
            origem = c.origem,
            minutos = math.floor((os.time() - c.criado) / 60),
            medico = c.medicoNome,
            meu = c.medico == src,
        }
    end
    table.sort(lista, function(a, b) return a.id > b.id end)
    return lista
end)

---------------------------------------------------------------------
-- CELULAR (NPWD): ligar para o 192
---------------------------------------------------------------------
local function procurarDesmaiadoPerto(coords, raio)
    local melhor, melhorDist
    for alvo in pairs(desmaiados) do
        local dist = #(GetEntityCoords(GetPlayerPed(alvo)) - coords)
        if dist <= raio and (not melhorDist or dist < melhorDist) then
            melhor, melhorDist = alvo, dist
        end
    end
    return melhor
end

local function aoLigar(ctx)
    local src = ctx.incomingCaller.source
    local responder = function(msg) pcall(ctx.reply, msg) end

    if estaDesmaiado(src) then
        local ok, tipo, extra = chamarPorDesmaiado(src)
        if ok and tipo == 'medico' then
            responder('SAMU: chamado registrado. A equipe foi avisada da sua região.')
        elseif ok and tipo == 'npc' then
            responder('SAMU: uma ambulância está indo até você.')
        elseif tipo == 'espera' then
            responder(('SAMU: seu chamado já está na fila. Ligue de novo em %s s.'):format(extra))
        elseif tipo == 'npc' then
            responder('SAMU: a ambulância já está a caminho.')
        else
            responder('SAMU: ' .. Config.textos.semEquipe)
        end
        TriggerClientEvent('pa_medico:client:chamouPeloCelular', src, ok, tipo, extra)
        return ctx.exit()
    end

    -- Quem liga está bem: chamado na posição de quem ligou
    local espera = Config.esperaEntreChamados - (os.time() - (ultimaLigacao[src] or 0))
    if espera > 0 then
        responder(('SAMU: chamado já registrado. Ligue de novo em %s s.'):format(espera))
        return ctx.exit()
    end

    local coords = GetEntityCoords(GetPlayerPed(src))
    local qtd = exports.qbx_core:GetDutyCountType(Config.tipoEmprego)
    if qtd > 0 then
        ultimaLigacao[src] = os.time()
        local caido = procurarDesmaiadoPerto(coords, Config.telefone.raioProcurarCaido)
        local id = criarChamado(caido, coords, 'telefone')
        if caido then
            local d = garantir(caido)
            if d.chamado then fecharChamado(d.chamado, 'novo') end
            d.chamado = id
            d.ultimoChamado = os.time()
        end
        responder('SAMU: chamado registrado. A equipe foi avisada da sua região.')
        return ctx.exit()
    end

    if Config.npc.ativo then
        local caido = procurarDesmaiadoPerto(coords, Config.telefone.raioProcurarCaido)
        if caido and despacharNpc(caido) then
            ultimaLigacao[src] = os.time()
            responder('SAMU: sem equipe na rua, mas uma ambulância está indo até a vítima.')
            return ctx.exit()
        elseif caido then
            responder('SAMU: a ambulância já está a caminho da vítima.')
            return ctx.exit()
        end
    end

    responder('SAMU: ' .. Config.textos.semEquipe)
    return ctx.exit()
end

local function registrarTelefone()
    if not Config.telefone.ativo or GetResourceState('npwd') ~= 'started' then return end
    local ok, erro = pcall(function()
        exports.npwd:onCall(Config.telefone.numero, aoLigar)
    end)
    if not ok then lib.print.warn(('Falha ao registrar o %s no NPWD: %s'):format(Config.telefone.numero, erro)) end
end

AddEventHandler('onResourceStart', function(res)
    if res == 'npwd' then
        SetTimeout(2000, registrarTelefone)
    elseif res == GetCurrentResourceName() then
        registrarTelefone()
    end
end)

---------------------------------------------------------------------
-- EXPORTS
---------------------------------------------------------------------
exports('EstaDesmaiado', estaDesmaiado)
exports('TempoRestante', function(src)
    local d = desmaiados[src]
    return d and math.max(0, d.fim - os.time()) or 0
end)
