-- pa_policia · servidor · abordagem
-- Algemar, conduzir, viatura, revista e apreensão. Tudo conferido aqui.

local DEATH_BAG = 'qbx_medical:deathState'
local EVIDENCIAS = 'pa_policia_evidencias'
local ARMARIO = 'pa_policia_armario'
local ARSENAL = 'pa_policia_arsenal'

local ilegais = {}
for _, nome in ipairs(Config.ilegais) do ilegais[nome] = true end

local acordouEm = {}     -- [src] = os.time() em que saiu do desmaio
local algemadoPor = {}   -- [alvo] = policial

---------------------------------------------------------------------
-- ESTADOS
---------------------------------------------------------------------
function P.Desmaiado(src)
    local e = Player(src).state[DEATH_BAG]
    return e == 2 or e == 3
end

function P.Algemado(src)
    local p = P.Player(src)
    return p and p.PlayerData.metadata.ishandcuffed == true or false
end

local function setAlgema(alvo, tipo)
    exports.qbx_core:SetMetadata(alvo, 'ishandcuffed', tipo ~= nil)
    Player(alvo).state:set('pa_algema', tipo, true)
    if not tipo then
        algemadoPor[alvo] = nil
        Player(alvo).state:set('pa_conduzido', nil, true)
    end
end
P.SetAlgema = setAlgema

AddStateBagChangeHandler(DEATH_BAG, nil, function(bagName, _, valor)
    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 then return end
    if valor ~= 2 and valor ~= 3 then acordouEm[src] = os.time() end
end)

AddEventHandler('playerDropped', function()
    local src = source
    acordouEm[src] = nil
    algemadoPor[src] = nil
    for alvo, pol in pairs(algemadoPor) do
        if pol == src then algemadoPor[alvo] = nil end
    end
end)

-- Quem entra no jogo algemado continua algemado (metadado do qbx_core)
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    if P.Algemado(src) then Player(src).state:set('pa_algema', 'total', true) end
end)

---------------------------------------------------------------------
-- VALIDAÇÃO COMUM
---------------------------------------------------------------------
local function validarAlvo(src, alvo, acao)
    alvo = tonumber(alvo)
    if not alvo or alvo == src or not GetPlayerName(alvo) then return nil, 'Ninguém por perto.' end
    if not P.Pode(src, acao) then return nil, 'Você não tem permissão para isso (patente ou fora de serviço).' end
    if not P.Perto(src, alvo) then return nil, 'Chegue mais perto.' end
    return alvo
end

---------------------------------------------------------------------
-- ALGEMAR
---------------------------------------------------------------------
lib.callback.register('pa_policia:server:algemar', function(src, alvo, leve)
    local erro
    alvo, erro = validarAlvo(src, alvo, 'algemar')
    if not alvo then return false, erro end

    if P.Algemado(alvo) then
        setAlgema(alvo, nil)
        TriggerClientEvent('pa_policia:client:animAlgema', alvo, src, false)
        P.Notify(alvo, 'Você foi desalgemado.', 'inform')
        return true, 'solto'
    end

    if Config.abordagem.bloquearDesmaiado and P.Desmaiado(alvo) then
        return false, 'A pessoa está desmaiada: chame o SAMU antes de algemar.'
    end
    if exports.ox_inventory:Search(src, 'count', Config.abordagem.itemAlgema) < 1 then
        return false, 'Você precisa de uma algema.'
    end

    setAlgema(alvo, leve and 'leve' or 'total')
    algemadoPor[alvo] = src
    TriggerClientEvent('pa_policia:client:animAlgema', alvo, src, true)
    P.Notify(alvo, leve and 'Você foi algemado (mãos à frente).' or 'Você foi algemado.', 'error')
    return true, 'algemado'
end)

-- O pa_medico manda soltar a algema quando o jogador acorda no hospital
RegisterNetEvent('pa_policia:server:soltarAoAcordar', function()
    local src = source
    if not P.Algemado(src) then return end
    if os.time() - (acordouEm[src] or 0) > 30 then return end
    setAlgema(src, nil)
end)

