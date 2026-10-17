-- pa_policia · cliente · abordagem
-- Opções no olho (ox_target) em jogadores e veículos, efeitos de algemado/conduzido, mãos para cima.

local DEATH_BAG = 'qbx_medical:deathState'
local conduzidoPor = nil

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local function idDoPed(ped)
    local jogador = NetworkGetPlayerIndexFromPed(ped)
    if not jogador or jogador == -1 then return nil end
    return GetPlayerServerId(jogador)
end

local function estado(id)
    return Player(id).state
end

local function alvoAlgemado(id) return estado(id).pa_algema ~= nil end
local function alvoDesmaiado(id)
    local e = estado(id)[DEATH_BAG]
    return e == 2 or e == 3
end
local function alvoRendido(id) return estado(id).pa_rendido == true end

local function chamar(cb, ...)
    local ok, msg = lib.callback.await(cb, false, ...)
    PC.Resultado(ok, msg)
    return ok, msg
end

local function animPolicial()
    lib.requestAnimDict('mp_arresting')
    TaskPlayAnim(cache.ped, 'mp_arresting', 'a_uncuff', 8.0, -8.0, 3000, 48, 0, false, false, false)
    RemoveAnimDict('mp_arresting')
end

local function viaturaPerto()
    local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 6.0, false)
    return veh
end

---------------------------------------------------------------------
-- OLHO NOS JOGADORES
---------------------------------------------------------------------
exports.ox_target:addGlobalPlayer({
    {
        name = 'pa_policia_algemar', icon = 'fa-solid fa-handcuffs', label = 'Algemar / desalgemar',
        distance = Config.abordagem.distancia,
        canInteract = function() return PC.Pode('algemar') end,
        onSelect = function(data)
            local id = idDoPed(data.entity)
            if not id then return end
            if not alvoAlgemado(id) then animPolicial() end
            chamar('pa_policia:server:algemar', id, false)
        end,
    },
    {
        name = 'pa_policia_algema_leve', icon = 'fa-solid fa-hands-bound', label = 'Algemar com as mãos à frente',
        distance = Config.abordagem.distancia,
        canInteract = function(ent)
            if not PC.Pode('algemar') then return false end
            local id = idDoPed(ent)
            return id and not alvoAlgemado(id)
        end,
        onSelect = function(data)
            local id = idDoPed(data.entity)
            if not id then return end
            animPolicial()
            chamar('pa_policia:server:algemar', id, true)
        end,
    },
    {
        name = 'pa_policia_conduzir', icon = 'fa-solid fa-person-walking-arrow-right', label = 'Conduzir / soltar',
        distance = Config.abordagem.distancia,
        canInteract = function(ent)
            if not PC.Pode('algemar') then return false end
            local id = idDoPed(ent)
            return id and (alvoAlgemado(id) or alvoDesmaiado(id))
        end,
        onSelect = function(data)
            local id = idDoPed(data.entity)
            if id then chamar('pa_policia:server:conduzir', id) end
        end,
    },
    {
        name = 'pa_policia_viatura', icon = 'fa-solid fa-car-side', label = 'Colocar na viatura',
        distance = Config.abordagem.distancia,
        canInteract = function(ent)
            if not PC.Pode('algemar') then return false end
            local id = idDoPed(ent)
            return id and (alvoAlgemado(id) or alvoDesmaiado(id)) and viaturaPerto() ~= nil
        end,
        onSelect = function(data)
            local id = idDoPed(data.entity)
            local veh = viaturaPerto()
            if id and veh then chamar('pa_policia:server:colocarVeiculo', id, NetworkGetNetworkIdFromEntity(veh)) end
        end,
    },
    {
        name = 'pa_policia_revistar', icon = 'fa-solid fa-magnifying-glass', label = 'Revistar',
        distance = Config.abordagem.distancia,
        canInteract = function(ent)
            if not PC.Pode('revistar') then return false end
            local id = idDoPed(ent)
            return id and (alvoAlgemado(id) or alvoDesmaiado(id) or alvoRendido(id))
        end,
        onSelect = function(data)
            local id = idDoPed(data.entity)
            if not id then return end
            if lib.progressCircle({
                duration = Config.abordagem.tempoRevista, label = 'Revistando...', position = 'bottom',
                canCancel = true, disable = { move = true, car = true, combat = true },
                anim = { dict = 'anim@gangops@facility@servers@bodysearch@', clip = 'player_search' },
            }) then
                chamar('pa_policia:server:revistar', id)
            end
        end,
    },
    {
        name = 'pa_policia_apreender', icon = 'fa-solid fa-box-open', label = 'Apreender itens ilegais',
        distance = Config.abordagem.distancia,
        canInteract = function(ent)
            if not PC.Pode('apreender') then return false end
            local id = idDoPed(ent)
            return id and (alvoAlgemado(id) or alvoDesmaiado(id) or alvoRendido(id))
        end,
        onSelect = function(data)
            local id = idDoPed(data.entity)
            if id then chamar('pa_policia:server:apreender', id) end
        end,
    },
    {
        name = 'pa_policia_polvora', icon = 'fa-solid fa-flask', label = 'Teste de pólvora',
        distance = Config.abordagem.distancia,
        canInteract = function() return PC.Pode('pericia') end,
        onSelect = function(data)
            local id = idDoPed(data.entity)
            if not id then return end
            if lib.progressCircle({ duration = 3000, label = 'Coletando resíduo...', position = 'bottom', canCancel = true,
                disable = { move = true, combat = true } }) then
                local ok, msg = lib.callback.await('pa_policia:server:testePolvora', false, id)
                if msg then PC.Aviso(msg, ok and 'inform' or 'error', 7000) end
            end
        end,
    },
    {
        name = 'pa_policia_ficha', icon = 'fa-solid fa-id-card', label = 'Ficha / multar / pena (tablet)',
        distance = 3.0,
        canInteract = function() return PC.EmServico() end,
        onSelect = function(data)
            local id = idDoPed(data.entity)
            if id then TriggerEvent('pa_policia:client:abrirMdt', { aba = 'pessoa', alvo = id }) end
        end,
    },
})

