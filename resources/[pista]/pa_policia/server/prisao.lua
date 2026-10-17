-- pa_policia · servidor · prisão (Bolingbroke)
-- A pena corre só com o preso on-line. Trabalhos reduzem a pena. Saiu da área = fuga.

local presos = {}          -- [src] = { cid, restante (segundos), total (meses) }
local recargaTrabalho = {} -- [src] = { [ponto] = os.time() }

local function segundosDe(meses)
    return math.floor(meses * Config.prisao.minutosPorMes * 60)
end

local function salvar(src)
    local p = presos[src]
    if not p then return end
    MySQL.update('UPDATE pa_policia_presos SET restante = ? WHERE citizenid = ?', { math.max(0, p.restante), p.cid })
end

local function mandarParaPrisao(src, restante, primeiraVez)
    local entradas = Config.prisao.entrada
    TriggerClientEvent('pa_policia:client:preso', src, {
        restante = restante,
        entrada = entradas[math.random(#entradas)],
        primeiraVez = primeiraVez,
    })
end

--- Manda o jogador para a prisão por X meses (policial = source de quem prendeu, ou nil)
function P.Prender(alvo, meses, policial)
    local cid = P.Cid(alvo)
    if not cid then return false end
    meses = math.max(1, math.min(Config.prisao.maxMeses, math.floor(meses)))
    local seg = segundosDe(meses)

    -- ilegais vão para o depósito; o resto fica guardado e volta na saída
    P.Apreender(policial, alvo)
    exports.ox_inventory:ConfiscateInventory(alvo)
    P.SetAlgema(alvo, nil)

    MySQL.insert.await('INSERT INTO pa_policia_presos (citizenid, restante, total) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE restante = VALUES(restante), total = VALUES(total)',
        { cid, seg, meses })
    exports.qbx_core:SetMetadata(alvo, 'injail', meses)
    presos[alvo] = { cid = cid, restante = seg, total = meses }
    mandarParaPrisao(alvo, seg, true)
    P.Notify(alvo, ('Você foi condenado(a) a %d meses. Seus pertences ficam guardados até a saída.'):format(meses), 'error', 10000)
    return true
end
exports('prender', function(alvo, meses) return P.Prender(alvo, meses, nil) end)

local function soltar(src, motivo)
    local p = presos[src]
    presos[src] = nil
    recargaTrabalho[src] = nil
    if p then MySQL.query.await('DELETE FROM pa_policia_presos WHERE citizenid = ?', { p.cid }) end
    exports.qbx_core:SetMetadata(src, 'injail', 0)
    exports.ox_inventory:ReturnInventory(src)
    TriggerClientEvent('pa_policia:client:solto', src, motivo == 'fuga' and nil or Config.prisao.saida)
    if motivo == 'cumpriu' then
        P.Notify(src, 'Você cumpriu a pena. Seus pertences foram devolvidos.', 'success', 8000)
    elseif motivo == 'liberado' then
        P.Notify(src, 'Você foi liberado(a) pela LSPD. Seus pertences foram devolvidos.', 'success', 8000)
    end
end

function P.EstaPreso(src)
    return presos[src] ~= nil
end
exports('estaPreso', function(src) return presos[src] ~= nil end)

---------------------------------------------------------------------
-- RELÓGIO DA PENA
---------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(10000)
        for src, p in pairs(presos) do
            if not GetPlayerName(src) then
                presos[src] = nil
            else
                p.restante -= 10
                if p.restante <= 0 then
                    soltar(src, 'cumpriu')
                else
                    TriggerClientEvent('pa_policia:client:tempoPena', src, p.restante)
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        for src in pairs(presos) do salvar(src) end
    end
end)

-- Voltou ao jogo com pena: volta para Bolingbroke
local function verificarPreso(src)
    local cid = P.Cid(src)
    if not cid then return end
    local r = MySQL.single.await('SELECT restante, total FROM pa_policia_presos WHERE citizenid = ?', { cid })
    if not r then return end
    presos[src] = { cid = cid, restante = r.restante, total = r.total }
    if r.restante <= 0 then
        -- foi liberado pelo tablet enquanto estava off-line: devolve os pertences
        SetTimeout(4000, function() if presos[src] then soltar(src, 'liberado') end end)
        return
    end
    SetTimeout(4000, function()
        if presos[src] then mandarParaPrisao(src, r.restante, false) end
    end)
end

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    verificarPreso(source)
end)

AddEventHandler('pa_policia:server:bancoPronto', function()
    -- restart do script com gente presa on-line
    for _, p in pairs(exports.qbx_core:GetQBPlayers()) do
        verificarPreso(p.PlayerData.source)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    salvar(src)
    presos[src] = nil
    recargaTrabalho[src] = nil
end)

---------------------------------------------------------------------
-- TRABALHO NA PRISÃO
---------------------------------------------------------------------
lib.callback.register('pa_policia:server:trabalho', function(src, indice)
    local p = presos[src]
    if not p then return false end
    local ponto = Config.prisao.trabalho.pontos[tonumber(indice) or 0]
    if not ponto or P.Dist(src, ponto.coords) > 4.0 then return false, 'Longe demais.' end
    recargaTrabalho[src] = recargaTrabalho[src] or {}
    local ultimo = recargaTrabalho[src][indice] or 0
    local espera = math.ceil(Config.prisao.trabalho.tempo / 1000) * 3 - (os.time() - ultimo)
    if espera > 0 then return false, ('Esse serviço já foi feito. Tente outro ou volte em %d s.'):format(espera) end
    recargaTrabalho[src][indice] = os.time()
    p.restante = math.max(10, p.restante - segundosDe(Config.prisao.trabalho.reduzMeses))
    TriggerClientEvent('pa_policia:client:tempoPena', src, p.restante)
    return true, ('Pena reduzida. Faltam %d min.'):format(math.ceil(p.restante / 60))
end)

---------------------------------------------------------------------
-- FUGA
---------------------------------------------------------------------
lib.callback.register('pa_policia:server:fuga', function(src)
    local p = presos[src]
    if not p then return false end
    if P.Dist(src, Config.prisao.centro) <= Config.prisao.raio then return false end
    local nome = P.Nome(src)
    local cid = p.cid
    soltar(src, 'fuga')
    if Config.prisao.fuga.alerta then
        P.Alerta({
            codigo = '10-98', titulo = 'Fuga de Bolingbroke', descricao = ('%s fugiu da prisão'):format(nome),
            coords = Config.prisao.centro, raio = 250.0, prioridade = 'maxima', sprite = 188,
        })
    end
    if Config.prisao.fuga.mandadoAutomatico then
        P.MandadoPrisaoAutomatico(cid, 'Fuga do presídio de Bolingbroke')
    end
    return true
end)

---------------------------------------------------------------------
-- TABLET: soltar preso (Tenente+)
---------------------------------------------------------------------
lib.callback.register('pa_policia:mdt:soltarPreso', function(src, cid)
    if not P.Pode(src, 'cancelarMulta') then return false, 'Só Tenente ou acima libera preso.' end
    for s, p in pairs(presos) do
        if p.cid == cid then
            soltar(s, 'liberado')
            return true, 'Preso liberado.'
        end
    end
    local r = MySQL.update.await('UPDATE pa_policia_presos SET restante = 0 WHERE citizenid = ?', { cid })
    if r and r > 0 then
        return true, 'Pena encerrada. O cidadão está off-line: sai e recebe os pertences quando entrar.'
    end
    return false, 'Esse cidadão não está preso.'
end)

lib.callback.register('pa_policia:server:minhaPena', function(src)
    local p = presos[src]
    return p and p.restante or nil
end)
