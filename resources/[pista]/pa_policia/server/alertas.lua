-- pa_policia · servidor · central de alertas e ocorrências
-- Todo script manda o alerta por exports.pa_policia:alerta({...}).
-- O policial vê uma ÁREA aproximada (círculo), não o ponto exato, a não ser que o alerta seja "exato".

local ocorrencias = {}
local proxId = 0
local ultimoPanico = {}
local ultimaLigacao = {}

local PRIORIDADES = { baixa = 1, media = 2, alta = 3, maxima = 4 }

local function deslocar(c, raio)
    local ang = math.random() * math.pi * 2
    local dist = math.sqrt(math.random()) * raio
    return vec3(c.x + math.cos(ang) * dist, c.y + math.sin(ang) * dist, c.z)
end

local function publico(o)
    local assumidos = {}
    for _, nome in pairs(o.policiais) do assumidos[#assumidos + 1] = nome end
    return {
        id = o.id, codigo = o.codigo, titulo = o.titulo, descricao = o.descricao,
        centro = o.centro, raio = o.raio, prioridade = o.prioridade, sprite = o.sprite,
        criado = o.criado, policiais = assumidos, som = o.som,
    }
end

local function fechar(id, motivo)
    local o = ocorrencias[id]
    if not o then return end
    ocorrencias[id] = nil
    local _, lista = P.PoliciaisEmServico()
    for _, s in ipairs(lista) do
        TriggerClientEvent('pa_policia:client:fecharOcorrencia', s, id, motivo)
    end
end

--- Cria um alerta para a polícia.
--- dados = { codigo, titulo, descricao, coords, raio, exato, prioridade ('baixa'|'media'|'alta'|'maxima'), sprite, duracao, som }
function P.Alerta(dados)
    if type(dados) ~= 'table' or not dados.coords then return nil end
    local c = dados.coords
    c = vec3(c.x + 0.0, c.y + 0.0, (c.z or 0.0) + 0.0)

    proxId += 1
    local raio = dados.exato and 0.0 or (tonumber(dados.raio) or Config.alertas.raioPadrao)
    local o = {
        id = proxId,
        codigo = tostring(dados.codigo or '10-00'),
        titulo = tostring(dados.titulo or 'Ocorrência'),
        descricao = dados.descricao and tostring(dados.descricao) or nil,
        real = c,
        centro = raio > 0 and deslocar(c, raio * 0.7) or c,
        raio = raio,
        prioridade = PRIORIDADES[dados.prioridade] and dados.prioridade or 'media',
        sprite = tonumber(dados.sprite) or 161,
        som = dados.som ~= false,
        criado = os.time(),
        policiais = {},
    }
    ocorrencias[o.id] = o

    local _, lista = P.PoliciaisEmServico()
    local pub = publico(o)
    for _, s in ipairs(lista) do
        TriggerClientEvent('pa_policia:client:alerta', s, pub)
    end

    local dur = tonumber(dados.duracao) or Config.alertas.duracao
    SetTimeout(dur * 1000, function()
        if ocorrencias[o.id] then fechar(o.id, 'expirou') end
    end)
    return o.id
end

exports('alerta', P.Alerta)
exports('fecharAlerta', function(id) fechar(id, 'fechado') end)

-- Compatibilidade com scripts que chamavam o qbx_police
RegisterNetEvent('police:server:policeAlert', function(texto)
    local src = source
    P.Alerta({ codigo = '10-90', titulo = tostring(texto or 'Ocorrência'):sub(1, 80), coords = P.Coords(src), raio = 80.0 })
end)

---------------------------------------------------------------------
-- CALLBACKS DO POLICIAL
---------------------------------------------------------------------
lib.callback.register('pa_policia:server:assumir', function(src, id)
    if not P.Pode(src, 'servico') then return false end
    local o = ocorrencias[id]
    if not o then return false end
    o.policiais[src] = P.Nome(src)
    local _, lista = P.PoliciaisEmServico()
    for _, s in ipairs(lista) do
        TriggerClientEvent('pa_policia:client:ocorrenciaAssumida', s, id, P.Nome(src), src)
    end
    return true, o.centro
end)

lib.callback.register('pa_policia:server:encerrar', function(src, id)
    local o = ocorrencias[id]
    if not o then return false end
    if not o.policiais[src] and not P.Pode(src, 'mandado') then
        return false, 'Só quem assumiu (ou Sargento+) encerra a ocorrência.'
    end
    fechar(id, 'encerrada')
    return true
end)

function P.ListarOcorrencias()
    local lista = {}
    for _, o in pairs(ocorrencias) do lista[#lista + 1] = publico(o) end
    table.sort(lista, function(a, b) return a.id > b.id end)
    return lista
end

lib.callback.register('pa_policia:server:ocorrencias', function(src)
    if not P.Pode(src, 'servico') then return {} end
    return P.ListarOcorrencias()
end)

-- Painel do policial (F6)
lib.callback.register('pa_policia:server:painel', function(src)
    local p = P.Player(src)
    if not p or p.PlayerData.job.name ~= Config.job then return nil end
    local grau = P.Grau(src)
    local perms = {}
    for acao, min in pairs(Config.permissoes) do perms[acao] = grau >= min end
    local distintivo = p.PlayerData.metadata.callsign
    return {
        nome = P.Nome(src),
        patente = P.Patente(grau),
        distintivo = distintivo ~= 'NO CALLSIGN' and distintivo or nil,
        servico = p.PlayerData.job.onduty == true,
        colegas = (P.PoliciaisEmServico()),
        ocorrencias = p.PlayerData.job.onduty and P.ListarOcorrencias() or {},
        perms = perms,
    }
end)

-- Quem entra em serviço recebe as ocorrências abertas
AddEventHandler('QBCore:Server:SetDuty', function(src, emServico)
    if not emServico or not P.EmServico(src) then return end
    for _, o in pairs(ocorrencias) do
        local pub = publico(o)
        pub.som = false
        TriggerClientEvent('pa_policia:client:alerta', src, pub)
    end
end)

---------------------------------------------------------------------
-- BOTÃO DE PÂNICO
---------------------------------------------------------------------
lib.callback.register('pa_policia:server:panico', function(src)
    if not P.EmServico(src) then return false, 'Só policiais em serviço.' end
    local espera = Config.panico.espera - (os.time() - (ultimoPanico[src] or 0))
    if espera > 0 then return false, ('Aguarde %d s para apertar de novo.'):format(espera) end
    ultimoPanico[src] = os.time()

    local p = P.Player(src)
    local distintivo = p.PlayerData.metadata.callsign
    P.Alerta({
        codigo = '10-99',
        titulo = ('PÂNICO · %s %s'):format(P.Patente(P.Grau(src)), P.Nome(src)),
        descricao = distintivo and distintivo ~= 'NO CALLSIGN' and ('Distintivo %s'):format(distintivo) or nil,
        coords = P.Coords(src),
        exato = true,
        prioridade = 'maxima',
        sprite = 526,
        duracao = 600,
    })

    if Config.panico.avisarSamu and GetResourceState('pa_medico') == 'started' then
        local ok, desmaiado = pcall(function() return exports.pa_medico:EstaDesmaiado(src) end)
        if ok and desmaiado then
            pcall(function() exports.pa_medico:ChamarSamu(src) end)
        end
    end
    return true
end)

---------------------------------------------------------------------
-- CELULAR (NPWD): 190
---------------------------------------------------------------------
local function aoLigar(ctx)
    local src = ctx.incomingCaller.source
    local responder = function(msg) pcall(ctx.reply, msg) end

    local espera = Config.telefone.espera - (os.time() - (ultimaLigacao[src] or 0))
    if espera > 0 then
        responder(('190: sua ligação já foi registrada. Ligue de novo em %d s.'):format(espera))
        return ctx.exit()
    end

    if P.PoliciaisEmServico() == 0 then
        responder('190: no momento não há viaturas disponíveis.')
        return ctx.exit()
    end

    ultimaLigacao[src] = os.time()
    P.Alerta({
        codigo = '10-90',
        titulo = 'Ligação para o 190',
        descricao = ('Telefone de %s'):format(P.Nome(src)),
        coords = P.Coords(src),
        raio = Config.telefone.raio,
        prioridade = 'media',
        sprite = 459,
    })
    responder('190: ocorrência registrada. Uma viatura foi avisada da sua região.')
    return ctx.exit()
end

local function registrarTelefone()
    if not Config.telefone.ativo or GetResourceState('npwd') ~= 'started' then return end
    local ok, erro = pcall(function()
        exports.npwd:onCall(Config.telefone.numero, aoLigar)
    end)
    if not ok then lib.print.warn(('Falha ao registrar o %s no NPWD: %s'):format(Config.telefone.numero, erro)) end
end

AddEventHandler('onResourceStart', function(res)
    if res == 'npwd' then
        SetTimeout(2000, registrarTelefone)
    elseif res == GetCurrentResourceName() then
        registrarTelefone()
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    ultimoPanico[src] = nil
    ultimaLigacao[src] = nil
    for _, o in pairs(ocorrencias) do o.policiais[src] = nil end
end)
