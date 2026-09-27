-- pista_tuning - guincho da oficina, motor pendurado e bancada

local STATE_GUINCHO = 'pista_guincho'
local STATE_MOTOR = 'pista_motor'

local ANIM_AGACHADO = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' }
local ANIM_EMPURRAR = { dict = 'anim@heists@box_carry@', clip = 'idle' }

---------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------
local function pedirControle(ent)
    if not DoesEntityExist(ent) then return false end
    local limite = GetGameTimer() + 2000
    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < limite do
        Wait(10)
        NetworkRequestControlOfEntity(ent)
    end
    return NetworkHasControlOfEntity(ent)
end

local function entidadeDaRede(netId)
    local limite = GetGameTimer() + 3000
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < limite do Wait(10) end
    if not NetworkDoesNetworkIdExist(netId) then return nil end
    return NetworkGetEntityFromNetworkId(netId)
end

local function estadoGuincho(ent) return Entity(ent).state[STATE_GUINCHO] end
local function estadoMotor(ent) return Entity(ent).state[STATE_MOTOR] end

local function frenteDo(veh)
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, 2.2, 0.0)
end

local function objetosPerto(modelo, stateKey, coords, dist)
    local achados = {}
    for _, obj in ipairs(GetGamePool('CObject')) do
        if GetEntityModel(obj) == modelo and Entity(obj).state[stateKey] then
            local d = #(GetEntityCoords(obj) - coords)
            if d <= dist then achados[#achados + 1] = { obj = obj, dist = d } end
        end
    end
    table.sort(achados, function(a, b) return a.dist < b.dist end)
    return achados
end

--- Guincho parado perto. motor: false = vazio | string = com o motor dessa placa
local function guinchoParado(coords, dist, motor)
    for _, g in ipairs(objetosPerto(Config.motor.propGuincho, STATE_GUINCHO, coords, dist)) do
        local st = estadoGuincho(g.obj)
        local motorOk = (motor == false and not st.motor) or (st.motor == motor)
        if not st.carregadoPor and motorOk then return g.obj end
    end
end

local function pertoDeBancada(coords)
    for _, b in ipairs(Config.bancadas) do
        if #(coords - vec3(b.x, b.y, b.z)) <= Config.motor.distanciaBancada then return true end
    end
    return false
end

local function pendurarNoGancho(motor, guincho)
    if not pedirControle(motor) then return false end
    local g = Config.motor.gancho
    FreezeEntityPosition(motor, false)
    AttachEntityToEntity(motor, guincho, 0, g.pos.x, g.pos.y, g.pos.z, g.rot.x, g.rot.y, g.rot.z,
        false, false, false, false, 2, true)
    return true
end

---------------------------------------------------------------------
-- Esconde o guincho que já vem no MLO (o nosso nasce no lugar dele)
---------------------------------------------------------------------
CreateThread(function()
    if not Config.motor.esconderGuinchoDoMapa then return end
    for _, p in ipairs(Config.guinchos) do
        CreateModelHide(p.x, p.y, p.z, 2.0, Config.motor.propGuincho, true)
    end
end)

---------------------------------------------------------------------
-- Empurrar o guincho
---------------------------------------------------------------------
local empurrando = nil

local function prenderNoJogador(guincho)
    local e = Config.motor.empurrar
    AttachEntityToEntity(guincho, cache.ped, GetPedBoneIndex(cache.ped, 0), e.pos.x, e.pos.y, e.pos.z,
        e.rot.x, e.rot.y, e.rot.z, false, false, false, false, 2, true)
end

local function soltarGuincho()
    local guincho = empurrando
    if not guincho then return end
    empurrando = nil
    lib.hideTextUI()
    StopAnimTask(cache.ped, ANIM_EMPURRAR.dict, ANIM_EMPURRAR.clip, 1.0)

    if DoesEntityExist(guincho) and pedirControle(guincho) then
        DetachEntity(guincho, true, false)
        local pos = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, Config.motor.empurrar.pos.y, 0.0)
        SetEntityCoords(guincho, pos.x, pos.y, pos.z, false, false, false, false)
        SetEntityHeading(guincho, GetEntityHeading(cache.ped) + Config.motor.empurrar.rot.z)
        PlaceObjectOnGroundProperly(guincho)
        FreezeEntityPosition(guincho, true)
    end
    lib.callback.await('pista_tuning:server:soltarGuincho', false, ObjToNet(guincho))
