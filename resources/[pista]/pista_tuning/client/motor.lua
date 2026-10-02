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
-- Animação: motor subindo/descendo no gancho
---------------------------------------------------------------------
local function suavizar(t) return t * t * (3.0 - 2.0 * t) end

local function offsetNoGuincho(guincho, mundo)
    return GetOffsetFromEntityGivenWorldCoords(guincho, mundo.x, mundo.y, mundo.z)
end

local function cofreDoCarro(veh)
    local osso = GetEntityBoneIndexByName(veh, 'engine')
    if osso ~= -1 then return GetWorldPositionOfEntityBone(veh, osso) end
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, 1.5, 0.2)
end

local function motorPendurado(guincho)
    for _, obj in ipairs(GetGamePool('CObject')) do
        if GetEntityModel(obj) == Config.motor.propMotor and GetEntityAttachedTo(obj) == guincho then return obj end
    end
end

--- Move o motor preso no guincho de `de` até `para` (posições relativas ao guincho).
--- `parar` (opcional) interrompe no meio. Devolve a posição onde parou.
local function animarMotor(motor, guincho, de, para, duracao, parar)
    if not pedirControle(motor) then return de end
    FreezeEntityPosition(motor, false)
    local rot = Config.motor.gancho.rot
    local atual = de
    local inicio = GetGameTimer()
    while DoesEntityExist(motor) and DoesEntityExist(guincho) do
        local t = math.min(1.0, (GetGameTimer() - inicio) / duracao)
        atual = de + (para - de) * suavizar(t)
        AttachEntityToEntity(motor, guincho, 0, atual.x, atual.y, atual.z, rot.x, rot.y, rot.z,
            false, false, false, false, 2, true)
        if t >= 1.0 or (parar and parar()) then break end
        Wait(0)
    end
    return atual
end

--- Barra de progresso enquanto o motor se move. Se cancelar, o motor volta.
local function moverComProgresso(label, motor, guincho, de, para, duracao, podeCancelar)
    local cancelou, terminou, parouEm = false, false, de
    CreateThread(function()
        parouEm = animarMotor(motor, guincho, de, para, duracao, function() return cancelou end)
        terminou = true
    end)
    local ok = Trabalhar(duracao, label, { semCancelar = not podeCancelar })
    if not ok then cancelou = true end
    while not terminou do Wait(0) end
    if not ok then animarMotor(motor, guincho, parouEm, de, 1500) end
    return ok
end

---------------------------------------------------------------------
-- Corda entre a ponta do guincho e o motor (cada jogador desenha a sua)
---------------------------------------------------------------------
local cordas = {} -- [motor] = { rope, guincho }

local function pontoCorda(guincho)
    local c = Config.motor.corda.pos
    return GetOffsetFromEntityInWorldCoords(guincho, c.x, c.y, c.z)
end

local function pontoMotor(motor)
    local m = Config.motor.corda.motor
    return GetOffsetFromEntityInWorldCoords(motor, m.x, m.y, m.z)
end

