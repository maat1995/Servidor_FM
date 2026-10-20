-- pa_roubocarro · servidor · duplas, contratos, roubo, rastreador e entrega

local grupos = {}        -- [lider] = { lider = src, parceiro = src|nil }
local grupoDe = {}       -- [src] = lider
local convites = {}      -- [convidado] = { de = src, expira = os.time() }
local contratos = {}     -- [id] = contrato
local contratoDe = {}    -- [src] = id
local espera = {}        -- [citizenid] = os.time() liberado
local proxId = 0

---------------------------------------------------------------------
-- DUPLA
---------------------------------------------------------------------
function RC.Membros(src)
    local lider = grupoDe[src]
    local g = lider and grupos[lider]
    if not g then return { src } end
    local lista = { g.lider }
    if g.parceiro then lista[2] = g.parceiro end
    return lista
end

function RC.Grupo(src)
    local lider = grupoDe[src]
    return lider and grupos[lider] or nil
end

function RC.Convidar(src, alvo)
    alvo = tonumber(alvo)
    if not alvo or alvo == src or not RC.Player(alvo) then return false, 'Jogador não encontrado.' end
    if contratoDe[src] then return false, 'Termine o contrato atual antes.' end
    local g = RC.Grupo(src)
    if g and g.lider ~= src then return false, 'Só quem montou a dupla convida.' end
    if g and g.parceiro then return false, 'Sua dupla já está completa.' end
    if grupoDe[alvo] then return false, 'Esse jogador já está numa dupla.' end
    if exports.ox_inventory:Search(alvo, 'count', Config.itemTablet) < 1 then
        return false, 'Ele precisa ter um tablet de roubo.'
    end
    convites[alvo] = { de = src, expira = os.time() + Config.dupla.tempoConvite }
    TriggerClientEvent('pa_roubocarro:client:convite', alvo, RC.Nome(src), Config.dupla.tempoConvite)
    return true, ('Convite enviado para %s.'):format(RC.Nome(alvo))
end

function RC.Aceitar(src)
    local c = convites[src]
    convites[src] = nil
    if not c or c.expira < os.time() then return false, 'Nenhum convite válido.' end
    local de = c.de
    if not RC.Player(de) then return false, 'Quem convidou saiu.' end
    if contratoDe[de] then return false, 'Ele já começou um contrato.' end
    if grupoDe[src] then return false, 'Você já está numa dupla.' end
    local g = grupos[de]
    if not g then
        g = { lider = de }
        grupos[de] = g
        grupoDe[de] = de
    end
    if g.parceiro then return false, 'A dupla já está completa.' end
    g.parceiro = src
    grupoDe[src] = de
    RC.Notificar(de, ('%s entrou na sua dupla.'):format(RC.Nome(src)), 'success')
    RC.AtualizarTablet(de)
    return true, ('Você entrou na dupla de %s.'):format(RC.Nome(de))
end

function RC.SairDupla(src)
    local g = RC.Grupo(src)
    if not g then return false, 'Você não está numa dupla.' end
    local outro = g.lider == src and g.parceiro or g.lider
    grupos[g.lider] = nil
    grupoDe[g.lider] = nil
    if g.parceiro then grupoDe[g.parceiro] = nil end

    -- contrato em andamento continua só com quem ficou
    local id = contratoDe[src]
    local ct = id and contratos[id]
    if ct then
        contratoDe[src] = nil
        for i, m in ipairs(ct.membros) do
            if m == src then table.remove(ct.membros, i) break end
        end
        TriggerClientEvent('pa_roubocarro:client:fimContrato', src, 'Você saiu da dupla.')
        if #ct.membros == 0 then RC.Encerrar(id, nil) end
    end

    if outro then
        RC.Notificar(outro, ('%s saiu da dupla.'):format(RC.Nome(src)), 'error')
        RC.AtualizarTablet(outro)
    end
    return true, 'Você saiu da dupla.'
end

---------------------------------------------------------------------
-- CONTRATO: dados para o cliente
---------------------------------------------------------------------
local function publico(ct, src)
    local c = Config.classes[ct.classe]
    local raio = ct.raio
    local parceiro
    for _, m in ipairs(ct.membros) do
        if m ~= src then parceiro = RC.Nome(m) end
    end
    return {
        id = ct.id,
        classe = ct.classe,
        label = c.label,
        modo = ct.modo,
        modelo = ct.modelo,
        modelos = ct.modo == 'rua' and c.modelos or nil,
        area = ct.area and { x = ct.area.x, y = ct.area.y, z = ct.area.z, raio = raio } or nil,
        alvoNet = ct.alvoNet,
        localNet = ct.localNet,
        pego = ct.pego,
        entrega = ct.pego and ct.entrega or nil,
        rastreador = ct.rastreadorAtivo,
        restante = math.max(0, ct.fim - os.time()),
        parceiro = parceiro,
    }
