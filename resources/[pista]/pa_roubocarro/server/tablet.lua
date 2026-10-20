-- pa_roubocarro · servidor · tablet: perfil, ofertas, melhorias e carros riscados

local function temTablet(src)
    return exports.ox_inventory:Search(src, 'count', Config.itemTablet) > 0
end

function RC.AtualizarTablet(src)
    TriggerClientEvent('pa_roubocarro:client:atualizar', src)
end

local function ofertas(cid)
    local rows = MySQL.query.await('SELECT id, modelo, classe, preco, expira FROM pa_roubocarro_ofertas WHERE citizenid = ? AND expira > ? ORDER BY id DESC',
        { cid, os.time() }) or {}
    for _, r in ipairs(rows) do
        r.horas = math.max(0, math.floor((r.expira - os.time()) / 3600))
        r.expira = nil
    end
    return rows
end

local function riscadosDe(cid)
    return MySQL.query.await([[
        SELECT pv.plate, pv.vehicle AS modelo FROM player_vehicles pv
        JOIN pa_roubocarro_chassi c ON c.plate = pv.plate
        WHERE pv.citizenid = ?
    ]], { cid }) or {}
end

lib.callback.register('pa_roubocarro:server:tablet', function(src)
    if not temTablet(src) then return nil end
    local d, cid = RC.Dados(src)
    if not d then return nil end
    local nivel = RC.Nivel(d.xp)
    local atual, prox = RC.Progresso(d.xp)

    local classes = {}
    for _, k in ipairs(Config.ordemClasses) do
        local c = Config.classes[k]
        classes[#classes + 1] = {
            chave = k, label = c.label, nivelMin = c.niveis[1], liberada = c.niveis[1] <= nivel,
            modo = c.modo, xp = c.xp, moedas = c.moedas, tempo = c.tempo, rastreador = c.rastreador,
        }
    end

    local melhorias = {}
    for chave, m in pairs(Config.melhorias) do
        local n = d.melhorias[chave] or 0
        melhorias[#melhorias + 1] = {
            chave = chave, label = m.label, descricao = m.descricao,
            nivel = n, max = #m.precos, preco = m.precos[n + 1],
        }
    end
    table.sort(melhorias, function(a, b) return a.label < b.label end)

    local g = RC.Grupo(src)
    local dupla
    if g then
        dupla = {
            souLider = g.lider == src,
            lider = RC.Nome(g.lider),
            parceiro = g.parceiro and RC.Nome(g.parceiro) or nil,
        }
    end

    return {
        nome = RC.Nome(src),
        moeda = Config.nomeMoeda,
        perfil = {
            nivel = nivel, xp = d.xp, xpAtual = atual, xpProx = prox,
            moedas = d.moedas, roubos = d.roubos, classe = RC.ClasseDoNivel(nivel),
        },
        classes = classes,
        contrato = RC.ContratoPublico(src),
        dupla = dupla,
        ofertas = ofertas(cid),
        melhorias = melhorias,
        riscados = riscadosDe(cid),
        etapasRastreador = RC.EtapasRastreador(src),
    }
end)

---------------------------------------------------------------------
-- COMPRAR O CARRO ENTREGUE (chassi riscado)
---------------------------------------------------------------------
local function comprarOferta(src, id)
    local d, cid = RC.Dados(src)
    local o = MySQL.single.await('SELECT * FROM pa_roubocarro_ofertas WHERE id = ? AND citizenid = ?', { tonumber(id) or 0, cid })
    if not o or o.expira < os.time() then return false, 'Oferta não encontrada ou expirada.' end
    if d.moedas < o.preco then return false, ('Faltam %d %s.'):format(o.preco - d.moedas, Config.nomeMoeda) end
    if GetResourceState('qbx_vehicles') ~= 'started' then return false, 'Sistema de veículos fora do ar.' end

    -- tira a oferta antes para não comprar duas vezes
    local apagou = MySQL.update.await('DELETE FROM pa_roubocarro_ofertas WHERE id = ?', { o.id })
    if apagou == 0 then return false, 'Oferta já comprada.' end

    local props = (o.props and json.decode(o.props)) or {}
    local placa = RC.GerarPlaca()
    props.plate = placa

    local vehicleId = exports.qbx_vehicles:CreatePlayerVehicle({ model = o.modelo, citizenid = cid, props = props })
    if not vehicleId then
        MySQL.insert('INSERT INTO pa_roubocarro_ofertas (citizenid, modelo, classe, preco, props, expira) VALUES (?, ?, ?, ?, ?, ?)',
            { cid, o.modelo, o.classe, o.preco, o.props, o.expira })
        return false, 'Não foi possível registrar o carro. Tente de novo.'
    end

    d.moedas -= o.preco
    RC.Salvar(src)
    RC.MarcarRiscado(placa, cid, o.modelo)

    local r = Config.retirada
    local ok, netId, veh = pcall(qbx.spawnVehicle, { model = o.modelo, spawnSource = r, props = props })
    if ok and veh and DoesEntityExist(veh) then
        Entity(veh).state:set('vehicleid', vehicleId, false)
        SetVehicleNumberPlateText(veh, placa)
        MySQL.update('UPDATE player_vehicles SET state = 0 WHERE id = ?', { vehicleId })
        RC.DarChaves(src, veh)
        TriggerClientEvent('pa_roubocarro:client:retirada', src, { x = r.x, y = r.y, z = r.z })
        return true, ('Carro %s comprado. Retire no hangar de Sandy Shores (placa %s). O chassi está riscado.'):format(o.modelo:upper(), placa)
    end
    return true, ('Carro %s comprado (placa %s). Ele está na sua garagem. O chassi está riscado.'):format(o.modelo:upper(), placa)
