-- pista_estetica - servidor: valida o mecânico, cobra o cliente e salva o carro

local pendentes = {} -- [mecanico] = { plate, ate }

local function trim(s)
    local r = (s or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return r
end

local function ehAdminTeste(source)
    return IsPlayerAceAllowed(source, 'command.estetica')
end

local function ehMecanico(source)
    local player = exports.qbx_core:GetPlayer(source)
    local job = player and player.PlayerData.job
    if not job or job.name ~= Config.job then return false end
    return job.onduty or not Config.precisaServico
end

local function nomeDo(source)
    local player = exports.qbx_core:GetPlayer(source)
    local ci = player and player.PlayerData.charinfo
    if ci and ci.firstname then return ('%s %s'):format(ci.firstname, ci.lastname or '') end
    return GetPlayerName(source) or ('ID %d'):format(source)
end

--- O carro está em um local desse tipo?
local function noLocal(coords, tipo)
    for _, l in ipairs(Config.locais) do
        if l.tipo == tipo and #(coords - l.coords.xyz) <= (l.raio or 4.0) + 2.0 then return true end
    end
    return false
end

local function validar(source, netId, tipo)
    if tipo ~= 'pintura' and tipo ~= 'estetica' then return nil, 'Serviço inválido' end
    if tipo == 'estetica' and not Config.esteticaLigada then return nil, 'A oficina de estética ainda não está liberada' end
    local veh = NetworkGetEntityFromNetworkId(netId or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then
        return nil, 'Carro não encontrado'
    end
    if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(veh)) > 12.0 then
        return nil, 'Você está longe do carro'
    end
    local admin = ehAdminTeste(source)
    if not admin then
        if not ehMecanico(source) then return nil, 'Só mecânico em serviço' end
        if not noLocal(GetEntityCoords(veh), tipo) then
            return nil, tipo == 'pintura' and 'O carro precisa estar na cabine de pintura' or 'O carro precisa estar na oficina de estética'
        end
    end
    return veh
end

lib.callback.register('pista_estetica:server:abrir', function(source, netId, tipo)
    local veh, err = validar(source, netId, tipo)
    if not veh then return false, err end
    -- pintura e estética: o mecânico faz de dentro do carro, no banco do motorista
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(source) then return false, 'Entre no carro, no banco do motorista' end
    return true
end)

--- Preço de uma mudança: a chave começa pelo grupo ("mod:0", "pint:primaria", "neon:2"...)
local function precoDa(chave)
    local grupo = tostring(chave):match('^([%a]+)')
    return Config.precos[grupo]
end

local function calcular(tipo, chaves)
    local total, n = 0, 0
    for _, chave in ipairs(type(chaves) == 'table' and chaves or {}) do
        local grupo = tostring(chave):match('^([%a]+)')
        local ehPintura = grupo == 'pint'
        if (tipo == 'pintura') == ehPintura then
            local preco = precoDa(chave)
            if preco then
                total = total + preco
                n = n + 1
            end
        end
    end
    return total, n
end

local function cobrarDinheiro(source, valor)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    if player.Functions.GetMoney('cash') >= valor then
        return player.Functions.RemoveMoney('cash', valor, 'estetica-automotiva')
    elseif player.Functions.GetMoney('bank') >= valor then
        return player.Functions.RemoveMoney('bank', valor, 'estetica-automotiva')
    end
    return false
end

-- Lista de quem dá para cobrar (jogadores perto do mecânico)
lib.callback.register('pista_estetica:server:clientes', function(source, ids)
    local eu = GetEntityCoords(GetPlayerPed(source))
    local lista = { { id = source, nome = 'Eu mesmo (' .. nomeDo(source) .. ')' } }
    for _, id in ipairs(type(ids) == 'table' and ids or {}) do
        id = tonumber(id)
        if id and id ~= source and GetPlayerPed(id) ~= 0
            and #(GetEntityCoords(GetPlayerPed(id)) - eu) <= Config.distanciaCliente then
            lista[#lista + 1] = { id = id, nome = ('%s (ID %d)'):format(nomeDo(id), id) }
        end
    end
    return lista
end)

lib.callback.register('pista_estetica:server:cobrar', function(source, netId, tipo, alvo, chaves)
    local veh, err = validar(source, netId, tipo)
    if not veh then return false, err end

    local total, n = calcular(tipo, chaves)
    if n == 0 then return false, 'Nada foi mudado' end

    alvo = tonumber(alvo) or source
    local placa = trim(GetVehicleNumberPlateText(veh))

    if alvo ~= source then
        local ped = GetPlayerPed(alvo)
        if not ped or ped == 0 then return false, 'Cliente não encontrado' end
        if #(GetEntityCoords(ped) - GetEntityCoords(GetPlayerPed(source))) > Config.distanciaCliente then
            return false, 'O cliente precisa estar perto'
        end
        local aceitou = lib.callback.await('pista_estetica:client:confirmar', alvo, {
            mecanico = nomeDo(source),
            placa = placa,
            total = total,
            itens = n,
            servico = tipo == 'pintura' and 'pintura' or 'estética',
        })
        if not aceitou then return false, 'O cliente recusou a cobrança' end
    end

    if not cobrarDinheiro(alvo, total) then
        return false, alvo == source and 'Você não tem dinheiro suficiente' or 'O cliente não tem dinheiro suficiente'
    end
    if alvo ~= source then
        local mecanico = exports.qbx_core:GetPlayer(source)
        if mecanico then mecanico.Functions.AddMoney(Config.recebimento.conta, total, 'servico-estetica') end
        exports.qbx_core:Notify(alvo, ('Você pagou $%d pelo serviço de %s'):format(total, tipo == 'pintura' and 'pintura' or 'estética'), 'success')
    end

    pendentes[source] = { plate = placa, ate = os.time() + 180 }
    return true, ('Pago: $%d (%d %s)'):format(total, n, n == 1 and 'item' or 'itens')
end)

-- Depois do serviço, o mecânico manda como o carro ficou e salvamos na garagem do dono
RegisterNetEvent('pista_estetica:server:salvar', function(props)
    local source = source
    local p = pendentes[source]
    pendentes[source] = nil
    if not p or os.time() > p.ate or type(props) ~= 'table' then return end
    if trim(props.plate) ~= p.plate then return end
    MySQL.update('UPDATE player_vehicles SET mods = ? WHERE plate = ?', { json.encode(props), p.plate })
end)

AddEventHandler('playerDropped', function()
    pendentes[source] = nil
end)

-- Teste do admin: abre a tela no carro mais perto, em qualquer lugar
lib.addCommand('estetica', {
    help = 'Abrir a tela de pintura ou estética no carro mais perto (teste)',
    params = { { name = 'tipo', type = 'string', help = 'pintura ou estetica', optional = true } },
    restricted = 'group.admin',
}, function(source, args)
    local tipo = args.tipo == 'estetica' and 'estetica' or 'pintura'
    TriggerClientEvent('pista_estetica:client:abrirTeste', source, tipo)
end)
