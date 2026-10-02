-- pista_tuning - elevador
-- [E] no elevador: sobe / desce o carro.
-- Alt mirando na roda (com o carro no alto): retirar roda, instalar freio,
-- instalar suspensão regulável e recolocar a roda. Texto em cima de cada roda.

local STATE_ELEV = 'pista_elevador'   -- { i, z0, alto, descendo }
local STATE_RODAS = 'pista_rodas'     -- { r0 = propNet|true, ... }

local RODAS = {
    { bone = 'wheel_lf', idx = 0, nome = 'Dianteira esquerda' },
    { bone = 'wheel_rf', idx = 1, nome = 'Dianteira direita' },
    { bone = 'wheel_lr', idx = 2, nome = 'Traseira esquerda' },
    { bone = 'wheel_rr', idx = 3, nome = 'Traseira direita' },
}
local OSSOS = {}
for i, r in ipairs(RODAS) do OSSOS[i] = r.bone end

local ANIM_ALTO = { dict = 'amb@prop_human_movie_bulb@base', clip = 'base' }
local ANIM_PAINEL = { dict = 'anim@heists@prison_heiststation@cop_reactions', clip = 'cop_b_idle' }
local animando = {} -- [veh] = true enquanto este cliente move o carro
local ocupado = false

---------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------
local function controle(ent)
    local limite = GetGameTimer() + 2000
    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < limite do
        Wait(10)
        NetworkRequestControlOfEntity(ent)
    end
    return NetworkHasControlOfEntity(ent)
end

local function souMecanico()
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job
    if not job or job.name ~= Config.elevador.job then return false end
    return job.onduty or not Config.elevador.precisaEstarEmServico
end

local function estadoElev(veh) return Entity(veh).state[STATE_ELEV] end
local function rodasFora(veh) return Entity(veh).state[STATE_RODAS] or {} end

local function noAlto(veh)
    local st = estadoElev(veh)
    return st and st.alto and not st.descendo
end

--- Carro em cima do elevador i (o mais perto do centro, dentro do raio)
local function carroNoElevador(i)
    local e = Config.elevadores[i]
    local centro = vec2(e.coords.x, e.coords.y)
    local melhor, melhorDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local c = GetEntityCoords(veh)
        local d = #(vec2(c.x, c.y) - centro)
        local st = estadoElev(veh)
        if (d <= e.raio or (st and st.i == i)) and (not melhorDist or d < melhorDist) then
            melhor, melhorDist = veh, d
        end
    end
    return melhor
end

local function suavizar(t) return t * t * (3.0 - 2.0 * t) end

local function diferencaAngulo(a, b)
    return (b - a + 180.0) % 360.0 - 180.0
end

--- Move o carro de uma posição/direção para outra (para encaixar e subir/descer)
local function moverCarro(veh, de, deH, para, paraH, duracao)
    local inicio = GetGameTimer()
    local giro = diferencaAngulo(deH, paraH)
    while DoesEntityExist(veh) do
        local t = math.min(1.0, (GetGameTimer() - inicio) / duracao)
        local k = suavizar(t)
        local p = de + (para - de) * k
        SetEntityCoordsNoOffset(veh, p.x, p.y, p.z, false, false, false)
        SetEntityHeading(veh, deH + giro * k)
        if t >= 1.0 then break end
        Wait(0)
    end
end

local function moverComBarra(veh, de, deH, para, paraH, duracao, label)
    if not controle(veh) then return Avisar('Não foi possível controlar o carro, tente de novo', 'error') end
    animando[veh] = true
    FreezeEntityPosition(veh, true)
    local terminou = false
    CreateThread(function()
        moverCarro(veh, de, deH, para, paraH, duracao)
        terminou = true
    end)
    Trabalhar(duracao, label, { semCancelar = true, anim = ANIM_PAINEL })
    while not terminou do Wait(0) end
    animando[veh] = nil
    return true
end

--- Posição da roda no mundo
local function posRoda(veh, roda)
    local osso = GetEntityBoneIndexByName(veh, roda.bone)
    if osso == -1 then return nil end
    return GetWorldPositionOfEntityBone(veh, osso)
end

--- Roda mais perto do ponto mirado
local function rodaPerto(veh, coords)
    coords = coords or GetEntityCoords(cache.ped)
    local melhor, melhorDist
    for _, roda in ipairs(RODAS) do
        local p = posRoda(veh, roda)
        if p then
            local d = #(p - coords)
            if not melhorDist or d < melhorDist then melhor, melhorDist = roda, d end
        end
    end
    return melhor