---------------------------------------------------------------------
-- OLHO NOS VEÍCULOS
---------------------------------------------------------------------
local function temGenteAtras(veh)
    for i = 1, GetVehicleMaxNumberOfPassengers(veh) do
        local ped = GetPedInVehicleSeat(veh, i)
        if ped ~= 0 and IsPedAPlayer(ped) then return true end
    end
    local ped = GetPedInVehicleSeat(veh, 0)
    return ped ~= 0 and IsPedAPlayer(ped)
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'pa_policia_tirar', icon = 'fa-solid fa-person-walking-arrow-loop-left', label = 'Tirar do veículo',
        distance = 3.0,
        canInteract = function(ent) return PC.Pode('algemar') and temGenteAtras(ent) end,
        onSelect = function(data)
            local opcoes = {}
            for i = -1, GetVehicleMaxNumberOfPassengers(data.entity) do
                local ped = GetPedInVehicleSeat(data.entity, i)
                local id = ped ~= 0 and IsPedAPlayer(ped) and idDoPed(ped)
                if id and id ~= cache.serverId then
                    opcoes[#opcoes + 1] = {
                        title = ('ID %d%s'):format(id, alvoAlgemado(id) and ' (algemado)' or ''),
                        icon = 'person', onSelect = function() chamar('pa_policia:server:tirarVeiculo', id) end,
                    }
                end
            end
            if #opcoes == 0 then return end
            lib.registerContext({ id = 'pa_policia_tirar', title = 'Tirar do veículo', options = opcoes })
            lib.showContext('pa_policia_tirar')
        end,
    },
    {
        name = 'pa_policia_vistoria', icon = 'fa-solid fa-clipboard-check', label = 'Vistoria veicular',
        distance = 3.5,
        canInteract = function() return PC.Pode('vistoria') end,
        onSelect = function(data) TriggerEvent('pa_policia:client:vistoria', data.entity) end,
    },
    {
        name = 'pa_policia_patio', icon = 'fa-solid fa-truck-pickup', label = 'Mandar para o pátio',
        distance = 3.5,
        canInteract = function() return PC.Pode('patio') end,
        onSelect = function(data) TriggerEvent('pa_policia:client:menuPatio', data.entity) end,
    },
    {
        name = 'pa_policia_digital', icon = 'fa-solid fa-fingerprint', label = 'Coletar digital do volante',
        distance = 3.0,
        canInteract = function() return PC.Pode('pericia') end,
        onSelect = function(data)
            if lib.progressCircle({ duration = 5000, label = 'Coletando digital...', position = 'bottom', canCancel = true,
                disable = { move = true, combat = true }, anim = { dict = 'amb@prop_human_bum_bin@base', clip = 'base' } }) then
                chamar('pa_policia:server:coletarDigital', NetworkGetNetworkIdFromEntity(data.entity))
            end
        end,
    },
    {
        name = 'pa_policia_placa', icon = 'fa-solid fa-magnifying-glass', label = 'Consultar placa (tablet)',
        distance = 4.0,
        canInteract = function() return PC.EmServico() end,
        onSelect = function(data)
            TriggerEvent('pa_policia:client:abrirMdt', { aba = 'veiculo', placa = GetVehicleNumberPlateText(data.entity) })
        end,
    },
})

