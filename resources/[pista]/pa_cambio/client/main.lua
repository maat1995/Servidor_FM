-- pa_cambio - cliente
-- Marcha: 0 = neutro (N) | -1 = ré (R) | 1..N = marchas à frente

local NEUTRO, RE = 0, -1

local marcha = NEUTRO
local carroAtual = nil
local corteAte = 0          -- até quando a aceleração fica cortada (troca/limitador)
local rpmNeutro = 0.2
local limites = {}          -- [modelo][marcha] = maior velocidade (m/s) vista no limitador

local modelosAuto = {}
for _, nome in ipairs(Config.modelosAutomaticos) do modelosAuto[joaat(nome)] = true end

-- Controles do GTA
local ACELERAR, FREAR = 71, 72
local RADIO_PROX, RADIO_ANT = 81, 82
local CONFLITOS = { 21, 36, 61, 62 } -- correr, agachar, subir/descer (Shift/Ctrl)

---------------------------------------------------------------------
-- O carro é manual?
---------------------------------------------------------------------
local function empregoAutomatico()
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job
    return job ~= nil and job.onduty == true and Config.empregosAutomaticos[job.name] == true
end

local function ehManual(veh)
    if not Config.ativo or not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    if Config.classesAutomaticas[GetVehicleClass(veh)] then return false end
    if modelosAuto[GetEntityModel(veh)] then return false end
    local st = Entity(veh).state
    if st.pa_cambio_auto then return false end
    local prep = st.pista_tuning
    if type(prep) == 'table' and prep.automatico then return false end
    if empregoAutomatico() then return false end
    return true
end
exports('ehManual', ehManual)

local function souMotorista(veh)
    return veh and cache.vehicle == veh and cache.seat == -1
end

--- Para a HUD: 'N', 'R', '1'... ou nil (carro automático / não sou o motorista)
exports('marcha', function(veh)
    veh = veh or cache.vehicle
    if not souMotorista(veh) or not ehManual(veh) then return nil end
    if not GetIsVehicleEngineRunning(veh) then return '-' end
    if marcha == NEUTRO then return 'N' end
    if marcha == RE then return 'R' end
    return tostring(marcha)
end)

---------------------------------------------------------------------
-- Troca de marcha
---------------------------------------------------------------------
local function velocidadeFrente(veh)
    return GetEntitySpeedVector(veh, true).y -- m/s; negativo = andando de ré
end

local function maxMarchas(veh)
    local n = GetVehicleHighGear(veh)
    if not n or n < 1 then n = 5 end
    return n
end

local function avisar(msg, tipo)
    exports.qbx_core:Notify(msg, tipo or 'inform', 2500)
end

local function podeTrocar()
    local veh = cache.vehicle
    if not souMotorista(veh) or not ehManual(veh) then return nil end
    if IsPauseMenuActive() or IsNuiFocused() then return nil end
    return veh
end

local function trocar(nova, veh)
    if nova == marcha then return end
    marcha = nova
    corteAte = GetGameTimer() + Config.tempoTroca
end

local function subir()
    local veh = podeTrocar()
    if not veh then return end
    if marcha == RE then
        trocar(NEUTRO, veh)
    elseif marcha < maxMarchas(veh) then
        trocar(marcha + 1, veh)
    end
end

local function descer()
    local veh = podeTrocar()
    if not veh then return end
    if marcha == RE then return end
    if marcha == NEUTRO then
        if velocidadeFrente(veh) > 2.0 then
            return avisar('Pare o carro para engatar a ré', 'error')
        end
        return trocar(RE, veh)
    end
    local nova = marcha - 1
    if nova >= 1 and Config.protegerReducao then
        local lim = limites[GetEntityModel(veh)]
        local max = lim and lim[nova]
        if max and velocidadeFrente(veh) > max * 1.05 then
            return avisar(('Giro alto demais para a %dª'):format(nova), 'error')
        end
    end
    trocar(nova, veh)
end

lib.addKeybind({
    name = 'pa_cambio_subir',
    description = 'Câmbio manual: subir marcha',
    defaultKey = Config.teclas.subir,
    secondaryMapper = Config.teclas.controle and 'PAD_DIGITALBUTTON' or nil,
    secondaryKey = Config.teclas.controle and Config.teclas.controle.subir or nil,
    onPressed = subir,
})