end

local function rodaPeloOsso(veh, osso, coords)
    if osso then
        for _, roda in ipairs(RODAS) do
            if GetEntityBoneIndexByName(veh, roda.bone) == osso then return roda end
        end
    end
    return coords and rodaPerto(veh, coords) or nil
end

local function olharPara(pos)
    if not pos then return end
    TaskTurnPedToFaceCoord(cache.ped, pos.x, pos.y, pos.z, 600)
    Wait(600)
end

--- O GTA só devolve rodas consertando o carro: guarda o estado, conserta
--- e tira de novo as rodas que continuam fora.
local function restaurarRodas(veh)
    local motor, lataria, tanque = GetVehicleEngineHealth(veh), GetVehicleBodyHealth(veh), GetVehiclePetrolTankHealth(veh)
    local combustivel, sujeira = GetVehicleFuelLevel(veh), GetVehicleDirtLevel(veh)
    SetVehicleFixed(veh)
    SetVehicleEngineHealth(veh, motor)
    SetVehicleBodyHealth(veh, lataria)
    SetVehiclePetrolTankHealth(veh, tanque)
    SetVehicleFuelLevel(veh, combustivel)
    SetVehicleDirtLevel(veh, sujeira)
    for chave in pairs(rodasFora(veh)) do
        BreakOffVehicleWheel(veh, tonumber(chave:sub(2)), false, true, true, false)
    end
end

local function executar(fn, ...)
    if ocupado then return end
    ocupado = true
    local args = { ... }
    CreateThread(function()
        local ok, err = pcall(fn, table.unpack(args))
        if not ok then print('[pista_tuning] erro no elevador: ' .. tostring(err)) end
        ocupado = false
    end)
end

---------------------------------------------------------------------
-- Subir / descer
---------------------------------------------------------------------
local function subir(i, veh)
    if GetVehicleNumberOfWheels(veh) ~= 4 then return Avisar('Esse elevador é só para carros de 4 rodas', 'error') end
    local ok, info = lib.callback.await('pista_tuning:server:subirElevador', false, VehToNet(veh))
    if not ok then return Avisar(info, 'error') end

    -- encaixa no centro do elevador, alinhado com as colunas (frente ou ré, o que for mais perto)
    local e = Config.elevadores[i].coords
    local h = GetEntityHeading(veh)
    local alvoH = math.abs(diferencaAngulo(h, e.w)) <= 90.0 and e.w or (e.w + 180.0) % 360.0
    local de = GetEntityCoords(veh)
    local encaixe = vec3(e.x, e.y, info.z0)
    moverComBarra(veh, de, h, encaixe, alvoH, 1500, 'Encaixando o carro...')
    moverComBarra(veh, encaixe, alvoH, encaixe + vec3(0.0, 0.0, Config.elevador.altura), alvoH,
        Config.elevador.tempoSubir, 'Subindo o elevador...')
    Avisar('Carro no alto. Mire numa roda com o Alt para trabalhar nela.', 'inform', 6000)
end

local function descer(veh)
    local ok, info = lib.callback.await('pista_tuning:server:descerElevador', false, VehToNet(veh))
    if not ok then return Avisar(info, 'error') end
    local c, h = GetEntityCoords(veh), GetEntityHeading(veh)
    moverComBarra(veh, c, h, vec3(c.x, c.y, info.z0), h, Config.elevador.tempoDescer, 'Descendo o elevador...')
    FreezeEntityPosition(veh, false)
    SetVehicleOnGroundProperly(veh)
    lib.callback.await('pista_tuning:server:elevadorLiberado', false, VehToNet(veh))
end

