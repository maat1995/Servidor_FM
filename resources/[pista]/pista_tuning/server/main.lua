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
    if cache[plate].pistao == true then cache[plate].pistao = 'forjado' end -- versão antiga
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

    -- O motor sai do cofre direto para os braços do mecânico
    local fc = frenteDo(veh, 1.6)
    local m = { x = fc.x, y = fc.y, z = fc.z + 0.5, h = GetEntityHeading(veh), aberto = false, ['local'] = 'mao' }
    local motor = criarMotor(plate, m)
    if not motor then return false, 'Não foi possível tirar o motor' end
    local st = estadoMotor(motor)
    st.carregadoPor = source
    Entity(motor).state:set(STATE_MOTOR, st, true)
    FreezeEntityPosition(motor, false)

    m.z = fc.z
    m['local'] = 'chao' -- se o servidor cair com ele na mão, fica no chão
    dados.motor = m
    aplicarDados(veh, dados)
    gastarFerramenta(source, 'soquetes', 'motor')
    darXP(source, Config.motor.xpRetirar)
    return true, 'Motor retirado. Leve até a bancada.', NetworkGetNetworkIdFromEntity(motor)
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

    local motor = motorDaPlaca(plate)
    local st = motor and estadoMotor(motor)
    if not st or st.carregadoPor ~= source then return false, 'Traga o motor deste carro nos braços' end
    if #(GetEntityCoords(motor) - GetEntityCoords(veh)) > 6.0 then return false, 'Chegue mais perto do carro' end
    DeleteEntity(motor)

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
                local onde = estadoMotor(obj)['local']
                if onde ~= 'guincho' and onde ~= 'mao' and #(GetEntityCoords(obj) - bc) < 1.2 then ocupada = true end
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
        if Config.motor.usarGuincho then
            for i = 1, #Config.guinchos do criarGuincho(i) end
        end

        -- motores que estavam fora do carro continuam fora
        local linhas = MySQL.query.await('SELECT plate, dados FROM pista_tuning WHERE dados LIKE ?', { '%"motor":{%' }) or {}
        for _, linha in ipairs(linhas) do
            local dados = json.decode(linha.dados)
            if dados and dados.motor then
                cache[linha.plate] = dados
                -- estava pendurado: fica no chão onde o guincho parou
                if dados.motor['local'] == 'guincho' or dados.motor['local'] == 'mao' then dados.motor['local'] = 'chao' end
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

lib.addCommand('ajustecorda', {
    help = 'Ajusta de onde sai a corda no guincho',
    params = { { name = 'x', type = 'number' }, { name = 'y', type = 'number' }, { name = 'z', type = 'number' } },
    restricted = 'group.admin',
}, function(source, args)
    TriggerClientEvent('pista_tuning:client:ajuste', source, 'corda', args.x, args.y, args.z, 0.0)
end)

---------------------------------------------------------------------
-- Elevador: rodas, freio e suspensão
---------------------------------------------------------------------
local STATE_ELEV = 'pista_elevador'
local STATE_RODAS = 'pista_rodas'

local function exigirMecanicoElevador(source)
    local player = exports.qbx_core:GetPlayer(source)
    local job = player and player.PlayerData.job
    local cfg = Config.elevador
    if not job or job.name ~= cfg.job then return 'Só mecânico pode usar o elevador' end
    if cfg.precisaEstarEmServico and not job.onduty then return 'Entre em serviço primeiro' end
end

local function carroComGente(veh)
    for assento = -1, 6 do
        if GetPedInVehicleSeat(veh, assento) ~= 0 then return true end
    end
    return false
end

local function elevadorOcupado(i)
    for _, veh in ipairs(GetAllVehicles()) do
        local st = Entity(veh).state[STATE_ELEV]
        if st and st.i == i then return true end
    end
    return false
end

local function validarNoAlto(source, netId)
    local veh, err = pegarVeiculo(source, netId, false)
    if not veh then return nil, err end
    err = exigirMecanicoElevador(source)
    if err then return nil, err end
    local st = Entity(veh).state[STATE_ELEV]
    if not st or not st.alto or st.descendo then return nil, 'O carro precisa estar no alto do elevador' end
    return veh, nil, st