end

local function empurrarGuincho(guincho)
    if empurrando or cache.vehicle then return end
    local ok, msg = lib.callback.await('pista_tuning:server:pegarGuincho', false, ObjToNet(guincho))
    if not ok then return Avisar(msg, 'error') end
    if not pedirControle(guincho) then
        lib.callback.await('pista_tuning:server:soltarGuincho', false, ObjToNet(guincho))
        return Avisar('Não foi possível pegar o guincho, tente de novo', 'error')
    end

    FreezeEntityPosition(guincho, false)
    prenderNoJogador(guincho)
    lib.requestAnimDict(ANIM_EMPURRAR.dict)
    empurrando = guincho
    lib.showTextUI('[E] Soltar guincho', { position = 'left-center', icon = 'fa-solid fa-dolly' })

    CreateThread(function()
        while empurrando == guincho do
            Wait(0)
            if not IsEntityPlayingAnim(cache.ped, ANIM_EMPURRAR.dict, ANIM_EMPURRAR.clip, 3) then
                TaskPlayAnim(cache.ped, ANIM_EMPURRAR.dict, ANIM_EMPURRAR.clip, 8.0, -8.0, -1, 49, 0, false, false, false)
            end
            DisableControlAction(0, 21, true)  -- correr
            DisableControlAction(0, 22, true)  -- pular
            DisableControlAction(0, 23, true)  -- entrar em veículo
            DisableControlAction(0, 24, true)  -- atacar
            DisableControlAction(0, 25, true)  -- mirar
            DisableControlAction(0, 44, true)  -- cobertura
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            if IsControlJustPressed(0, 38) or IsEntityDead(cache.ped) or cache.vehicle or not DoesEntityExist(guincho) then
                soltarGuincho()
            end
        end
    end)
end

---------------------------------------------------------------------
-- Instalar peça interna (chamado pelo usarPeca)
---------------------------------------------------------------------
local function motorAbertoProximo()
    for _, m in ipairs(objetosPerto(Config.motor.propMotor, STATE_MOTOR, GetEntityCoords(cache.ped), 2.5)) do
        local st = estadoMotor(m.obj)
        if st.aberto and st['local'] == 'bancada' then return m.obj end
    end
end

local function instalarNoMotor(motor, itemName)
    local peca = Config.itens[itemName]
    exports.ox_inventory:closeInventory()
    if not Trabalhar(peca.tempo, ('Montando %s...'):format(peca.label), { anim = ANIM_AGACHADO }) then
        return Avisar('Cancelado', 'error')
    end
    local ok, msg = lib.callback.await('pista_tuning:server:instalarNoMotor', false, ObjToNet(motor), itemName)
    Avisar(msg, ok and 'success' or 'error')
end

function InstalarNoMotorProximo(itemName)
    if cache.vehicle then return Avisar('Saia do veículo', 'error') end
    local motor = motorAbertoProximo()
    if not motor then
        return Avisar('Essa peça vai dentro do motor: leve o motor até a bancada e abra com o torquímetro', 'error', 7000)
    end
    if not TemFerramenta('torquimetro') then return Avisar('Você precisa do torquímetro', 'error') end
    instalarNoMotor(motor, itemName)
end

