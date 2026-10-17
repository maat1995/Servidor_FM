-- pa_policia · servidor · tablet policial (MDT)
-- Fichas, código penal, multas, BO, mandados, licenças, placas, equipe e caixa da LSPD.

local placasProcuradas = {}   -- [placa] = motivo
local codigoCache

---------------------------------------------------------------------
-- CÓDIGO PENAL (config + alterações salvas no banco)
---------------------------------------------------------------------
function P.Codigo()
    if codigoCache then return codigoCache end
    local lista, porId = {}, {}
    for _, a in ipairs(Config.codigoPenal) do
        local copia = { id = a.id, titulo = a.titulo, multa = a.multa, meses = a.meses }
        lista[#lista + 1] = copia
        porId[a.id] = copia
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM pa_policia_codigo') or {}) do
        local a = porId[r.id]
        if r.removido == 1 then
            if a then a.removido = true end
        elseif a then
            a.titulo, a.multa, a.meses = r.titulo, r.multa, r.meses
        else
            local novo = { id = r.id, titulo = r.titulo, multa = r.multa, meses = r.meses }
            lista[#lista + 1] = novo
            porId[r.id] = novo
        end
    end
    local final = {}
    for _, a in ipairs(lista) do if not a.removido then final[#final + 1] = a end end
    table.sort(final, function(a, b) return a.id < b.id end)
    codigoCache = final
    return final
end

local function artigoPorId(id)
    for _, a in ipairs(P.Codigo()) do if a.id == id then return a end end
end

---------------------------------------------------------------------
-- MULTAS
---------------------------------------------------------------------
--- Registra uma multa. Se o cidadão estiver on-line, tenta cobrar do banco na hora.
--- policial = source do policial ou nil (radar/sistema)
function P.Multar(cid, valor, motivo, policial)
    valor = math.floor(tonumber(valor) or 0)
    if valor <= 0 or not cid then return false end
    local alvo = exports.qbx_core:GetPlayerByCitizenId(cid)
    local pago = 0
    if alvo and P.CobrarBanco(alvo.PlayerData.source, valor, 'multa-lspd') then pago = 1 end
    local id = MySQL.insert.await(
        'INSERT INTO pa_policia_multas (citizenid, nome, valor, motivo, policial, policial_cid, pago) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { cid, P.NomeCid(cid), valor, tostring(motivo):sub(1, 250), policial and P.Nome(policial) or 'Sistema', policial and P.Cid(policial) or nil, pago })
    if alvo then
        local s = alvo.PlayerData.source
        if pago == 1 then
            P.Notify(s, ('Multa de $%d paga: %s'):format(valor, motivo), 'error', 8000)
        else
            P.Notify(s, ('Multa de $%d (sem saldo no banco, ficou pendente): %s. Pague na DP.'):format(valor, motivo), 'error', 10000)
        end
    end
    return true, id, pago == 1
end
exports('multar', P.Multar)

---------------------------------------------------------------------
-- LICENÇAS
---------------------------------------------------------------------
local function darDocumento(alvo, tipo, validade)
    local cfg = Config.licencas[tipo]
    local cid = P.Cid(alvo)
    local nome = P.Nome(alvo)
    for _, s in pairs(exports.ox_inventory:Search(alvo, 'slots', cfg.item) or {}) do
        exports.ox_inventory:RemoveItem(alvo, cfg.item, s.count, nil, s.slot)
    end
    return exports.ox_inventory:AddItem(alvo, cfg.item, 1, {
        cid = cid,
        titular = nome,
        validade = validade,
        description = ('Titular: %s\nID: %s\nVálida até: %s'):format(nome, cid, os.date('%d/%m/%Y', validade)),
    })
end

local function setPorteMetadata(src, valor)
    local p = P.Player(src)
    if not p then return end
    local lic = p.PlayerData.metadata.licences or {}
    lic.weapon = valor
    exports.qbx_core:SetMetadata(src, 'licences', lic)
end

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local function proximo(src, alvo, dist)
    alvo = tonumber(alvo)
    if not alvo or not GetPlayerName(alvo) then return nil end
    if alvo ~= src and not P.Perto(src, alvo, dist or 5.0) then return nil end
    return alvo
end

local function lerCharinfo(raw)
    local c = type(raw) == 'string' and json.decode(raw) or raw or {}
    return c
end

local function dataBR(ts)
    if not ts then return '' end
    if type(ts) == 'number' then
        if ts > 9999999999 then ts = math.floor(ts / 1000) end
        return os.date('%d/%m/%Y %H:%M', ts)
    end
    return tostring(ts)
end

---------------------------------------------------------------------
-- ABRIR
---------------------------------------------------------------------
lib.callback.register('pa_policia:mdt:abrir', function(src)
    if not P.EmServico(src) then return nil end
    local grau = P.Grau(src)
    local perms = {}
    for acao, min in pairs(Config.permissoes) do perms[acao] = grau >= min end

    local _, lista = P.PoliciaisEmServico()
    local equipe = {}
    for _, s in ipairs(lista) do
        local p = P.Player(s)
        if p then
            equipe[#equipe + 1] = {
                nome = P.NomeDe(p),
                patente = p.PlayerData.job.name == Config.job and P.Patente(p.PlayerData.job.grade.level) or p.PlayerData.job.label,
                distintivo = p.PlayerData.metadata.callsign ~= 'NO CALLSIGN' and p.PlayerData.metadata.callsign or '',
            }
        end
    end

    return {
        eu = { nome = P.Nome(src), patente = P.Patente(grau), grau = grau, perms = perms, teto = Config.tetoMulta[grau] or 0 },
        patentes = Config.patentes,
        promoverAte = Config.promoverAte[grau] or -1,
        codigo = P.Codigo(),
        ocorrencias = P.ListarOcorrencias(),
        equipe = equipe,
        minutosPorMes = Config.prisao.minutosPorMes,
    }
end)

---------------------------------------------------------------------
-- CIDADÃOS
---------------------------------------------------------------------
lib.callback.register('pa_policia:mdt:buscar', function(src, termo)
    if not P.EmServico(src) then return {} end
    termo = P.Trim(tostring(termo or '')):sub(1, 40)
    if #termo < 2 then return {} end
    local rows = MySQL.query.await([[
        SELECT citizenid, charinfo FROM players
        WHERE citizenid = ?
           OR CONCAT(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))) LIKE ?
           OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone')) = ?
        LIMIT 30
    ]], { termo:upper(), '%' .. termo .. '%', termo }) or {}
    local lista = {}
    for _, r in ipairs(rows) do
        local c = lerCharinfo(r.charinfo)
        lista[#lista + 1] = {
            cid = r.citizenid,
            nome = ('%s %s'):format(c.firstname or '?', c.lastname or ''),
            nascimento = c.birthdate,
            online = exports.qbx_core:GetPlayerByCitizenId(r.citizenid) ~= nil,
        }
    end
    return lista
end)

lib.callback.register('pa_policia:mdt:proximos', function(src)
    if not P.EmServico(src) then return {} end
    local lista = {}
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= src and P.Perto(src, id, 6.0) then
            local p = P.Player(id)
            if p then lista[#lista + 1] = { id = id, cid = p.PlayerData.citizenid, nome = P.NomeDe(p) } end
        end
    end
    return lista
end)

local function licencasDe(cid)
    local rows = MySQL.query.await(
        'SELECT id, tipo, validade, policial, revogada FROM pa_policia_licencas WHERE citizenid = ? ORDER BY id DESC LIMIT 20', { cid }) or {}
    local agora = os.time()
    local lista = {}
    for _, r in ipairs(rows) do
        lista[#lista + 1] = {
            id = r.id, tipo = r.tipo, validade = os.date('%d/%m/%Y', r.validade), policial = r.policial,
            ativa = r.revogada == 0 and r.validade > agora, revogada = r.revogada == 1,
        }
    end
    return lista
end

lib.callback.register('pa_policia:mdt:ficha', function(src, cid)
    if not P.EmServico(src) then return nil end
    local row = MySQL.single.await('SELECT citizenid, charinfo, job, metadata FROM players WHERE citizenid = ?', { cid })
    if not row then return nil end
    local c = lerCharinfo(row.charinfo)
    local job = row.job and json.decode(row.job) or {}
    local meta = row.metadata and json.decode(row.metadata) or {}

    local multas = MySQL.query.await(
        'SELECT id, valor, motivo, policial, pago, cancelada, criado FROM pa_policia_multas WHERE citizenid = ? ORDER BY id DESC LIMIT 40', { cid }) or {}
    for _, m in ipairs(multas) do m.criado = dataBR(m.criado) end
    local prisoes = MySQL.query.await(
        'SELECT id, meses, multa, artigos, policial, criado FROM pa_policia_prisoes WHERE citizenid = ? ORDER BY id DESC LIMIT 30', { cid }) or {}
    for _, pr in ipairs(prisoes) do pr.criado = dataBR(pr.criado); pr.artigos = pr.artigos and json.decode(pr.artigos) or {} end
    local mandados = MySQL.query.await(
        'SELECT id, tipo, motivo, policial, expira FROM pa_policia_mandados WHERE citizenid = ? AND ativo = 1 AND expira > ? ORDER BY id DESC', { cid, os.time() }) or {}
    for _, m in ipairs(mandados) do m.expira = dataBR(m.expira) end
    local veiculos = MySQL.query.await('SELECT plate, vehicle, state, garage FROM player_vehicles WHERE citizenid = ?', { cid }) or {}
    for _, v in ipairs(veiculos) do
        v.procurado = placasProcuradas[v.plate] ~= nil
    end
    local apreensoes = MySQL.query.await(
        'SELECT id, itens, policial, criado FROM pa_policia_apreensoes WHERE citizenid = ? ORDER BY id DESC LIMIT 15', { cid }) or {}
    for _, a in ipairs(apreensoes) do a.criado = dataBR(a.criado); a.itens = a.itens and json.decode(a.itens) or {} end

    local preso = MySQL.single.await('SELECT restante, total FROM pa_policia_presos WHERE citizenid = ?', { cid })

    return {
        cid = cid,
        nome = ('%s %s'):format(c.firstname or '?', c.lastname or ''),
        nascimento = c.birthdate,
        sexo = c.gender == 1 and 'Feminino' or 'Masculino',
        nacionalidade = c.nationality,
        telefone = c.phone,
        emprego = job.label or job.name,
        digital = meta.fingerprint,
        sangue = meta.bloodtype,
        online = exports.qbx_core:GetPlayerByCitizenId(cid) ~= nil,
        licencas = licencasDe(cid),
        habilitacao = meta.licences and meta.licences.driver ~= false,
        multas = multas,
        prisoes = prisoes,
        mandados = mandados,
        veiculos = veiculos,
        apreensoes = apreensoes,
        preso = preso and { restante = math.ceil(preso.restante / 60), total = preso.total } or nil,
    }
end)

---------------------------------------------------------------------
-- MULTAR / CANCELAR
---------------------------------------------------------------------
lib.callback.register('pa_policia:mdt:multar', function(src, cid, valor, motivo)
    if not P.Pode(src, 'multar') then return false, 'Sem permissão.' end
    valor = math.floor(tonumber(valor) or 0)
    motivo = P.Trim(tostring(motivo or ''))
    if valor <= 0 then return false, 'Valor inválido.' end
    if #motivo < 3 then return false, 'Escreva o motivo.' end
    local teto = Config.tetoMulta[P.Grau(src)] or 0
    if valor > teto then return false, ('Sua patente multa até $%d.'):format(teto) end
    if not MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ?', { cid }) then return false, 'Cidadão não encontrado.' end
    local ok, _, pago = P.Multar(cid, valor, motivo, src)
    if not ok then return false, 'Falha ao registrar.' end
    return true, pago and 'Multa paga na hora.' or 'Multa registrada como pendente.'
end)

lib.callback.register('pa_policia:mdt:cancelarMulta', function(src, id)
    if not P.Pode(src, 'cancelarMulta') then return false, 'Só Tenente ou acima.' end
    local m = MySQL.single.await('SELECT citizenid, valor, pago FROM pa_policia_multas WHERE id = ?', { id })
    if not m then return false, 'Multa não encontrada.' end
    MySQL.update.await('UPDATE pa_policia_multas SET cancelada = 1 WHERE id = ?', { id })
    if m.pago == 1 then
        -- devolve no banco (funciona com o cidadão on-line ou off-line)
        exports.qbx_core:AddMoney(m.citizenid, 'bank', m.valor, 'multa-cancelada')
        local alvo = exports.qbx_core:GetPlayerByCitizenId(m.citizenid)
        if alvo then
            P.Notify(alvo.PlayerData.source, ('Uma multa de $%d foi cancelada e devolvida.'):format(m.valor), 'success')
        end
    end
    return true, 'Multa cancelada.'
end)

-- Cidadão paga as multas pendentes na recepção da DP
lib.callback.register('pa_policia:server:minhasMultas', function(src)
    local cid = P.Cid(src)
    return MySQL.query.await(
        'SELECT id, valor, motivo, criado FROM pa_policia_multas WHERE citizenid = ? AND pago = 0 AND cancelada = 0 ORDER BY id', { cid }) or {}
end)

lib.callback.register('pa_policia:server:pagarMultas', function(src)
    if P.Dist(src, Config.dp.servico) > 6.0 then return false, 'Pague na recepção da DP.' end
    local cid = P.Cid(src)
    local rows = MySQL.query.await('SELECT id, valor FROM pa_policia_multas WHERE citizenid = ? AND pago = 0 AND cancelada = 0', { cid }) or {}
    if #rows == 0 then return false, 'Você não tem multas pendentes.' end
    local total = 0
    for _, r in ipairs(rows) do total = total + r.valor end
    local p = P.Player(src)
    if not p.Functions.RemoveMoney('bank', total, 'multas-lspd') and not p.Functions.RemoveMoney('cash', total, 'multas-lspd') then
        return false, ('Você precisa de $%d (banco ou dinheiro).'):format(total)
    end
    P.Sociedade(total)
    for _, r in ipairs(rows) do MySQL.update('UPDATE pa_policia_multas SET pago = 1 WHERE id = ?', { r.id }) end
    return true, ('Multas pagas: $%d.'):format(total)
end)

---------------------------------------------------------------------
-- APLICAR PENA (código penal)
---------------------------------------------------------------------
lib.callback.register('pa_policia:mdt:aplicarPena', function(src, alvo, artigos)
    if not P.Pode(src, 'prender') then return false, 'Só Oficial 1 ou acima aplica pena.' end
    alvo = proximo(src, alvo, 6.0)
    if not alvo or alvo == src then return false, 'O preso precisa estar perto de você.' end
    if Config.prisao.exigirNaDP and (not P.NaDP(src) or not P.NaDP(alvo)) then
        return false, 'Leve o preso até a DP para aplicar a pena.'
    end
    if type(artigos) ~= 'table' or #artigos == 0 then return false, 'Escolha os artigos.' end

    local multa, meses, lista = 0, 0, {}
    for _, id in ipairs(artigos) do
        local a = artigoPorId(tostring(id))
        if a then
            multa += a.multa
            meses += a.meses
            lista[#lista + 1] = ('%s %s'):format(a.id, a.titulo)
        end
    end
    if #lista == 0 then return false, 'Artigos inválidos.' end
    meses = math.min(meses, Config.prisao.maxMeses)

    local cid = P.Cid(alvo)
    if multa > 0 then P.Multar(cid, multa, 'Código penal: ' .. table.concat(lista, ', '), src) end
    MySQL.insert.await('INSERT INTO pa_policia_prisoes (citizenid, nome, meses, multa, artigos, policial) VALUES (?, ?, ?, ?, ?, ?)',
        { cid, P.Nome(alvo), meses, multa, json.encode(lista), P.Nome(src) })
    -- cumpre os mandados de prisão abertos
    MySQL.update.await("UPDATE pa_policia_mandados SET ativo = 0 WHERE citizenid = ? AND tipo = 'prisao' AND ativo = 1", { cid })
    exports.qbx_core:SetMetadata(alvo, 'criminalrecord', { hasRecord = true, date = os.date('%d/%m/%Y') })

    if meses > 0 then
        P.Prender(alvo, meses, src)
        return true, ('Pena aplicada: %d meses e $%d de multa.'):format(meses, multa)
    end
    return true, ('Multa aplicada: $%d (sem prisão).'):format(multa)
end)

---------------------------------------------------------------------
-- LICENÇAS
---------------------------------------------------------------------
lib.callback.register('pa_policia:mdt:emitirLicenca', function(src, alvo, tipo)
    if not P.Pode(src, 'licencas') then return false, 'Só Sargento ou acima emite licença.' end
    local cfg = Config.licencas[tipo]
    if not cfg then return false, 'Licença inválida.' end
    alvo = proximo(src, alvo, 6.0)
    if not alvo or alvo == src then return false, 'O cidadão precisa estar perto (o documento é entregue na mão).' end

    if cfg.preco > 0 and not P.CobrarBanco(alvo, cfg.preco, 'licenca-' .. tipo) then
        return false, ('O cidadão precisa de $%d no banco.'):format(cfg.preco)
    end
    local validade = os.time() + cfg.dias * 86400
    if not darDocumento(alvo, tipo, validade) then return false, 'O cidadão não tem espaço no inventário.' end

    MySQL.update.await('UPDATE pa_policia_licencas SET revogada = 1 WHERE citizenid = ? AND tipo = ? AND revogada = 0', { P.Cid(alvo), tipo })
    MySQL.insert.await('INSERT INTO pa_policia_licencas (citizenid, tipo, validade, policial) VALUES (?, ?, ?, ?)',
        { P.Cid(alvo), tipo, validade, P.Nome(src) })
    if tipo == 'porte' then setPorteMetadata(alvo, true) end

    local nome = tipo == 'porte' and 'porte de arma' or 'licença de caça'
    P.Notify(alvo, ('Você recebeu %s válido(a) até %s.'):format(nome, os.date('%d/%m/%Y', validade)), 'success')
    return true, ('%s emitido(a) para %s.'):format(nome:gsub('^%l', string.upper), P.Nome(alvo))
end)

lib.callback.register('pa_policia:mdt:revogarLicenca', function(src, id)
    if not P.Pode(src, 'revogarLicenca') then return false, 'Só Tenente ou acima revoga licença.' end
    local l = MySQL.single.await('SELECT citizenid, tipo FROM pa_policia_licencas WHERE id = ?', { id })
    if not l then return false, 'Licença não encontrada.' end
    MySQL.update.await('UPDATE pa_policia_licencas SET revogada = 1 WHERE id = ?', { id })
    local alvo = exports.qbx_core:GetPlayerByCitizenId(l.citizenid)
    if alvo then
        local s = alvo.PlayerData.source
        local cfg = Config.licencas[l.tipo]
        if cfg then
            for _, slot in pairs(exports.ox_inventory:Search(s, 'slots', cfg.item) or {}) do
                exports.ox_inventory:RemoveItem(s, cfg.item, slot.count, nil, slot.slot)
            end
        end
        if l.tipo == 'porte' then setPorteMetadata(s, false) end
        P.Notify(s, 'Uma licença sua foi revogada pela LSPD.', 'error')
    end
    return true, 'Licença revogada.'
end)

---------------------------------------------------------------------
-- MANDADOS
---------------------------------------------------------------------
lib.callback.register('pa_policia:mdt:mandadoPrisao', function(src, cid, motivo)
    if not P.Pode(src, 'mandado') then return false, 'Só Sargento ou acima emite mandado.' end
    motivo = P.Trim(tostring(motivo or ''))
    if #motivo < 3 then return false, 'Escreva o motivo.' end
    if not MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ?', { cid }) then return false, 'Cidadão não encontrado.' end
    MySQL.insert.await("INSERT INTO pa_policia_mandados (tipo, citizenid, motivo, policial, expira) VALUES ('prisao', ?, ?, ?, ?)",
        { cid, motivo:sub(1, 250), P.Nome(src), os.time() + Config.mandados.validadePrisao })
    return true, 'Mandado de prisão emitido.'
end)

function P.MandadoPrisaoAutomatico(cid, motivo)
    MySQL.insert("INSERT INTO pa_policia_mandados (tipo, citizenid, motivo, policial, expira) VALUES ('prisao', ?, ?, 'Sistema', ?)",
        { cid, motivo, os.time() + Config.mandados.validadePrisao })
end

lib.callback.register('pa_policia:mdt:mandadoBusca', function(src, imovel, motivo)
    if not P.Pode(src, 'mandado') then return false, 'Só Sargento ou acima emite mandado.' end
    imovel = tonumber(imovel)
    if not imovel then return false, 'Informe o número do imóvel.' end
    if GetResourceState('pa_casas') ~= 'started' then return false, 'O sistema de casas não está ligado.' end
    local ok, msg = exports.pa_casas:emitirMandado(src, imovel)
    if not ok then return false, msg or 'Não foi possível emitir.' end
    MySQL.insert.await("INSERT INTO pa_policia_mandados (tipo, imovel, motivo, policial, expira) VALUES ('busca', ?, ?, ?, ?)",
        { imovel, P.Trim(tostring(motivo or '')):sub(1, 250), P.Nome(src), os.time() + Config.mandados.validadeBusca })
    return true, msg or 'Mandado de busca emitido (está no seu inventário).'
end)

lib.callback.register('pa_policia:mdt:mandados', function(src)
    if not P.EmServico(src) then return {} end
    local rows = MySQL.query.await(
        'SELECT id, tipo, citizenid, imovel, motivo, policial, expira FROM pa_policia_mandados WHERE ativo = 1 AND expira > ? ORDER BY id DESC LIMIT 60',
        { os.time() }) or {}
    for _, r in ipairs(rows) do
        r.nome = r.citizenid and P.NomeCid(r.citizenid) or nil
        r.expira = dataBR(r.expira)
    end
    return rows
end)

lib.callback.register('pa_policia:mdt:encerrarMandado', function(src, id)
    if not P.Pode(src, 'mandado') then return false, 'Só Sargento ou acima.' end
    MySQL.update.await('UPDATE pa_policia_mandados SET ativo = 0 WHERE id = ?', { id })
    return true, 'Mandado encerrado.'
end)

---------------------------------------------------------------------
-- VEÍCULOS / PLACAS
---------------------------------------------------------------------
function P.PlacaProcurada(plate)
    return placasProcuradas[P.Trim(plate)]
end

local function enviarPlacas(alvo)
    TriggerClientEvent('pa_policia:client:placas', alvo, placasProcuradas)
end

AddEventHandler('pa_policia:server:bancoPronto', function()
    for _, r in ipairs(MySQL.query.await('SELECT plate, motivo FROM pa_policia_placas') or {}) do
        placasProcuradas[r.plate] = r.motivo
    end
end)

AddEventHandler('QBCore:Server:SetDuty', function(src, emServico)
    if emServico then enviarPlacas(src) end
end)

local function atualizarPlacas()
    local _, lista = P.PoliciaisEmServico()
    for _, s in ipairs(lista) do enviarPlacas(s) end
end

lib.callback.register('pa_policia:mdt:veiculo', function(src, plate)
    if not P.EmServico(src) then return nil end
    plate = P.Trim(tostring(plate or '')):upper()
    if #plate < 2 then return nil end
    local v = MySQL.single.await('SELECT citizenid, vehicle, state, garage, plate FROM player_vehicles WHERE plate = ?', { plate })
    local hist = MySQL.query.await('SELECT tipo, resultado, policial, criado FROM pa_policia_veiculos WHERE plate = ? ORDER BY id DESC LIMIT 20', { plate }) or {}
    for _, h in ipairs(hist) do h.criado = dataBR(h.criado) end
    local patio = MySQL.single.await('SELECT tipo, motivo, policial, criado FROM pa_policia_patio WHERE plate = ?', { plate })
    if patio then patio.criado = dataBR(patio.criado) end
    local laudo
    if GetResourceState('pa_dinamometro') == 'started' then
        local ok, r = pcall(MySQL.single.await, 'SELECT criado FROM pa_dinamometro WHERE plate = ? ORDER BY id DESC LIMIT 1', { plate })
        if ok and r then laudo = dataBR(r.criado) end
    end
    return {
        plate = plate,
        registrado = v ~= nil,
        modelo = v and v.vehicle or nil,
        dono = v and P.NomeCid(v.citizenid) or nil,
        donoCid = v and v.citizenid or nil,
        procurado = placasProcuradas[plate],
        historico = hist,
        patio = patio,
        laudo = laudo,
    }
end)

lib.callback.register('pa_policia:mdt:marcarPlaca', function(src, plate, motivo)
    if not P.Pode(src, 'marcarPlaca') then return false, 'Só Oficial 2 ou acima.' end
    plate = P.Trim(tostring(plate or '')):upper()
    if #plate < 2 then return false, 'Placa inválida.' end
    if placasProcuradas[plate] then
        placasProcuradas[plate] = nil
        MySQL.query.await('DELETE FROM pa_policia_placas WHERE plate = ?', { plate })
        atualizarPlacas()
        return true, 'Placa removida da lista de procurados.'
    end
    motivo = P.Trim(tostring(motivo or 'Procurado')):sub(1, 250)
    placasProcuradas[plate] = motivo
    MySQL.insert.await('INSERT INTO pa_policia_placas (plate, motivo, policial) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE motivo = VALUES(motivo)',
        { plate, motivo, P.Nome(src) })
    atualizarPlacas()
    return true, 'Placa marcada como procurada.'
end)

---------------------------------------------------------------------
-- BOLETINS DE OCORRÊNCIA
---------------------------------------------------------------------
lib.callback.register('pa_policia:mdt:bos', function(src, termo)
    if not P.EmServico(src) then return {} end
    termo = P.Trim(tostring(termo or ''))
    local rows
    if #termo > 0 then
        rows = MySQL.query.await('SELECT id, titulo, policial, criado FROM pa_policia_bos WHERE titulo LIKE ? OR envolvidos LIKE ? OR id = ? ORDER BY id DESC LIMIT 50',
            { '%' .. termo .. '%', '%' .. termo .. '%', tonumber(termo) or -1 })
    else
        rows = MySQL.query.await('SELECT id, titulo, policial, criado FROM pa_policia_bos ORDER BY id DESC LIMIT 50')
    end
    for _, r in ipairs(rows or {}) do r.criado = dataBR(r.criado) end
    return rows or {}
end)

lib.callback.register('pa_policia:mdt:bo', function(src, id)
    if not P.EmServico(src) then return nil end
    local r = MySQL.single.await('SELECT * FROM pa_policia_bos WHERE id = ?', { id })
    if not r then return nil end
    r.criado = dataBR(r.criado)
    r.envolvidos = r.envolvidos and json.decode(r.envolvidos) or {}
    r.pericias = r.pericias and json.decode(r.pericias) or {}
    local laudos = {}
    for _, pid in ipairs(r.pericias) do
        local l = MySQL.single.await('SELECT id, tipo, resultado FROM pa_policia_pericias WHERE id = ?', { tonumber(pid) })
        if l then laudos[#laudos + 1] = l end
    end
    r.laudos = laudos
    return r
end)

lib.callback.register('pa_policia:mdt:criarBo', function(src, dados)
    if not P.Pode(src, 'bo') then return false, 'Só Oficial 1 ou acima registra BO.' end
    if type(dados) ~= 'table' then return false, 'Dados inválidos.' end
    local titulo = P.Trim(tostring(dados.titulo or ''))
    if #titulo < 3 then return false, 'Escreva um título.' end
    local envolvidos = {}
    for _, cid in ipairs(type(dados.envolvidos) == 'table' and dados.envolvidos or {}) do
        cid = tostring(cid):upper()
        if MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ?', { cid }) then
            envolvidos[#envolvidos + 1] = { cid = cid, nome = P.NomeCid(cid) }
        end
    end
    local pericias = {}
    for pid in tostring(dados.pericias or ''):gmatch('%d+') do pericias[#pericias + 1] = tonumber(pid) end
    local id = MySQL.insert.await(
        'INSERT INTO pa_policia_bos (titulo, descricao, envolvidos, apreensoes, pericias, policial, policial_cid) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { titulo:sub(1, 150), tostring(dados.descricao or ''):sub(1, 6000), json.encode(envolvidos),
          tostring(dados.apreensoes or ''):sub(1, 2000), json.encode(pericias), P.Nome(src), P.Cid(src) })
    return true, ('BO #%d registrado.'):format(id), id
end)

---------------------------------------------------------------------
-- CÓDIGO PENAL (Chefe)
---------------------------------------------------------------------
lib.callback.register('pa_policia:mdt:salvarArtigo', function(src, a)
    if not P.Pode(src, 'codigoPenal') then return false, 'Só o Chefe edita o código penal.' end
    if type(a) ~= 'table' then return false end
    local id = P.Trim(tostring(a.id or '')):upper():sub(1, 10)
    local titulo = P.Trim(tostring(a.titulo or '')):sub(1, 150)
    if #id < 1 or #titulo < 3 then return false, 'Preencha código e título.' end
    local multa = math.max(0, math.floor(tonumber(a.multa) or 0))
    local meses = math.max(0, math.min(Config.prisao.maxMeses, math.floor(tonumber(a.meses) or 0)))
    MySQL.insert.await([[INSERT INTO pa_policia_codigo (id, titulo, multa, meses, removido) VALUES (?, ?, ?, ?, 0)
        ON DUPLICATE KEY UPDATE titulo = VALUES(titulo), multa = VALUES(multa), meses = VALUES(meses), removido = 0]],
        { id, titulo, multa, meses })
    codigoCache = nil
    return true, 'Artigo salvo.', P.Codigo()
end)

lib.callback.register('pa_policia:mdt:removerArtigo', function(src, id)
    if not P.Pode(src, 'codigoPenal') then return false, 'Só o Chefe edita o código penal.' end
    id = tostring(id):upper():sub(1, 10)
    MySQL.insert.await([[INSERT INTO pa_policia_codigo (id, titulo, removido) VALUES (?, '-', 1)
        ON DUPLICATE KEY UPDATE removido = 1]], { id })
    codigoCache = nil
    return true, 'Artigo removido.', P.Codigo()
end)

---------------------------------------------------------------------
-- EQUIPE (Diretor e Chefe) e CAIXA
---------------------------------------------------------------------
local function grauDeCid(cid)
    for _, m in ipairs(exports.qbx_core:GetGroupMembers(Config.job, 'job') or {}) do
        if m.citizenid == cid then return m.grade end
    end
end

lib.callback.register('pa_policia:mdt:equipe', function(src)
    if not P.EmServico(src) then return nil end
    local lista = {}
    for _, m in ipairs(exports.qbx_core:GetGroupMembers(Config.job, 'job') or {}) do
        local online = exports.qbx_core:GetPlayerByCitizenId(m.citizenid)
        lista[#lista + 1] = {
            cid = m.citizenid,
            nome = P.NomeCid(m.citizenid),
            grau = m.grade,
            patente = P.Patente(m.grade),
            online = online ~= nil,
            servico = online and online.PlayerData.job.name == Config.job and online.PlayerData.job.onduty or false,
        }
    end
    table.sort(lista, function(a, b) return a.grau == b.grau and a.nome < b.nome or a.grau > b.grau end)
    local saldo
    if P.Pode(src, 'caixa') and Config.contaSociedade and GetResourceState('Renewed-Banking') == 'started' then
        local ok, v = pcall(function() return exports['Renewed-Banking']:getAccountMoney(Config.contaSociedade) end)
        if ok then saldo = v end
    end
    return { membros = lista, saldo = saldo }
end)

lib.callback.register('pa_policia:mdt:contratar', function(src, alvo)
    if not P.Pode(src, 'contratar') then return false, 'Só Diretor ou Chefe contrata.' end
    alvo = tonumber(alvo)
    if not alvo or not P.Player(alvo) then return false, 'Jogador não encontrado (use o ID do servidor).' end
    if P.Grau(alvo) then return false, 'Essa pessoa já é da LSPD.' end
    exports.qbx_core:SetJob(alvo, Config.job, 0)
    exports.qbx_core:SetJobDuty(alvo, false)
    P.Notify(alvo, ('Bem-vindo(a) à LSPD como %s! Bata o ponto na DP de Mission Row.'):format(P.Patente(0)), 'success', 10000)
    return true, ('%s contratado(a) como %s.'):format(P.Nome(alvo), P.Patente(0))
end)

lib.callback.register('pa_policia:mdt:setGrau', function(src, cid, grau)
    if not P.Pode(src, 'contratar') then return false, 'Só Diretor ou Chefe.' end
    grau = math.floor(tonumber(grau) or -1)
    local meu = P.Grau(src)
    if cid == P.Cid(src) then return false, 'Você não pode mudar a própria patente.' end
    local atual = grauDeCid(cid)
    if not atual then return false, 'Não é membro da LSPD.' end
    if atual >= meu then return false, 'Você só mexe em patentes abaixo da sua.' end
    if not Config.patentes[grau] then return false, 'Patente inválida.' end
    if grau > (Config.promoverAte[meu] or -1) then
        return false, ('Você promove até %s.'):format(P.Patente(Config.promoverAte[meu]))
    end
    exports.qbx_core:AddPlayerToJob(cid, Config.job, grau)
    local online = exports.qbx_core:GetPlayerByCitizenId(cid)
    if online then
        P.Notify(online.PlayerData.source, ('Sua patente agora é %s.'):format(P.Patente(grau)), grau > atual and 'success' or 'inform')
    end
    return true, ('%s agora é %s.'):format(P.NomeCid(cid), P.Patente(grau))
end)

lib.callback.register('pa_policia:mdt:demitir', function(src, cid)
    if not P.Pode(src, 'contratar') then return false, 'Só Diretor ou Chefe.' end
    if cid == P.Cid(src) then return false, 'Você não pode se demitir por aqui.' end
    local atual = grauDeCid(cid)
    if not atual then return false, 'Não é membro da LSPD.' end
    if atual >= P.Grau(src) then return false, 'Você só demite patentes abaixo da sua.' end
    exports.qbx_core:RemovePlayerFromJob(cid, Config.job)
    local online = exports.qbx_core:GetPlayerByCitizenId(cid)
    if online then P.Notify(online.PlayerData.source, 'Você foi desligado(a) da LSPD.', 'error', 10000) end
    return true, ('%s foi desligado(a).'):format(P.NomeCid(cid))
end)

lib.callback.register('pa_policia:mdt:caixa', function(src, acao, valor)
    if not P.Pode(src, 'caixa') then return false, 'Só o Chefe mexe no caixa.' end
    if not Config.contaSociedade or GetResourceState('Renewed-Banking') ~= 'started' then return false, 'Renewed-Banking desligado.' end
    valor = math.floor(tonumber(valor) or 0)
    if valor <= 0 then return false, 'Valor inválido.' end
    local p = P.Player(src)
    if acao == 'sacar' then
        local ok, tirou = pcall(function() return exports['Renewed-Banking']:removeAccountMoney(Config.contaSociedade, valor) end)
        if not ok or not tirou then return false, 'Saldo insuficiente no caixa.' end
        p.Functions.AddMoney('bank', valor, 'caixa-lspd')
        return true, ('Sacou $%d do caixa da LSPD.'):format(valor)
    elseif acao == 'depositar' then
        if not p.Functions.RemoveMoney('bank', valor, 'caixa-lspd') then return false, 'Saldo insuficiente no seu banco.' end
        P.Sociedade(valor)
        return true, ('Depositou $%d no caixa da LSPD.'):format(valor)
    end
    return false
end)

---------------------------------------------------------------------
-- LISTAS (apreensões e perícias)
---------------------------------------------------------------------
lib.callback.register('pa_policia:mdt:apreensoes', function(src)
    if not P.EmServico(src) then return {} end
    local rows = MySQL.query.await('SELECT id, nome, itens, policial, criado FROM pa_policia_apreensoes ORDER BY id DESC LIMIT 50') or {}
    for _, r in ipairs(rows) do r.criado = dataBR(r.criado); r.itens = r.itens and json.decode(r.itens) or {} end
    return rows
end)

lib.callback.register('pa_policia:mdt:pericias', function(src)
    if not P.EmServico(src) then return {} end
    local rows = MySQL.query.await('SELECT id, tipo, resultado, policial, criado FROM pa_policia_pericias ORDER BY id DESC LIMIT 50') or {}
    for _, r in ipairs(rows) do r.criado = dataBR(r.criado) end
    return rows
end)