AddEventHandler('pa_policia:client:menuPatio', function(veh)
    local net = NetworkGetNetworkIdFromEntity(veh)
    local opcoes = {
        { title = 'Pátio (retirada paga)', description = ('O dono retira no Impound Lot pagando $%d.'):format(Config.patio.taxa), icon = 'square-parking',
          onSelect = function()
              local r = lib.inputDialog('Pátio', { { type = 'input', label = 'Motivo', required = true, min = 3, max = 120 } })
              if r then chamar('pa_policia:server:patio', net, 'patio', r[1]) end
          end },
    }
    if PC.Pode('apreender') then
        opcoes[#opcoes + 1] = { title = 'Reter (apreensão)', description = 'Só sai quando um Tenente+ liberar pelo tablet.', icon = 'lock',
          onSelect = function()
              local r = lib.inputDialog('Reter veículo', { { type = 'input', label = 'Motivo', required = true, min = 3, max = 120 } })
              if r then chamar('pa_policia:server:patio', net, 'retido', r[1]) end
          end }
    end
    lib.registerContext({ id = 'pa_policia_patio', title = ('Pátio · %s'):format(GetVehicleNumberPlateText(veh)), options = opcoes })
    lib.showContext('pa_policia_patio')
end)

---------------------------------------------------------------------
-- QUEM ESTÁ ALGEMADO
---------------------------------------------------------------------
RegisterNetEvent('pa_policia:client:animAlgema', function(policial, algemando)
    if GetInvokingResource() then return end
    if not algemando then
        ClearPedTasksImmediately(cache.ped)
        return
    end
    local pol = GetPlayerPed(GetPlayerFromServerId(policial))
    if pol and pol ~= 0 then
        local h = GetEntityHeading(pol)
        local pos = GetOffsetFromEntityInWorldCoords(pol, 0.0, 0.45, 0.0)
        SetEntityCoords(cache.ped, pos.x, pos.y, pos.z - 1.0, true, false, false, false)
        SetEntityHeading(cache.ped, h)
    end
    lib.requestAnimDict('mp_arrest_paired')
    TaskPlayAnim(cache.ped, 'mp_arrest_paired', 'crook_p2_back_right', 3.0, 3.0, -1, 32, 0, false, false, false)
    Wait(2500)
    RemoveAnimDict('mp_arrest_paired')
end)

local function algemado()
    return LocalPlayer.state.pa_algema
end

CreateThread(function()
    while true do
        local tipo = algemado()
        if not tipo then
            Wait(500)
        else
            Wait(0)
            DisableControlAction(0, 24, true)  -- atacar
            DisableControlAction(0, 25, true)  -- mirar
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            DisableControlAction(0, 37, true)  -- roda de armas
            DisableControlAction(0, 23, true)  -- entrar em veículo
            DisableControlAction(0, 75, true)  -- sair do veículo
            DisableControlAction(27, 75, true)
            DisableControlAction(0, 289, true) -- inventário (F2)
            DisableControlAction(0, 170, true)
            DisableControlAction(0, 167, true)
            if tipo == 'total' then
                DisableControlAction(0, 21, true) -- correr
                DisableControlAction(0, 22, true) -- pular
            end
            SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
            local st = LocalPlayer.state[DEATH_BAG]
            local desmaiado = st == 2 or st == 3
            if not desmaiado and not cache.vehicle then
                local dict, clip = 'mp_arresting', 'idle'
                if not IsEntityPlayingAnim(cache.ped, dict, clip, 3) and not IsEntityPlayingAnim(cache.ped, 'mp_arrest_paired', 'crook_p2_back_right', 3) then
                    lib.requestAnimDict(dict)
                    TaskPlayAnim(cache.ped, dict, clip, 8.0, -8.0, -1, 49, 0, false, false, false)
                end
            end
        end
    end
end)

