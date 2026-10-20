-- pa_policia · servidor · fiscalização veicular
-- Objetos de blitz, vistoria (peças do pista_tuning), radares fixos com ANPR e pátio.

local OBJ_BAG = 'pa_policia_obj'
local PATIO_BAG = 'pa_patio'

local objetosDe = {}        -- [src] = { netId, ... }
local recargaRadar = {}     -- [src..':'..indice] = os.time()
local aguardandoGuincho = {}-- [netId] = { plate, tipo, prazo, motivo, policial }

local objetoPorId = {}
for _, o in ipairs(Config.objetos.lista) do objetoPorId[o.id] = o end

---------------------------------------------------------------------
-- OBJETOS DE BLITZ
---------------------------------------------------------------------
local function contarObjetos(src)
    local lista, vivos = objetosDe[src] or {}, {}
    for _, net in ipairs(lista) do
        local ent = NetworkGetEntityFromNetworkId(net)
        if ent ~= 0 and DoesEntityExist(ent) then vivos[#vivos + 1] = net end
    end
    objetosDe[src] = vivos
    return #vivos
end

lib.callback.register('pa_policia:server:colocarObjeto', function(src, id, coords, heading)
    if not P.Pode(src, 'objetos') then return false, 'Blitz: a partir de Oficial 2.' end
    local cfg = objetoPorId[id]
    if not cfg or type(coords) ~= 'vector3' and type(coords) ~= 'table' then return false, 'Objeto inválido.' end
    coords = vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    if P.Dist(src, coords) > 8.0 then return false, 'Longe demais.' end
    if contarObjetos(src) >= Config.objetos.limitePorPolicial then
        return false, ('Limite de %d objetos. Recolha algum.'):format(Config.objetos.limitePorPolicial)
    end
    local obj = CreateObjectNoOffset(cfg.modelo, coords.x, coords.y, coords.z, true, true, false)
    local limite = GetGameTimer() + 3000
    while not DoesEntityExist(obj) and GetGameTimer() < limite do Wait(10) end
    if not DoesEntityExist(obj) then return false, 'Falha ao criar o objeto.' end
    SetEntityHeading(obj, (tonumber(heading) or 0.0) + 0.0)
    FreezeEntityPosition(obj, cfg.congelar == true)
    local net = NetworkGetNetworkIdFromEntity(obj)
    Entity(obj).state:set(OBJ_BAG, { id = cfg.id, dono = src, tapete = cfg.tapete == true }, true)
    objetosDe[src] = objetosDe[src] or {}
    table.insert(objetosDe[src], net)
    return true, net
end)

lib.callback.register('pa_policia:server:recolherObjeto', function(src, net)
    if not P.EmServico(src) then return false, 'Só policiais em serviço.' end
    local obj = NetworkGetEntityFromNetworkId(net or 0)
    if obj == 0 or not DoesEntityExist(obj) or not Entity(obj).state[OBJ_BAG] then return false, 'Objeto não encontrado.' end
    if #(GetEntityCoords(obj) - P.Coords(src)) > 5.0 then return false, 'Chegue mais perto.' end
    DeleteEntity(obj)
    return true
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, lista in pairs(objetosDe) do
        for _, net in ipairs(lista) do
            local ent = NetworkGetEntityFromNetworkId(net)
            if ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
        end
    end
end)

---------------------------------------------------------------------
-- VEÍCULO: helpers
---------------------------------------------------------------------
local function veiculoPerto(src, net, dist)
    local veh = NetworkGetEntityFromNetworkId(net or 0)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil end
    if #(GetEntityCoords(veh) - P.Coords(src)) > (dist or Config.vistoria.distancia + 3.0) then return nil end
    return veh
end

local function placaDe(veh)
    return P.Trim(GetVehicleNumberPlateText(veh))
end

local function donoDaPlaca(plate)
    return MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE plate = ?', { plate })
end

local function historico(plate, tipo, resultado, policial)
    MySQL.insert('INSERT INTO pa_policia_veiculos (plate, tipo, resultado, policial) VALUES (?, ?, ?, ?)',
        { plate, tipo, resultado, policial and P.Nome(policial) or 'Sistema' })
end

local function laudoRecente(plate)
    if GetResourceState('pa_dinamometro') ~= 'started' then return false end
    local ok, criado = pcall(MySQL.scalar.await,
        'SELECT UNIX_TIMESTAMP(criado) FROM pa_dinamometro WHERE plate = ? ORDER BY id DESC LIMIT 1', { plate })
    if not ok or not criado then return false end
    return os.time() - tonumber(criado) <= Config.vistoria.laudoDias * 86400, tonumber(criado)
end

---------------------------------------------------------------------
-- VISTORIA
---------------------------------------------------------------------
local function avaliar(dados, temLaudo)
    local itens, multa, apreender = {}, 0, false
    local slotIrregular = {}
    for _, r in ipairs(Config.vistoria.regras) do
        local v = dados[r.slot]
        local tem = v ~= nil and v ~= false and v ~= 0
        if tem and r.acima then tem = (tonumber(v) or 0) > r.acima end
        if tem and r.igual ~= nil then tem = v == r.igual end
        if tem and not slotIrregular[r.slot] then
            local irregular = not (r.exigeLaudo and temLaudo)
            if irregular then
                slotIrregular[r.slot] = true
                multa += r.multa or 0
                apreender = apreender or r.apreender == true
            end
            itens[#itens + 1] = { label = r.label, irregular = irregular, multa = irregular and r.multa or 0, apreender = irregular and r.apreender == true }
        end
    end
    return itens, multa, apreender
end

local ultimaVistoria = {} -- [src] = { plate, multa, apreender, motivo }

lib.callback.register('pa_policia:server:vistoria', function(src, net)
    if not P.Pode(src, 'vistoria') then return false, 'Vistoria: a partir de Oficial 2.' end
    local veh = veiculoPerto(src, net)
    if not veh then return false, 'Fique perto do carro.' end
    local plate = placaDe(veh)
    local dados = {}
    if GetResourceState('pista_tuning') == 'started' then
        dados = exports.pista_tuning:dadosDaPlaca(plate) or {}
    end
    if GetResourceState('pa_roubocarro') == 'started' and exports.pa_roubocarro:chassiRiscado(plate) then
        dados.chassi_riscado = true
    end
    local temLaudo, quando = laudoRecente(plate)
    local itens, multa, apreender = avaliar(dados, temLaudo)
    local dono = donoDaPlaca(plate)

    local irregulares = {}
    for _, i in ipairs(itens) do if i.irregular then irregulares[#irregulares + 1] = i.label end end
    local motivo = #irregulares > 0 and ('Vistoria: ' .. table.concat(irregulares, ', ')) or nil
    ultimaVistoria[src] = { plate = plate, net = net, multa = multa, apreender = apreender, motivo = motivo, dono = dono }
    historico(plate, 'vistoria', #irregulares > 0 and table.concat(irregulares, ', ') or 'Regular', src)

    return true, {
        plate = plate,
        dono = dono and P.NomeCid(dono) or 'Sem registro',
        laudo = quando and os.date('%d/%m/%Y', quando) or nil,
        laudoValido = temLaudo,
        itens = itens,
        multa = multa,
        apreender = apreender,
        procurado = P.PlacaProcurada(plate),
    }
end)

lib.callback.register('pa_policia:server:vistoriaAcao', function(src, acao)
    local v = ultimaVistoria[src]
    if not v then return false, 'Faça a vistoria antes.' end
    if acao == 'multar' then
        if not P.Pode(src, 'multar') then return false, 'Sem permissão.' end
        if v.multa <= 0 then return false, 'Nada irregular.' end
        if not v.dono then return false, 'Carro sem dono registrado: apreenda.' end
        local teto = Config.tetoMulta[P.Grau(src)] or 0
        local valor = math.min(v.multa, teto)
        P.Multar(v.dono, valor, ('%s (placa %s)'):format(v.motivo, v.plate), src)
        historico(v.plate, 'multa', ('$%d · %s'):format(valor, v.motivo), src)
        ultimaVistoria[src] = nil
        return true, ('Multa de $%d aplicada ao dono.'):format(valor)
    elseif acao == 'apreender' then
        local veh = veiculoPerto(src, v.net, 15.0)
        if not veh then return false, 'O carro não está mais aqui.' end
        local ok, msg = P.MandarPatio(src, veh, 'retido', v.motivo or 'Vistoria')
        ultimaVistoria[src] = nil
        return ok, msg
    end
    return false
end)

---------------------------------------------------------------------
-- PÁTIO
---------------------------------------------------------------------
local function finalizarPatio(veh, plate, tipo)
    local id = GetResourceState('qbx_vehicles') == 'started' and exports.qbx_vehicles:GetVehicleIdByPlate(plate) or nil
    if id then
        if tipo == 'retido' then
            exports.qbx_garages:SetVehicleGarage(id, Config.patio.garagemRetido)
        else
            exports.qbx_garages:SetVehicleGarage(id, Config.patio.garagemDepot)
            exports.qbx_garages:SetVehicleDepotPrice(id, Config.patio.taxa)
            MySQL.query('DELETE FROM pa_policia_patio WHERE plate = ?', { plate })
        end
    else
        MySQL.query('DELETE FROM pa_policia_patio WHERE plate = ?', { plate })
    end
    if veh and DoesEntityExist(veh) then exports.qbx_core:DeleteVehicle(veh) end
end

--- Manda o carro para o pátio. tipo = 'patio' (retira pagando) ou 'retido' (só sai com Tenente+)
function P.MandarPatio(src, veh, tipo, motivo)
    if not P.Pode(src, 'patio') then return false, 'Pátio: a partir de Oficial 1.' end
    if tipo == 'retido' and not P.Pode(src, 'apreender') then return false, 'Sem permissão para reter.' end
    for i = -1, 6 do
        local ped = GetPedInVehicleSeat(veh, i)
        if ped ~= 0 and IsPedAPlayer(ped) then return false, 'Tire todo mundo do carro antes.' end
    end
    local plate = placaDe(veh)
    local temDono = donoDaPlaca(plate) ~= nil
    motivo = tostring(motivo or 'Apreensão'):sub(1, 250)

    if temDono then
        MySQL.insert.await('INSERT INTO pa_policia_patio (plate, tipo, motivo, policial) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE tipo = VALUES(tipo), motivo = VALUES(motivo), policial = VALUES(policial)',
            { plate, tipo, motivo, P.Nome(src) })
    end
    historico(plate, tipo == 'retido' and 'retido' or 'patio', motivo, src)

    local mecanicos = Config.patio.esperarGuincho and exports.qbx_core:GetDutyCountJob(Config.patio.jobMecanico) or 0
    if mecanicos > 0 and temDono then
        local net = NetworkGetNetworkIdFromEntity(veh)
        Entity(veh).state:set(PATIO_BAG, { tipo = tipo }, true)
        aguardandoGuincho[net] = { plate = plate, tipo = tipo, prazo = os.time() + Config.patio.tempoGuincho }
        local _, lista = exports.qbx_core:GetDutyCountJob(Config.patio.jobMecanico)
        local c = GetEntityCoords(veh)
        for _, m in ipairs(lista or {}) do
            TriggerClientEvent('pa_policia:client:chamadoGuincho', m, { plate = plate, x = c.x, y = c.y, z = c.z })
        end
        return true, 'Carro marcado. Um mecânico foi chamado para levar ao pátio da DP.'
    end

    finalizarPatio(veh, plate, tipo)
    return true, tipo == 'retido' and 'Carro retido no pátio da LSPD.' or ('Carro levado ao pátio (retirada no Impound Lot: $%d).'):format(Config.patio.taxa)
end

lib.callback.register('pa_policia:server:patio', function(src, net, tipo, motivo)
    local veh = veiculoPerto(src, net, 8.0)
    if not veh then return false, 'Fique perto do carro.' end
    if tipo ~= 'retido' then tipo = 'patio' end
    return P.MandarPatio(src, veh, tipo, motivo)
end)

-- Guincho entregou no pátio (ou o tempo acabou)
CreateThread(function()
    local entrega = vec3(Config.dp.patio.x, Config.dp.patio.y, Config.dp.patio.z)
    while true do
        Wait(5000)
        for net, a in pairs(aguardandoGuincho) do
            local veh = NetworkGetEntityFromNetworkId(net)
            local existe = veh ~= 0 and DoesEntityExist(veh)
            if not existe then
                aguardandoGuincho[net] = nil
                finalizarPatio(nil, a.plate, a.tipo)
            elseif #(GetEntityCoords(veh) - entrega) <= Config.patio.raioEntrega then
                aguardandoGuincho[net] = nil
                finalizarPatio(veh, a.plate, a.tipo)
                local _, lista = exports.qbx_core:GetDutyCountJob(Config.patio.jobMecanico)
                for _, m in ipairs(lista or {}) do
                    if #(P.Coords(m) - entrega) < 40.0 then
                        P.Notify(m, ('Carro %s entregue no pátio da LSPD.'):format(a.plate), 'success')
                    end
                end
            elseif os.time() > a.prazo then
                aguardandoGuincho[net] = nil
                finalizarPatio(veh, a.plate, a.tipo)
            end
        end
    end
end)

lib.callback.register('pa_policia:mdt:liberarPatio', function(src, plate, cobrar)
    if not P.Pode(src, 'liberarPatio') then return false, 'Só Tenente ou acima libera o pátio.' end
    plate = P.Trim(tostring(plate or '')):upper()
    local row = MySQL.single.await('SELECT tipo FROM pa_policia_patio WHERE plate = ?', { plate })
    if not row then return false, 'Esse carro não está retido.' end
    local id = exports.qbx_vehicles:GetVehicleIdByPlate(plate)
    if id then
        exports.qbx_garages:SetVehicleGarage(id, Config.patio.garagemDepot)
        exports.qbx_garages:SetVehicleDepotPrice(id, cobrar and Config.patio.taxa or 0)
    end
    MySQL.query.await('DELETE FROM pa_policia_patio WHERE plate = ?', { plate })
    historico(plate, 'liberado', cobrar and ('Liberado com taxa de $%d'):format(Config.patio.taxa) or 'Liberado sem taxa', src)
    return true, 'Liberado: o dono retira no Impound Lot.'
end)

-- Garagem dos carros retidos (qbx_garages). Ninguém retira: só sai quando um Tenente+ libera.
local function registrarGaragem()
    if GetResourceState('qbx_garages') ~= 'started' then return end
    local p = Config.dp.patio
    exports.qbx_garages:RegisterGarage(Config.patio.garagemRetido, {
        label = 'Pátio da LSPD (retidos)',
        vehicleType = 'car',
        groups = { [Config.job] = Config.permissoes.liberarPatio },
        shared = false,
        accessPoints = { { coords = vec4(p.x, p.y, p.z, p.w or 0.0) } },
    })
end

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then
        SetTimeout(1000, registrarGaragem)
    elseif res == 'qbx_garages' then
        SetTimeout(2000, registrarGaragem)
    end
end)

---------------------------------------------------------------------
-- RADARES FIXOS + ANPR
---------------------------------------------------------------------
local function multaRadar(excesso)
    for _, f in ipairs(Config.radares.multas) do
        if excesso <= f.ate then return f.valor end
    end
    return Config.radares.multas[#Config.radares.multas].valor
end

RegisterNetEvent('pa_policia:server:radar', function(indice, kmh)
    local src = source
    if not Config.radares.ativo then return end
    local r = Config.radares.locais[tonumber(indice) or 0]
    if not r then return end
    if P.Dist(src, r.coords) > Config.radares.raio + 20.0 then return end
    local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return end

    local chave = ('%d:%d'):format(src, indice)
    if os.time() - (recargaRadar[chave] or 0) < 60 then return end
    recargaRadar[chave] = os.time()

    local plate = placaDe(veh)

    -- ANPR: placa procurada passando no radar
    local motivo = P.PlacaProcurada(plate)
    if motivo then
        P.Alerta({
            codigo = '10-29', titulo = ('Placa procurada: %s'):format(plate), descricao = motivo,
            coords = r.coords, exato = true, prioridade = 'alta', sprite = 225,
        })
    end

    if P.EmServico(src) or GetVehicleClass(veh) == 18 then return end
    -- confere a velocidade no servidor (aceita um pouco de diferença do cliente)
    local real = #GetEntityVelocity(veh) * 3.6
    kmh = math.min(tonumber(kmh) or 0, real + 15.0)
    local excesso = math.floor(kmh - r.limite)
    if excesso <= Config.radares.tolerancia then return end

    local valor = multaRadar(excesso)
    local cid = donoDaPlaca(plate) or P.Cid(src)
    P.Multar(cid, valor, ('Radar: %d km/h numa via de %d km/h (placa %s)'):format(math.floor(kmh), r.limite, plate), nil)
    historico(plate, 'radar', ('%d km/h em %d km/h · $%d'):format(math.floor(kmh), r.limite, valor), nil)
    TriggerClientEvent('pa_policia:client:flashRadar', src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    ultimaVistoria[src] = nil
end)