end

local function nivelNome(nivel)
    return ({ [0] = 'de rua', [1] = 'esportivo', [2] = 'de competição' })[nivel] or tostring(nivel)
end

local function itemDoKit(kits, nivel)
    for nome, k in pairs(kits) do
        if k.nivel == nivel then return nome end
    end
end

lib.callback.register('pista_tuning:server:subirElevador', function(source, netId)
    local veh, err = pegarVeiculo(source, netId, false)
    if not veh then return false, err end
    err = exigirMecanicoElevador(source)
    if err then return false, err end
    if Entity(veh).state[STATE_ELEV] then return false, 'O carro já está no elevador' end
    if carroComGente(veh) then return false, 'Tire todo mundo de dentro do carro' end

    local c = GetEntityCoords(veh)
    local escolhido
    for i, e in ipairs(Config.elevadores) do
        if #(vec2(c.x, c.y) - vec2(e.coords.x, e.coords.y)) <= e.raio then escolhido = i break end
    end
    if not escolhido then return false, 'Posicione o carro entre as colunas do elevador' end
    if elevadorOcupado(escolhido) then return false, 'Esse elevador já está ocupado' end

    Entity(veh).state:set(STATE_ELEV, { i = escolhido, z0 = c.z, alto = true }, true)
    Entity(veh).state:set(STATE_RODAS, {}, true)
    return true, { z0 = c.z }
end)

lib.callback.register('pista_tuning:server:descerElevador', function(source, netId)
    local veh, err, st = validarNoAlto(source, netId)
    if not veh then return false, err end
    if next(Entity(veh).state[STATE_RODAS] or {}) then return false, 'Coloque todas as rodas antes de descer' end
    st.descendo = true
    Entity(veh).state:set(STATE_ELEV, st, true)
    return true, { z0 = st.z0 }
end)