-- inventário e celular bloqueados enquanto algemado
AddStateBagChangeHandler('pa_algema', ('player:%s'):format(cache.serverId), function(_, _, valor)
    LocalPlayer.state:set('invBusy', valor ~= nil, false)
    if valor == nil then
        ClearPedTasks(cache.ped)
    end
end)

---------------------------------------------------------------------
-- CONDUZIDO
---------------------------------------------------------------------
AddStateBagChangeHandler('pa_conduzido', ('player:%s'):format(cache.serverId), function(_, _, valor)
    conduzidoPor = valor
    if not valor then
        DetachEntity(cache.ped, true, false)
        return
    end
    CreateThread(function()
        while conduzidoPor == valor do
            local pol = GetPlayerPed(GetPlayerFromServerId(valor))
            if pol == 0 or not DoesEntityExist(pol) then break end
            if not IsEntityAttachedToEntity(cache.ped, pol) then
                AttachEntityToEntity(cache.ped, pol, 11816, 0.45, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            end
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            Wait(0)
        end
        DetachEntity(cache.ped, true, false)
    end)
end)

RegisterNetEvent('pa_policia:client:entrarVeiculo', function(net)
    if GetInvokingResource() then return end
    local veh = NetworkGetEntityFromNetworkId(net)
    if not veh or veh == 0 then return end
    conduzidoPor = nil
    DetachEntity(cache.ped, true, false)
    for _, banco in ipairs({ 2, 1, 0 }) do
        if IsVehicleSeatFree(veh, banco) then
            ClearPedTasksImmediately(cache.ped)
            SetPedIntoVehicle(cache.ped, veh, banco)
            return
        end
    end
end)

RegisterNetEvent('pa_policia:client:sairVeiculo', function()
    if GetInvokingResource() then return end
    if not cache.vehicle then return end
    TaskLeaveVehicle(cache.ped, cache.vehicle, 16)
end)

---------------------------------------------------------------------
-- COMPATIBILIDADE (pa_medico e scripts que chamavam o qbx_police)
---------------------------------------------------------------------
-- pa_medico: ao acordar no hospital, solta a algema e a condução
AddEventHandler('police:client:GetCuffed', function(policial)
    if policial == -1 and algemado() then TriggerServerEvent('pa_policia:server:soltarAoAcordar') end
end)
AddEventHandler('police:client:DeEscort', function()
    if conduzidoPor then DetachEntity(cache.ped, true, false) end
end)

exports('IsHandcuffed', function() return algemado() ~= nil end)
exports('estaAlgemado', function() return algemado() ~= nil end)

---------------------------------------------------------------------
-- MÃOS PARA CIMA (X) - deixa ser revistado sem algema
---------------------------------------------------------------------
local rendido = false
lib.addKeybind({
    name = 'pa_policia_rendido',
    description = 'Mãos para cima (rendido)',
    defaultKey = 'X',
    onPressed = function()
        if algemado() or cache.vehicle or IsPedRagdoll(cache.ped) then return end
        rendido = not rendido
        LocalPlayer.state:set('pa_rendido', rendido, true)
        if rendido then
            lib.requestAnimDict('missminuteman_1ig_2')
            TaskPlayAnim(cache.ped, 'missminuteman_1ig_2', 'handsup_base', 8.0, -8.0, -1, 49, 0, false, false, false)
        else
            ClearPedSecondaryTask(cache.ped)
        end
    end,
})

CreateThread(function()
    while true do
        Wait(250)
        if rendido and (not IsEntityPlayingAnim(cache.ped, 'missminuteman_1ig_2', 'handsup_base', 3) or cache.vehicle) then
            rendido = false
            LocalPlayer.state:set('pa_rendido', false, true)
        end
    end
end)