local function criarCorda(motor, guincho)
    RopeLoadTextures()
    local limite = GetGameTimer() + 2000
    while not RopeAreTexturesLoaded() and GetGameTimer() < limite do Wait(0) end
    local a, b = pontoCorda(guincho), pontoMotor(motor)
    local comprimento = math.max(0.1, #(a - b))
    local rope = AddRope(a.x, a.y, a.z, 0.0, 0.0, 0.0, comprimento, Config.motor.corda.tipo, 10.0, 0.05, 1.0,
        false, false, false, 1.0, false, 0)
    AttachEntitiesToRope(rope, guincho, motor, a.x, a.y, a.z, b.x, b.y, b.z, comprimento, false, false, nil, nil)
    return rope
end

local function apagarCorda(motor)
    local c = cordas[motor]
    if c then
        if DoesRopeExist(c.rope) then DeleteRope(c.rope) end
        cordas[motor] = nil
    end
end

CreateThread(function()
    if not Config.motor.corda.ativa then return end
    while true do
        local eu = GetEntityCoords(cache.ped)
        local vistos = {}
        for _, obj in ipairs(GetGamePool('CObject')) do
            if GetEntityModel(obj) == Config.motor.propMotor and estadoMotor(obj) then
                local pai = GetEntityAttachedTo(obj)
                if pai ~= 0 and GetEntityModel(pai) == Config.motor.propGuincho and #(GetEntityCoords(obj) - eu) < 60.0 then
                    vistos[obj] = true
                    local c = cordas[obj]
                    if not c or c.guincho ~= pai or not DoesRopeExist(c.rope) then
                        apagarCorda(obj)
                        cordas[obj] = { rope = criarCorda(obj, pai), guincho = pai }
                    end
                end
            end
        end
        for obj in pairs(cordas) do
            if not vistos[obj] then apagarCorda(obj) end
        end

        -- acompanha o motor subindo/descendo
        local ate = GetGameTimer() + 300
        repeat
            for obj, c in pairs(cordas) do
                if DoesEntityExist(obj) and DoesEntityExist(c.guincho) then
                    RopeForceLength(c.rope, math.max(0.05, #(pontoCorda(c.guincho) - pontoMotor(obj))))
                end
            end
            Wait(next(cordas) and 0 or 300)
        until GetGameTimer() >= ate
    end
end)

---------------------------------------------------------------------
-- Esconde os guinchos que já vêm no MLO
---------------------------------------------------------------------
CreateThread(function()
    if not Config.motor.esconderGuinchoDoMapa then return end
    for _, p in ipairs(Config.esconderGuinchosMLO or {}) do
        CreateModelHide(p.x, p.y, p.z, 2.0, Config.motor.propGuincho, true)
    end
end)

---------------------------------------------------------------------
-- Vaga / bancada: utilidades
---------------------------------------------------------------------
local ocupado = false

local function executar(fn, ...)
    if ocupado then return end
    ocupado = true
    local args = { ... }
    CreateThread(function()
        local ok, err = pcall(fn, table.unpack(args))
        if not ok then print('[pista_tuning] erro no motor: ' .. tostring(err)) end
        ocupado = false
    end)
end

local function podeMecanico()
    return not cache.vehicle and MeuNivel() >= Config.motor.nivel
end

local function diferencaAngulo(a, b) return (b - a + 180.0) % 360.0 - 180.0 end

local function guinchoDaVaga(i)
    for _, obj in ipairs(GetGamePool('CObject')) do
        if GetEntityModel(obj) == Config.motor.propGuincho then
            local st = estadoGuincho(obj)
            if st and st.home == i then return obj end
        end
    end
end

local function carroNaVaga(i)
    local v = Config.vagasMotor[i]
    local centro = vec2(v.carro.x, v.carro.y)
    local melhor, melhorDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local c = GetEntityCoords(veh)
        local d = #(vec2(c.x, c.y) - centro)
        if d <= v.raio and (not melhorDist or d < melhorDist) then melhor, melhorDist = veh, d end
    end
    return melhor
end

local function motorNaBancada(b)
    local bc = vec3(b.x, b.y, b.z)
    for _, m in ipairs(objetosPerto(Config.motor.propMotor, STATE_MOTOR, bc, 1.5)) do
        if estadoMotor(m.obj)['local'] == 'bancada' then return m.obj end
    end
end

--- Encaixa o carro na vaga (centro e direção certos)
local function encaixarCarro(veh, v)
    local c, h = GetEntityCoords(veh), GetEntityHeading(veh)
    local alvo = vec3(v.carro.x, v.carro.y, c.z)
    if #(c.xy - alvo.xy) < 0.15 and math.abs(diferencaAngulo(h, v.carro.w)) < 3.0 then return true end
    if not pedirControle(veh) then return false end
    FreezeEntityPosition(veh, true)
    local giro = diferencaAngulo(h, v.carro.w)
    local inicio, duracao = GetGameTimer(), 1200
    CreateThread(function()
        while DoesEntityExist(veh) do
            local t = math.min(1.0, (GetGameTimer() - inicio) / duracao)
            local k = suavizar(t)
            local p = c + (alvo - c) * k
            SetEntityCoordsNoOffset(veh, p.x, p.y, p.z, false, false, false)
            SetEntityHeading(veh, h + giro * k)
            if t >= 1.0 then break end
            Wait(0)
        end
    end)
    Trabalhar(duracao, 'Encaixando o carro na vaga...', { semCancelar = true })
    FreezeEntityPosition(veh, false)
    SetVehicleOnGroundProperly(veh)
    return true
end

---------------------------------------------------------------------
-- Carregar o motor nos braços
---------------------------------------------------------------------
local carregando = nil

local function prenderNosBracos(motor)
    local c = Config.motor.carregar
    AttachEntityToEntity(motor, cache.ped, GetPedBoneIndex(cache.ped, 0), c.pos.x, c.pos.y, c.pos.z,
        c.rot.x, c.rot.y, c.rot.z, false, false, false, false, 2, true)
end

local function pararDeCarregar()
    carregando = nil
    lib.hideTextUI()
    StopAnimTask(cache.ped, ANIM_EMPURRAR.dict, ANIM_EMPURRAR.clip, 1.0)
end

local function largarNoChao()
    local motor = carregando
    if not motor then return end
    pararDeCarregar()
    if pedirControle(motor) then
        DetachEntity(motor, true, false)
        SetEntityCollision(motor, true, true) -- sem isso o Alt não "enxerga" o motor no chão
        local pos = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 0.9, 0.0)
        SetEntityCoords(motor, pos.x, pos.y, pos.z, false, false, false, false)
        PlaceObjectOnGroundProperly(motor)
        FreezeEntityPosition(motor, true)
    end
    Wait(300)
    local ok, msg = lib.callback.await('pista_tuning:server:motorPosicionado', false, ObjToNet(motor), 'chao')
    if ok then Avisar(msg, 'inform') end
end

local function iniciarCarga(motor)
    if not pedirControle(motor) then return Avisar('Não foi possível pegar o motor, tente de novo', 'error') end

    DetachEntity(motor, true, false)
    FreezeEntityPosition(motor, false)
    SetEntityCollision(motor, false, false)
    prenderNosBracos(motor)
    lib.requestAnimDict(ANIM_EMPURRAR.dict)
    carregando = motor
    lib.showTextUI('Carregando o motor  \n[E] na bancada ou no carro  \n[G] Largar no chão', { position = 'left-center', icon = 'fa-solid fa-box' })

    CreateThread(function()
        while carregando == motor do
            Wait(0)
            if not IsEntityPlayingAnim(cache.ped, ANIM_EMPURRAR.dict, ANIM_EMPURRAR.clip, 3) then
                TaskPlayAnim(cache.ped, ANIM_EMPURRAR.dict, ANIM_EMPURRAR.clip, 8.0, -8.0, -1, 49, 0, false, false, false)
            end
            for _, c in ipairs({ 21, 22, 23, 24, 25, 44, 140, 141, 142 }) do DisableControlAction(0, c, true) end
            if IsControlJustPressed(0, 47) or IsEntityDead(cache.ped) or cache.vehicle then
                largarNoChao()
            elseif not DoesEntityExist(motor) then
                pararDeCarregar()
            end
        end
    end)
end

local function comecarACarregar(motor)
    local ok, msg = lib.callback.await('pista_tuning:server:pegarMotor', false, ObjToNet(motor))
    if not ok then return Avisar(msg, 'error') end
    iniciarCarga(motor)
end

---------------------------------------------------------------------
-- Ações da vaga
---------------------------------------------------------------------
local function retirarMotor(i, veh)
    if not NaOficina(GetEntityCoords(veh)) then return Avisar('Só dá para tirar o motor dentro da oficina', 'error') end
    if not TemFerramenta('soquetes') then return Avisar('Você precisa do jogo de soquetes', 'error') end
    if not encaixarCarro(veh, Config.vagasMotor[i]) then return Avisar('Não foi possível encaixar o carro', 'error') end

    if not Trabalhar(Config.motor.tempoRetirar, 'Soltando e tirando o motor...', { capo = veh }) then return end
    local ok, msg, motorNet = lib.callback.await('pista_tuning:server:retirarMotor', false, VehToNet(veh))
    if not ok then return Avisar(msg, 'error') end
    local motor = entidadeDaRede(motorNet)
    if motor then iniciarCarga(motor) end
    Avisar(msg, 'success', 6000)
end

local function recolocarMotor(veh)
    if not TemFerramenta('soquetes') then return Avisar('Você precisa do jogo de soquetes', 'error') end
    SetVehicleDoorOpen(veh, 4, false, false)
    if not Trabalhar(Config.motor.tempoRecolocar, 'Colocando e fixando o motor...', { capo = veh }) then return end
    local ok, msg = lib.callback.await('pista_tuning:server:recolocarMotor', false, VehToNet(veh))
    if ok then pararDeCarregar() end
    Avisar(msg, ok and 'success' or 'error', 6000)
end

local function abrirMenuVaga(i)
    local v = Config.vagasMotor[i]
    local veh = carroNaVaga(i)
    local opcoes = {}

    if veh then
        local dados = DadosDo(veh)
        local placa = qbx.getVehiclePlate(veh)
        opcoes[#opcoes + 1] = {
            title = ('Carro %s'):format(placa or ''),
            description = dados.motor and 'Sem motor' or 'Com motor',
            icon = 'fa-solid fa-car', readOnly = true,
        }
        if not dados.motor and not carregando then
            opcoes[#opcoes + 1] = {
                title = 'Retirar motor', icon = 'fa-solid fa-upload', iconColor = '#f1c232',
                description = 'Precisa do jogo de soquetes. O motor vai para os seus braços.',
                onSelect = function() executar(retirarMotor, i, veh) end,
            }
        elseif dados.motor and carregando then
            local st = estadoMotor(carregando)
            if st and st.plate == placa then
                opcoes[#opcoes + 1] = {
                    title = 'Recolocar motor', icon = 'fa-solid fa-download', iconColor = '#f1c232',
                    description = 'Precisa do jogo de soquetes',
                    onSelect = function() executar(recolocarMotor, veh) end,
                }
            else
                opcoes[#opcoes + 1] = { title = 'Esse motor é de outro carro', description = st and ('Motor do carro %s'):format(st.plate) or '', icon = 'fa-solid fa-triangle-exclamation', readOnly = true }
            end
        elseif dados.motor then
            opcoes[#opcoes + 1] = { title = 'O motor está fora', description = 'Busque o motor na bancada para recolocar', icon = 'fa-solid fa-circle-info', readOnly = true }
        end
    else
        opcoes[#opcoes + 1] = { title = 'Nenhum carro na vaga', description = 'Pare o carro na vaga', icon = 'fa-solid fa-car', readOnly = true }
    end

    lib.registerContext({ id = 'pista_vaga_motor', title = v.label, options = opcoes })
    lib.showContext('pista_vaga_motor')
end

---------------------------------------------------------------------
-- Ações da bancada
---------------------------------------------------------------------
local function instalarNoMotor(motor, itemName)
    local peca = Config.itens[itemName]
    exports.ox_inventory:closeInventory()
    if not Trabalhar(peca.tempo, ('Montando %s...'):format(peca.label), { anim = ANIM_AGACHADO }) then
        return Avisar('Cancelado', 'error')
    end
    local ok, msg = lib.callback.await('pista_tuning:server:instalarNoMotor', false, ObjToNet(motor), itemName)
    Avisar(msg, ok and 'success' or 'error')
end

local function motorAbertoProximo()
    for _, m in ipairs(objetosPerto(Config.motor.propMotor, STATE_MOTOR, GetEntityCoords(cache.ped), 2.5)) do
        local st = estadoMotor(m.obj)
        if st.aberto and st['local'] == 'bancada' then return m.obj end
    end
end

function InstalarNoMotorProximo(itemName)
    if cache.vehicle then return Avisar('Saia do veículo', 'error') end
    local motor = motorAbertoProximo()
    if not motor then
        return Avisar('Essa peça vai dentro do motor: leve o motor até a bancada e abra com o torquímetro', 'error', 7000)
    end
    if not TemFerramenta('torquimetro') then return Avisar('Você precisa do torquímetro', 'error') end
    executar(instalarNoMotor, motor, itemName)
end

--- Kit de retífica (item): usado no motor aberto na bancada
function RetificarMotorProximo()
    if cache.vehicle then return Avisar('Saia do veículo', 'error') end
    local motor = motorAbertoProximo()
    if not motor then
        return Avisar('A retífica é feita no motor aberto: leve o motor até a bancada e abra com o torquímetro', 'error', 7000)
    end
    if not TemFerramenta('torquimetro') then return Avisar('Você precisa do torquímetro', 'error') end
    exports.ox_inventory:closeInventory()
    executar(function()
        if not Trabalhar(Config.reparo.retifica.tempo, 'Retificando o motor...', { anim = ANIM_AGACHADO }) then
            return Avisar('Cancelado', 'error')
        end
        local ok, msg = lib.callback.await('pista_tuning:server:retificarMotor', false, ObjToNet(motor))
        Avisar(msg, ok and 'success' or 'error', 6000)
    end)
end

local function colocarNaBancada()
    local motor = carregando
    if not motor then return end
    local ok, info = lib.callback.await('pista_tuning:server:lugarNaBancada', false, ObjToNet(motor))
    if not ok then return Avisar(info, 'error') end
    pararDeCarregar()
    if not pedirControle(motor) then return end
    DetachEntity(motor, true, false)
    SetEntityCollision(motor, true, true)
    SetEntityCoords(motor, info.x, info.y, info.z + 0.35, false, false, false, false)
    SetEntityHeading(motor, info.h)
    PlaceObjectOnGroundProperly(motor)
    FreezeEntityPosition(motor, true)
    Wait(300)
    local certo, msg = lib.callback.await('pista_tuning:server:motorPosicionado', false, ObjToNet(motor), 'bancada')
    Avisar(msg or 'Não foi possível colocar o motor', certo and 'success' or 'error')
end

local function abrirFechar(motor, abrir)
    if not TemFerramenta('torquimetro') then return Avisar('Você precisa do torquímetro', 'error') end
    local tempo = abrir and Config.motor.tempoAbrir or Config.motor.tempoFechar
    if not Trabalhar(tempo, abrir and 'Abrindo o motor...' or 'Fechando e torqueando o motor...', { anim = ANIM_AGACHADO }) then return end
    local ok, msg = lib.callback.await('pista_tuning:server:abrirFecharMotor', false, ObjToNet(motor), abrir)
    Avisar(msg, ok and 'success' or 'error')
end

local function retirarDoMotor(motor, slot, label)
    if not Trabalhar(15000, ('Retirando %s...'):format(label), { anim = ANIM_AGACHADO }) then return end
    local ok, msg = lib.callback.await('pista_tuning:server:removerDoMotor', false, ObjToNet(motor), slot)
    Avisar(msg, ok and 'success' or 'error')
end

local function abrirMenuBancada(b)
    local motor = motorNaBancada(b)
    local opcoes = {}

    if not motor then
        if carregando then
            opcoes[#opcoes + 1] = {
                title = 'Colocar o motor na bancada', icon = 'fa-solid fa-arrow-down', iconColor = '#f1c232',
                onSelect = function() executar(colocarNaBancada) end,
            }
        else
            opcoes[#opcoes + 1] = { title = 'Bancada vazia', description = 'Traga um motor da vaga', icon = 'fa-solid fa-table', readOnly = true }
        end
    else
        local dados, st = lib.callback.await('pista_tuning:server:dadosMotor', false, ObjToNet(motor))
        st = st or estadoMotor(motor)
        dados = dados or {}
        opcoes[#opcoes + 1] = {
            title = ('Motor do carro %s'):format(st.plate),
            description = st.aberto and 'Aberto' or 'Fechado',
            icon = 'fa-solid fa-gears', readOnly = true,
        }

        if not st.aberto then
            opcoes[#opcoes + 1] = {
                title = 'Abrir motor', icon = 'fa-solid fa-lock-open', iconColor = '#f1c232',
                description = 'Precisa do torquímetro',
                onSelect = function() executar(abrirFechar, motor, true) end,
            }
            if not carregando then
                opcoes[#opcoes + 1] = {
                    title = 'Pegar o motor', icon = 'fa-solid fa-hand', iconColor = '#58a6ff',
                    description = 'Levar de volta para o guincho',
                    onSelect = function() executar(comecarACarregar, motor) end,
                }
            end
        else
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
                        onSelect = instalado and function() executar(retirarDoMotor, motor, s.id, s.label) end or nil,
                    }
                end
            end
            for nome, peca in pairs(Config.itens) do
                if peca.motor and TemItem(nome) then
                    opcoes[#opcoes + 1] = {
                        title = ('Instalar %s'):format(peca.label),
                        description = ('Nível %d'):format(peca.nivel),
                        icon = 'fa-solid fa-screwdriver-wrench', iconColor = '#58a6ff',
                        onSelect = function() executar(instalarNoMotor, motor, nome) end,
                    }
                end
            end
            opcoes[#opcoes + 1] = {
                title = 'Fechar motor', icon = 'fa-solid fa-lock', iconColor = '#f1c232',
                description = 'Precisa do torquímetro',
                onSelect = function() executar(abrirFechar, motor, false) end,
            }
        end
    end

    lib.registerContext({ id = 'pista_bancada', title = 'Bancada do motor', options = opcoes })
    lib.showContext('pista_bancada')
end

---------------------------------------------------------------------
-- [E] na vaga e na bancada
---------------------------------------------------------------------
local textoAtual = nil

local function mostrarTexto(texto)
    if textoAtual ~= texto then
        textoAtual = texto
        lib.showTextUI(texto, { position = 'left-center', icon = 'fa-solid fa-wrench' })
    end
end

local function esconderTexto()
    if textoAtual then
        textoAtual = nil
        if not carregando then lib.hideTextUI() end
    end
end

-- Um laço só decide qual menu vale (vaga ou bancada), sem um apagar o outro.
-- A bancada tem prioridade quando você está colado nela.
CreateThread(function()
    while true do
        local espera = 500
        if podeMecanico() and not ocupado then
            local eu = GetEntityCoords(cache.ped)
            local alvo, tipo, indice

            for bi, b in ipairs(Config.bancadas) do
                if #(eu.xy - vec2(b.x, b.y)) <= 1.8 then alvo, tipo, indice = b, 'bancada', bi break end
            end
            if not alvo and not carregando then
                for _, m in ipairs(objetosPerto(Config.motor.propMotor, STATE_MOTOR, eu, 1.6)) do
                    local onde = estadoMotor(m.obj)['local']
                    -- 'mao' sem estar preso em ninguém = ficou no chão por algum erro
                    if onde == 'chao' or (onde == 'mao' and GetEntityAttachedTo(m.obj) == 0) then
                        alvo, tipo = m.obj, 'chao' break
                    end
                end
            end
            if not alvo then
                for vi, v in ipairs(Config.vagasMotor) do
                    if #(eu.xy - vec2(v.carro.x, v.carro.y)) <= v.raio + 1.5 then
                        alvo, tipo, indice = v, 'vaga', vi break
                    end
                end
            end

            if alvo then
                espera = 0
                local textos = { bancada = '[E] Bancada', vaga = '[E] Motor', chao = '[E] Pegar o motor' }
                if not carregando then mostrarTexto(textos[tipo]) end
                if IsControlJustReleased(0, 38) then
                    esconderTexto()
                    if tipo == 'bancada' then abrirMenuBancada(alvo)
                    elseif tipo == 'chao' then executar(comecarACarregar, alvo)
                    else abrirMenuVaga(indice) end
                end
            else
                esconderTexto()
            end
        else
            esconderTexto()
        end
        Wait(espera)
    end
end)

-- Motor largado no chão: pegar com o olho (Alt)
CreateThread(function()
    exports.ox_target:addModel(Config.motor.propMotor, {
        {
            name = 'pista_motor_pegar',
            icon = 'fa-solid fa-hand',
            label = 'Pegar o motor',
            distance = 2.5,
            canInteract = function(entity)
                local st = estadoMotor(entity)
                return st and st['local'] == 'chao' and not carregando and podeMecanico()
            end,
            onSelect = function(data) executar(comecarACarregar, data.entity) end,
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
    if not cfg then return end
    cfg.pos = vec3(x + 0.0, y + 0.0, z + 0.0)
    if cfg.rot then cfg.rot = vec3(cfg.rot.x, cfg.rot.y, rz + 0.0) end

    if tipo == 'carregar' and carregando then
        prenderNosBracos(carregando)
    elseif tipo == 'gancho' then
        for _, m in ipairs(objetosPerto(Config.motor.propMotor, STATE_MOTOR, GetEntityCoords(cache.ped), 15.0)) do
            local pai = GetEntityAttachedTo(m.obj)
            if pai ~= 0 and GetEntityModel(pai) == Config.motor.propGuincho then pendurarNoGancho(m.obj, pai) end
        end
    elseif tipo == 'corda' then
        for motor in pairs(cordas) do apagarCorda(motor) end
    end

    local linha = tipo == 'corda' and ('corda pos = vec3(%.2f, %.2f, %.2f)'):format(x, y, z)
        or ('%s = { pos = vec3(%.2f, %.2f, %.2f), rot = vec3(0.0, 0.0, %.1f) },'):format(tipo, x, y, z, rz)
    lib.setClipboard(linha)
    print('[pista_tuning] ' .. linha)
    Avisar('Ajuste aplicado e copiado. Me mande quando ficar bom.', 'success', 6000)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for motor in pairs(cordas) do apagarCorda(motor) end
    RopeUnloadTextures()
    if carregando then pararDeCarregar() end
    if textoAtual then lib.hideTextUI() end
    exports.ox_target:removeModel(Config.motor.propMotor, 'pista_motor_pegar')
    for _, p in ipairs(Config.esconderGuinchosMLO or {}) do
        RemoveModelHide(p.x, p.y, p.z, 2.0, Config.motor.propGuincho, false)
    end
end)
