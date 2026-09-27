-- pista_tuning - nitro

local STATE_KEY = 'pista_tuning'
local usando = false

local ESCAPES = { 'exhaust', 'exhaust_2', 'exhaust_3', 'exhaust_4' }

local function chamaEscapamento(veh)
    if not HasNamedPtfxAssetLoaded('core') then
        RequestNamedPtfxAsset('core')
        return
    end
    for _, bone in ipairs(ESCAPES) do
        local idx = GetEntityBoneIndexByName(veh, bone)
        if idx ~= -1 then
            UseParticleFxAssetNextCall('core')
            StartParticleFxNonLoopedOnEntityBone('veh_backfire', veh, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, idx, 1.3, false, false, false)
        end
    end
end

local function usarNitro()
    if usando then return end
    local veh = cache.vehicle
    if not veh or cache.seat ~= -1 then return end

    local dados = Entity(veh).state[STATE_KEY]
    if not dados or not dados.nitro then return end

    local carga = dados.nitroCarga or 0.0
    if carga <= 0.0 then
        return exports.qbx_core:Notify('Nitro vazio', 'error')
    end

    usando = true
    local gasto = 0.0
    local ultimo = GetGameTimer()
    local ultimaChama = 0

    CreateThread(function()
        SetTransitionTimecycleModifier('RaceTurbo', 0.5)
        while usando and cache.vehicle == veh and (carga - gasto) > 0.0 do
            local agora = GetGameTimer()
            gasto = gasto + Config.nitro.consumoPorSegundo * ((agora - ultimo) / 1000.0)
            ultimo = agora

            SetVehicleCheatPowerIncrease(veh, Config.nitro.potencia)
            if Config.nitro.efeitoEscapamento and agora - ultimaChama > 120 then
                ultimaChama = agora
                chamaEscapamento(veh)
            end
            Wait(0)
        end
        ClearTimecycleModifier()
        usando = false

        gasto = math.min(gasto, carga)
        if gasto > 0.0 then
            TriggerServerEvent('pista_tuning:server:usouNitro', VehToNet(veh), gasto)
        end
        if carga - gasto <= 0.0 then
            exports.qbx_core:Notify('Nitro acabou', 'inform')
        end
    end)
end

lib.addKeybind({
    name = 'pista_nitro',
    description = 'Usar nitro',
    defaultKey = Config.nitro.tecla,
    onPressed = usarNitro,
    onReleased = function() usando = false end,
})

-- Garrafa de nitro (chamado pelo ox_inventory)
exports('usarGarrafaNitro', function()
    local veh = cache.vehicle or lib.getClosestVehicle(GetEntityCoords(cache.ped), 4.0, false)
    if not veh then
        return exports.qbx_core:Notify('Nenhum veículo por perto', 'error')
    end

    exports.ox_inventory:closeInventory()
    local ok = lib.progressCircle({
        duration = 5000,
        label = 'Trocando garrafa de nitro...',
        position = 'bottom',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
    if not ok then return end

    local sucesso, msg = lib.callback.await('pista_tuning:server:recarregarNitro', false, VehToNet(veh))
    exports.qbx_core:Notify(msg or '', sucesso and 'success' or 'error')
end)
