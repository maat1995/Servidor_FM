-- pa_roubocarro · cliente · tablet (NUI)

local aberto = false
local prop

local function animTablet(ligar)
    if ligar then
        lib.requestAnimDict('amb@code_human_in_bus_passenger_idles@female@tablet@base')
        lib.requestModel(`prop_cs_tablet`)
        prop = CreateObject(`prop_cs_tablet`, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(prop, cache.ped, GetPedBoneIndex(cache.ped, 60309), 0.03, 0.002, 0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
        TaskPlayAnim(cache.ped, 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 3.0, 3.0, -1, 49, 0, false, false, false)
        SetModelAsNoLongerNeeded(`prop_cs_tablet`)
    else
        if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
        prop = nil
        StopAnimTask(cache.ped, 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 1.0)
    end
end

local function dados()
    return lib.callback.await('pa_roubocarro:server:tablet', false)
end

local function fechar()
    if not aberto then return end
    aberto = false
    SetNuiFocus(false, false)
    SendNUIMessage({ acao = 'fechar' })
    if not cache.vehicle then animTablet(false) end
end

local function abrir()
    if aberto then return end
    local d = dados()
    if not d then return RCc.Notificar('Você não está com o tablet.', 'error') end
    aberto = true
    if not cache.vehicle then animTablet(true) end
    SetNuiFocus(true, true)
    SendNUIMessage({ acao = 'abrir', dados = d })
end

function RCc.AtualizarTabletAberto()
    if not aberto then return end
    local d = dados()
    if d then SendNUIMessage({ acao = 'atualizar', dados = d }) end
end

RegisterNetEvent('pa_roubocarro:client:atualizar', function()
    if GetInvokingResource() then return end
    RCc.AtualizarTabletAberto()
end)

-- usado pelo ox_inventory (item tablet_roubo)
exports('usarTablet', function()
    abrir()
end)

RegisterNUICallback('fechar', function(_, cb)
    fechar()
    cb(1)
end)

RegisterNUICallback('acao', function(req, cb)
    local ok, msg = lib.callback.await('pa_roubocarro:server:acao', false, req.nome, req.args or {})
    if msg then RCc.Notificar(msg, ok and 'success' or 'error') end
    cb({ ok = ok == true })
    local d = dados()
    if d and aberto then SendNUIMessage({ acao = 'atualizar', dados = d }) end
end)

RegisterNUICallback('rastreador', function(req, cb)
    cb(1)
    fechar()
    RCc.DesligarRastreador(tonumber(req.etapas))
end)

RegisterNUICallback('gps', function(_, cb)
    cb(1)
    local ct = RCc.contrato
    if not ct then return end
    local alvo = ct.entrega or ct.area
    if alvo then
        SetNewWaypoint(alvo.x, alvo.y)
        RCc.Notificar('GPS marcado.', 'success')
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if aberto then SetNuiFocus(false, false) end
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
end)
