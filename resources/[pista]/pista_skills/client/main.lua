-- pista_skills - cliente

local estado = {}      -- [arvore] = { xp, nivel, pontos, habilidades = {lista}, profissional, ... }
local habSet = {}      -- [arvore] = { [id] = true }
local aberto = false

---------------------------------------------------------------------
-- Estado
---------------------------------------------------------------------
local function aplicarEstado(novo)
    estado = novo or {}
    habSet = {}
    for arvore, e in pairs(estado) do
        local s = {}
        for _, id in ipairs(e.habilidades or {}) do s[id] = true end
        habSet[arvore] = s
    end
    if aberto then
        SendNUIMessage({ acao = 'estado', estado = estado })
    end
end

local function atualizar()
    aplicarEstado(lib.callback.await('pista_skills:server:estado', false))
end

RegisterNetEvent('pista_skills:client:estado', aplicarEstado)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() SetTimeout(1000, atualizar) end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function() SetTimeout(700, atualizar) end)
RegisterNetEvent('QBCore:Client:SetDuty', function() SetTimeout(700, atualizar) end)
AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then SetTimeout(1500, atualizar) end
end)

RegisterNetEvent('pista_skills:client:subiuNivel', function(arvore, nivel)
    PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', true)
    if aberto then SendNUIMessage({ acao = 'subiu', arvore = arvore, nivel = nivel }) end
end)

---------------------------------------------------------------------
-- Exports para outros scripts (pista_tuning, qbx_customs...)
---------------------------------------------------------------------
local function tem(id, arvore)
    arvore = arvore or 'mecanica'
    local e = estado[arvore]
    if not e then return false end
    return e.profissional or (habSet[arvore] and habSet[arvore][id]) == true
end

local function modificador(efeito, arvore)
    arvore = arvore or 'mecanica'
    local arv = Config.arvores[arvore]
    if not arv then return 1.0 end
    local mult = 1.0
    for _, h in ipairs(arv.habilidades) do
        if h.efeito and h.efeito[efeito] and tem(h.id, arvore) then
            mult = mult * h.efeito[efeito]
        end
    end
    return mult
end

exports('tem', tem)
exports('modificador', modificador)
exports('profissional', function(arvore) local e = estado[arvore or 'mecanica'] return e and e.profissional or false end)
exports('nivel', function(arvore) local e = estado[arvore or 'mecanica'] return e and e.nivel or 0 end)
exports('label', function(id, arvore)
    local arv = Config.arvores[arvore or 'mecanica']
    for _, h in ipairs(arv and arv.habilidades or {}) do
        if h.id == id then return h.label, h.nivel end
    end
    return id, 0
end)

---------------------------------------------------------------------
-- Tela
---------------------------------------------------------------------
local function definicoes()
    local arvores = {}
    for id, arv in pairs(Config.arvores) do
        arvores[id] = {
            label = arv.label, icone = arv.icone, descricao = arv.descricao,
            niveis = arv.niveis, ramos = arv.ramos, habilidades = arv.habilidades,
            pontosPorNivel = arv.pontosPorNivel, pontosExtras = arv.pontosExtras,
        }
    end
    return arvores
end

local function fontesDeXP()
    local x = Config.xp
    return {
        { icone = 'bandeira', titulo = 'Corridas legais', texto = ('%d a %d XP (pódio dá mais)'):format(x.corrida.legal.participar, x.corrida.legal.participar + x.corrida.legal.terminar + x.corrida.legal.podio[1]) },
        { icone = 'mascara', titulo = 'Corridas ilegais', texto = ('%d a %d XP, mas com risco de polícia'):format(x.corrida.ilegal.participar, x.corrida.ilegal.participar + x.corrida.ilegal.terminar + x.corrida.ilegal.podio[1]) },
        { icone = 'ferramentas', titulo = 'Instalar peças', texto = 'Só peça nova em cada carro dá XP' },
        { icone = 'carro', titulo = 'Consertos', texto = 'Pneu, funilaria, kit de emergência e retífica' },
        { icone = 'velocimetro', titulo = 'Dinamômetro', texto = ('/dyno na oficina: %d XP por carro a cada %d min'):format(x.dyno.xp, x.dyno.cooldownMin) },
        { icone = 'aprendiz', titulo = 'Aprendiz', texto = ('Perto de um mecânico trabalhando: %d%% do XP dele'):format(math.floor(x.aprendiz.porcentagem * 100)) },
        { icone = 'livro', titulo = 'Manuais técnicos', texto = 'XP uma única vez por manual' },
        { icone = 'cronometro', titulo = 'Time attack', texto = ('Bater o próprio recorde: %d XP'):format(x.timeAttack.xp) },
        { icone = 'alerta', titulo = 'Falhas', texto = 'Instalação que dá errado também ensina um pouco' },
    }
end

