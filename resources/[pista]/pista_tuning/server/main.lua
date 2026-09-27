-- pista_tuning - servidor
-- Toda validação importante acontece aqui (o cliente só pede).

local STATE_KEY = 'pista_tuning'
local STATE_GUINCHO = 'pista_guincho'
local STATE_MOTOR = 'pista_motor'

---------------------------------------------------------------------
-- Banco de dados / dados por placa
---------------------------------------------------------------------
local cache = {} -- [placa] = dados

local function trim(s)
    local r = (s or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return r
end

local function placaDo(veh)
    return trim(GetVehicleNumberPlateText(veh))
end

local function carroTemDono(plate)
    return MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate }) ~= nil
end

local function obterDados(plate)
    if cache[plate] then return cache[plate] end
    local raw = MySQL.scalar.await('SELECT dados FROM pista_tuning WHERE plate = ?', { plate })
    cache[plate] = raw and json.decode(raw) or {}
    return cache[plate]
end

local function veiculosDaPlaca(plate)
    local lista = {}
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and placaDo(veh) == plate then lista[#lista + 1] = veh end
    end
    return lista
end

--- Salva a preparação da placa: cache, state bag dos carros com essa placa e banco.
local function salvar(plate, dados)
    cache[plate] = dados
    for _, veh in ipairs(veiculosDaPlaca(plate)) do
        Entity(veh).state:set(STATE_KEY, dados, true)
    end
    if carroTemDono(plate) then -- carro de spawn/NPC não fica salvo
        MySQL.insert.await(
            'INSERT INTO pista_tuning (plate, dados) VALUES (?, ?) ON DUPLICATE KEY UPDATE dados = VALUES(dados)',
            { plate, json.encode(dados) }
        )
    end
end

local function dadosDoVeiculo(veh)
    local dados = obterDados(placaDo(veh))
    if not Entity(veh).state[STATE_KEY] then
        Entity(veh).state:set(STATE_KEY, dados, true)
    end
    return dados
end

local function aplicarDados(veh, dados)
    salvar(placaDo(veh), dados)
end

---------------------------------------------------------------------
-- Skill / permissão
---------------------------------------------------------------------
local function nivelPorXP(xp)
    local nivel = 0
    for n = 1, #Config.niveisXP do
        if xp >= Config.niveisXP[n] then nivel = n end
    end
    return nivel
end

local function xpDo(player)
    return tonumber(player.PlayerData.metadata.tuning_xp) or 0
end

--- Nível efetivo: o maior entre a skill e o cargo de mecânico especializado.
local function nivelEfetivo(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return 0 end

    local nivel = nivelPorXP(xpDo(player))
    local job = player.PlayerData.job
    local cfg = Config.mecanico

    if job and job.name == cfg.job and (job.onduty or not cfg.precisaEstarEmServico) then
        local grade = job.grade and job.grade.level or 0
        if grade >= cfg.gradeMinimo then
            nivel = math.max(nivel, grade)
        end
    end

    return nivel
end
exports('nivelEfetivo', nivelEfetivo)

local function exigirNivel(source, minimo)
    local nivel = nivelEfetivo(source)
    if nivel < (minimo or 1) then
        return ('Você precisa de nível %d em preparação (seu nível: %d)'):format(minimo or 1, nivel)
    end
end

local function darXP(source, quantidade)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or not quantidade or quantidade <= 0 then return end
    local antes = xpDo(player)
    local depois = antes + quantidade
    player.Functions.SetMetaData('tuning_xp', depois)

    local nAntes, nDepois = nivelPorXP(antes), nivelPorXP(depois)
    if nDepois > nAntes then
        exports.qbx_core:Notify(source, ('Sua skill de preparação subiu para o nível %d!'):format(nDepois), 'success', 7000)
    else
        exports.qbx_core:Notify(source, ('+%d XP de preparação'):format(quantidade), 'inform')
    end
    TriggerClientEvent('pista_tuning:client:atualizarNivel', source)
end

---------------------------------------------------------------------
-- Ferramentas (durabilidade)
---------------------------------------------------------------------
local function slotFerramenta(source, chave)
    local f = Config.ferramentas[chave]
    local slots = exports.ox_inventory:GetSlotsWithItem(source, f.item) or {}
    -- usa a mais gasta primeiro
    table.sort(slots, function(a, b)
        return ((a.metadata and a.metadata.durability) or 100) < ((b.metadata and b.metadata.durability) or 100)
    end)
    return slots[1], f
end

local function exigirFerramenta(source, chave)
    local slot, f = slotFerramenta(source, chave)
    if not slot then return ('Você precisa de %s'):format(f.label) end
end

local function gastarFerramenta(source, chave, tipo)
    local slot, f = slotFerramenta(source, chave)
    if not slot then return end
    local atual = (slot.metadata and slot.metadata.durability) or 100
    local nova = atual - (f.desgaste[tipo] or 0)
    if nova <= 0 then
        exports.ox_inventory:RemoveItem(source, f.item, 1, nil, slot.slot)
        exports.qbx_core:Notify(source, ('%s quebrou!'):format(f.label), 'error', 6000)
    else
        exports.ox_inventory:SetDurability(source, slot.slot, nova)
    end
end

---------------------------------------------------------------------
-- Lugares
---------------------------------------------------------------------
local function naOficina(coords)
    for _, o in ipairs(Config.oficinas) do
        if #(coords - o.coords) <= o.raio then return true end
    end
    return false
end

local function frenteDo(veh, distancia)
    local c = GetEntityCoords(veh)
    local h = math.rad(GetEntityHeading(veh))
    return vec3(c.x - math.sin(h) * distancia, c.y + math.cos(h) * distancia, c.z)
end

local function pegarVeiculo(source, netId, permitirDentro)
    local veh = NetworkGetEntityFromNetworkId(netId or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then
        return nil, 'Veículo não encontrado'
    end
    local ped = GetPlayerPed(source)
    local dentro = GetVehiclePedIsIn(ped, false) == veh
    if dentro and not permitirDentro then
        return nil, 'Saia do veículo para trabalhar nele'
    end
    if not dentro and #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 6.0 then
        return nil, 'Você está longe do veículo'
    end
    return veh
end

local function objetosComState(chave)
    local lista = {}
    for _, obj in ipairs(GetAllObjects()) do
        if DoesEntityExist(obj) and Entity(obj).state[chave] then lista[#lista + 1] = obj end
    end
    return lista
end

local function motorDaPlaca(plate)
    for _, obj in ipairs(objetosComState(STATE_MOTOR)) do
        if Entity(obj).state[STATE_MOTOR].plate == plate then return obj end
    end
end

local function pegarObjeto(source, netId, chave, dist)
    local obj = NetworkGetEntityFromNetworkId(netId or 0)
    if not obj or obj == 0 or not DoesEntityExist(obj) or not Entity(obj).state[chave] then
        return nil, 'Objeto não encontrado'
    end
    if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(obj)) > (dist or 3.5) then
        return nil, 'Você está longe'
    end
    return obj
end

local function criarObjeto(modelo, coords, heading)
    local obj = CreateObjectNoOffset(modelo, coords.x, coords.y, coords.z, true, true, false)
    local tentativas = 0
    while not DoesEntityExist(obj) and tentativas < 50 do
        Wait(20)
        tentativas = tentativas + 1
    end
    if not DoesEntityExist(obj) then return nil end
    SetEntityHeading(obj, heading or 0.0)
    FreezeEntityPosition(obj, true)
    if SetEntityOrphanMode then SetEntityOrphanMode(obj, 2) end -- não some sozinho
    return obj
end

---------------------------------------------------------------------
-- Peças: utilidades
---------------------------------------------------------------------
local function itemDoSlot(slot, valor)
    for nome, p in pairs(Config.itens) do
        if p.slot == slot and p.valor == valor then return nome end
    end
end

local function slotEhDoMotor(slot)
    for _, p in pairs(Config.itens) do
        if p.slot == slot then return p.motor == true end
    end
    return false
end

local function labelSlot(slot)
    for _, s in ipairs(Config.slots) do
        if s.id == slot then return s.label end
    end
    return slot
end

local function checarRequisitos(peca, dados)
    if dados[peca.slot] == peca.valor then
        return ('%s já está instalado'):format(peca.label)
    end
    for _, req in ipairs(peca.requer or {}) do
        if not dados[req] then
            return ('Precisa ter %s instalado antes'):format(labelSlot(req))
        end
    end
end

local function checarDependentes(slot, dados)
    for _, p in pairs(Config.itens) do
        if dados[p.slot] == p.valor then
            for _, req in ipairs(p.requer or {}) do
                if req == slot then return ('Remova o %s antes'):format(p.label) end
            end
        end
    end
end

--- Coloca a peça e devolve a antiga (ex.: trocar stage do chip)
local function colocarPeca(source, dados, itemName, peca)
    local anterior = dados[peca.slot]
    if anterior ~= nil and anterior ~= false then
        local itemAntigo = itemDoSlot(peca.slot, anterior)
        if itemAntigo then exports.ox_inventory:AddItem(source, itemAntigo, 1) end
    end
    dados[peca.slot] = peca.valor
    if peca.slot == 'chip' then dados.remap = nil end -- chip novo vem com mapa original
    if peca.slot == 'nitro' and dados.nitroCarga == nil then dados.nitroCarga = 0.0 end
    if peca.slot == 'cabecote' and dados.remap then dados.remap = NormalizarRemap(dados.remap, dados) end
end

local function tirarPeca(source, dados, slot)
    local valor = dados[slot]
    local item = itemDoSlot(slot, valor)
    if item and not exports.ox_inventory:CanCarryItem(source, item, 1) then
        return false, 'Você não tem espaço no inventário'
    end
    dados[slot] = nil
    if slot == 'nitro' then dados.nitroCarga = nil end
    if slot == 'chip' then dados.remap = nil end
    if (slot == 'turbo' or slot == 'cabecote') and dados.remap then dados.remap = NormalizarRemap(dados.remap, dados) end
    if item then exports.ox_inventory:AddItem(source, item, 1) end
    return true
end

---------------------------------------------------------------------
-- Peças externas (turbo, intercooler, nitro, chip)
---------------------------------------------------------------------
local function validarPecaExterna(source, netId, itemName)
    local peca = Config.itens[itemName]
    if not peca then return nil, 'Essa peça não existe' end
    if peca.motor then return nil, ('%s vai dentro do motor: tire o motor e abra ele'):format(peca.label) end

    local veh, err = pegarVeiculo(source, netId, false)
    if not veh then return nil, err end
    if Config.pecasExternasSoNaOficina and not naOficina(GetEntityCoords(veh)) then
        return nil, 'Isso só pode ser feito dentro da oficina'
    end
    err = exigirNivel(source, peca.nivel)
    if err then return nil, err end
    if exports.ox_inventory:Search(source, 'count', itemName) < 1 then
        return nil, ('Você não tem %s'):format(peca.label)
    end
    if peca.slot ~= 'chip' then
        err = exigirFerramenta(source, 'soquetes')
        if err then return nil, err end
    end

    local dados = dadosDoVeiculo(veh)
    err = checarRequisitos(peca, dados)
    if err then return nil, err end
    return veh, nil, peca, dados
end

lib.callback.register('pista_tuning:server:podeInstalar', function(source, netId, itemName)
    local veh, err = validarPecaExterna(source, netId, itemName)
    return veh ~= nil, err
end)

lib.callback.register('pista_tuning:server:instalar', function(source, netId, itemName)
    local veh, err, peca, dados = validarPecaExterna(source, netId, itemName)
    if not veh then return false, err end

    if not exports.ox_inventory:RemoveItem(source, itemName, 1) then
        return false, 'Não foi possível usar a peça'
    end
    colocarPeca(source, dados, itemName, peca)
    aplicarDados(veh, dados)
    if peca.slot ~= 'chip' then gastarFerramenta(source, 'soquetes', 'peca') end
    darXP(source, peca.xp)

    return true, ('%s instalado com sucesso'):format(peca.label)
end)

lib.callback.register('pista_tuning:server:remover', function(source, netId, slot)
    local veh, err = pegarVeiculo(source, netId, false)
    if not veh then return false, err end
    if slotEhDoMotor(slot) then return false, 'Essa peça é do motor: tire o motor e abra ele' end
    err = exigirNivel(source, 1)
    if err then return false, err end
    if slot ~= 'chip' then
        err = exigirFerramenta(source, 'soquetes')
        if err then return false, err end
    end

    local dados = dadosDoVeiculo(veh)
    if dados[slot] == nil or dados[slot] == false then return false, 'Não tem peça nesse slot' end
    err = checarDependentes(slot, dados)
    if err then return false, err end

    local ok, msg = tirarPeca(source, dados, slot)
    if not ok then return false, msg end
    aplicarDados(veh, dados)
    if slot ~= 'chip' then gastarFerramenta(source, 'soquetes', 'peca') end
    return true, 'Peça removida'
end)

---------------------------------------------------------------------
-- Guinchos da oficina
---------------------------------------------------------------------
-- state do guincho: { home = índice, carregadoPor = serverId|nil, motor = placa|nil }

local function estadoGuincho(obj) return Entity(obj).state[STATE_GUINCHO] end
local function estadoMotor(obj) return Entity(obj).state[STATE_MOTOR] end

--- Guincho parado (ninguém empurrando) perto de coords. motor: nil = qualquer,
--- false = sem motor pendurado, string = com o motor dessa placa.
local function guinchoParadoPerto(coords, dist, motor)
    local melhor, melhorDist
    for _, obj in ipairs(objetosComState(STATE_GUINCHO)) do
        local st = estadoGuincho(obj)
        local d = #(GetEntityCoords(obj) - coords)
        local motorOk = motor == nil or (motor == false and not st.motor) or (st.motor == motor)
        if not st.carregadoPor and motorOk and d <= dist and (not melhorDist or d < melhorDist) then
            melhor, melhorDist = obj, d
        end
    end
    return melhor
end

local function criarGuincho(indice)
    local p = Config.guinchos[indice]
    local obj = criarObjeto(Config.motor.propGuincho, vec3(p.x, p.y, p.z), p.w)
    if obj then Entity(obj).state:set(STATE_GUINCHO, { home = indice }, true) end
    return obj
end

local function exigirMecanico(source)
    return exigirNivel(source, Config.motor.nivel)
end

lib.callback.register('pista_tuning:server:pegarGuincho', function(source, netId)
    local obj, err = pegarObjeto(source, netId, STATE_GUINCHO, 3.0)
    if not obj then return false, err end
    err = exigirMecanico(source)
    if err then return false, err end
    local st = estadoGuincho(obj)
    if st.carregadoPor and GetPlayerPing(st.carregadoPor) > 0 then
        return false, 'Alguém já está empurrando esse guincho'
    end
    st.carregadoPor = source
    Entity(obj).state:set(STATE_GUINCHO, st, true)
    FreezeEntityPosition(obj, false)
    return true
end)

local function atualizarPosMotorPendurado(obj, st)
    if not st.motor then return end
    local dados = obterDados(st.motor)
    if dados.motor then
        local c = GetEntityCoords(obj)
        dados.motor.x, dados.motor.y, dados.motor.z, dados.motor.h = c.x, c.y, c.z, GetEntityHeading(obj)
        salvar(st.motor, dados)
    end
end

local function soltarGuincho(obj)
    local st = estadoGuincho(obj)
    st.carregadoPor = nil
    Entity(obj).state:set(STATE_GUINCHO, st, true)
    FreezeEntityPosition(obj, true)
    atualizarPosMotorPendurado(obj, st)
end

lib.callback.register('pista_tuning:server:soltarGuincho', function(source, netId)
    local obj = NetworkGetEntityFromNetworkId(netId or 0)
    if not obj or obj == 0 or not DoesEntityExist(obj) then return false end
    local st = estadoGuincho(obj)
    if not st or st.carregadoPor ~= source then return false end
    soltarGuincho(obj)
    return true
end)

lib.callback.register('pista_tuning:server:guardarGuincho', function(source, netId)
    local obj, err = pegarObjeto(source, netId, STATE_GUINCHO, 3.0)
    if not obj then return false, err end
    local st = estadoGuincho(obj)
    if st.carregadoPor then return false, 'Solte o guincho primeiro' end
    if st.motor then return false, 'Tire o motor do guincho antes de guardar' end
    local p = Config.guinchos[st.home]
    if not p or #(GetEntityCoords(obj) - vec3(p.x, p.y, p.z)) > 6.0 then
        return false, 'Leve o guincho até o lugar dele'
    end
    SetEntityCoords(obj, p.x, p.y, p.z, false, false, false, false)
    SetEntityHeading(obj, p.w)
    FreezeEntityPosition(obj, true)
    return true, 'Guincho guardado'
end)

-- Quem sai do jogo empurrando um guincho: ele fica onde parou
AddEventHandler('playerDropped', function()
    local src = source
    for _, obj in ipairs(objetosComState(STATE_GUINCHO)) do
        if estadoGuincho(obj).carregadoPor == src then soltarGuincho(obj) end
    end
end)

---------------------------------------------------------------------
-- Motor
---------------------------------------------------------------------
-- state do motor: { plate, aberto, local = 'guincho'|'bancada'|'chao' }

local function criarMotor(plate, m)
    local obj = criarObjeto(Config.motor.propMotor, vec3(m.x, m.y, m.z), m.h)
    if obj then
        Entity(obj).state:set(STATE_MOTOR, { plate = plate, aberto = m.aberto == true, ['local'] = m['local'] or 'chao' }, true)
    end
    return obj
end

local function salvarMotor(plate, mudancas)
    local dados = obterDados(plate)
    if not dados.motor then return end
    for k, v in pairs(mudancas) do dados.motor[k] = v end
    salvar(plate, dados)
end

lib.callback.register('pista_tuning:server:retirarMotor', function(source, netId)
    local veh, err = pegarVeiculo(source, netId, false)
    if not veh then return false, err end
    if not naOficina(GetEntityCoords(veh)) then return false, 'Só dá para tirar o motor dentro da oficina' end
    err = exigirMecanico(source) or exigirFerramenta(source, 'soquetes')
    if err then return false, err end

    local plate = placaDo(veh)
    local dados = dadosDoVeiculo(veh)
    if dados.motor then return false, 'Esse carro já está sem motor' end
    if GetPedInVehicleSeat(veh, -1) ~= 0 then return false, 'Tem alguém no volante' end

    local guincho = guinchoParadoPerto(frenteDo(veh, 2.2), Config.motor.distanciaGuincho, false)
    if not guincho then return false, 'Traga o guincho (vazio) para a frente do carro' end

    local gc = GetEntityCoords(guincho)
    local m = { x = gc.x, y = gc.y, z = gc.z + 1.0, h = GetEntityHeading(guincho), aberto = false, ['local'] = 'guincho' }
    local motor = criarMotor(plate, m)
    if not motor then return false, 'Não foi possível tirar o motor' end

    local stG = estadoGuincho(guincho)
    stG.motor = plate
    Entity(guincho).state:set(STATE_GUINCHO, stG, true)

    m.z = gc.z
    dados.motor = m
    aplicarDados(veh, dados)
    gastarFerramenta(source, 'soquetes', 'motor')
    darXP(source, Config.motor.xpRetirar)
    return true, 'Motor no guincho. Leve até a bancada.', NetworkGetNetworkIdFromEntity(motor), NetworkGetNetworkIdFromEntity(guincho)
end)

lib.callback.register('pista_tuning:server:recolocarMotor', function(source, netId)
    local veh, err = pegarVeiculo(source, netId, false)
    if not veh then return false, err end
    if not naOficina(GetEntityCoords(veh)) then return false, 'Só dá para colocar o motor dentro da oficina' end
    err = exigirMecanico(source) or exigirFerramenta(source, 'soquetes')
    if err then return false, err end

    local plate = placaDo(veh)
    local dados = dadosDoVeiculo(veh)
    if not dados.motor then return false, 'Esse carro está com motor' end

    local guincho = guinchoParadoPerto(frenteDo(veh, 2.2), Config.motor.distanciaGuincho, plate)
    if not guincho then return false, 'Traga o guincho com o motor deste carro para a frente dele' end

    local motor = motorDaPlaca(plate)
    if motor then DeleteEntity(motor) end
    local stG = estadoGuincho(guincho)
    stG.motor = nil
    Entity(guincho).state:set(STATE_GUINCHO, stG, true)

    dados.motor = nil
    aplicarDados(veh, dados)
    gastarFerramenta(source, 'soquetes', 'motor')
    return true, 'Motor recolocado'
end)

--- Bancada livre perto de coords (sem outro motor em cima)
local function bancadaLivrePerto(coords, coords2)
    for i, b in ipairs(Config.bancadas) do
        local bc = vec3(b.x, b.y, b.z)
        local perto = #(coords - bc) <= Config.motor.distanciaBancada
            or (coords2 and #(coords2 - bc) <= Config.motor.distanciaBancada)
        if perto then
            local ocupada = false
            for _, obj in ipairs(objetosComState(STATE_MOTOR)) do
                if estadoMotor(obj)['local'] ~= 'guincho' and #(GetEntityCoords(obj) - bc) < 1.2 then ocupada = true end
            end
            if not ocupada then return i, b end
        end
    end
end

-- Passo 1: o servidor confirma e diz para qual bancada; o cliente solta o motor lá
lib.callback.register('pista_tuning:server:podeDescerNaBancada', function(source, netId)
    local guincho, err = pegarObjeto(source, netId, STATE_GUINCHO, 3.5)
    if not guincho then return false, err end
    err = exigirMecanico(source)
    if err then return false, err end
    local stG = estadoGuincho(guincho)
    if stG.carregadoPor then return false, 'Solte o guincho primeiro' end
    if not stG.motor then return false, 'Não tem motor no guincho' end
    local motor = motorDaPlaca(stG.motor)
    if not motor then return false, 'Motor não encontrado' end
    local i, b = bancadaLivrePerto(GetEntityCoords(guincho), GetEntityCoords(motor))
    if not i then return false, 'Leve o guincho mais perto da bancada (ou ela já tem um motor)' end
    return true, { bancada = i, x = b.x, y = b.y, z = b.z, h = b.w, motor = NetworkGetNetworkIdFromEntity(motor) }
end)

-- Passo 2: motor já está na bancada
lib.callback.register('pista_tuning:server:motorNaBancada', function(source, guinchoNet, bancada)
    local guincho = NetworkGetEntityFromNetworkId(guinchoNet or 0)
    local b = Config.bancadas[bancada]
    if not guincho or guincho == 0 or not DoesEntityExist(guincho) or not b then return false end
    local stG = estadoGuincho(guincho)
    if not stG or not stG.motor then return false end
    local plate = stG.motor
    local motor = motorDaPlaca(plate)
    if not motor then return false end

    FreezeEntityPosition(motor, true)
    local mc = GetEntityCoords(motor)
    local st = estadoMotor(motor)
    st['local'] = 'bancada'
    Entity(motor).state:set(STATE_MOTOR, st, true)
    stG.motor = nil
    Entity(guincho).state:set(STATE_GUINCHO, stG, true)
    salvarMotor(plate, { x = mc.x, y = mc.y, z = mc.z, h = GetEntityHeading(motor), ['local'] = 'bancada' })
    return true, 'Motor na bancada. Abra com o torquímetro.'
end)

lib.callback.register('pista_tuning:server:pendurarMotor', function(source, motorNet)
    local motor, err = pegarObjeto(source, motorNet, STATE_MOTOR, 3.0)
    if not motor then return false, err end
    err = exigirMecanico(source)
    if err then return false, err end
    local st = estadoMotor(motor)
    if st['local'] == 'guincho' then return false, 'O motor já está no guincho' end
    if st.aberto then return false, 'Feche o motor antes' end

    local guincho = guinchoParadoPerto(GetEntityCoords(motor), Config.motor.distanciaBancada + 0.5, false)
    if not guincho then return false, 'Traga um guincho vazio até o motor' end

    st['local'] = 'guincho'
    Entity(motor).state:set(STATE_MOTOR, st, true)
    local stG = estadoGuincho(guincho)
    stG.motor = st.plate
    Entity(guincho).state:set(STATE_GUINCHO, stG, true)
    local gc = GetEntityCoords(guincho)
    salvarMotor(st.plate, { x = gc.x, y = gc.y, z = gc.z, h = GetEntityHeading(guincho), ['local'] = 'guincho' })
    return true, 'Motor no guincho', NetworkGetNetworkIdFromEntity(guincho)
end)

local function validarMotorAberto(source, netId, precisaAberto)
    local obj, err = pegarObjeto(source, netId, STATE_MOTOR, 3.5)
    if not obj then return nil, err end
    local st = estadoMotor(obj)
    if st['local'] ~= 'bancada' then return nil, 'Coloque o motor na bancada primeiro' end
    err = exigirMecanico(source) or exigirFerramenta(source, 'torquimetro')
    if err then return nil, err end
    if precisaAberto ~= nil and st.aberto ~= precisaAberto then
        return nil, precisaAberto and 'Abra o motor primeiro' or 'O motor já está aberto'
    end
    return obj, nil, st, obterDados(st.plate)
end

lib.callback.register('pista_tuning:server:dadosMotor', function(source, netId)
    local obj = NetworkGetEntityFromNetworkId(netId or 0)
    if not obj or obj == 0 or not DoesEntityExist(obj) or not estadoMotor(obj) then return nil end
    local st = estadoMotor(obj)
    return obterDados(st.plate), st
end)

lib.callback.register('pista_tuning:server:abrirFecharMotor', function(source, netId, abrir)
    local obj, err, st = validarMotorAberto(source, netId, not abrir)
    if not obj then return false, err end

    st.aberto = abrir == true
    Entity(obj).state:set(STATE_MOTOR, st, true)
    salvarMotor(st.plate, { aberto = st.aberto })
    gastarFerramenta(source, 'torquimetro', 'abrir')
    return true, abrir and 'Motor aberto' or 'Motor fechado'
end)

lib.callback.register('pista_tuning:server:instalarNoMotor', function(source, netId, itemName)
    local peca = Config.itens[itemName]
    if not peca or not peca.motor then return false, 'Essa peça não vai dentro do motor' end

    local obj, err, st, dados = validarMotorAberto(source, netId, true)
    if not obj then return false, err end
    err = exigirNivel(source, peca.nivel) or checarRequisitos(peca, dados)
    if err then return false, err end
    if not exports.ox_inventory:RemoveItem(source, itemName, 1) then
        return false, ('Você não tem %s'):format(peca.label)
    end

    colocarPeca(source, dados, itemName, peca)
    salvar(st.plate, dados)
    gastarFerramenta(source, 'torquimetro', 'peca')
    darXP(source, peca.xp)
    return true, ('%s instalado no motor'):format(peca.label)
end)

lib.callback.register('pista_tuning:server:removerDoMotor', function(source, netId, slot)
    if not slotEhDoMotor(slot) then return false, 'Essa peça não é do motor' end
    local obj, err, st, dados = validarMotorAberto(source, netId, true)
    if not obj then return false, err end
    if dados[slot] == nil or dados[slot] == false then return false, 'Não tem peça nesse slot' end
    err = checarDependentes(slot, dados)
    if err then return false, err end

    local ok, msg = tirarPeca(source, dados, slot)
    if not ok then return false, msg end
    salvar(st.plate, dados)
    gastarFerramenta(source, 'torquimetro', 'peca')
    return true, 'Peça retirada do motor'
end)

---------------------------------------------------------------------
-- Início / fim do script
---------------------------------------------------------------------
local function limparObjetos()
    for _, obj in ipairs(objetosComState(STATE_GUINCHO)) do DeleteEntity(obj) end
    for _, obj in ipairs(objetosComState(STATE_MOTOR)) do DeleteEntity(obj) end
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then limparObjetos() end
end)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `pista_tuning` (
            `plate` VARCHAR(12) NOT NULL,
            `dados` LONGTEXT NOT NULL,
            `atualizado` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`plate`)
        )
    ]])

    CreateThread(function()
        Wait(2000)
        limparObjetos()

        -- guinchos nos lugares deles
        for i = 1, #Config.guinchos do criarGuincho(i) end

        -- motores que estavam fora do carro continuam fora
        local linhas = MySQL.query.await('SELECT plate, dados FROM pista_tuning WHERE dados LIKE ?', { '%"motor":{%' }) or {}
        for _, linha in ipairs(linhas) do
            local dados = json.decode(linha.dados)
            if dados and dados.motor then
                cache[linha.plate] = dados
                -- estava pendurado: fica no chão onde o guincho parou
                if dados.motor['local'] == 'guincho' then dados.motor['local'] = 'chao' end
                criarMotor(linha.plate, dados.motor)
            end
        end
    end)
