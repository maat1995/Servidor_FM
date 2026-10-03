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

--- Guincho vazio mais perto do carro
local function guinchoPerto(carro)
    local c = GetEntityCoords(carro)
    local melhor, melhorDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if GetEntityModel(veh) == Config.modelo and veh ~= carro and not Entity(veh).state[STATE] then
            local d = #(GetEntityCoords(veh) - c)
            if d <= Config.distanciaGuincho and (not melhorDist or d < melhorDist) then melhor, melhorDist = veh, d end
        end
    end
    return melhor
end

local function carregar(guincho, carro)
    carro = carro or carroAtras(guincho)
    if not carro then return avisar('Deixe o carro perto da traseira do guincho', 'error') end
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
    -- Alt no carro quebrado: coloca no guincho vazio mais perto
    exports.ox_target:addGlobalVehicle({
        {
            name = 'pista_guincho_colocar',
            icon = 'fa-solid fa-truck-pickup',
            label = 'Colocar no guincho',
            distance = 3.0,
            canInteract = function(carro)
                return not ocupado and not cache.vehicle and souMecanico() and GetEntityModel(carro) ~= Config.modelo
                    and not IsEntityAttached(carro) and guinchoPerto(carro) ~= nil
            end,
            onSelect = function(data)
                local guincho = guinchoPerto(data.entity)
                if guincho then executar(carregar, guincho, data.entity) end
            end,
        },
    })

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
        exports.ox_target:removeGlobalVehicle({ 'pista_guincho_colocar' })
    end
end)

-- /guinchodebug: mostra por que a opção não aparece
RegisterCommand('guinchodebug', function()
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job
    local eu = GetEntityCoords(cache.ped)
    local guincho, dg
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if GetEntityModel(veh) == Config.modelo then
            local d = #(GetEntityCoords(veh) - eu)
            if not dg or d < dg then guincho, dg = veh, d end
        end
    end
    local carro = lib.getClosestVehicle(eu, 6.0, false)
    local linhas = {
        ('Emprego: %s | em serviço: %s | pode usar: %s'):format(job and job.name or '?', tostring(job and job.onduty), tostring(souMecanico())),
        guincho and ('Guincho mais perto: %.1f m | carregado: %s'):format(dg, tostring(Entity(guincho).state[STATE] ~= nil))
            or 'Nenhum guincho (modelo flatbed) encontrado por perto',
        carro and ('Carro mais perto: %s | é o guincho: %s | preso: %s | guincho vazio a até %.0f m: %s'):format(
            GetDisplayNameFromVehicleModel(GetEntityModel(carro)), tostring(carro == guincho),
            tostring(IsEntityAttached(carro)), Config.distanciaGuincho, tostring(guinchoPerto(carro) ~= nil))
            or 'Nenhum carro perto',
    }
    lib.alertDialog({ header = 'Diagnóstico do guincho', content = table.concat(linhas, '  \n'), centered = true })
end, false)

---------------------------------------------------------------------
-- [E] perto do carro: colocar no guincho / descarregar
---------------------------------------------------------------------
local function texto3D(pos, texto)
    SetDrawOrigin(pos.x, pos.y, pos.z, 0)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 235)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(texto)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

CreateThread(function()
    local alvo, acao, guinchoAlvo
    local proxima = 0
    while true do
        local espera = 400
        if not cache.vehicle and not ocupado then
            if GetGameTimer() >= proxima then
                proxima = GetGameTimer() + 250
                alvo, acao, guinchoAlvo = nil, nil, nil
                local eu = GetEntityCoords(cache.ped)
                -- guincho carregado perto: descarregar
                for _, veh in ipairs(GetGamePool('CVehicle')) do
                    if GetEntityModel(veh) == Config.modelo and Entity(veh).state[STATE]
                        and #(GetEntityCoords(veh) - eu) <= 6.0 then
                        alvo, acao, guinchoAlvo = veh, 'descarregar', veh
                        break
                    end
                end
                -- carro perto com guincho vazio por perto: colocar
                if not alvo then
                    local carro = lib.getClosestVehicle(eu, 3.5, false)
                    if carro and GetEntityModel(carro) ~= Config.modelo and not IsEntityAttached(carro) then
                        local g = guinchoPerto(carro)
                        if g then alvo, acao, guinchoAlvo = carro, 'carregar', g end
                    end
                end
            end
            if alvo and DoesEntityExist(alvo) then
                espera = 0
                local c = GetEntityCoords(alvo)
                texto3D(vec3(c.x, c.y, c.z + 1.2), acao == 'carregar' and '[E] Colocar no guincho' or '[E] Descarregar o carro')
                if IsControlJustReleased(0, 38) then
                    if not souMecanico() then
                        avisar('Só mecânico em serviço pode usar o guincho (use /servico)', 'error')
                    elseif acao == 'carregar' then
                        executar(carregar, guinchoAlvo, alvo)
                    else
                        executar(descarregar, guinchoAlvo)
                    end
                end
            end
        end
        Wait(espera)
    end
end)