lib.callback.register('pista_tuning:server:elevadorLiberado', function(source, netId)
    local veh = NetworkGetEntityFromNetworkId(netId or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local st = Entity(veh).state[STATE_ELEV]
    if st and st.descendo then
        Entity(veh).state:set(STATE_ELEV, nil, true)
        Entity(veh).state:set(STATE_RODAS, nil, true)
    end
    return true
end)

local function rodaValida(roda)
    roda = tonumber(roda)
    return roda and roda >= 0 and roda <= 3 and math.floor(roda) == roda and roda or nil
end

lib.callback.register('pista_tuning:server:retirarRoda', function(source, netId, roda)
    local veh, err = validarNoAlto(source, netId)
    if not veh then return false, err end
    roda = rodaValida(roda)
    if not roda then return false, 'Roda inválida' end
    local rodas = Entity(veh).state[STATE_RODAS] or {}
    if rodas['r' .. roda] then return false, 'Essa roda já está fora' end
    rodas['r' .. roda] = true
    Entity(veh).state:set(STATE_RODAS, rodas, true)
    return true, 'Roda fora'
end)

lib.callback.register('pista_tuning:server:registrarRoda', function(source, netId, roda, propNet)
    local veh = NetworkGetEntityFromNetworkId(netId or 0)
    roda = rodaValida(roda)
    if not veh or veh == 0 or not DoesEntityExist(veh) or not roda then return false end
    local rodas = Entity(veh).state[STATE_RODAS] or {}
    if rodas['r' .. roda] then
        rodas['r' .. roda] = tonumber(propNet) or true
        Entity(veh).state:set(STATE_RODAS, rodas, true)
    end
    return true
end)

lib.callback.register('pista_tuning:server:recolocarRoda', function(source, netId, roda)
    local veh, err = validarNoAlto(source, netId)
    if not veh then return false, err end
    roda = rodaValida(roda)
    if not roda then return false, 'Roda inválida' end
    local rodas = Entity(veh).state[STATE_RODAS] or {}
    local prop = rodas['r' .. roda]
    if not prop then return false, 'Essa roda já está no carro' end

    if type(prop) == 'number' then
        local obj = NetworkGetEntityFromNetworkId(prop)
        if obj and obj ~= 0 and DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    rodas['r' .. roda] = nil
    Entity(veh).state:set(STATE_RODAS, rodas, true)
    return true, 'Roda recolocada'
end)

--- Kits que vão roda por roda (freio e suspensão): 1 kit = 4 rodas
local function kitDaRoda(tipo, itemName)
    if tipo == 'freio' then
        local k = Config.kitsFreio[itemName]
        return k and { label = k.label, nivel = k.nivel, obra = 'freioObra' } or nil
    elseif tipo == 'susp' and itemName == Config.suspensao.item then
        return { label = Config.suspensao.label, obra = 'suspObra' }
    end
end

lib.callback.register('pista_tuning:server:instalarNaRoda', function(source, netId, roda, tipo, itemName)
    local kit = kitDaRoda(tipo, itemName)
    if not kit then return false, 'Esse item não vai na roda' end
    local veh, err = validarNoAlto(source, netId)
    if not veh then return false, err end
    roda = rodaValida(roda)
    if not roda then return false, 'Roda inválida' end
    if not (Entity(veh).state[STATE_RODAS] or {})['r' .. roda] then return false, 'Tire a roda primeiro' end

    local dados = dadosDoVeiculo(veh)
    local obra = dados[kit.obra]
    if obra and obra.item ~= itemName then
        local outro = kitDaRoda(tipo, obra.item)
        return false, ('Termine primeiro o %s que já foi começado'):format(outro and outro.label or 'kit')
    end
    if not obra then
        if tipo == 'freio' and dados.freio == kit.nivel then
            return false, ('Esse carro já tem freio %s'):format(nivelNome(kit.nivel))
        end
        if tipo == 'susp' and dados.suspensao then
            return false, 'Esse carro já tem suspensão regulável: é só regular'
        end
        if not exports.ox_inventory:RemoveItem(source, itemName, 1) then
            return false, ('Você não tem %s'):format(kit.label)
        end
        obra = { item = itemName, rodas = {} }
    end
    if obra.rodas['r' .. roda] then return false, ('Essa roda já está com %s'):format(kit.label:lower()) end
    obra.rodas['r' .. roda] = true

    local feitas = 0
    for _ in pairs(obra.rodas) do feitas = feitas + 1 end

    local msg
    if feitas >= 4 then
        dados[kit.obra] = nil
        if tipo == 'freio' then
            local antigo = dados.freio
            dados.freio = kit.nivel
            if antigo ~= nil then
                local itemAntigo = itemDoKit(Config.kitsFreio, antigo)
                if itemAntigo then exports.ox_inventory:AddItem(source, itemAntigo, 1) end
            end
        else
            dados.suspensao = true
            dados.susp = NormalizarSusp(dados.susp or Config.suspensao.padrao)
            darXP(source, Config.suspensao.xp)
        end
        msg = tipo == 'susp' and 'Suspensão regulável instalada nas 4 rodas! Use /suspensao para regular.'
            or ('%s instalado nas 4 rodas!'):format(kit.label)
    else
        dados[kit.obra] = obra
        msg = ('%s instalado nesta roda (%d/4)'):format(kit.label, feitas)
    end
    aplicarDados(veh, dados)
    return true, msg
end)

---------------------------------------------------------------------
-- Transmissão: instala igual turbo (em qualquer lugar, com soquetes)
---------------------------------------------------------------------
local function ehMecanico(source, precisaServico)
    local player = exports.qbx_core:GetPlayer(source)
    local job = player and player.PlayerData.job
    if not job or job.name ~= Config.elevador.job then return false end
    return job.onduty or not precisaServico
end

local function validarCambio(source, netId, itemName)
    local kit = Config.kitsCambio[itemName]
    if not kit then return nil, 'Esse item não é uma transmissão' end
    local veh, err = pegarVeiculo(source, netId, false)
    if not veh then return nil, err end
    if Config.pecasExternasSoNaOficina and not naOficina(GetEntityCoords(veh)) then
        return nil, 'Isso só pode ser feito dentro da oficina'
    end
    if not ehMecanico(source, true) then
        err = exigirNivel(source, Config.cambio.nivel)
        if err then return nil, err end
    end
    if exports.ox_inventory:Search(source, 'count', itemName) < 1 then
        return nil, ('Você não tem %s'):format(kit.label)
    end
    err = exigirFerramenta(source, 'soquetes')
    if err then return nil, err end
    local dados = dadosDoVeiculo(veh)
    if dados.motor then return nil, 'Esse carro está sem motor' end
    if dados.cambio == kit.nivel then return nil, ('Esse carro já tem transmissão %s'):format(nivelNome(kit.nivel)) end
    return veh, nil, kit, dados
end

lib.callback.register('pista_tuning:server:podeInstalarCambio', function(source, netId, itemName)
    local veh, err = validarCambio(source, netId, itemName)
    return veh ~= nil, err
end)

lib.callback.register('pista_tuning:server:instalarCambio', function(source, netId, itemName)
    local veh, err, kit, dados = validarCambio(source, netId, itemName)
    if not veh then return false, err end
    if not exports.ox_inventory:RemoveItem(source, itemName, 1) then
        return false, ('Você não tem %s'):format(kit.label)
    end
    local antigo = dados.cambio
    if antigo ~= nil then
        local itemAntigo = itemDoKit(Config.kitsCambio, antigo)
        if itemAntigo then exports.ox_inventory:AddItem(source, itemAntigo, 1) end
    end
    dados.cambio = kit.nivel
    aplicarDados(veh, dados)
    gastarFerramenta(source, 'soquetes', 'peca')
    darXP(source, Config.cambio.xp)
    return true, ('%s instalada'):format(kit.label)
end)

---------------------------------------------------------------------
-- Suspensão regulável: o dono do carro ou um mecânico regula (sem chave)
---------------------------------------------------------------------
local function ehDono(source, plate)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    return MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? AND citizenid = ?',
        { plate, player.PlayerData.citizenid }) ~= nil