---------------------------------------------------------------------
-- CONDUZIR / VIATURA
---------------------------------------------------------------------
lib.callback.register('pa_policia:server:conduzir', function(src, alvo)
    local erro
    alvo, erro = validarAlvo(src, alvo, 'algemar')
    if not alvo then return false, erro end
    if not P.Algemado(alvo) and not P.Desmaiado(alvo) then return false, 'Só dá para conduzir algemado ou desmaiado.' end

    local st = Player(alvo).state
    if st.pa_conduzido == src then
        st:set('pa_conduzido', nil, true)
        return true, 'solto'
    end
    if st.pa_conduzido and GetPlayerName(st.pa_conduzido) then return false, 'Outro policial já está conduzindo.' end
    st:set('pa_conduzido', src, true)
    return true, 'conduzindo'
end)

lib.callback.register('pa_policia:server:colocarVeiculo', function(src, id, netVeh)
    local alvo, erro = validarAlvo(src, id, 'algemar')
    if not alvo then
        -- quem está sendo conduzido fica grudado no policial: aceita mesmo um pouco mais longe
        alvo = tonumber(id)
        if not alvo or not GetPlayerName(alvo) or not P.Pode(src, 'algemar') or Player(alvo).state.pa_conduzido ~= src then
            return false, erro
        end
    end
    if not P.Algemado(alvo) and not P.Desmaiado(alvo) then return false, 'Só algemado ou desmaiado.' end
    local veh = NetworkGetEntityFromNetworkId(netVeh or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false, 'Viatura não encontrada.' end
    if #(GetEntityCoords(veh) - P.Coords(src)) > 8.0 then return false, 'A viatura está longe.' end
    Player(alvo).state:set('pa_conduzido', nil, true)
    TriggerClientEvent('pa_policia:client:entrarVeiculo', alvo, netVeh)
    return true
end)

lib.callback.register('pa_policia:server:tirarVeiculo', function(src, alvo)
    alvo = tonumber(alvo)
    if not alvo or not GetPlayerName(alvo) then return false, 'Ninguém aí.' end
    if not P.Pode(src, 'algemar') then return false, 'Sem permissão.' end
    if not P.Perto(src, alvo, 6.0) then return false, 'Chegue mais perto.' end
    TriggerClientEvent('pa_policia:client:sairVeiculo', alvo)
    return true
end)

---------------------------------------------------------------------
-- REVISTA
---------------------------------------------------------------------
local function podeSerRevistado(alvo)
    return P.Algemado(alvo) or P.Desmaiado(alvo) or Player(alvo).state.pa_rendido == true
end

lib.callback.register('pa_policia:server:revistar', function(src, alvo)
    local erro
    alvo, erro = validarAlvo(src, alvo, 'revistar')
    if not alvo then return false, erro end
    if not podeSerRevistado(alvo) then return false, 'A pessoa precisa estar algemada, rendida ou desmaiada.' end
    exports.ox_inventory:forceOpenInventory(src, 'player', alvo)
    P.Notify(alvo, 'Você está sendo revistado.', 'inform')
    return true
end)

---------------------------------------------------------------------
-- LICENÇAS (usadas na revista)
---------------------------------------------------------------------
local function itemLicencaValido(src, item, cid)
    for _, s in pairs(exports.ox_inventory:Search(src, 'slots', item) or {}) do
        local m = s.metadata or {}
        if m.cid == cid and (tonumber(m.validade) or 0) > os.time() then return true end
    end
    return false
end

--- Licença ativa (tablet) ou documento válido no bolso
function P.TemLicenca(src, tipo)
    local cid = P.Cid(src)
    if not cid then return false end
    local cfg = Config.licencas[tipo]
    if cfg and itemLicencaValido(src, cfg.item, cid) then return true end
    local ok = MySQL.scalar.await(
        'SELECT 1 FROM pa_policia_licencas WHERE citizenid = ? AND tipo = ? AND revogada = 0 AND validade > ? LIMIT 1',
        { cid, tipo, os.time() })
    return ok ~= nil
end

---------------------------------------------------------------------
-- APREENSÃO
---------------------------------------------------------------------
local function ehIlegal(src, item, porte, caca)
    if ilegais[item.name] then return true end
    if item.name:sub(1, 7) == 'WEAPON_' then
        local m = item.metadata or {}
        if m.registered == 'LSPD' or m.serial == 'LSPD' then return true end -- arma da polícia com civil
        if Config.armasCaca[item.name] then return not caca end
        if Config.armasLivres[item.name] then return false end
        if not m.serial or m.serial == '' then return true end              -- arma sem número de série
        return not porte
    end
    return false
end

--- Tira tudo que é ilegal do jogador e guarda no depósito de evidências
function P.Apreender(policial, alvo)
    local porte = P.TemLicenca(alvo, 'porte')
    local caca = P.TemLicenca(alvo, 'caca')
    local itens = exports.ox_inventory:GetInventoryItems(alvo) or {}
    local levados = {}
    for _, item in pairs(itens) do
        if item and item.name and ehIlegal(alvo, item, porte, caca) then
            if exports.ox_inventory:RemoveItem(alvo, item.name, item.count, item.metadata, item.slot) then
                exports.ox_inventory:AddItem(EVIDENCIAS, item.name, item.count, item.metadata)
                levados[#levados + 1] = { item = item.name, label = item.label or item.name, qtd = item.count }
            end
        end
    end
    if #levados > 0 then
        MySQL.insert('INSERT INTO pa_policia_apreensoes (citizenid, nome, itens, policial) VALUES (?, ?, ?, ?)',
            { P.Cid(alvo), P.Nome(alvo), json.encode(levados), policial and P.Nome(policial) or 'Sistema' })
    end
    return levados
end

lib.callback.register('pa_policia:server:apreender', function(src, alvo)
    local erro
    alvo, erro = validarAlvo(src, alvo, 'apreender')
    if not alvo then return false, erro end
    if not podeSerRevistado(alvo) then return false, 'A pessoa precisa estar algemada, rendida ou desmaiada.' end

    local levados = P.Apreender(src, alvo)
    if #levados == 0 then return true, 'Nada ilegal encontrado.' end
    local partes = {}
    for _, l in ipairs(levados) do partes[#partes + 1] = ('%dx %s'):format(l.qtd, l.label) end
    local texto = table.concat(partes, ', ')
    P.Notify(alvo, 'A polícia apreendeu: ' .. texto, 'error', 8000)
    return true, 'Apreendido: ' .. texto
end)

---------------------------------------------------------------------
-- ARSENAL, ARMÁRIO E DEPÓSITO (ox_inventory)
---------------------------------------------------------------------
CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do Wait(500) end
    local inventario = {}
    for _, item in ipairs(Config.arsenal) do
        inventario[#inventario + 1] = { name = item.name, price = item.price or 0, grade = item.grade, metadata = item.metadata }
    end
    exports.ox_inventory:RegisterShop(ARSENAL, {
        name = 'Arsenal da LSPD',
        groups = { [Config.job] = 0 },
        inventory = inventario,
    })
    exports.ox_inventory:RegisterStash(ARMARIO, 'Armário pessoal (LSPD)', 60, 80000, true, { [Config.job] = 0 })
    exports.ox_inventory:RegisterStash(EVIDENCIAS, 'Depósito de evidências', 300, 5000000, nil, { [Config.job] = Config.permissoes.apreender })
end)

lib.callback.register('pa_policia:server:abrir', function(src, qual)
    if not P.EmServico(src) then return false, 'Você precisa estar em serviço.' end
    local dp = Config.dp
    if qual == 'arsenal' and P.Dist(src, dp.arsenal) < 4.0 then
        return true, ARSENAL -- a loja é aberta pelo cliente (ox_inventory:openInventory 'shop')
    elseif qual == 'armario' and P.Dist(src, dp.armario) < 4.0 then
        exports.ox_inventory:forceOpenInventory(src, 'stash', { id = ARMARIO, owner = P.Cid(src) })
        return true
    elseif qual == 'evidencias' and P.Dist(src, dp.evidencias) < 4.0 then
        if not P.Pode(src, 'apreender') then return false, 'Depósito de evidências: a partir de Oficial 1.' end
        exports.ox_inventory:forceOpenInventory(src, 'stash', EVIDENCIAS)
        return true
    end
    return false, 'Longe demais.'
end)