---------------------------------------------------------------------
-- Rodas
---------------------------------------------------------------------
local function retirarRoda(veh, roda)
    local mundo = posRoda(veh, roda)
    if not mundo then return Avisar('Esse carro não tem essa roda', 'error') end
    olharPara(mundo)
    if not Trabalhar(Config.elevador.tempoRoda, ('Tirando a roda %s...'):format(roda.nome:lower()), { anim = ANIM_ALTO }) then return end
    local ok, msg = lib.callback.await('pista_tuning:server:retirarRoda', false, VehToNet(veh), roda.idx)
    if not ok then return Avisar(msg, 'error') end

    -- roda vai para o chão, do lado de fora
    local off = GetOffsetFromEntityGivenWorldCoords(veh, mundo)
    local lado = off.x >= 0 and 1.0 or -1.0
    local chao = GetOffsetFromEntityInWorldCoords(veh, off.x + lado * 1.4, off.y, 0.0)

    if controle(veh) then BreakOffVehicleWheel(veh, roda.idx, false, true, true, false) end

    lib.requestModel(Config.elevador.propRoda)
    local st = estadoElev(veh)
    local prop = CreateObject(Config.elevador.propRoda, chao.x, chao.y, st and st.z0 or chao.z, true, true, false)
    SetModelAsNoLongerNeeded(Config.elevador.propRoda)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)
    lib.callback.await('pista_tuning:server:registrarRoda', false, VehToNet(veh), roda.idx, ObjToNet(prop))
    Avisar(msg, 'success')
end

local function recolocarRoda(veh, roda)
    olharPara(posRoda(veh, roda))
    if not Trabalhar(Config.elevador.tempoRoda, ('Colocando a roda %s...'):format(roda.nome:lower()), { anim = ANIM_ALTO }) then return end
    local ok, msg = lib.callback.await('pista_tuning:server:recolocarRoda', false, VehToNet(veh), roda.idx)
    if not ok then return Avisar(msg, 'error') end
    Wait(200) -- espera o estado das rodas atualizar
    if controle(veh) then restaurarRodas(veh) end
    Avisar(msg, 'success')
end

--- tipo = 'freio' | 'susp'
local function instalarNaRoda(veh, roda, tipo, item)
    olharPara(posRoda(veh, roda))
    local label = tipo == 'susp' and 'suspensão' or 'freio'
    local tempo = tipo == 'susp' and Config.suspensao.tempo or Config.elevador.tempoFreio
    if not Trabalhar(tempo, ('Instalando %s na roda %s...'):format(label, roda.nome:lower()), { anim = ANIM_ALTO }) then return end
    local ok, msg = lib.callback.await('pista_tuning:server:instalarNaRoda', false, VehToNet(veh), roda.idx, tipo, item)
    Avisar(msg, ok and 'success' or 'error', 6000)
end

