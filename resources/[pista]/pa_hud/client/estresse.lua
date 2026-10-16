-- pa_hud - estresse (veio do qbx_hud, que foi desligado)

local estresse = 0
local comArma = false

local function atualizarLocal()
    local st = LocalPlayer.state.stress
    if st == nil and QBX and QBX.PlayerData and QBX.PlayerData.metadata then
        st = QBX.PlayerData.metadata.stress
    end
    estresse = tonumber(st) or 0
end

AddStateBagChangeHandler('stress', ('player:%s'):format(cache.serverId), function(_, _, valor)
    estresse = tonumber(valor) or 0
end)

RegisterNetEvent('hud:client:UpdateStress', function(valor) estresse = tonumber(valor) or 0 end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() SetTimeout(1000, atualizarLocal) end)

if not Config.estresse.ativo then return end

---------------------------------------------------------------------
-- Ganho ao atirar
---------------------------------------------------------------------
local function armaLiberada(hash)
    for _, h in ipairs(Config.estresse.armasSemEstresse) do
        if hash == joaat(h) then return true end
    end
    return false
end

AddEventHandler('ox_inventory:currentWeapon', function(arma)
    comArma = false
    Wait(0)
    if not arma or armaLiberada(arma.hash) then return end
    comArma = true
    CreateThread(function()
        while comArma do
            if IsPedShooting(cache.ped) and math.random() <= Config.estresse.chanceTiro then
                TriggerServerEvent('hud:server:GainStress', math.random(1, 5))
            end
            Wait(0)
        end
    end)
end)

---------------------------------------------------------------------
-- Ganho em alta velocidade (sem cinto ganha mais fácil)
---------------------------------------------------------------------
CreateThread(function()
    local limite = Config.estresse.velocidade
    if not limite then return end
    while true do
        Wait(10000)
        local veh = cache.vehicle
        if veh and LocalPlayer.state.isLoggedIn then
            local classe = GetVehicleClass(veh)
            if classe ~= 13 and classe ~= 14 and classe ~= 15 and classe ~= 16 and classe ~= 21 then
                local kmh = GetEntitySpeed(veh) * 3.6
                local alvo = LocalPlayer.state.seatbelt and limite.comCinto or limite.semCinto
                if classe == 8 then alvo = limite.comCinto end
                if alvo and kmh >= alvo then
                    TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                end
            end
        end
    end
end)

---------------------------------------------------------------------
-- Efeitos na tela
---------------------------------------------------------------------
local function faixa(lista, valor, campo, padrao)
    for _, f in ipairs(lista) do
        if valor >= f.min and valor <= f.max then return f[campo] end
    end
    return padrao
end

CreateThread(function()
    Wait(3000)
    atualizarLocal()
    while true do
        local intervalo = faixa(Config.estresse.intervalo, estresse, 'tempo', 60000)
        local blur = faixa(Config.estresse.embacar, estresse, 'tempo', 1500)
        if estresse >= 100 then
            local quedas = math.random(2, 4)
            local tempoQueda = quedas * 1750
            TriggerScreenblurFadeIn(1000.0)
            Wait(blur)
            TriggerScreenblurFadeOut(1000.0)
            if not IsPedRagdoll(cache.ped) and IsPedOnFoot(cache.ped) and not IsPedSwimming(cache.ped) then
                local f = GetEntityForwardVector(cache.ped)
                SetPedToRagdollWithFall(cache.ped, tempoQueda, tempoQueda, 1, f.x, f.y, f.z, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
            end
            Wait(1000)
            for _ = 1, quedas do
                Wait(750)
                DoScreenFadeOut(200)
                Wait(1000)
                DoScreenFadeIn(200)
                TriggerScreenblurFadeIn(1000.0)
                Wait(blur)
                TriggerScreenblurFadeOut(1000.0)
            end
        elseif estresse >= Config.estresse.minimoEfeito then
            TriggerScreenblurFadeIn(1000.0)
            Wait(blur)
            TriggerScreenblurFadeOut(1000.0)
        end
        Wait(intervalo)
    end
end)
