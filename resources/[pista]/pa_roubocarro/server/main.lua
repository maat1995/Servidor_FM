-- pa_roubocarro · servidor · dados do jogador, banco, níveis e utilidades
RC = {}

local dados = {}     -- [citizenid] = { xp, moedas, roubos, melhorias = {} }
local riscados = {}  -- cache: [plate] = true (chassi riscado)

---------------------------------------------------------------------
-- BANCO
---------------------------------------------------------------------
MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS pa_roubocarro_jogadores (
            citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
            xp INT NOT NULL DEFAULT 0,
            moedas INT NOT NULL DEFAULT 0,
            roubos INT NOT NULL DEFAULT 0,
            melhorias LONGTEXT NULL
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS pa_roubocarro_ofertas (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            modelo VARCHAR(50) NOT NULL,
            classe VARCHAR(2) NOT NULL,
            preco INT NOT NULL,
            props LONGTEXT NULL,
            expira INT NOT NULL,
            INDEX (citizenid)
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS pa_roubocarro_chassi (
            plate VARCHAR(12) NOT NULL PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            modelo VARCHAR(50) NOT NULL,
            criado TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    MySQL.query('DELETE FROM pa_roubocarro_ofertas WHERE expira < ?', { os.time() })
    for _, r in ipairs(MySQL.query.await('SELECT plate FROM pa_roubocarro_chassi') or {}) do
        riscados[r.plate] = true
    end
end)

---------------------------------------------------------------------
-- JOGADOR
---------------------------------------------------------------------
function RC.Player(src)
    return exports.qbx_core:GetPlayer(src)
end

function RC.Cid(src)
    local p = RC.Player(src)
    return p and p.PlayerData.citizenid or nil
end

function RC.Nome(src)
    local p = RC.Player(src)
    if not p then return ('ID %s'):format(src) end
    local c = p.PlayerData.charinfo
    return ('%s %s'):format(c.firstname, c.lastname)
end

function RC.Notificar(src, texto, tipo)
    exports.qbx_core:Notify(src, texto, tipo or 'inform')
end

function RC.Coords(src)
    return GetEntityCoords(GetPlayerPed(src))
end

function RC.Dados(src)
    local cid = RC.Cid(src)
    if not cid then return nil end
    if dados[cid] then return dados[cid], cid end
    local r = MySQL.single.await('SELECT xp, moedas, roubos, melhorias FROM pa_roubocarro_jogadores WHERE citizenid = ?', { cid })
    local d = {
        xp = r and r.xp or 0,
        moedas = r and r.moedas or 0,
        roubos = r and r.roubos or 0,
        melhorias = (r and r.melhorias and json.decode(r.melhorias)) or {},
    }
    if not r then
        MySQL.insert.await('INSERT INTO pa_roubocarro_jogadores (citizenid) VALUES (?)', { cid })
    end
    dados[cid] = d
    return d, cid
end

function RC.Salvar(src)
    local d, cid = RC.Dados(src)
    if not d then return end
    MySQL.update('UPDATE pa_roubocarro_jogadores SET xp = ?, moedas = ?, roubos = ?, melhorias = ? WHERE citizenid = ?',
        { d.xp, d.moedas, d.roubos, json.encode(d.melhorias), cid })
end

AddEventHandler('qbx_core:server:playerLoggedOut', function(src)
    local cid = RC.Cid(src)
    if cid then dados[cid] = nil end
end)

---------------------------------------------------------------------
-- NÍVEIS
---------------------------------------------------------------------
function RC.Nivel(xp)
    local nivel = 1
    for n, precisa in ipairs(Config.xpNivel) do
        if xp >= precisa then nivel = n end
    end
    return nivel
end

--- Progresso dentro do nível atual: atual, proximo (nil no nível máximo)
function RC.Progresso(xp)
    local n = RC.Nivel(xp)
    return Config.xpNivel[n], Config.xpNivel[n + 1]
end

function RC.ClasseDoNivel(nivel)
    for _, k in ipairs(Config.ordemClasses) do
        local c = Config.classes[k]
        if nivel >= c.niveis[1] and nivel <= c.niveis[2] then return k end
    end
    return 'D'
end

--- Classes liberadas para o nível (a do nível e todas abaixo)
function RC.ClassesLiberadas(nivel)
    local lista = {}
    for _, k in ipairs(Config.ordemClasses) do
        if Config.classes[k].niveis[1] <= nivel then lista[#lista + 1] = k end
    end
    return lista
end

function RC.Melhoria(src, chave)
    local d = RC.Dados(src)
    local nivel = d and d.melhorias[chave] or 0
    local m = Config.melhorias[chave]
    return m.valor[nivel + 1] or m.valor[#m.valor], nivel
end

--- Dá XP e moedas e avisa quando sobe de nível
function RC.Recompensar(src, xp, moedas)
    local d = RC.Dados(src)
    if not d then return end
    local antes = RC.Nivel(d.xp)
    d.xp += xp
    d.moedas += moedas
    d.roubos += 1
    RC.Salvar(src)
    local depois = RC.Nivel(d.xp)
    RC.Notificar(src, ('Contrato pago: +%d XP e +%d %s.'):format(xp, moedas, Config.nomeMoeda), 'success')
    if depois > antes then
        local classe = RC.ClasseDoNivel(depois)
        RC.Notificar(src, ('Tablet subiu para o nível %d! %s'):format(depois, Config.classes[classe].label), 'success')
    end
end

---------------------------------------------------------------------
-- UTILIDADES
---------------------------------------------------------------------
function RC.PoliciaisEmServico()
    local ok, n = pcall(function() return exports.qbx_core:GetDutyCountType('leo') end)
    return ok and n or 0
end

function RC.Trim(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local modelosPorHash = {}
for classe, c in pairs(Config.classes) do
    for _, m in ipairs(c.modelos) do modelosPorHash[joaat(m)] = { modelo = m, classe = classe } end
end

--- Modelo e classe de um hash (nil se não for carro de contrato)
function RC.ModeloDoHash(hash)
    return modelosPorHash[hash]
end

local LETRAS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
function RC.GerarPlaca()
    for _ = 1, 20 do
        local p = ''
        for i = 1, 8 do
            if i <= 3 then
                local n = math.random(1, #LETRAS)
                p = p .. LETRAS:sub(n, n)
            else
                p = p .. tostring(math.random(0, 9))
            end
        end
        local existe = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { p })
        if not existe then return p end
    end
    return ('RC%06d'):format(math.random(0, 999999))
end

--- Alerta para a pa_policia (se ela estiver rodando)
function RC.Alerta(dadosAlerta)
    if GetResourceState('pa_policia') ~= 'started' then return nil end
    local ok, id = pcall(function() return exports.pa_policia:alerta(dadosAlerta) end)
    return ok and id or nil
end

function RC.FecharAlerta(id)
    if not id or GetResourceState('pa_policia') ~= 'started' then return end
    pcall(function() exports.pa_policia:fecharAlerta(id) end)
end

function RC.DarChaves(src, veh)
    if GetResourceState('qbx_vehiclekeys') ~= 'started' then return end
    pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, veh) end)
end

---------------------------------------------------------------------
-- CHASSI RISCADO (consultado pela vistoria da pa_policia)
---------------------------------------------------------------------
function RC.MarcarRiscado(plate, cid, modelo)
    plate = RC.Trim(plate):upper()
    riscados[plate] = true
    MySQL.insert('INSERT INTO pa_roubocarro_chassi (plate, citizenid, modelo) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE citizenid = VALUES(citizenid)',
        { plate, cid, modelo })
end

function RC.ChassiRiscado(plate)
    return riscados[RC.Trim(plate):upper()] == true
end

exports('chassiRiscado', RC.ChassiRiscado)

---------------------------------------------------------------------
-- ADMIN
---------------------------------------------------------------------
lib.addCommand('rc_ponto', {
    help = 'Roubo de carros: mostra a posição atual para colocar no config',
    restricted = 'group.admin',
}, function(src)
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = veh ~= 0 and veh or ped
    local c, h = GetEntityCoords(ent), GetEntityHeading(ent)
    local texto = ('vec4(%.1f, %.1f, %.1f, %.1f),'):format(c.x, c.y, c.z, h)
    TriggerClientEvent('pa_roubocarro:client:copiar', src, texto)
end)

lib.addCommand('rc_xp', {
    help = 'Roubo de carros: dar XP/moedas ao tablet de um jogador',
    restricted = 'group.admin',
    params = {
        { name = 'id', type = 'playerId', help = 'ID do jogador' },
        { name = 'xp', type = 'number', help = 'XP' },
        { name = 'moedas', type = 'number', help = 'Moedas', optional = true },
    },
}, function(src, args)
    local d = RC.Dados(args.id)
    if not d then return end
    d.xp = math.max(0, d.xp + args.xp)
    d.moedas = math.max(0, d.moedas + (args.moedas or 0))
    RC.Salvar(args.id)
    RC.Notificar(src, ('Tablet de %s: nível %d, %d XP, %d %s.'):format(RC.Nome(args.id), RC.Nivel(d.xp), d.xp, d.moedas, Config.nomeMoeda), 'success')
end)
