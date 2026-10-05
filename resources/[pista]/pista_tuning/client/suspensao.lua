-- pista_tuning - suspensão regulável
-- Handling (quem dirige), visual sincronizado (altura, cambagem, bitola) e painel NUI.

local previa = nil        -- { veh, netId, valores } enquanto o painel está aberto
local ativos = {}         -- [veh] = valores normalizados (carros perto com suspensão)
local basesRodas = {}     -- [veh] = { modelo, n, x = { [i] = offset original } }
local basesHandling = {}  -- [veh] = { modelo, force, biasSusp, roll, biasRoll, comp, rebound }

---------------------------------------------------------------------
-- Handling (só faz efeito no cliente de quem dirige)
---------------------------------------------------------------------
local function baseHandling(veh)
    local modelo = GetEntityModel(veh)
    local b = basesHandling[veh]
    if not b or b.modelo ~= modelo then
        local function ler(campo) return GetVehicleHandlingFloat(veh, 'CHandlingData', campo) end
        b = {
            modelo = modelo,
            force = ler('fSuspensionForce'), biasSusp = ler('fSuspensionBiasFront'),
            roll = ler('fAntiRollBarForce'), biasRoll = ler('fAntiRollBarBiasFront'),
            comp = ler('fSuspensionCompDamp'), rebound = ler('fSuspensionReboundDamp'),
        }
        basesHandling[veh] = b
    end
    return b
end

--- Chamado pelo client/main.lua junto com o resto da preparação
function AplicarSuspensao(veh, dados)
    if not dados.suspensao and not basesHandling[veh] then return end -- nunca mexemos nesse carro
    local s = NormalizarSusp(dados.suspensao and dados.susp or Config.suspensao.padrao)
    for campo, valor in pairs(HandlingDaSusp(s, baseHandling(veh))) do
        SetVehicleHandlingFloat(veh, 'CHandlingData', campo, valor + 0.0)
    end
end

---------------------------------------------------------------------
-- Visual: altura, cambagem e bitola (todo mundo vê)
---------------------------------------------------------------------
local function baseRodas(veh)
    local modelo = GetEntityModel(veh)
    local b = basesRodas[veh]
    if not b or b.modelo ~= modelo then
        b = { modelo = modelo, n = GetVehicleNumberOfWheels(veh), x = {} }
        for i = 0, b.n - 1 do b.x[i] = GetVehicleWheelXOffset(veh, i) end
        basesRodas[veh] = b
    end
    return b
end

local function aplicarVisual(veh, s)
    local b = baseRodas(veh)
    SetVehicleSuspensionHeight(veh, -s.altura / 100.0)
    local inverter = Config.suspensao.inverterCambagem and -1.0 or 1.0
    for i = 0, b.n - 1 do
        local frente = i < 2
        local lado = b.x[i] < 0.0 and -1.0 or 1.0   -- esquerda = negativo
        local bitola = (frente and s.bitolaD or s.bitolaT) / 100.0
        local camber = math.rad(frente and s.cambagemD or s.cambagemT)
        SetVehicleWheelXOffset(veh, i, b.x[i] + lado * bitola)
        SetVehicleWheelYRotation(veh, i, -lado * camber * inverter)
    end
end

local function restaurarVisual(veh)
    local b = basesRodas[veh]
    if not b or not DoesEntityExist(veh) then return end
    SetVehicleSuspensionHeight(veh, 0.0)
    for i = 0, b.n - 1 do
        SetVehicleWheelXOffset(veh, i, b.x[i])
        SetVehicleWheelYRotation(veh, i, 0.0)
    end
end

-- Lista dos carros por perto com suspensão regulável (atualiza 2x por segundo)
CreateThread(function()
    while true do
        local lista = {}
        local eu = GetEntityCoords(cache.ped)
        local dist = Config.suspensao.distanciaVisual
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if #(GetEntityCoords(veh) - eu) <= dist then
                local d = Entity(veh).state[STATE_KEY]
                if d and d.suspensao then lista[veh] = NormalizarSusp(d.susp) end
            end
        end
        ativos = lista
        for veh in pairs(basesRodas) do
            if not DoesEntityExist(veh) then
                basesRodas[veh] = nil
            elseif not lista[veh] and not (previa and previa.veh == veh) then
                restaurarVisual(veh) -- suspensão tirada (ou carro longe): volta ao original
                basesRodas[veh] = nil
            end
        end
        for veh in pairs(basesHandling) do
            if not DoesEntityExist(veh) then basesHandling[veh] = nil end
        end
        Wait(500)
    end
end)