end

local function validarSusp(source, netId)
    local veh, err = pegarVeiculo(source, netId, true)
    if not veh then return nil, err end
    local dados = dadosDoVeiculo(veh)
    if not dados.suspensao then return nil, 'Esse carro não tem suspensão regulável' end
    if not ehMecanico(source, Config.suspensao.mecanicoPrecisaServico) and not ehDono(source, placaDo(veh)) then
        return nil, 'Só o dono do carro ou um mecânico pode regular a suspensão'
    end
    return veh, nil, dados
end

lib.callback.register('pista_tuning:server:abrirSusp', function(source, netId)
    local veh, err, dados = validarSusp(source, netId)
    if not veh then return false, err end
    return true, { susp = NormalizarSusp(dados.susp), placa = placaDo(veh) }
end)

lib.callback.register('pista_tuning:server:salvarSusp', function(source, netId, valores)
    local veh, err, dados = validarSusp(source, netId)
    if not veh then return false, err end
    dados.susp = NormalizarSusp(valores)
    aplicarDados(veh, dados)
    return true, 'Suspensão regulada'
end)

-- /servico: entra e sai de serviço (mecânico)
lib.addCommand('servico', {
    help = 'Entrar ou sair de serviço',
}, function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    local job = player.PlayerData.job
    if not job or job.name == 'unemployed' then
        return exports.qbx_core:Notify(source, 'Você não tem emprego', 'error')
    end
    local novo = not job.onduty
    player.Functions.SetJobDuty(novo)
    TriggerClientEvent('QBCore:Client:SetDuty', source, novo)
    exports.qbx_core:Notify(source, novo and 'Você entrou em serviço' or 'Você saiu de serviço', novo and 'success' or 'inform')
end)

---------------------------------------------------------------------
-- Admin: preparar tudo no máximo / voltar ao original (para testes)
---------------------------------------------------------------------
--- Carro em que o admin está, ou o mais perto (até 6 m)
local function carroDoAdmin(source)
    local ped = GetPlayerPed(source)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    local eu, melhor, melhorDist = GetEntityCoords(ped), nil, 6.0
    for _, v in ipairs(GetAllVehicles()) do
        local d = #(GetEntityCoords(v) - eu)
        if d < melhorDist then melhor, melhorDist = v, d end
    end
    return melhor