--- Kits de freio que dá para usar agora nessa roda (o da obra começada ou os do inventário)
local function kitsFreioDisponiveis(veh)
    local obra = DadosDo(veh).freioObra
    if obra then return { obra.item } end
    local lista = {}
    for item in pairs(Config.kitsFreio) do
        if TemItem(item) then lista[#lista + 1] = item end
    end
    table.sort(lista, function(a, b) return Config.kitsFreio[a].nivel < Config.kitsFreio[b].nivel end)
    return lista
end

local function feitaNaObra(obra, roda)
    return obra and obra.rodas and obra.rodas['r' .. roda.idx]
end

---------------------------------------------------------------------
-- Alt na roda (ox_target)
---------------------------------------------------------------------
local function podeMexer(veh)
    return not ocupado and not cache.vehicle and souMecanico() and noAlto(veh)
end

local function rodaDoAlvo(entity, coords, osso)
    if not podeMexer(entity) then return nil end
    return rodaPeloOsso(entity, osso, coords)
end

local function estaFora(veh, roda)
    return rodasFora(veh)['r' .. roda.idx] ~= nil
end

CreateThread(function()
    exports.ox_target:addGlobalVehicle({
        {
            name = 'pista_roda_retirar',
            icon = 'fa-solid fa-circle-minus',
            label = 'Retirar roda',
            bones = OSSOS,
            distance = 2.5,
            canInteract = function(entity, _, coords, _, osso)
                local roda = rodaDoAlvo(entity, coords, osso)
                return roda ~= nil and not estaFora(entity, roda)
            end,
            onSelect = function(data)
                local roda = rodaPerto(data.entity, data.coords)
                if roda then executar(retirarRoda, data.entity, roda) end
            end,
        },
        {
            name = 'pista_roda_freio',
            icon = 'fa-solid fa-circle-stop',
            label = 'Instalar freio',
            bones = OSSOS,
            distance = 2.5,
            canInteract = function(entity, _, coords, _, osso)
                local roda = rodaDoAlvo(entity, coords, osso)
                if not roda or not estaFora(entity, roda) then return false end
                if feitaNaObra(DadosDo(entity).freioObra, roda) then return false end
                return #kitsFreioDisponiveis(entity) > 0
            end,
            onSelect = function(data)
                local veh = data.entity
                local roda = rodaPerto(veh, data.coords)
                if not roda then return end
                local kits = kitsFreioDisponiveis(veh)
                if #kits == 1 then return executar(instalarNaRoda, veh, roda, 'freio', kits[1]) end
                local opcoes = {}
                for _, item in ipairs(kits) do
                    opcoes[#opcoes + 1] = {
                        title = Config.kitsFreio[item].label,
                        icon = 'fa-solid fa-circle-stop', iconColor = '#58a6ff',
                        onSelect = function() executar(instalarNaRoda, veh, roda, 'freio', item) end,
                    }
                end
                lib.registerContext({ id = 'pista_roda_freio', title = 'Qual freio?', options = opcoes })
                lib.showContext('pista_roda_freio')
            end,
        },
        {
            name = 'pista_roda_susp',
            icon = 'fa-solid fa-arrows-up-down',
            label = 'Instalar suspensão regulável',
            bones = OSSOS,
            distance = 2.5,
            canInteract = function(entity, _, coords, _, osso)
                local roda = rodaDoAlvo(entity, coords, osso)
                if not roda or not estaFora(entity, roda) then return false end
                local dados = DadosDo(entity)
                if dados.suspObra then return not feitaNaObra(dados.suspObra, roda) end
                return not dados.suspensao and TemItem(Config.suspensao.item)
            end,
            onSelect = function(data)
                local roda = rodaPerto(data.entity, data.coords)
                if roda then executar(instalarNaRoda, data.entity, roda, 'susp', Config.suspensao.item) end
            end,
        },
        {
            name = 'pista_roda_recolocar',
            icon = 'fa-solid fa-circle-plus',
            label = 'Recolocar roda',
            bones = OSSOS,
            distance = 2.5,
            canInteract = function(entity, _, coords, _, osso)
                local roda = rodaDoAlvo(entity, coords, osso)
                return roda ~= nil and estaFora(entity, roda)
            end,
            onSelect = function(data)
                local roda = rodaPerto(data.entity, data.coords)
                if roda then executar(recolocarRoda, data.entity, roda) end
            end,
        },
    })
end)

---------------------------------------------------------------------
-- Texto em cima de cada roda (carro no alto)
---------------------------------------------------------------------
local function texto3D(pos, texto)
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(texto)
    SetDrawOrigin(pos.x, pos.y, pos.z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

local function textoDaRoda(veh, roda, dados, fora)
    local linhas = { fora['r' .. roda.idx] ~= nil and '~r~Roda fora' or '~g~Roda no carro' }
    if feitaNaObra(dados.freioObra, roda) then
        linhas[#linhas + 1] = '~b~Freio novo OK'
    elseif dados.freioObra then
        linhas[#linhas + 1] = '~y~Falta o freio'
    end
    if feitaNaObra(dados.suspObra, roda) then
        linhas[#linhas + 1] = '~b~Suspensão OK'
    elseif dados.suspObra then
        linhas[#linhas + 1] = '~y~Falta a suspensão'
    end
    return linhas
end

CreateThread(function()
    local carros = {}
    local proximaBusca = 0
    while true do
        local espera = 500
        local agora = GetGameTimer()
        if agora >= proximaBusca then
            proximaBusca = agora + 1000
            carros = {}
            local eu = GetEntityCoords(cache.ped)
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if noAlto(veh) and #(GetEntityCoords(veh) - eu) <= Config.elevador.distanciaTexto then
                    carros[#carros + 1] = veh
                end
            end
        end
        if #carros > 0 and not cache.vehicle then
            espera = 0
            for _, veh in ipairs(carros) do
                if DoesEntityExist(veh) then
                    local dados, fora = DadosDo(veh), rodasFora(veh)
                    for _, roda in ipairs(RODAS) do
                        local p = posRoda(veh, roda)
                        if p then
                            local linhas = textoDaRoda(veh, roda, dados, fora)
                            for n, l in ipairs(linhas) do
                                texto3D(p + vec3(0.0, 0.0, 0.55 - (n - 1) * 0.11), l)
                            end
                        end
                    end
                end
            end
        end
        Wait(espera)
    end
end)

---------------------------------------------------------------------
-- [E] perto do elevador: sobe / desce
---------------------------------------------------------------------
local function textoDoBotao(i)
    local veh = carroNoElevador(i)
    if not veh then return nil end
    local st = estadoElev(veh)
    if not st then return '[E] Subir o carro', veh, 'subir' end
    if st.alto and not st.descendo then
        local faltando = 0
        for _ in pairs(rodasFora(veh)) do faltando = faltando + 1 end
        if faltando > 0 then return ('Coloque as rodas para descer (%d fora)'):format(faltando), veh, nil end
        return '[E] Descer o carro', veh, 'descer'
    end
    return nil
end

CreateThread(function()
    for i, e in ipairs(Config.elevadores) do
        local ultimoTexto
        lib.points.new({
            coords = e.coords.xyz,
            distance = e.raio + 2.0,
            nearby = function()
                local texto, veh, acao
                if not cache.vehicle and not ocupado and souMecanico() then
                    texto, veh, acao = textoDoBotao(i)
                end
                if not texto then
                    if ultimoTexto then lib.hideTextUI() ultimoTexto = nil end
                    return
                end
                if texto ~= ultimoTexto then
                    lib.showTextUI(texto, { position = 'left-center', icon = 'fa-solid fa-car-side' })
                    ultimoTexto = texto
                end
                if acao and IsControlJustReleased(0, 38) then
                    lib.hideTextUI()
                    ultimoTexto = nil
                    if acao == 'subir' then executar(subir, i, veh) else executar(descer, veh) end
                end
            end,
            onExit = function()
                if ultimoTexto then lib.hideTextUI() ultimoTexto = nil end
            end,
        })
    end
end)

---------------------------------------------------------------------
-- Mantém o carro no alto (quem for "dono" do carro na rede segura ele)
---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(500)
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            local st = estadoElev(veh)
            if st and st.alto and not st.descendo and not animando[veh] and NetworkHasControlOfEntity(veh) then
                FreezeEntityPosition(veh, true)
                local c = GetEntityCoords(veh)
                local alvo = st.z0 + Config.elevador.altura
                if math.abs(c.z - alvo) > 0.08 then
                    SetEntityCoordsNoOffset(veh, c.x, c.y, alvo, false, false, false)
                end
            end
        end
    end
end)

-- Carro no elevador não liga
CreateThread(function()
    while true do
        local espera = 1000
        local veh = cache.vehicle
        if veh and cache.seat == -1 and estadoElev(veh) then
            espera = 0
            SetVehicleEngineOn(veh, false, true, true)
            DisableControlAction(0, 71, true)
            DisableControlAction(0, 72, true)
        end
        Wait(espera)
    end
end)

---------------------------------------------------------------------
-- Usar o kit pelo inventário: explica o caminho
---------------------------------------------------------------------
local function dicaKit()
    exports.ox_inventory:closeInventory()
    Avisar('Suba o carro no elevador ([E]), mire na roda com o Alt, tire a roda e instale o kit. Vai nas 4 rodas.', 'inform', 8000)
end
exports('usarFreio', dicaKit)
exports('usarSuspensao', dicaKit)

---------------------------------------------------------------------
-- Diagnóstico: /pistadebug
---------------------------------------------------------------------
RegisterCommand('pistadebug', function()
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job
    local linhas = {
        ('Emprego: %s | cargo: %s | em serviço: %s'):format(job and job.name or '?', job and job.grade and job.grade.level or '?', tostring(job and job.onduty)),
        ('Pode usar o elevador: %s'):format(tostring(souMecanico())),
    }
    local eu = GetEntityCoords(cache.ped)
    for i, e in ipairs(Config.elevadores) do
        local veh = carroNoElevador(i)
        linhas[#linhas + 1] = ('%s: você a %.1f m | carro em cima: %s'):format(e.label, #(eu - e.coords.xyz), veh and 'sim' or 'não')
    end
    local texto = table.concat(linhas, '  \n')
    print('[pista_tuning] ' .. texto:gsub('  \n', ' | '))
    lib.alertDialog({ header = 'Diagnóstico do elevador', content = texto, centered = true })
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if lib.isTextUIOpen() then lib.hideTextUI() end
    exports.ox_target:removeGlobalVehicle({ 'pista_roda_retirar', 'pista_roda_freio', 'pista_roda_susp', 'pista_roda_recolocar' })
end)
