-- pa_policia · servidor · perícia
-- Cápsulas (com número de série da arma), sangue (tipo sanguíneo) e digitais no volante.
-- Coleta com saco de evidência e análise no laboratório da DP.

local evidencias = {}     -- [id] = { id, tipo, coords, criado, dados }
local proxId = 0
local ultimoTiro = {}     -- [src] = os.time()  (teste de pólvora)
local ultimaCapsula = {}  -- [src] = GetGameTimer() (limite de cápsulas por segundo)
local ultimoSangue = {}
local digitais = {}       -- [netId] = { { fp, cid, t }, ... }

local function publico(e)
    return { id = e.id, tipo = e.tipo, coords = e.coords, rotulo = e.rotulo }
end

local function enviarParaPolicia(evento, ...)
    local _, lista = P.PoliciaisEmServico()
    for _, s in ipairs(lista) do TriggerClientEvent(evento, s, ...) end
end

local function criar(tipo, coords, rotulo, dados)
    proxId += 1
    local e = { id = proxId, tipo = tipo, coords = coords, rotulo = rotulo, dados = dados, criado = os.time() }
    evidencias[e.id] = e
    enviarParaPolicia('pa_policia:client:evidencia', publico(e))
    return e.id
end

local function remover(id)
    if not evidencias[id] then return end
    evidencias[id] = nil
    enviarParaPolicia('pa_policia:client:removerEvidencia', id)
end

-- validade das evidências
CreateThread(function()
    while true do
        Wait(60000)
        local limite = os.time() - Config.pericia.duracao
        for id, e in pairs(evidencias) do
            if e.criado < limite then remover(id) end
        end
    end
end)