end

lib.addCommand('tunarmax', {
    help = 'Instala tudo no máximo no carro (dentro ou do lado)',
    restricted = 'group.admin',
}, function(source)
    local veh = carroDoAdmin(source)
    if not veh then return exports.qbx_core:Notify(source, 'Nenhum carro por perto', 'error') end
    local dados = dadosDoVeiculo(veh)
    if dados.motor then return exports.qbx_core:Notify(source, 'Esse carro está sem motor: recoloque antes', 'error') end

    dados.chip = 3
    dados.turbo = true
    dados.intercooler = true
    dados.pistao = 'forjado'
    dados.cabecote = 2
    dados.junta = true
    dados.bielas = true
    dados.nitro = true
    dados.nitroCarga = Config.nitro.cargaGarrafa
    dados.freio = 2
    dados.cambio = 2
    dados.freioObra, dados.suspObra = nil, nil
    dados.suspensao = true
    dados.susp = NormalizarSusp(dados.susp or Config.suspensao.presets.Pista)
    dados.remap = nil -- mapa original: ajuste no notebook
    aplicarDados(veh, dados)
    exports.qbx_core:Notify(source, ('Carro %s no máximo: Stage 3, turbo, motor forjado de corrida, nitro cheio, freio/câmbio de competição e suspensão regulável'):format(placaDo(veh)), 'success', 8000)
end)

lib.addCommand('tunarzerar', {
    help = 'Tira toda a preparação do carro (volta ao original)',
    restricted = 'group.admin',
}, function(source)
    local veh = carroDoAdmin(source)
    if not veh then return exports.qbx_core:Notify(source, 'Nenhum carro por perto', 'error') end
    local dados = dadosDoVeiculo(veh)
    local motor = dados.motor -- se o motor estiver fora, continua fora
    for k in pairs(dados) do dados[k] = nil end
    dados.motor = motor
    aplicarDados(veh, dados)
    exports.qbx_core:Notify(source, ('Carro %s voltou ao original'):format(placaDo(veh)), 'success')
end)

---------------------------------------------------------------------
-- Carregar o motor nos braços (vaga -> bancada)
---------------------------------------------------------------------
local function motorNaMaoDe(source, netId)
    local motor = NetworkGetEntityFromNetworkId(netId or 0)
    if not motor or motor == 0 or not DoesEntityExist(motor) then return nil end
    local st = estadoMotor(motor)
    if not st or st.carregadoPor ~= source then return nil end
    return motor, st
end

lib.callback.register('pista_tuning:server:pegarMotor', function(source, netId)
    local motor, err = pegarObjeto(source, netId, STATE_MOTOR, 4.0)
    if not motor then return false, err end
    err = exigirMecanico(source)
    if err then return false, err end
    local st = estadoMotor(motor)
    if st.carregadoPor and st.carregadoPor ~= source and GetPlayerPing(st.carregadoPor) > 0 then
        return false, 'Alguém já está carregando esse motor'
    end
    if st.aberto then return false, 'Feche o motor antes' end

    if st['local'] == 'guincho' then
        for _, g in ipairs(objetosComState(STATE_GUINCHO)) do
            local sg = estadoGuincho(g)
            if sg.motor == st.plate then
                sg.motor = nil
                Entity(g).state:set(STATE_GUINCHO, sg, true)
            end
        end
    end
    st['local'] = 'mao'
    st.carregadoPor = source
    Entity(motor).state:set(STATE_MOTOR, st, true)
    FreezeEntityPosition(motor, false)
    return true
end)

-- Pede o lugar da bancada para colocar o motor que está na mão
lib.callback.register('pista_tuning:server:lugarNaBancada', function(source, netId)
    local motor = motorNaMaoDe(source, netId)
    if not motor then return false, 'Você não está carregando esse motor' end
    local i, b = bancadaLivrePerto(GetEntityCoords(GetPlayerPed(source)))
    if not i then return false, 'Chegue perto de uma bancada livre' end
    return true, { x = b.x, y = b.y, z = b.z, h = b.w }
end)