end

function RC.ContratoPublico(src)
    local id = contratoDe[src]
    return id and contratos[id] and publico(contratos[id], src) or nil
end

local function enviar(ct)
    for _, m in ipairs(ct.membros) do
        TriggerClientEvent('pa_roubocarro:client:contrato', m, publico(ct, m))
    end
end

---------------------------------------------------------------------
-- CONTRATO: pedir
---------------------------------------------------------------------
local function deslocar(c, raio)
    local ang = math.random() * math.pi * 2
    local dist = math.sqrt(math.random()) * raio * 0.75
    return vec3(c.x + math.cos(ang) * dist, c.y + math.sin(ang) * dist, c.z)
end

local function esperarEntidade(ent, ms)
    local fim = GetGameTimer() + (ms or 3000)
    while not DoesEntityExist(ent) and GetGameTimer() < fim do Wait(50) end
    return DoesEntityExist(ent)
end

local function spawnarCarroLocal(classe, modelo)
    local lista = Config.locais[classe]
    if not lista or #lista == 0 then return nil end
    -- evita usar um ponto que já tem carro de contrato
    local ocupados = {}
    for _, ct in pairs(contratos) do
        if ct.pontoLocal then ocupados[ct.pontoLocal] = true end
    end
    local livres = {}
    for i = 1, #lista do if not ocupados[lista[i]] then livres[#livres + 1] = lista[i] end end
    if #livres == 0 then return nil end
    local p = livres[math.random(#livres)]

    local veh = CreateVehicleServerSetter(joaat(modelo), 'automobile', p.x, p.y, p.z + 0.3, p.w)
    if not esperarEntidade(veh) then return nil end
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleNumberPlateText(veh, RC.GerarPlaca())
    Entity(veh).state:set('pa_roubocarro', true, true)
    return veh, p
end

function RC.PedirContrato(src, classe)
    if contratoDe[src] then return false, 'Você já tem um contrato.' end
    local g = RC.Grupo(src)
    if g and g.lider ~= src then return false, 'Quem pede o contrato é quem montou a dupla.' end

    local d, cid = RC.Dados(src)
    if not d then return false end
    local nivel = RC.Nivel(d.xp)
    local c = Config.classes[classe]
    if not c then return false, 'Classe inválida.' end
    if c.niveis[1] > nivel then return false, ('Classe %s libera no nível %d.'):format(classe, c.niveis[1]) end

    local membros = RC.Membros(src)
    for _, m in ipairs(membros) do
        local mcid = RC.Cid(m)
        if espera[mcid] and espera[mcid] > os.time() then
            local min = math.ceil((espera[mcid] - os.time()) / 60)
            return false, (m == src and 'Aguarde %d min para outro contrato.' or 'Seu parceiro precisa aguardar %d min.'):format(min)
        end
        if contratoDe[m] then return false, 'Seu parceiro já está num contrato.' end
    end

    if RC.PoliciaisEmServico() < c.policiaMin then
        return false, 'Sem encomendas dessa classe agora. Tente mais tarde.'
    end

    proxId += 1
    local extra = RC.Melhoria(src, 'tempo')
    local ct = {
        id = proxId,
        classe = classe,
        modo = c.modo,
        lider = src,
        membros = membros,
        inicio = os.time(),
        fim = os.time() + (c.tempo + extra) * 60,
        pego = false,
        alarmou = false,
    }

    if c.modo == 'local' then
        local modelo = c.modelos[math.random(#c.modelos)]
        local veh, ponto = spawnarCarroLocal(classe, modelo)
        if not veh then return false, 'Nenhum carro dessa classe disponível agora.' end
        ct.modelo = modelo
        ct.veh = veh
        ct.localNet = NetworkGetNetworkIdFromEntity(veh)
        ct.pontoLocal = ponto
        ct.real = vec3(ponto.x, ponto.y, ponto.z)
        ct.raio = Config.area.raio * RC.Melhoria(src, 'area')
        ct.area = deslocar(ct.real, ct.raio)
    end

    contratos[ct.id] = ct
    for _, m in ipairs(membros) do contratoDe[m] = ct.id end
    enviar(ct)

    local texto = c.modo == 'rua'
        and ('Encomenda: qualquer carro da %s. Pegue um na rua e leve ao ponto de entrega.'):format(c.label)
        or ('Encomenda: %s. Está estacionado na área marcada no GPS.'):format(ct.modelo:upper())
    for _, m in ipairs(membros) do RC.Notificar(m, texto, 'inform') end
    return true
end

---------------------------------------------------------------------
-- CONTRATO: encerrar
---------------------------------------------------------------------
function RC.Encerrar(id, motivo, falhou)
    local ct = contratos[id]
    if not ct then return end
    contratos[id] = nil
    RC.FecharAlerta(ct.alertaId)

    -- carro do contrato que ninguém pegou some
    if ct.veh and not ct.pego and DoesEntityExist(ct.veh) then DeleteEntity(ct.veh) end
    if ct.veh and ct.pego and DoesEntityExist(ct.veh) then
        Entity(ct.veh).state:set('pa_roubocarro', nil, true)
    end

    for _, m in ipairs(ct.membros) do
        contratoDe[m] = nil
        local cid = RC.Cid(m)
        if cid and falhou ~= nil then
            espera[cid] = os.time() + (falhou and Config.espera.falhou or Config.espera.entregou)
        end
        TriggerClientEvent('pa_roubocarro:client:fimContrato', m, motivo)
    end
end

function RC.Cancelar(src)
    local id = contratoDe[src]
    if not id then return false, 'Sem contrato ativo.' end
    local ct = contratos[id]
    if ct.lider ~= src and #ct.membros > 1 then return false, 'Só quem pediu pode cancelar.' end
    RC.Encerrar(id, 'Contrato cancelado.', true)
    return true
end

---------------------------------------------------------------------
-- ROUBO
---------------------------------------------------------------------
local function veiculoDe(net)
    local veh = NetworkGetEntityFromNetworkId(tonumber(net) or 0)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil end
    return veh
end

local function alertar(ct, veh, real)
    local c = Config.classes[ct.classe]
    local nome = 'Veículo'
    local modelo = RC.ModeloDoHash(GetEntityModel(veh))
    if modelo then nome = modelo.modelo:upper() end
    local placa = RC.Trim(GetVehicleNumberPlateText(veh))
    RC.FecharAlerta(ct.alertaId)
    ct.alertaId = RC.Alerta({
        codigo = Config.policia.codigo,
        titulo = Config.policia.titulo,
        descricao = ('%s · placa %s · %s. Padrão de roubo sob encomenda.'):format(nome, placa, c.label),
        coords = real or GetEntityCoords(veh),
        raio = Config.policia.raio,
        prioridade = Config.policia.prioridade[ct.classe],
        sprite = Config.policia.sprite,
    })
end

local function podeMexer(src, veh, ct)
    if #(GetEntityCoords(veh) - RC.Coords(src)) > 6.0 then return false, 'Chegue mais perto do carro.' end
    if ct.modo == 'local' then
        if veh ~= ct.veh then return false, 'Esse não é o carro da encomenda.' end
    else
        local m = RC.ModeloDoHash(GetEntityModel(veh))
        if not m or m.classe ~= ct.classe then return false, 'Esse carro não serve para a encomenda.' end
        local placa = RC.Trim(GetVehicleNumberPlateText(veh))
        if MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { placa }) then
            return false, 'Carro de jogador não entra na encomenda.'
        end
    end
    return true
end

--- Arrombar: o cliente já fez o minigame. sucesso = acertou
lib.callback.register('pa_roubocarro:server:arrombar', function(src, net, sucesso)
    local id = contratoDe[src]
    local ct = id and contratos[id]
    if not ct then return false, 'Sem contrato ativo.' end
    local veh = veiculoDe(net)
    if not veh then return false, 'Carro não encontrado.' end
    local ok, msg = podeMexer(src, veh, ct)
    if not ok then return false, msg end

    local ferramenta
    for _, f in ipairs(Config.ferramentas) do
        if exports.ox_inventory:Search(src, 'count', f) > 0 then ferramenta = f break end
    end
    if not ferramenta then return false, 'Você precisa de uma lockpick.' end

    if not sucesso then
        if math.random() < RC.Melhoria(src, 'lockpick') then
            exports.ox_inventory:RemoveItem(src, ferramenta, 1)
            return false, 'A ferramenta quebrou.'
        end
        return false, 'Não deu. Tente de novo.'
    end

    SetVehicleDoorsLocked(veh, 1)
    RC.DarChaves(src, veh)
    local c = Config.classes[ct.classe]
    if not ct.alarmou and math.random() < c.alarme then
        ct.alarmou = true
        TriggerClientEvent('pa_roubocarro:client:alarme', -1, NetworkGetNetworkIdFromEntity(veh))
        alertar(ct, veh)
    end
    return true
end)

--- Entrou no banco do motorista de um carro válido
lib.callback.register('pa_roubocarro:server:pegou', function(src, net)
    local id = contratoDe[src]
    local ct = id and contratos[id]
    if not ct or ct.pego then return false end
    local veh = veiculoDe(net)
    if not veh or GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return false end
    local ok = podeMexer(src, veh, ct)
    if not ok then return false end

    ct.pego = true
    ct.veh = veh
    ct.alvoNet = NetworkGetNetworkIdFromEntity(veh)
    Entity(veh).state:set('pa_roubocarro', ct.id, true)
    RC.DarChaves(src, veh)
    for _, m in ipairs(ct.membros) do
        if m ~= src then RC.DarChaves(m, veh) end
    end

    -- entrega: prefere o ponto mais longe de onde o carro foi pego
    local pos = GetEntityCoords(veh)
    local melhor, dist = nil, -1
    for _, e in ipairs(Config.entregas) do
        local dd = #(pos - e) + math.random() * 800.0
        if dd > dist then melhor, dist = e, dd end
    end
    ct.entrega = { x = melhor.x, y = melhor.y, z = melhor.z }
    ct.pontoEntrega = melhor

    local c = Config.classes[ct.classe]
    -- roubo na rua sem arrombar (tirou o motorista, carro aberto): ainda pode ter alarme/denúncia
    if not ct.alarmou and math.random() < c.alarme then
        ct.alarmou = true
        alertar(ct, veh)
    end
    if c.rastreador then ct.rastreadorAtivo = true end

    enviar(ct)
    for _, m in ipairs(ct.membros) do
        RC.Notificar(m, c.rastreador and 'Carro pego! Ele tem rastreador: desligue pelo tablet.' or 'Carro pego! Leve ao ponto de entrega.', 'success')
    end
    return true
end)

--- Desligar o rastreador (minigame feito no cliente)
lib.callback.register('pa_roubocarro:server:rastreador', function(src, sucesso)
    local id = contratoDe[src]
    local ct = id and contratos[id]
    if not ct or not ct.rastreadorAtivo then return false, 'Nada para desligar.' end
    if not ct.veh or GetVehiclePedIsIn(GetPlayerPed(src), false) ~= ct.veh then
        return false, 'Você precisa estar dentro do carro.'
    end
    if not sucesso then return false, 'Falhou. O rastreador continua ligado.' end
    ct.rastreadorAtivo = false
    RC.FecharAlerta(ct.alertaId)
    ct.alertaId = nil
    enviar(ct)
    return true, 'Rastreador desligado.'
end)

function RC.EtapasRastreador(src)
    return RC.Melhoria(src, 'rastreador')
end

---------------------------------------------------------------------
-- ENTREGA
---------------------------------------------------------------------
local function saudeDoCarro(veh)
    local motor = math.max(0.0, GetVehicleEngineHealth(veh)) / 10.0
    local lataria = math.max(0.0, GetVehicleBodyHealth(veh)) / 10.0
    return math.floor(math.min(100.0, (motor + lataria) / 2))
end

lib.callback.register('pa_roubocarro:server:entregar', function(src, props)
    local id = contratoDe[src]
    local ct = id and contratos[id]
    if not ct or not ct.pego then return false, 'Sem carro para entregar.' end
    local veh = ct.veh
    if not veh or not DoesEntityExist(veh) then return false, 'O carro sumiu.' end
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return false, 'Você precisa estar dirigindo o carro.' end
    if #(GetEntityCoords(veh) - ct.pontoEntrega) > Config.raioEntrega + 2.0 then return false, 'Fora do ponto de entrega.' end
    if ct.rastreadorAtivo then return false, 'O comprador não aceita carro com rastreador ligado.' end

    local c = Config.classes[ct.classe]
    local saude = saudeDoCarro(veh)
    local mult = 1.0
    if saude < Config.danoSemDesconto then
        mult = math.max(Config.pagamentoMinimo, saude / Config.danoSemDesconto)
    end
    local xp = math.floor(c.xp * mult)
    local moedas = math.floor(c.moedas * mult)

    -- divisão: solo leva tudo; dupla 70% para quem entregou e 30% para o parceiro
    local solo = #ct.membros == 1
    for _, m in ipairs(ct.membros) do
        if RC.Player(m) then
            local parte = solo and 1.0 or (m == src and Config.dupla.entregou or Config.dupla.parceiro)
            RC.Recompensar(m, math.floor(xp * parte), math.floor(moedas * parte))
        end
    end

    -- oferta: quem entregou pode comprar o carro com chassi riscado (24h)
    local cid = RC.Cid(src)
    local modelo = ct.modelo or (RC.ModeloDoHash(GetEntityModel(veh)) or {}).modelo
    if cid and modelo and type(props) == 'table' then
        props.plate = nil
        MySQL.insert('INSERT INTO pa_roubocarro_ofertas (citizenid, modelo, classe, preco, props, expira) VALUES (?, ?, ?, ?, ?, ?)',
            { cid, modelo, ct.classe, c.precoCarro, json.encode(props), os.time() + 86400 })
    end

    TaskLeaveVehicle(GetPlayerPed(src), veh, 0)
    SetTimeout(2500, function()
        if DoesEntityExist(veh) then DeleteEntity(veh) end
    end)
    ct.veh = nil
    RC.Encerrar(id, ('Carro entregue (%d%% de estado). Ele ficou disponível no tablet por 24h.'):format(saude), false)
    return true
end)

---------------------------------------------------------------------
-- VIGIA: tempo, carro perdido e rastreador
---------------------------------------------------------------------
CreateThread(function()
    local ultimoRastreio = 0
    while true do
        Wait(5000)
        local agora = os.time()
        local rastrear = agora - ultimoRastreio >= Config.rastreador.intervalo
        if rastrear then ultimoRastreio = agora end

        for id, ct in pairs(contratos) do
            if agora >= ct.fim then
                RC.Encerrar(id, 'O tempo da encomenda acabou.', true)
            elseif ct.veh and not DoesEntityExist(ct.veh) then
                RC.Encerrar(id, ct.pego and 'O carro da encomenda foi perdido.' or 'O carro da encomenda não está mais lá.', ct.pego)
            elseif ct.pego and GetVehicleEngineHealth(ct.veh) <= 0.0 then
                RC.Encerrar(id, 'O carro da encomenda foi destruído.', true)
            elseif ct.rastreadorAtivo and rastrear then
                local c = Config.classes[ct.classe]
                local modelo = (ct.modelo or ''):upper()
                RC.FecharAlerta(ct.alertaId)
                ct.alertaId = RC.Alerta({
                    codigo = Config.policia.codigo,
                    titulo = ('Rastreador: %s'):format(modelo ~= '' and modelo or 'veículo roubado'),
                    descricao = ('Placa %s · %s. Sinal do rastreador do carro.'):format(RC.Trim(GetVehicleNumberPlateText(ct.veh)), c.label),
                    coords = GetEntityCoords(ct.veh),
                    raio = Config.rastreador.raio,
                    prioridade = Config.policia.prioridade[ct.classe],
                    sprite = Config.policia.sprite,
                    som = false,
                    duracao = Config.rastreador.intervalo + 10,
                })
            end
        end
    end
end)

---------------------------------------------------------------------
-- SAÍDA DO JOGADOR
---------------------------------------------------------------------
local function saiu(src)
    convites[src] = nil
    if grupoDe[src] then RC.SairDupla(src) end
    local id = contratoDe[src]
    if id and contratos[id] then
        local ct = contratos[id]
        contratoDe[src] = nil
        for i, m in ipairs(ct.membros) do
            if m == src then table.remove(ct.membros, i) break end
        end
        if #ct.membros == 0 then RC.Encerrar(id, nil, true) end
    end
end

AddEventHandler('playerDropped', function() saiu(source) end)
AddEventHandler('qbx_core:server:playerLoggedOut', saiu)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ct in pairs(contratos) do
        RC.FecharAlerta(ct.alertaId)
        if ct.veh and not ct.pego and DoesEntityExist(ct.veh) then DeleteEntity(ct.veh) end
    end
end)

--- Aceitar o convite pelo aviso (tecla) também funciona
RegisterNetEvent('pa_roubocarro:server:aceitarConvite', function()
    local src = source
    local ok, msg = RC.Aceitar(src)
    RC.Notificar(src, msg, ok and 'success' or 'error')
    if ok then RC.AtualizarTablet(src) end
end)
