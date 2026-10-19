-- pa_handling - servidor: guarda a calibração (data/calibracao.json) e cuida do teste

local RECURSO = GetCurrentResourceName()
local ARQUIVO = 'data/calibracao.json'
local cfg = Config.calibracao

local Calib = { carros = {} }
local calibrando = {} -- [source] = true

local function carregar()
    local txt = LoadResourceFile(RECURSO, ARQUIVO)
    if txt and txt ~= '' then
        local ok, dados = pcall(json.decode, txt)
        if ok and type(dados) == 'table' then
            Calib = dados
            Calib.carros = Calib.carros or {}
        end
    end
    local n = 0
    for _ in pairs(Calib.carros) do n = n + 1 end
    print(('[pa_handling] %d carro(s) calibrado(s) carregados'):format(n))
end

local function salvar()
    SaveResourceFile(RECURSO, ARQUIVO, json.encode(Calib, { indent = true }), -1)
end

local function mediana(lista)
    if #lista == 0 then return nil end
    table.sort(lista)
    local m = math.floor((#lista + 1) / 2)
    if #lista % 2 == 1 then return lista[m] end
    return (lista[m] + lista[m + 1]) / 2
end

--- Recalcula o chute geral (vale para os carros ainda não calibrados)
local function recalcularK()
    local ks, kv = {}, {}
    for _, c in pairs(Calib.carros) do
        if c.ok and c.alvo and c.forca and c.flatvel then
            ks[#ks + 1] = c.forca * (c.alvo.tempo * 100.0 / c.alvo.marco)
            kv[#kv + 1] = c.flatvel / c.alvo.vmax
        end
    end
    Calib.kForca = mediana(ks)
    Calib.kVel = mediana(kv)
end

carregar()

lib.callback.register('pa_handling:server:calib', function()
    return Calib
end)

---------------------------------------------------------------------
-- Calibração
---------------------------------------------------------------------
local function permitido(src)
    return IsPlayerAceAllowed(src, Config.permissao)
end

lib.callback.register('pa_handling:server:iniciar', function(src)
    if not permitido(src) then return false, 'Você não tem permissão para calibrar' end
    calibrando[src] = true
    SetRoutingBucketPopulationEnabled(cfg.bucket, false)
    SetPlayerRoutingBucket(src, cfg.bucket)
    return true
end)

local function terminar(src)
    if not calibrando[src] then return end
    calibrando[src] = nil
    if GetPlayerName(src) then SetPlayerRoutingBucket(src, 0) end
end

RegisterNetEvent('pa_handling:server:terminar', function()
    local src = source
    terminar(src)
    TriggerClientEvent('pa_handling:client:calib', -1, Calib)
end)

AddEventHandler('playerDropped', function()
    calibrando[source] = nil
end)

-- Chave do carro de teste (sem chave alguns scripts desligam o motor)
RegisterNetEvent('pa_handling:server:chaves', function(netId)
    local src = source
    if not calibrando[src] then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 then return end
    if GetResourceState('qbx_vehiclekeys') == 'started' then
        pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, veh, true) end)
    end
end)

local function numero(v) return type(v) == 'number' and v == v and v > 0 and v < 100000 end

RegisterNetEvent('pa_handling:server:resultado', function(h, r)
    local src = source
    if not calibrando[src] or not permitido(src) then return end
    if type(h) ~= 'string' or type(r) ~= 'table' then return end
    if not numero(r.forca) or not numero(r.flatvel) or type(r.alvo) ~= 'table' then return end
    if not numero(r.alvo.tempo) or not numero(r.alvo.vmax) or not numero(r.alvo.marco) then return end

    Calib.carros[h] = {
        forca = r.forca,
        flatvel = r.flatvel,
        arrasto = numero(r.arrasto) and r.arrasto or nil,
        alvo = { tempo = r.alvo.tempo, vmax = r.alvo.vmax, marco = r.alvo.marco },
        medido = type(r.medido) == 'table' and {
            tempo = numero(r.medido.tempo) and r.medido.tempo or nil,
            vmax = numero(r.medido.vmax) and r.medido.vmax or nil,
        } or nil,
        ok = r.ok == true,
        limiteAderencia = r.limiteAderencia == true or nil,
        tentativas = tonumber(r.tentativas),
        data = os.date('%Y-%m-%d %H:%M'),
    }
    recalcularK()
    salvar()
    TriggerClientEvent('pa_handling:client:carro', -1, h, Calib.carros[h], Calib.kForca, Calib.kVel)
end)

---------------------------------------------------------------------
-- Console: apagar a calibração de um carro (ou tudo)
---------------------------------------------------------------------
RegisterCommand('handling_resetar', function(src, args)
    if src ~= 0 and not permitido(src) then return end
    local alvo = args[1]
    if not alvo then
        print('[pa_handling] use: handling_resetar <HANDLING | tudo>')
        return
    end
    if alvo == 'tudo' then
        Calib = { carros = {} }
    else
        Calib.carros[alvo:upper()] = nil
    end
    recalcularK()
    salvar()
    TriggerClientEvent('pa_handling:client:calib', -1, Calib)
    print('[pa_handling] calibração apagada: ' .. alvo)
end, false)