end

---------------------------------------------------------------------
-- MELHORIAS
---------------------------------------------------------------------
local function comprarMelhoria(src, chave)
    local m = Config.melhorias[chave]
    if not m then return false, 'Melhoria inválida.' end
    local d = RC.Dados(src)
    local n = d.melhorias[chave] or 0
    local preco = m.precos[n + 1]
    if not preco then return false, 'Já está no máximo.' end
    if d.moedas < preco then return false, ('Faltam %d %s.'):format(preco - d.moedas, Config.nomeMoeda) end
    d.moedas -= preco
    d.melhorias[chave] = n + 1
    RC.Salvar(src)
    return true, ('%s nível %d comprado.'):format(m.label, n + 1)
end

---------------------------------------------------------------------
-- VENDER (transferir) CARRO RISCADO PARA OUTRO JOGADOR
---------------------------------------------------------------------
local function transferir(src, placa, alvo)
    alvo = tonumber(alvo)
    placa = RC.Trim(placa):upper()
    local cid = RC.Cid(src)
    if not alvo or alvo == src then return false, 'ID inválido.' end
    local p = RC.Player(alvo)
    if not p then return false, 'Jogador não encontrado.' end
    if #(RC.Coords(src) - RC.Coords(alvo)) > Config.transferencia.distancia then
        return false, 'O comprador precisa estar do seu lado.'
    end
    if not RC.ChassiRiscado(placa) then return false, 'Esse carro não é de chassi riscado.' end
    local dono = MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE plate = ?', { placa })
    if dono ~= cid then return false, 'Esse carro não é seu.' end

    MySQL.update.await('UPDATE player_vehicles SET citizenid = ?, license = ? WHERE plate = ?',
        { p.PlayerData.citizenid, p.PlayerData.license, placa })
    MySQL.update('UPDATE pa_roubocarro_chassi SET citizenid = ? WHERE plate = ?', { p.PlayerData.citizenid, placa })
    RC.Notificar(alvo, ('%s passou para você o carro de placa %s (chassi riscado).'):format(RC.Nome(src), placa), 'success')
    return true, ('Carro %s passado para %s.'):format(placa, RC.Nome(alvo))
end

---------------------------------------------------------------------
-- AÇÕES DO TABLET
---------------------------------------------------------------------
local acoes = {
    pedir       = function(src, a) return RC.PedirContrato(src, a.classe) end,
    cancelar    = function(src) return RC.Cancelar(src) end,
    convidar    = function(src, a) return RC.Convidar(src, a.id) end,
    aceitar     = function(src) return RC.Aceitar(src) end,
    sairDupla   = function(src) return RC.SairDupla(src) end,
    comprar     = function(src, a) return comprarOferta(src, a.id) end,
    melhoria    = function(src, a) return comprarMelhoria(src, a.chave) end,
    transferir  = function(src, a) return transferir(src, a.placa, a.id) end,
}

local ocupado = {}

lib.callback.register('pa_roubocarro:server:acao', function(src, nome, args)
    if not temTablet(src) then return false, 'Você não está com o tablet.' end
    local f = acoes[nome]
    if not f then return false end
    if ocupado[src] then return false, 'Aguarde.' end
    ocupado[src] = true
    local ok, r1, r2 = pcall(f, src, type(args) == 'table' and args or {})
    ocupado[src] = nil
    if not ok then
        print(('[pa_roubocarro] erro na ação %s: %s'):format(nome, r1))
        return false, 'Erro. Tente de novo.'
    end
    return r1, r2
end)
