-- pa_policia · servidor · base
-- Funções comuns, serviço (bater ponto), permissões por patente, contagem de policiais e banco.

P = {}
local RES = GetCurrentResourceName()

---------------------------------------------------------------------
-- UTILITÁRIOS
---------------------------------------------------------------------
function P.Player(src)
    return exports.qbx_core:GetPlayer(src)
end

function P.Cid(src)
    local p = P.Player(src)
    return p and p.PlayerData.citizenid
end

function P.NomeDe(p)
    local c = p and p.PlayerData.charinfo or {}
    return ('%s %s'):format(c.firstname or '?', c.lastname or '')
end

function P.Nome(src)
    return P.NomeDe(P.Player(src))
end

local nomesCache = {}
--- Nome de um cidadão on-line ou off-line
function P.NomeCid(cid)
    if not cid then return '?' end
    local p = exports.qbx_core:GetPlayerByCitizenId(cid)
    if p then return P.NomeDe(p) end
    if nomesCache[cid] then return nomesCache[cid] end
    local raw = MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', { cid })
    local c = raw and json.decode(raw) or {}
    local nome = ('%s %s'):format(c.firstname or '?', c.lastname or '')
    nomesCache[cid] = nome
    return nome
end

function P.Notify(src, msg, tipo, dur)
    TriggerClientEvent('ox_lib:notify', src, { title = Config.Titulo, description = msg, type = tipo or 'inform', duration = dur })
end

function P.Coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return vec3(0, 0, 0) end
    return GetEntityCoords(ped)
end

function P.Dist(src, coords)
    return #(P.Coords(src) - vec3(coords.x, coords.y, coords.z))
end

function P.Perto(src, alvo, dist)
    if not alvo or not GetPlayerName(alvo) then return false end
    return #(P.Coords(src) - P.Coords(alvo)) <= (dist or Config.abordagem.distancia)
end

function P.NaDP(src)
    return P.Dist(src, Config.dp.centro) <= Config.dp.raio
end

function P.Log(acao, ...)
    if Config.Debug then print(('[pa_policia] %s'):format(acao), ...) end
end

function P.Trim(s)
    return ((s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

---------------------------------------------------------------------
-- POLÍCIA / PATENTES
---------------------------------------------------------------------
--- Grau do jogador na LSPD (nil se não for policial)
function P.Grau(src)
    local p = P.Player(src)
    local job = p and p.PlayerData.job
    if not job or job.name ~= Config.job then return nil end
    return job.grade and job.grade.level or 0
end

function P.EmServico(src)
    local p = P.Player(src)
    local job = p and p.PlayerData.job
    return job and job.name == Config.job and job.onduty == true or false
end

function P.Patente(grau)
    return Config.patentes[grau or 0] or ('Grau %s'):format(grau)
end

--- Pode fazer a ação? (em serviço e com a patente mínima)
function P.Pode(src, acao)
    if not P.EmServico(src) then return false end
    local min = Config.permissoes[acao]
    if min == nil then return false end
    return (P.Grau(src) or -1) >= min
end

--- Igual ao P.Pode, mas avisa o motivo
function P.Exigir(src, acao)
    if not P.EmServico(src) then
        P.Notify(src, 'Você precisa estar em serviço na LSPD.', 'error')
        return false
    end
    if not P.Pode(src, acao) then
        P.Notify(src, ('Sua patente não permite isso (mínimo: %s).'):format(P.Patente(Config.permissoes[acao])), 'error')
        return false
    end
    return true
end

--- Policiais em serviço (contagem e lista de sources). Conta todo emprego do tipo leo.
function P.PoliciaisEmServico()
    local n, lista = exports.qbx_core:GetDutyCountType(Config.tipo)
    return n or 0, lista or {}
end

---------------------------------------------------------------------
-- DINHEIRO
---------------------------------------------------------------------
function P.Sociedade(valor)
    if not Config.contaSociedade or valor <= 0 then return end
    if GetResourceState('Renewed-Banking') ~= 'started' then return end
    pcall(function() exports['Renewed-Banking']:addAccountMoney(Config.contaSociedade, valor) end)
end

--- Cobra do banco de um jogador on-line (dinheiro vai para a LSPD)
function P.CobrarBanco(src, valor, motivo)
    local p = P.Player(src)
    if not p or valor <= 0 then return valor <= 0 end
    if p.Functions.RemoveMoney('bank', valor, motivo or 'lspd') then
        P.Sociedade(valor)
        return true
    end
    return false
end

---------------------------------------------------------------------
-- BANCO DE DADOS
---------------------------------------------------------------------
MySQL.ready(function()
    local sql = LoadResourceFile(RES, 'sql/pa_policia.sql') or ''
    sql = sql:gsub('%-%-[^\n]*', '')
    for comando in sql:gmatch('[^;]+') do
        if comando:find('%S') then MySQL.query.await(comando) end
    end
    TriggerEvent('pa_policia:server:bancoPronto')
end)

---------------------------------------------------------------------
-- SERVIÇO (bater ponto)
---------------------------------------------------------------------
lib.callback.register('pa_policia:server:servico', function(src)
    local p = P.Player(src)
    if not p or p.PlayerData.job.name ~= Config.job then return false, 'Você não é da LSPD.' end
    if P.Dist(src, Config.dp.servico) > 5.0 then return false, 'Bata o ponto na recepção da DP.' end
    local novo = not p.PlayerData.job.onduty
    exports.qbx_core:SetJobDuty(src, novo)
    if novo then
        local n = P.PoliciaisEmServico()
        P.Notify(src, ('Em serviço como %s. %d policial(is) na rua.'):format(P.Patente(P.Grau(src)), n), 'success')
    else
        P.Notify(src, 'Você saiu de serviço.', 'inform')
    end
    return true, novo
end)

lib.callback.register('pa_policia:server:meusDados', function(src)
    local p = P.Player(src)
    if not p or p.PlayerData.job.name ~= Config.job then return nil end
    local grau = P.Grau(src)
    local perms = {}
    for acao, min in pairs(Config.permissoes) do perms[acao] = grau >= min end
    return {
        grau = grau,
        patente = P.Patente(grau),
        servico = p.PlayerData.job.onduty,
        nome = P.Nome(src),
        distintivo = p.PlayerData.metadata.callsign,
        perms = perms,
    }
end)

-- Distintivo (callsign)
lib.addCommand('distintivo', {
    help = 'Definir seu número de distintivo (LSPD)',
    params = { { name = 'numero', type = 'string', help = 'Ex.: 1-ADAM-12' } },
}, function(src, args)
    if not P.Grau(src) then return P.Notify(src, 'Só policiais.', 'error') end
    local n = tostring(args.numero):sub(1, 16)
    exports.qbx_core:SetMetadata(src, 'callsign', n)
    P.Notify(src, ('Distintivo: %s'):format(n), 'success')
end)

-- Admin: copiar coordenadas para o config
lib.addCommand('pospolicia', {
    help = 'Mostra/copia a sua posição (para o config do pa_policia)',
    restricted = 'group.admin',
}, function(src)
    TriggerClientEvent('pa_policia:client:copiarPosicao', src)
end)

---------------------------------------------------------------------
-- POSIÇÃO DOS COLEGAS (blips no mapa para quem está em serviço)
---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(3000)
        local _, lista = P.PoliciaisEmServico()
        if #lista > 0 then
            local dados = {}
            for _, s in ipairs(lista) do
                local p = P.Player(s)
                if p then
                    local ped = GetPlayerPed(s)
                    local c = GetEntityCoords(ped)
                    dados[#dados + 1] = {
                        s = s,
                        x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped),
                        n = ('%s %s'):format(p.PlayerData.metadata.callsign ~= 'NO CALLSIGN' and p.PlayerData.metadata.callsign or '', P.NomeDe(p)),
                        v = GetVehiclePedIsIn(ped, false) ~= 0,
                    }
                end
            end
            for _, s in ipairs(lista) do
                TriggerClientEvent('pa_policia:client:colegas', s, dados)
            end
        end
    end
end)