local function abrir()
    if aberto then return end
    atualizar()
    aberto = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        acao = 'abrir',
        arvores = definicoes(),
        emBreve = Config.emBreve,
        estado = estado,
        fontes = fontesDeXP(),
        nome = QBX and QBX.PlayerData and QBX.PlayerData.charinfo
            and (QBX.PlayerData.charinfo.firstname .. ' ' .. QBX.PlayerData.charinfo.lastname) or '',
    })
end

local function fechar()
    aberto = false
    SetNuiFocus(false, false)
    SendNUIMessage({ acao = 'fechar' })
end

RegisterCommand(Config.comando, abrir, false)
RegisterKeyMapping(Config.comando, 'Abrir habilidades (skills)', 'keyboard', Config.tecla)
TriggerEvent('chat:addSuggestion', '/' .. Config.comando, 'Ver seu nível, pontos e árvore de habilidades')

RegisterNUICallback('fechar', function(_, cb) cb(1) fechar() end)

RegisterNUICallback('aprender', function(dados, cb)
    local ok, msg, novo = lib.callback.await('pista_skills:server:aprender', false, dados.arvore, dados.id)
    if ok then
        PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)
        aplicarEstado(novo)
    end
    cb({ ok = ok, msg = msg, estado = ok and estado or nil })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and aberto then SetNuiFocus(false, false) end
end)

---------------------------------------------------------------------
-- Manuais técnicos (item do ox_inventory)
---------------------------------------------------------------------
exports('usarManual', function(data, slot)
    local item = data and data.name
    local s = slot and slot.slot or (data and data.slot)
    exports.ox_inventory:closeInventory()
    local ok = lib.progressCircle({
        duration = 6000,
        label = 'Lendo o manual...',
        position = 'bottom',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'cellphone@', clip = 'cellphone_text_read_base' },
        prop = { model = `prop_novel_01`, bone = 6286, pos = vec3(0.15, 0.03, -0.065), rot = vec3(0.0, 180.0, 90.0) },
    })
    if not ok then return end
    local lido, msg = lib.callback.await('pista_skills:server:lerManual', false, item, s)
    if not lido and msg then exports.qbx_core:Notify(msg, 'error') end
end)

---------------------------------------------------------------------
-- Dinamômetro
---------------------------------------------------------------------
local ultimaMedicao = {} -- [placa] = cv

--- Potência estimada a partir da handling (já com a preparação aplicada)
local function medir(veh)
    local forca = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce')
    local massa = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fMass')
    local vmax = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel')
    local mult = 1.0 + (GetVehicleMod(veh, 11) + 1) * 0.05 + (IsToggleModOn(veh, 18) and 0.1 or 0.0)
    local cv = math.floor(forca * massa * vmax / 140.0 * mult)
    local torque = math.floor(cv * 716.2 / 6500 * 10) / 10 -- kgfm no pico (aprox.)
    return cv, torque
end

RegisterCommand('dyno', function()
    local veh = cache.vehicle
    if not veh or GetPedInVehicleSeat(veh, -1) ~= cache.ped then
        return exports.qbx_core:Notify('Entre no carro, no banco do motorista', 'error')
    end
    if GetEntitySpeed(veh) > 1.0 then
        return exports.qbx_core:Notify('Pare o carro no dinamômetro', 'error')
    end
    local pode, erro = lib.callback.await('pista_skills:server:podeDyno', false)
    if not pode then return exports.qbx_core:Notify(erro or 'Não dá para usar o dinamômetro aqui', 'error') end

    FreezeEntityPosition(veh, true)
    local rodando = true
    CreateThread(function()
        local inicio = GetGameTimer()
        while rodando do
            local p = math.min(1.0, (GetGameTimer() - inicio) / Config.xp.dyno.tempo)
            SetVehicleCurrentRpm(veh, 0.25 + 0.75 * p)
            SetVehicleCheatPowerIncrease(veh, 1.0)
            Wait(0)
        end
    end)
    local ok = lib.progressBar({
        duration = Config.xp.dyno.tempo,
        label = 'Puxada no dinamômetro...',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
    rodando = false
    FreezeEntityPosition(veh, false)
    if not ok then return end

    local cv, torque = medir(veh)
    local placa = GetVehicleNumberPlateText(veh)
    local antes = ultimaMedicao[placa]
    ultimaMedicao[placa] = cv
    local diferenca = antes and (' (%s%d cv desde a última medição)'):format(cv >= antes and '+' or '', cv - antes) or ''

    lib.alertDialog({
        header = 'Dinamômetro',
        content = ('**Potência:** %d cv%s  \n**Torque:** %.1f kgfm'):format(cv, diferenca, torque),
        centered = true,
    })
    lib.callback.await('pista_skills:server:dynoFeito', false)
end, false)
TriggerEvent('chat:addSuggestion', '/dyno', 'Medir a potência do carro no dinamômetro (dentro da oficina)')