AddEventHandler('QBCore:Server:SetDuty', function(src, emServico)
    if not emServico then return end
    local lista = {}
    for _, e in pairs(evidencias) do lista[#lista + 1] = publico(e) end
    TriggerClientEvent('pa_policia:client:evidencias', src, lista)
end)

local function rotuloArma(nome)
    local item = exports.ox_inventory:Items(nome)
    return item and item.label or nome
end

---------------------------------------------------------------------
-- TIRO: cápsula + alerta + pólvora na mão
---------------------------------------------------------------------
RegisterNetEvent('pa_policia:server:tiro', function(coords, info)
    local src = source
    if type(coords) ~= 'vector3' then return end
    if P.Dist(src, coords) > 6.0 then return end
    if GetGameTimer() - (ultimaCapsula[src] or 0) < 900 then return end
    ultimaCapsula[src] = GetGameTimer()
    local arma = exports.ox_inventory:GetCurrentWeapon(src)
    if not arma or not arma.name or Config.pericia.semCapsula[arma.name] then return end

    ultimoTiro[src] = os.time()
    local policial = P.EmServico(src)

    local m = arma.metadata or {}
    criar('capsula', coords, ('Cápsula · %s'):format(rotuloArma(arma.name)), {
        arma = arma.name,
        serial = m.serial,
        registrada = m.registered,
        policial = policial,
    })

    -- alerta de disparo (testemunha liga para o 190)
    if not policial then
        info = type(info) == 'table' and info or {}
        P.Crime(src, info.veiculo and 'tiroVeiculo' or 'tiro', info)
    end
end)

---------------------------------------------------------------------
-- SANGUE
---------------------------------------------------------------------
RegisterNetEvent('pa_policia:server:sangue', function(coords)
    local src = source
    if type(coords) ~= 'vector3' or P.Dist(src, coords) > 4.0 then return end
    if os.time() - (ultimoSangue[src] or 0) < 15 then return end
    ultimoSangue[src] = os.time()
    local p = P.Player(src)
    if not p then return end
    local tipo = p.PlayerData.metadata.bloodtype or '?'
    criar('sangue', coords, ('Sangue · tipo %s'):format(tipo), { cid = p.PlayerData.citizenid, tipoSangue = tipo })
end)

---------------------------------------------------------------------
-- DIGITAIS NO VOLANTE
---------------------------------------------------------------------
RegisterNetEvent('pa_policia:server:digital', function(net)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(net or 0)
    if veh == 0 or not DoesEntityExist(veh) then return end
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return end
    local p = P.Player(src)
    if not p then return end
    local fp = p.PlayerData.metadata.fingerprint
    local lista = digitais[net] or {}
    for i = #lista, 1, -1 do
        if lista[i].fp == fp then table.remove(lista, i) end
    end
    table.insert(lista, 1, { fp = fp, cid = p.PlayerData.citizenid, t = os.time() })
    while #lista > Config.pericia.digitaisPorCarro do table.remove(lista) end
    digitais[net] = lista
end)

---------------------------------------------------------------------
-- COLETA
---------------------------------------------------------------------
local function ensacar(src, metadata)
    if exports.ox_inventory:Search(src, 'count', Config.pericia.itemVazio) < 1 then
        return false, 'Você precisa de um saco de evidência vazio.'
    end
    if not exports.ox_inventory:CanCarryItem(src, Config.pericia.itemCheio, 1, metadata) then
        return false, 'Sem espaço no inventário.'
    end
    exports.ox_inventory:RemoveItem(src, Config.pericia.itemVazio, 1)
    exports.ox_inventory:AddItem(src, Config.pericia.itemCheio, 1, metadata)
    return true
end

local function ruaDe(coords)
    -- o nome da rua é calculado no cliente; aqui só guardamos as coordenadas
    return ('%.0f, %.0f'):format(coords.x, coords.y)
end

lib.callback.register('pa_policia:server:coletar', function(src, id, rua)
    if not P.Pode(src, 'pericia') then return false, 'Perícia: a partir de Oficial 1.' end
    local e = evidencias[id]
    if not e then return false, 'Essa evidência não existe mais.' end
    if P.Dist(src, e.coords) > 3.0 then return false, 'Chegue mais perto.' end

    local meta = {
        pa_tipo = e.tipo,
        pa_dados = e.dados,
        pa_analisado = false,
        label = e.tipo == 'capsula' and 'Evidência: cápsula' or 'Evidência: sangue',
        description = ('%s\nLocal: %s\nColetado por: %s\nData: %s\nAguardando análise no laboratório.'):format(
            e.rotulo, tostring(rua or ruaDe(e.coords)):sub(1, 60), P.Nome(src), os.date('%d/%m/%Y %H:%M')),
    }
    local ok, erro = ensacar(src, meta)
    if not ok then return false, erro end
    remover(id)
    return true, 'Evidência coletada.'
end)

lib.callback.register('pa_policia:server:coletarDigital', function(src, net)
    if not P.Pode(src, 'pericia') then return false, 'Perícia: a partir de Oficial 1.' end
    local veh = NetworkGetEntityFromNetworkId(net or 0)
    if veh == 0 or not DoesEntityExist(veh) then return false, 'Veículo não encontrado.' end
    if #(GetEntityCoords(veh) - P.Coords(src)) > 4.0 then return false, 'Chegue mais perto do carro.' end
    local lista = digitais[net]
    if not lista or #lista == 0 then return false, 'Nenhuma digital aproveitável no volante.' end
    local d = table.remove(lista, 1)
    local plate = P.Trim(GetVehicleNumberPlateText(veh))
    local ok, erro = ensacar(src, {
        pa_tipo = 'digital',
        pa_dados = { fp = d.fp, cid = d.cid, plate = plate },
        pa_analisado = false,
        label = 'Evidência: digital',
        description = ('Digital no volante do carro %s\nColetado por: %s\nData: %s\nAguardando análise no laboratório.'):format(
            plate, P.Nome(src), os.date('%d/%m/%Y %H:%M')),
    })
    if not ok then return false, erro end
    return true, ('Digital coletada (%d restante(s) no volante).'):format(#lista)
end)

---------------------------------------------------------------------
-- LABORATÓRIO
---------------------------------------------------------------------
lib.callback.register('pa_policia:server:sacosParaAnalise', function(src)
    if not P.Pode(src, 'pericia') then return {} end
    local lista = {}
    for _, s in pairs(exports.ox_inventory:Search(src, 'slots', Config.pericia.itemCheio) or {}) do
        local m = s.metadata or {}
        if m.pa_tipo and not m.pa_analisado then
            lista[#lista + 1] = { slot = s.slot, label = m.label or 'Evidência', descricao = (m.description or ''):match('^[^\n]*') }
        end
    end
    return lista
end)

lib.callback.register('pa_policia:server:analisar', function(src, slot)
    if not P.Pode(src, 'pericia') then return false, 'Perícia: a partir de Oficial 1.' end
    if P.Dist(src, Config.dp.laboratorio) > 4.0 then return false, 'Use o laboratório da DP.' end
    local item = exports.ox_inventory:GetSlot(src, slot)
    if not item or item.name ~= Config.pericia.itemCheio then return false, 'Evidência não encontrada.' end
    local m = item.metadata or {}
    if not m.pa_tipo or m.pa_analisado then return false, 'Essa evidência já foi analisada.' end
    local d = m.pa_dados or {}

    local resultado, cid
    if m.pa_tipo == 'capsula' then
        if d.policial or d.serial == 'LSPD' then
            resultado = ('Arma da LSPD (%s)'):format(rotuloArma(d.arma))
        elseif not d.serial or d.serial == '' then
            resultado = ('%s sem número de série (fabricação clandestina)'):format(rotuloArma(d.arma))
        else
            resultado = ('%s · série %s'):format(rotuloArma(d.arma), d.serial)
            if d.registrada and d.registrada ~= '' then resultado = resultado .. (' · registrada para %s'):format(d.registrada) end
        end
    elseif m.pa_tipo == 'sangue' then
        cid = d.cid
        resultado = ('Sangue tipo %s · compatível com %s (%s)'):format(d.tipoSangue or '?', P.NomeCid(cid), cid)
    elseif m.pa_tipo == 'digital' then
        cid = d.cid
        resultado = ('Digital %s · %s (%s) · carro %s'):format(d.fp or '?', P.NomeCid(cid), cid, d.plate or '?')
    else
        return false, 'Evidência inválida.'
    end

    local laudo = MySQL.insert.await('INSERT INTO pa_policia_pericias (tipo, dados, resultado, citizenid, policial) VALUES (?, ?, ?, ?, ?)',
        { m.pa_tipo, json.encode(d), resultado:sub(1, 250), cid, P.Nome(src) })

    m.pa_analisado = true
    m.pa_laudo = laudo
    m.description = ('%s\n\nLAUDO #%d: %s\nAnalisado por %s em %s'):format(
        m.description:gsub('\nAguardando análise no laboratório%.', ''), laudo, resultado, P.Nome(src), os.date('%d/%m/%Y %H:%M'))
    exports.ox_inventory:SetMetadata(src, slot, m)
    return true, ('Laudo #%d: %s'):format(laudo, resultado)
end)

---------------------------------------------------------------------
-- LIMPAR CENA / TESTE DE PÓLVORA
---------------------------------------------------------------------
lib.callback.register('pa_policia:server:limparCena', function(src)
    if not P.Pode(src, 'pericia') then return false, 'Perícia: a partir de Oficial 1.' end
    local c, n = P.Coords(src), 0
    for id, e in pairs(evidencias) do
        if #(c - e.coords) <= 10.0 then remover(id); n = n + 1 end
    end
    return true, ('%d evidência(s) removida(s).'):format(n)
end)

lib.callback.register('pa_policia:server:testePolvora', function(src, alvo)
    if not P.Pode(src, 'pericia') then return false, 'Perícia: a partir de Oficial 1.' end
    alvo = tonumber(alvo)
    if not alvo or not P.Perto(src, alvo, 3.0) then return false, 'Chegue mais perto.' end
    local positivo = os.time() - (ultimoTiro[alvo] or 0) <= Config.pericia.testePolvora
    return true, positivo and 'POSITIVO: resíduo de pólvora nas mãos.' or 'Negativo: sem resíduo de pólvora.'
end)

-- nadar/tomar banho lava a mão
RegisterNetEvent('pa_policia:server:lavouMao', function()
    ultimoTiro[source] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    ultimoTiro[src] = nil
    ultimaCapsula[src] = nil
    ultimoSangue[src] = nil
end)

AddEventHandler('entityRemoved', function(ent)
    if GetEntityType(ent) ~= 2 then return end
    local net = NetworkGetNetworkIdFromEntity(ent)
    if net then digitais[net] = nil end
end)