lib.addKeybind({
    name = 'pa_cambio_descer',
    description = 'Câmbio manual: descer marcha',
    defaultKey = Config.teclas.descer,
    secondaryMapper = Config.teclas.controle and 'PAD_DIGITALBUTTON' or nil,
    secondaryKey = Config.teclas.controle and Config.teclas.controle.descer or nil,
    onPressed = descer,
})

---------------------------------------------------------------------
-- Entrou/saiu do carro: sempre neutro
---------------------------------------------------------------------
lib.onCache('vehicle', function()
    marcha = NEUTRO
    carroAtual = nil
end)
lib.onCache('seat', function()
    marcha = NEUTRO
end)

---------------------------------------------------------------------
-- Laço do câmbio (todo frame enquanto dirige um carro manual)
---------------------------------------------------------------------
local function aprenderLimite(veh, velocidade)
    local modelo = GetEntityModel(veh)
    limites[modelo] = limites[modelo] or {}
    local atual = limites[modelo][marcha]
    if not atual or velocidade > atual then limites[modelo][marcha] = velocidade end
end

local function frameManual(veh)
    local agora = GetGameTimer()
    local vel = velocidadeFrente(veh)

    for _, c in ipairs(CONFLITOS) do DisableControlAction(0, c, true) end
    if Config.teclas.controle and not IsUsingKeyboard(0) then
        DisableControlAction(0, RADIO_PROX, true)
        DisableControlAction(0, RADIO_ANT, true)
    end

    if not GetIsVehicleEngineRunning(veh) then
        marcha = NEUTRO -- liga sempre em neutro
        return
    end

    if marcha == NEUTRO then
        -- Motor solto: acelera no vazio, o carro não anda
        DisableControlAction(0, ACELERAR, true)
        if vel < 0.5 then DisableControlAction(0, FREAR, true) end -- S parado não vira ré
        local pedal = GetDisabledControlNormal(0, ACELERAR)
        local alvo = 0.2 + 0.8 * pedal
        rpmNeutro = rpmNeutro + (alvo - rpmNeutro) * (alvo > rpmNeutro and 0.12 or 0.05)
        if rpmNeutro >= Config.limitador.rpm then rpmNeutro = 0.9 end -- bate no limitador
        SetVehicleCurrentRpm(veh, rpmNeutro)
        return
    end

    rpmNeutro = math.max(0.2, GetVehicleCurrentRpm(veh))

    if marcha == RE then
        -- Ré: anda segurando S; W não leva o carro para frente
        if vel > -0.5 then DisableControlAction(0, ACELERAR, true) end
        return
    end

    -- Marchas à frente: prende a marcha escolhida
    SetVehicleNextGear(veh, marcha)
    SetVehicleCurrentGear(veh, marcha)
    if vel < 0.5 then DisableControlAction(0, FREAR, true) end -- S parado não vira ré

    local pedal = GetControlNormal(0, ACELERAR)

    -- Saiu parado com marcha alta
    if Config.morrerSaidaAlta and marcha > Config.marchaMaxSaida and vel < 1.0 and pedal > 0.3 then
        SetVehicleEngineOn(veh, false, true, true)
        marcha = NEUTRO
        avisar('O motor morreu. Saia de 1ª ou 2ª', 'error')
        return
    end

    -- Limitador de giro
    if GetVehicleCurrentRpm(veh) >= Config.limitador.rpm and pedal > 0.1 then
        aprenderLimite(veh, vel)
        corteAte = math.max(corteAte, agora + Config.limitador.corte)
    end

    if agora < corteAte then DisableControlAction(0, ACELERAR, true) end
end

CreateThread(function()
    local manual, checado = false, 0
    while true do
        local veh = cache.vehicle
        if veh and cache.seat == -1 then
            -- Rever se é manual de vez em quando (peça instalada, entrou em serviço...)
            local agora = GetGameTimer()
            if carroAtual ~= veh or agora - checado > 300 then
                manual, checado = ehManual(veh), agora
                if carroAtual ~= veh then
                    carroAtual = veh
                    marcha = NEUTRO
                end
            end
        else
            manual, carroAtual = false, nil
        end

        if manual then
            frameManual(veh)
            Wait(0)
        else
            Wait(veh and 300 or 500)
        end
    end
end)