-- O cliente já colocou o motor (na bancada ou no chão): grava
lib.callback.register('pista_tuning:server:motorPosicionado', function(source, netId, onde)
    local motor, st = motorNaMaoDe(source, netId)
    if not motor then return false end
    onde = onde == 'bancada' and 'bancada' or 'chao'
    FreezeEntityPosition(motor, true)
    st['local'] = onde
    st.carregadoPor = nil
    Entity(motor).state:set(STATE_MOTOR, st, true)
    local c = GetEntityCoords(motor)
    salvarMotor(st.plate, { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(motor), ['local'] = onde })
    return true, onde == 'bancada' and 'Motor na bancada. Abra com o torquímetro.' or 'Motor no chão'
end)

-- Motor da mão para o gancho do guincho
lib.callback.register('pista_tuning:server:motorNoGancho', function(source, netId)
    local motor, st = motorNaMaoDe(source, netId)
    if not motor then return false, 'Você não está carregando esse motor' end
    local guincho = guinchoParadoPerto(GetEntityCoords(GetPlayerPed(source)), 4.0, false)
    if not guincho then return false, 'Chegue perto do guincho vazio' end

    st['local'] = 'guincho'
    st.carregadoPor = nil
    Entity(motor).state:set(STATE_MOTOR, st, true)
    local sg = estadoGuincho(guincho)
    sg.motor = st.plate
    Entity(guincho).state:set(STATE_GUINCHO, sg, true)
    local gc = GetEntityCoords(guincho)
    salvarMotor(st.plate, { x = gc.x, y = gc.y, z = gc.z, h = GetEntityHeading(guincho), ['local'] = 'guincho' })
    return true, 'Motor no gancho', NetworkGetNetworkIdFromEntity(guincho)
end)

-- Saiu do jogo carregando o motor: ele fica no chão
AddEventHandler('playerDropped', function()
    local src = source
    for _, obj in ipairs(objetosComState(STATE_MOTOR)) do
        local st = estadoMotor(obj)
        if st.carregadoPor == src then
            st['local'] = 'chao'
            st.carregadoPor = nil
            Entity(obj).state:set(STATE_MOTOR, st, true)
            local c = GetEntityCoords(obj)
            salvarMotor(st.plate, { x = c.x, y = c.y, z = c.z - 0.5, ['local'] = 'chao' })
        end
    end
end)