---------------------------------------------------------------------
-- Menu do motor aberto
---------------------------------------------------------------------
local function abrirMenuMotor(motor)
    local dados, st = lib.callback.await('pista_tuning:server:dadosMotor', false, ObjToNet(motor))
    if not dados then return end

    local opcoes = {
        {
            title = ('Motor do carro %s'):format(st.plate),
            description = st.aberto and 'Aberto na bancada' or 'Fechado',
            icon = 'fa-solid fa-gears',
            readOnly = true,
        },
    }

    for _, s in ipairs(Config.slots) do
        if SlotEhDoMotor(s.id) then
            local valor = dados[s.id]
            local instalado = valor ~= nil and valor ~= false
            opcoes[#opcoes + 1] = {
                title = s.label,
                description = TextoSlot(s.id, valor),
                icon = instalado and 'fa-solid fa-circle-check' or 'fa-regular fa-circle',
                iconColor = instalado and '#3fb950' or '#8b949e',
                disabled = not instalado,
                metadata = instalado and { 'Clique para retirar' } or nil,
                onSelect = instalado and function()
                    if not Trabalhar(15000, ('Retirando %s...'):format(s.label), { anim = ANIM_AGACHADO }) then return end
                    local ok, msg = lib.callback.await('pista_tuning:server:removerDoMotor', false, ObjToNet(motor), s.id)
                    Avisar(msg, ok and 'success' or 'error')
                    if ok then abrirMenuMotor(motor) end
                end or nil,
            }
        end
    end

    for nome, peca in pairs(Config.itens) do
        if peca.motor and TemItem(nome) then
            opcoes[#opcoes + 1] = {
                title = ('Instalar %s'):format(peca.label),
                description = ('Nível %d'):format(peca.nivel),
                icon = 'fa-solid fa-screwdriver-wrench',
                iconColor = '#f1c232',
                onSelect = function() instalarNoMotor(motor, nome) end,
            }
        end
    end

    lib.registerContext({ id = 'pista_tuning_motor', title = 'Motor na bancada', options = opcoes })
    lib.showContext('pista_tuning_motor')
end

---------------------------------------------------------------------
-- ox_target
---------------------------------------------------------------------
local function podeMecanico()
    return not cache.vehicle and not empurrando and MeuNivel() >= Config.motor.nivel
end