-- O GTA desfaz cambagem/bitola sozinho: reaplica todo frame nos carros da lista
CreateThread(function()
    while true do
        local tem = false
        for veh, s in pairs(ativos) do
            if DoesEntityExist(veh) then
                tem = true
                aplicarVisual(veh, (previa and previa.veh == veh) and previa.valores or s)
            end
        end
        if previa and not ativos[previa.veh] and DoesEntityExist(previa.veh) then
            tem = true
            aplicarVisual(previa.veh, previa.valores)
        end
        Wait(tem and 0 or 300)
    end
end)

---------------------------------------------------------------------
-- Painel
---------------------------------------------------------------------
local function fecharPainel()
    SetNuiFocus(false, false)
    SendNUIMessage({ acao = 'fecharSusp' })
end

function AbrirSuspensao(veh)
    if previa then return end
    if not veh or not DoesEntityExist(veh) then return Avisar('Nenhum veículo por perto', 'error') end
    local netId = VehToNet(veh)
    local ok, info = lib.callback.await('pista_tuning:server:abrirSusp', false, netId)
    if not ok then return Avisar(info or 'Não foi possível abrir a suspensão', 'error') end

    previa = { veh = veh, netId = netId, valores = info.susp, original = info.susp }
    SendNUIMessage({
        acao = 'abrirSusp',
        placa = info.placa,
        modelo = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh))),
        faixas = Config.suspensao.faixas,
        padrao = NormalizarSusp(Config.suspensao.padrao),
        presets = Config.suspensao.presets,
        atual = info.susp,
        soPresets = info.soPresets,
    })
    SetNuiFocus(true, true)
end

RegisterNUICallback('suspPrevia', function(valores, cb)
    if not previa then return cb(nil) end
    previa.valores = NormalizarSusp(valores)
    cb(previa.valores)
end)

RegisterNUICallback('suspFechar', function(_, cb)
    cb(1)
    fecharPainel()
    previa = nil
end)

RegisterNUICallback('suspSalvar', function(valores, cb)
    cb(1)
    fecharPainel()
    local sessao = previa
    if not sessao or not DoesEntityExist(sessao.veh) then previa = nil return end
    sessao.valores = NormalizarSusp(valores)

    local ok = lib.progressCircle({
        duration = Config.suspensao.tempoRegular,
        label = 'Regulando a suspensão...',
        position = 'bottom',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = not cache.vehicle and { dict = 'mini@repair', clip = 'fixing_a_ped' } or nil,
    })
    if not ok then
        previa = nil
        return Avisar('Regulagem cancelada, a suspensão continua como estava', 'error')
    end

    local salvou, msg = lib.callback.await('pista_tuning:server:salvarSusp', false, sessao.netId, sessao.valores)
    Wait(300) -- espera o state bag chegar antes de soltar a prévia
    previa = nil
    Avisar(msg, salvou and 'success' or 'error')
end)

---------------------------------------------------------------------
-- Como abrir: /suspensao (dentro ou do lado do carro) ou Alt no carro
---------------------------------------------------------------------
RegisterCommand('suspensao', function()
    AbrirSuspensao(cache.vehicle or VeiculoProximo())
end, false)
TriggerEvent('chat:addSuggestion', '/suspensao', 'Regular a suspensão regulável do carro (dono ou mecânico)')

CreateThread(function()
    exports.ox_target:addGlobalVehicle({
        {
            name = 'pista_susp_regular',
            icon = 'fa-solid fa-arrows-up-down',
            label = 'Regular suspensão',
            distance = 3.0,
            canInteract = function(entity)
                return not cache.vehicle and not previa and DadosDo(entity).suspensao == true
            end,
            onSelect = function(data) AbrirSuspensao(data.entity) end,
        },
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if previa then SetNuiFocus(false, false) end
    for veh in pairs(basesRodas) do restaurarVisual(veh) end
    exports.ox_target:removeGlobalVehicle({ 'pista_susp_regular' })
end)