lib.addCommand('ajustecarregar', {
    help = 'Ajusta o motor nos braços',
    params = {
        { name = 'x', type = 'number' }, { name = 'y', type = 'number' }, { name = 'z', type = 'number' },
        { name = 'rz', type = 'number', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    TriggerClientEvent('pista_tuning:client:ajuste', source, 'carregar', args.x, args.y, args.z, args.rz or 90.0)
end)

-- /girarguincho [graus]: gira o guincho mais perto (para acertar a direção ao vivo)
lib.addCommand('girarguincho', {
    help = 'Gira o guincho mais perto',
    params = { { name = 'graus', type = 'number', help = 'Direção (0 a 360)' } },
    restricted = 'group.admin',
}, function(source, args)
    local eu = GetEntityCoords(GetPlayerPed(source))
    local perto, dist
    for _, g in ipairs(objetosComState(STATE_GUINCHO)) do
        local d = #(GetEntityCoords(g) - eu)
        if not dist or d < dist then perto, dist = g, d end
    end
    if not perto or dist > 10.0 then
        return exports.qbx_core:Notify(source, 'Nenhum guincho por perto', 'error')
    end
    SetEntityHeading(perto, args.graus + 0.0)
    local c = GetEntityCoords(perto)
    local linha = ('guincho = vec4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, args.graus)
    print('[pista_tuning] ' .. linha)
    exports.qbx_core:Notify(source, linha, 'inform', 10000)
end)

-- /moverguincho: leva o guincho mais perto para onde você está (mantém a direção)
lib.addCommand('moverguincho', {
    help = 'Move o guincho mais perto para a sua posição',
    restricted = 'group.admin',
}, function(source)
    local eu = GetEntityCoords(GetPlayerPed(source))
    local perto, dist
    for _, g in ipairs(objetosComState(STATE_GUINCHO)) do
        local d = #(GetEntityCoords(g) - eu)
        if not dist or d < dist then perto, dist = g, d end
    end
    if not perto or dist > 10.0 then
        return exports.qbx_core:Notify(source, 'Nenhum guincho por perto', 'error')
    end
    local z = GetEntityCoords(perto).z
    SetEntityCoords(perto, eu.x, eu.y, z, false, false, false, false)
    local h = GetEntityHeading(perto)
    local linha = ('guincho = vec4(%.2f, %.2f, %.2f, %.1f)'):format(eu.x, eu.y, z, h)
    print('[pista_tuning] ' .. linha)
    exports.qbx_core:Notify(source, linha, 'inform', 10000)
end)

---------------------------------------------------------------------
-- Consertos: pneu, lataria, funilaria, kits de emergência e retífica
---------------------------------------------------------------------
-- tipo -> quem pode (true = só mecânico em serviço)
local REPAROS = {
    pneu = { mecanico = false },
    funilaria = { mecanico = true },
    emergencia = { mecanico = false },
    avancado = { mecanico = true },
}

local function validarReparo(source, netId, tipo)
    local regra, cfg = REPAROS[tipo], Config.reparo[tipo]
    if not regra or not cfg then return nil, 'Conserto inválido' end
    local veh, err = pegarVeiculo(source, netId, false)
    if not veh then return nil, err end
    if regra.mecanico and not ehMecanico(source, true) then
        return nil, 'Só mecânico em serviço pode fazer isso'
    end
    if exports.ox_inventory:Search(source, 'count', cfg.item) < 1 then
        local item = exports.ox_inventory:Items(cfg.item)
        return nil, ('Você precisa de %s'):format(item and item.label or cfg.item)
    end
    if tipo == 'pneu' then
        err = exigirFerramenta(source, 'macaco')
        if err then return nil, err end
    end
    if (tipo == 'emergencia' or tipo == 'avancado') and dadosDoVeiculo(veh).motor then
        return nil, 'Esse carro está sem motor'
    end
    return veh, nil, cfg
end

lib.callback.register('pista_tuning:server:podeReparar', function(source, netId, tipo)
    local veh, err = validarReparo(source, netId, tipo)
    return veh ~= nil, err
end)

--- Gasta o item; o cliente aplica o conserto no carro em seguida
lib.callback.register('pista_tuning:server:reparar', function(source, netId, tipo)
    local veh, err, cfg = validarReparo(source, netId, tipo)
    if not veh then return false, err end
    if not exports.ox_inventory:RemoveItem(source, cfg.item, 1) then
        return false, 'Não foi possível usar o item'
    end
    if tipo == 'pneu' then gastarFerramenta(source, 'macaco', 'pneu') end
    return true
end)

-- Retífica: no motor aberto na bancada. O motor volta novo quando for recolocado.
lib.callback.register('pista_tuning:server:retificarMotor', function(source, netId)
    local cfg = Config.reparo.retifica
    local obj, err, st, dados = validarMotorAberto(source, netId, true)
    if not obj then return false, err end
    if dados.motorRetificado then return false, 'Esse motor já foi retificado' end
    if not exports.ox_inventory:RemoveItem(source, cfg.item, 1) then
        return false, 'Você precisa do kit de retífica'
    end
    dados.motorRetificado = true
    salvar(st.plate, dados)
    gastarFerramenta(source, 'torquimetro', 'peca')
    darXP(source, cfg.xp)
    return true, 'Motor retificado! Ele volta novo quando for recolocado no carro.'
end)

-- O motorista aplicou a vida do motor retificado: limpa a marca
RegisterNetEvent('pista_tuning:server:retificaAplicada', function(netId)
    local source = source
    local veh = NetworkGetEntityFromNetworkId(netId or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(source) then return end
    local dados = dadosDoVeiculo(veh)
    if not dados.motorRetificado or dados.motor then return end
    dados.motorRetificado = nil
    aplicarDados(veh, dados)
end)