CreateThread(function()
    -- Guincho
    exports.ox_target:addModel(Config.motor.propGuincho, {
        {
            name = 'pista_guincho_empurrar',
            icon = 'fa-solid fa-dolly',
            label = 'Empurrar guincho',
            distance = 2.5,
            canInteract = function(entity)
                local st = estadoGuincho(entity)
                return st and not st.carregadoPor and podeMecanico()
            end,
            onSelect = function(data) empurrarGuincho(data.entity) end,
        },
        {
            name = 'pista_guincho_bancada',
            icon = 'fa-solid fa-arrow-down',
            label = 'Descer motor na bancada',
            distance = 2.5,
            canInteract = function(entity)
                local st = estadoGuincho(entity)
                return st and st.motor and not st.carregadoPor and podeMecanico()
            end,
            onSelect = function(data)
                local guincho = data.entity
                local ok, info = lib.callback.await('pista_tuning:server:podeDescerNaBancada', false, ObjToNet(guincho))
                if not ok then return Avisar(info, 'error') end
                if not Trabalhar(Config.motor.tempoBancada, 'Descendo o motor na bancada...') then return end

                local motor = entidadeDaRede(info.motor)
                if not motor or not pedirControle(motor) then return Avisar('Não foi possível mexer no motor', 'error') end
                DetachEntity(motor, true, false)
                SetEntityCoords(motor, info.x, info.y, info.z, false, false, false, false)
                SetEntityHeading(motor, info.h)
                PlaceObjectOnGroundProperly(motor)
                FreezeEntityPosition(motor, true)
                Wait(300) -- deixa a posição sincronizar antes do servidor salvar

                local certo, msg = lib.callback.await('pista_tuning:server:motorNaBancada', false, ObjToNet(guincho), info.bancada)
                Avisar(msg or 'Não foi possível descer o motor', certo and 'success' or 'error')
            end,
        },
        {
            name = 'pista_guincho_guardar',
            icon = 'fa-solid fa-box',
            label = 'Guardar guincho',
            distance = 2.5,
            canInteract = function(entity)
                local st = estadoGuincho(entity)
                if not st or st.carregadoPor or st.motor or not podeMecanico() then return false end
                local p = Config.guinchos[st.home]
                return p and #(GetEntityCoords(entity) - vec3(p.x, p.y, p.z)) <= 6.0
            end,
            onSelect = function(data)
                local ok, msg = lib.callback.await('pista_tuning:server:guardarGuincho', false, ObjToNet(data.entity))
                Avisar(msg, ok and 'success' or 'error')
            end,
        },
    })

    -- Motor fora do carro
    exports.ox_target:addModel(Config.motor.propMotor, {
        {
            name = 'pista_motor_pendurar',
            icon = 'fa-solid fa-link',
            label = 'Pendurar no guincho',
            distance = 2.5,
            canInteract = function(entity)
                local st = estadoMotor(entity)
                return st and st['local'] ~= 'guincho' and not st.aberto and podeMecanico()
                    and guinchoParado(GetEntityCoords(entity), Config.motor.distanciaBancada + 0.5, false) ~= nil
            end,
            onSelect = function(data)
                local motor = data.entity
                if not Trabalhar(Config.motor.tempoBancada, 'Prendendo o motor no gancho...') then return end
                local ok, msg, guinchoNet = lib.callback.await('pista_tuning:server:pendurarMotor', false, ObjToNet(motor))
                if not ok then return Avisar(msg, 'error') end
                local guincho = entidadeDaRede(guinchoNet)
                if guincho then pendurarNoGancho(motor, guincho) end
                Avisar(msg, 'success')
            end,
        },
        {
            name = 'pista_motor_abrir',
            icon = 'fa-solid fa-lock-open',
            label = 'Abrir motor',
            distance = 2.5,
            canInteract = function(entity)
                local st = estadoMotor(entity)
                return st and st['local'] == 'bancada' and not st.aberto and podeMecanico()
            end,
            onSelect = function(data)
                if not TemFerramenta('torquimetro') then return Avisar('Você precisa do torquímetro', 'error') end
                if not Trabalhar(Config.motor.tempoAbrir, 'Abrindo o motor...', { anim = ANIM_AGACHADO }) then return end
                local ok, msg = lib.callback.await('pista_tuning:server:abrirFecharMotor', false, ObjToNet(data.entity), true)
                Avisar(msg, ok and 'success' or 'error')
                if ok then abrirMenuMotor(data.entity) end
            end,
        },
        {
            name = 'pista_motor_pecas',
            icon = 'fa-solid fa-gears',
            label = 'Peças do motor',
            distance = 2.5,
            canInteract = function(entity)
                local st = estadoMotor(entity)
                return st and st['local'] == 'bancada' and st.aberto and podeMecanico()
            end,
            onSelect = function(data) abrirMenuMotor(data.entity) end,
        },
        {
            name = 'pista_motor_fechar',
            icon = 'fa-solid fa-lock',
            label = 'Fechar motor',
            distance = 2.5,
            canInteract = function(entity)
                local st = estadoMotor(entity)
                return st and st['local'] == 'bancada' and st.aberto and podeMecanico()
            end,
            onSelect = function(data)
                if not TemFerramenta('torquimetro') then return Avisar('Você precisa do torquímetro', 'error') end
                if not Trabalhar(Config.motor.tempoFechar, 'Fechando e torqueando o motor...', { anim = ANIM_AGACHADO }) then return end
                local ok, msg = lib.callback.await('pista_tuning:server:abrirFecharMotor', false, ObjToNet(data.entity), false)
                Avisar(msg, ok and 'success' or 'error')
            end,
        },
    })

    -- Carro: tirar / recolocar motor
    exports.ox_target:addGlobalVehicle({
        {
            name = 'pista_motor_retirar',
            icon = 'fa-solid fa-upload',
            label = 'Retirar motor',
            distance = 3.0,
            canInteract = function(entity)
                return podeMecanico() and not DadosDo(entity).motor
                    and guinchoParado(frenteDo(entity), Config.motor.distanciaGuincho, false) ~= nil
            end,
            onSelect = function(data)
                local veh = data.entity
                if not NaOficina(GetEntityCoords(veh)) then return Avisar('Só dá para tirar o motor dentro da oficina', 'error') end
                if not TemFerramenta('soquetes') then return Avisar('Você precisa do jogo de soquetes', 'error') end
                if not Trabalhar(Config.motor.tempoRetirar, 'Soltando o motor e prendendo no gancho...', { capo = veh }) then return end

                local ok, msg, motorNet, guinchoNet = lib.callback.await('pista_tuning:server:retirarMotor', false, VehToNet(veh))
                if not ok then return Avisar(msg, 'error') end
                local motor, guincho = entidadeDaRede(motorNet), entidadeDaRede(guinchoNet)
                if motor and guincho then pendurarNoGancho(motor, guincho) end
                SetVehicleDoorOpen(veh, 4, false, false)
                Avisar(msg, 'success', 6000)
            end,
        },
        {
            name = 'pista_motor_recolocar',
            icon = 'fa-solid fa-download',
            label = 'Recolocar motor',
            distance = 3.0,
            canInteract = function(entity)
                if not podeMecanico() or not DadosDo(entity).motor then return false end
                return guinchoParado(frenteDo(entity), Config.motor.distanciaGuincho, qbx.getVehiclePlate(entity)) ~= nil
            end,
            onSelect = function(data)
                local veh = data.entity
                if not TemFerramenta('soquetes') then return Avisar('Você precisa do jogo de soquetes', 'error') end
                if not Trabalhar(Config.motor.tempoRecolocar, 'Descendo e fixando o motor...', { capo = veh }) then return end
                local ok, msg = lib.callback.await('pista_tuning:server:recolocarMotor', false, VehToNet(veh))
                Avisar(msg, ok and 'success' or 'error', 6000)
            end,
        },
    })
end)

