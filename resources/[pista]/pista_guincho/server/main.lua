-- pista_guincho - servidor

local STATE = 'pista_reboque'

local function ehMecanico(source)
    local player = exports.qbx_core:GetPlayer(source)
    local job = player and player.PlayerData.job
    if not job or job.name ~= Config.job then return false end
    return job.onduty or not Config.precisaServico
end

local function pegar(netId)
    local veh = NetworkGetEntityFromNetworkId(netId or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    return veh
end

local function validar(source, netGuincho)
    if not ehMecanico(source) then return nil, 'Só mecânico em serviço' end
    local guincho = pegar(netGuincho)
    if not guincho or GetEntityModel(guincho) ~= Config.modelo then return nil, 'Guincho não encontrado' end
    if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(guincho)) > 8.0 then return nil, 'Você está longe do guincho' end
    return guincho
end

lib.callback.register('pista_guincho:server:carregar', function(source, netGuincho, netCarro)
    local guincho, err = validar(source, netGuincho)
    if not guincho then return false, err end
    if Entity(guincho).state[STATE] then return false, 'O guincho já está carregado' end
    local carro = pegar(netCarro)
    if not carro or carro == guincho then return false, 'Carro não encontrado' end
    if #(GetEntityCoords(carro) - GetEntityCoords(guincho)) > 16.0 then return false, 'O carro está longe do guincho' end
    if GetPedInVehicleSeat(carro, -1) ~= 0 then return false, 'Tire o motorista do carro' end
    Entity(guincho).state:set(STATE, netCarro, true)
    return true
end)

lib.callback.register('pista_guincho:server:descarregar', function(source, netGuincho)
    local guincho, err = validar(source, netGuincho)
    if not guincho then return false, err end
    if not Entity(guincho).state[STATE] then return false, 'O guincho está vazio' end
    Entity(guincho).state:set(STATE, nil, true)
    return true
end)

lib.addCommand('ajusteguincho', {
    help = 'Ajusta onde o carro fica na plataforma do guincho',
    params = { { name = 'x', type = 'number' }, { name = 'y', type = 'number' }, { name = 'z', type = 'number' } },
    restricted = 'group.admin',
}, function(source, args)
    TriggerClientEvent('pista_guincho:client:ajuste', source, args.x, args.y, args.z)
end)