---------------------------------------------------------------------
-- EXPORTS (usados pelos roubos e outros scripts)
---------------------------------------------------------------------
exports('policiaisEmServico', function()
    return (P.PoliciaisEmServico())
end)

exports('temPoliciaMinima', function(minimo)
    return P.PoliciaisEmServico() >= (minimo or 0)
end)

exports('ehPolicia', function(src)
    return P.EmServico(src)
end)

exports('temPermissao', function(src, acao)
    return P.Pode(src, acao)
end)

exports('patente', function(src)
    return P.Grau(src)
end)

---------------------------------------------------------------------
-- GARAGEM DE VIATURAS
---------------------------------------------------------------------
local viaturas = {} -- [src] = netId

local function viaturaPermitida(src, modelo)
    local grau = P.Grau(src) or -1
    for _, v in ipairs(Config.viaturas) do
        if v.modelo == modelo then return grau >= v.grade end
    end
    return false
end

lib.callback.register('pa_policia:server:tirarViatura', function(src, modelo, vaga)
    if not P.EmServico(src) then return nil end
    if type(modelo) ~= 'string' or not viaturaPermitida(src, modelo) then return nil end
    local valida
    for _, v in ipairs(Config.dp.garagem.vagas) do
        if vaga and #(vec3(v.x, v.y, v.z) - vec3(vaga.x, vaga.y, vaga.z)) < 0.5 then valida = v end
    end
    if not valida or P.Dist(src, valida) > 60.0 then return nil end

    local antiga = viaturas[src] and NetworkGetEntityFromNetworkId(viaturas[src])
    if antiga and antiga ~= 0 and DoesEntityExist(antiga) then return nil end

    local placa = ('%s%04d'):format(Config.placaPrefixo, math.random(0, 9999)):sub(1, 8)
    local net, veh = qbx.spawnVehicle({ model = modelo, spawnSource = valida, props = { plate = placa } })
    if not net or not veh then return nil end
    SetVehicleNumberPlateText(veh, placa)
    Entity(veh).state:set('pa_viatura', src, true)
    viaturas[src] = net
    if GetResourceState('qbx_vehiclekeys') == 'started' then
        pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, veh) end)
    end
    return net
end)

lib.callback.register('pa_policia:server:guardarViatura', function(src, net)
    local veh = NetworkGetEntityFromNetworkId(net or 0)
    if veh == 0 or not DoesEntityExist(veh) then return false, 'Viatura não encontrada.' end
    if not Entity(veh).state.pa_viatura then return false, 'Isso não é uma viatura da LSPD.' end
    if #(GetEntityCoords(veh) - Config.dp.garagem.guardar) > 8.0 then return false, 'Pare no ponto da garagem.' end
    exports.qbx_core:DeleteVehicle(veh)
    for s, n in pairs(viaturas) do if n == net then viaturas[s] = nil end end
    return true, 'Viatura devolvida.'
end)

AddEventHandler('playerDropped', function()
    viaturas[source] = nil
end)
