-- pista_guincho - carregar e descarregar carro na plataforma

local STATE = 'pista_reboque' -- no guincho: netId do carro carregado
local ocupado = false
local posicao = Config.posicao

local function avisar(msg, tipo) exports.qbx_core:Notify(msg or '', tipo or 'inform') end

local function souMecanico()
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job
    if not job or job.name ~= Config.job then return false end
    return job.onduty or not Config.precisaServico
end

local function controle(ent)
    local limite = GetGameTimer() + 2000
    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < limite do
        Wait(10)
        NetworkRequestControlOfEntity(ent)
    end
    return NetworkHasControlOfEntity(ent)
end

--- Carro vazio parado atrás do guincho
local function carroAtras(guincho)
    local ponto = GetOffsetFromEntityInWorldCoords(guincho, 0.0, -7.0, 0.0)
    local melhor, melhorDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if veh ~= guincho and GetEntityModel(veh) ~= Config.modelo and not IsEntityAttached(veh) then
            local d = #(GetEntityCoords(veh) - ponto)
            if d <= Config.distanciaAtras and (not melhorDist or d < melhorDist) then melhor, melhorDist = veh, d end
        end
    end
    return melhor
end

local function carregado(guincho)
    local net = Entity(guincho).state[STATE]
    if not net then return nil end
    local veh = NetworkDoesNetworkIdExist(net) and NetToVeh(net) or 0
    return veh ~= 0 and DoesEntityExist(veh) and veh or nil
end

local function trabalhar(label)
    return lib.progressCircle({
        duration = Config.tempo, label = label, position = 'bottom',
        canCancel = true, disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    })
end

local function prender(guincho, carro)
    local osso = GetEntityBoneIndexByName(guincho, 'bodyshell')
    AttachEntityToEntity(carro, guincho, osso == -1 and 0 or osso, posicao.x, posicao.y, posicao.z,
        0.0, 0.0, 0.0, false, false, false, false, 2, true)
end

local function carregar(guincho)
    local carro = carroAtras(guincho)
    if not carro then return avisar('Deixe o carro logo atrás do guincho', 'error') end
    if GetPedInVehicleSeat(carro, -1) ~= 0 then return avisar('Tire o motorista do carro', 'error') end
    if not trabalhar('Prendendo o carro na plataforma...') then return end
    local ok, msg = lib.callback.await('pista_guincho:server:carregar', false, VehToNet(guincho), VehToNet(carro))
    if not ok then return avisar(msg, 'error') end
    if not controle(carro) then return avisar('Não foi possível mexer no carro', 'error') end
    prender(guincho, carro)
    avisar('Carro preso na plataforma', 'success')
end

local function descarregar(guincho)
    local carro = carregado(guincho)
    if not trabalhar('Soltando o carro...') then return end
    local ok, msg = lib.callback.await('pista_guincho:server:descarregar', false, VehToNet(guincho))
    if not ok then return avisar(msg, 'error') end
    if carro and controle(carro) then
        DetachEntity(carro, true, true)
        local atras = GetOffsetFromEntityInWorldCoords(guincho, 0.0, -9.0, 0.0)
        SetEntityCoords(carro, atras.x, atras.y, atras.z + 0.5, false, false, false, false)
        SetEntityHeading(carro, GetEntityHeading(guincho))
        SetVehicleOnGroundProperly(carro)
    end
    avisar('Carro descarregado atrás do guincho', 'success')
end

local function executar(fn, ...)
    if ocupado then return end
    ocupado = true
    local args = { ... }
    CreateThread(function()
        pcall(fn, table.unpack(args))
        ocupado = false
    end)
end

CreateThread(function()
    exports.ox_target:addModel(Config.modelo, {
        {
            name = 'pista_guincho_carregar',
            icon = 'fa-solid fa-truck-ramp-box',
            label = 'Carregar carro na plataforma',
            distance = 3.0,
            canInteract = function(guincho)
                return not ocupado and not cache.vehicle and souMecanico() and not Entity(guincho).state[STATE]
            end,
            onSelect = function(data) executar(carregar, data.entity) end,
        },
        {
            name = 'pista_guincho_descarregar',
            icon = 'fa-solid fa-truck-arrow-right',
            label = 'Descarregar carro',
            distance = 3.0,
            canInteract = function(guincho)
                return not ocupado and not cache.vehicle and souMecanico() and Entity(guincho).state[STATE] ~= nil
            end,
            onSelect = function(data) executar(descarregar, data.entity) end,
        },
    })
end)

-- Se o carro se soltar sozinho (outro jogador assumiu o controle), prende de novo
CreateThread(function()
    while true do
        Wait(1500)
        for _, guincho in ipairs(GetGamePool('CVehicle')) do
            if GetEntityModel(guincho) == Config.modelo then
                local carro = carregado(guincho)
                if carro and not IsEntityAttachedToEntity(carro, guincho) and NetworkHasControlOfEntity(carro) then
                    prender(guincho, carro)
                end
            end
        end
    end
end)

-- /ajusteguincho x y z (admin): muda onde o carro fica na plataforma, para testar
RegisterNetEvent('pista_guincho:client:ajuste', function(x, y, z)
    posicao = vec3(x + 0.0, y + 0.0, z + 0.0)
    for _, guincho in ipairs(GetGamePool('CVehicle')) do
        local carro = GetEntityModel(guincho) == Config.modelo and carregado(guincho)
        if carro and controle(carro) then prender(guincho, carro) end
    end
    avisar(('Config.posicao = vec3(%.2f, %.2f, %.2f)'):format(x, y, z), 'inform')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        exports.ox_target:removeModel(Config.modelo, { 'pista_guincho_carregar', 'pista_guincho_descarregar' })
    end
end)