end)

---------------------------------------------------------------------
-- Leitura / nível
---------------------------------------------------------------------
lib.callback.register('pista_tuning:server:meuNivel', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    return nivelEfetivo(source), player and xpDo(player) or 0
end)

lib.callback.register('pista_tuning:server:carregar', function(source, netId)
    local veh = NetworkGetEntityFromNetworkId(netId or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    return dadosDoVeiculo(veh)
end)

---------------------------------------------------------------------
-- Nitro
---------------------------------------------------------------------
lib.callback.register('pista_tuning:server:recarregarNitro', function(source, netId)
    local veh, err = pegarVeiculo(source, netId, true)
    if not veh then return false, err end

    local dados = dadosDoVeiculo(veh)
    if not dados.nitro then return false, 'Esse carro não tem kit de nitro' end
    if (dados.nitroCarga or 0) >= Config.nitro.cargaGarrafa then return false, 'O nitro já está cheio' end

    if not exports.ox_inventory:RemoveItem(source, Config.nitro.itemGarrafa, 1) then
        return false, 'Você não tem garrafa de nitro'
    end

    dados.nitroCarga = Config.nitro.cargaGarrafa
    aplicarDados(veh, dados)
    return true, 'Nitro recarregado'
end)

RegisterNetEvent('pista_tuning:server:usouNitro', function(netId, gasto)
    local source = source
    local veh = NetworkGetEntityFromNetworkId(netId or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(source) then return end

    local dados = dadosDoVeiculo(veh)
    if not dados.nitro then return end

    gasto = math.max(0.0, math.min(tonumber(gasto) or 0.0, Config.nitro.cargaGarrafa))
    dados.nitroCarga = math.max(0.0, (dados.nitroCarga or 0.0) - gasto)
    aplicarDados(veh, dados)
end)

---------------------------------------------------------------------
-- Notebook de remap (em qualquer lugar)
---------------------------------------------------------------------
local function validarRemap(source, netId)
    local veh, err = pegarVeiculo(source, netId, true)
    if not veh then return nil, err end
    err = exigirNivel(source, Config.remap.nivel)
    if err then return nil, err end
    if exports.ox_inventory:Search(source, 'count', Config.remap.item) < 1 then
        return nil, 'Você precisa do notebook de remap'
    end
    local dados = dadosDoVeiculo(veh)
    if not dados.chip then return nil, 'Esse carro não tem chip instalado' end
    return veh, nil, dados
end

lib.callback.register('pista_tuning:server:abrirRemap', function(source, netId)
    local veh, err, dados = validarRemap(source, netId)
    if not veh then return false, err end
    return true, {
        dados = dados,
        remap = NormalizarRemap(dados.remap, dados),
        placa = placaDo(veh),
    }
end)

lib.callback.register('pista_tuning:server:gravarRemap', function(source, netId, valores)
    local veh, err, dados = validarRemap(source, netId)
    if not veh then return false, err end

    dados.remap = NormalizarRemap(valores, dados)
    aplicarDados(veh, dados)
    darXP(source, Config.remap.xp)

    local risco = CalcularRemap(dados.remap, dados).risco
    return true, ('Mapa gravado na ECU (risco ao motor: %d%%)'):format(math.floor(risco))
end)

---------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------
lib.addCommand('minhaskill', {
    help = 'Ver seu nível de preparação',
}, function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    local xp = xpDo(player)
    local nivel = nivelPorXP(xp)
    local prox = Config.niveisXP[nivel + 1]
    local texto = prox and ('Skill de preparação: nível %d (%d/%d XP)'):format(nivel, xp, prox)
        or ('Skill de preparação: nível %d (máximo, %d XP)'):format(nivel, xp)
    local efetivo = nivelEfetivo(source)
    if efetivo > nivel then texto = texto .. (' | Como mecânico: nível %d'):format(efetivo) end
    exports.qbx_core:Notify(source, texto, 'inform', 8000)
end)

lib.addCommand('setskill', {
    help = 'Definir nível de preparação de um jogador',
    params = {
        { name = 'id', type = 'playerId', help = 'ID do jogador' },
        { name = 'nivel', type = 'number', help = 'Nível (0 a 4)' },
    },
    restricted = 'group.admin',
}, function(source, args)
    local alvo = exports.qbx_core:GetPlayer(args.id)
    if not alvo then return end
    local nivel = math.max(0, math.min(math.floor(args.nivel), #Config.niveisXP))
    alvo.Functions.SetMetaData('tuning_xp', nivel == 0 and 0 or Config.niveisXP[nivel])
    TriggerClientEvent('pista_tuning:client:atualizarNivel', args.id)
    exports.qbx_core:Notify(args.id, ('Sua skill de preparação agora é nível %d'):format(nivel), 'success')
    if source > 0 then
        exports.qbx_core:Notify(source, ('Skill do ID %d definida para nível %d'):format(args.id, nivel), 'success')
    end
end)

lib.addCommand('pegarcoords', {
    help = 'Mostra e copia a sua posição (para configurar a oficina)',
    restricted = 'group.admin',
}, function(source)
    TriggerClientEvent('pista_tuning:client:coords', source)
end)

lib.addCommand('ajustegancho', {
    help = 'Ajusta onde o motor fica pendurado no guincho',
    params = {
        { name = 'x', type = 'number' }, { name = 'y', type = 'number' }, { name = 'z', type = 'number' },
        { name = 'rz', type = 'number', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    TriggerClientEvent('pista_tuning:client:ajuste', source, 'gancho', args.x, args.y, args.z, args.rz or 0.0)
end)

lib.addCommand('ajusteempurrar', {
    help = 'Ajusta a posição do guincho enquanto você empurra',
    params = {
        { name = 'x', type = 'number' }, { name = 'y', type = 'number' }, { name = 'z', type = 'number' },
        { name = 'rz', type = 'number', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    TriggerClientEvent('pista_tuning:client:ajuste', source, 'empurrar', args.x, args.y, args.z, args.rz or 180.0)
end)