---------------------------------------------------------------------
-- Comandos de configuração (admin)
---------------------------------------------------------------------
RegisterNetEvent('pista_tuning:client:coords', function()
    local c = GetEntityCoords(cache.ped)
    local achou, chao = GetGroundZFor_3dCoord(c.x, c.y, c.z, false)
    local z = achou and chao or (c.z - 1.0)
    local texto = ('vec4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, z, GetEntityHeading(cache.ped))
    lib.setClipboard(texto)
    print('[pista_tuning] ' .. texto)
    lib.alertDialog({
        header = 'Sua posição (já copiada)',
        content = ('`%s`  \n\nCole na conversa com o Ctrl+V.'):format(texto),
        centered = true,
    })
end)

RegisterNetEvent('pista_tuning:client:ajuste', function(tipo, x, y, z, rz)
    local cfg = Config.motor[tipo]
    cfg.pos = vec3(x + 0.0, y + 0.0, z + 0.0)
    cfg.rot = vec3(cfg.rot.x, cfg.rot.y, rz + 0.0)

    if tipo == 'empurrar' and empurrando then
        prenderNoJogador(empurrando)
    elseif tipo == 'gancho' then
        for _, m in ipairs(objetosPerto(Config.motor.propMotor, STATE_MOTOR, GetEntityCoords(cache.ped), 15.0)) do
            local pai = GetEntityAttachedTo(m.obj)
            if pai ~= 0 then pendurarNoGancho(m.obj, pai) end
        end
    end

    local linha = ('%s = { pos = vec3(%.2f, %.2f, %.2f), rot = vec3(0.0, 0.0, %.1f) },'):format(tipo, x, y, z, rz)
    lib.setClipboard(linha)
    print('[pista_tuning] ' .. linha)
    Avisar('Ajuste aplicado e copiado. Me mande quando ficar bom.', 'success', 6000)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if empurrando then
        lib.hideTextUI()
        StopAnimTask(cache.ped, ANIM_EMPURRAR.dict, ANIM_EMPURRAR.clip, 1.0)
    end
    exports.ox_target:removeModel(Config.motor.propGuincho, { 'pista_guincho_empurrar', 'pista_guincho_bancada', 'pista_guincho_guardar' })
    exports.ox_target:removeModel(Config.motor.propMotor, { 'pista_motor_pendurar', 'pista_motor_abrir', 'pista_motor_pecas', 'pista_motor_fechar' })
    exports.ox_target:removeGlobalVehicle({ 'pista_motor_retirar', 'pista_motor_recolocar' })
    for _, p in ipairs(Config.guinchos) do
        RemoveModelHide(p.x, p.y, p.z, 2.0, Config.motor.propGuincho, false)
    end
end)
