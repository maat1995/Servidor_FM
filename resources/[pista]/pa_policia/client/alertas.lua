-- pa_policia · cliente · central de alertas
-- Recebe as ocorrências (área aproximada no mapa), assume com Y, /ocorrencias e botão de pânico.

local alertas = {}       -- [id] = { area, centro, pos, assumido, dados }
local ultimoPendente     -- { id, expira }

local CORES = { baixa = 3, media = 5, alta = 1, maxima = 1 }

local function nomeDaArea(c)
    local zona = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    if not zona or zona == 'NULL' or zona == '' then zona = 'Los Santos' end
    local rua = GetStreetNameFromHashKey(GetStreetNameAtCoord(c.x, c.y, c.z))
    if rua and rua ~= '' then return ('%s, %s'):format(rua, zona) end
    return zona
end
PC.NomeDaArea = nomeDaArea

local rotaAtiva -- id da ocorrência com rota no GPS

local function tirarRota()
    if rotaAtiva and alertas[rotaAtiva] and DoesBlipExist(alertas[rotaAtiva].centro) then
        SetBlipRoute(alertas[rotaAtiva].centro, false)
    end
    rotaAtiva = nil
end

local function remover(id)
    local a = alertas[id]
    if not a then return end
    if rotaAtiva == id then tirarRota() end
    if a.area and DoesBlipExist(a.area) then RemoveBlip(a.area) end
    if a.centro and DoesBlipExist(a.centro) then RemoveBlip(a.centro) end
    alertas[id] = nil
    if ultimoPendente and ultimoPendente.id == id then ultimoPendente = nil end
    SendNUIMessage({ acao = 'cardRemover', id = id })
end

local function limparTodos()
    for id in pairs(alertas) do remover(id) end
end
AddEventHandler('pa_policia:client:saiuServico', limparTodos)

local function assumir(id)
    local ok, centro = lib.callback.await('pa_policia:server:assumir', false, id)
    if not ok then return PC.Aviso(('A ocorrência #%s não existe mais.'):format(id), 'error') end
    local a = alertas[id]
    tirarRota()
    if a then
        a.assumido = true
        SetBlipColour(a.centro, 2)
        SetBlipFlashes(a.centro, false)
        if a.area then SetBlipColour(a.area, 2) end
        if Config.alertas.rota then
            SetBlipRoute(a.centro, true)
            SetBlipRouteColour(a.centro, 2)
            rotaAtiva = id
        end
    end
    if not a or not Config.alertas.rota then SetNewWaypoint(centro.x, centro.y) end
    SendNUIMessage({ acao = 'cardAssumido', id = id, eu = true })
    PlaySoundFrontend(-1, 'Menu_Accept', 'Phone_SoundSet_Default', true)
end
PC.AssumirOcorrencia = assumir

RegisterNetEvent('pa_policia:client:alerta', function(d)
    if GetInvokingResource() then return end
    if not PC.EmServico() then return end
    remover(d.id)

    local c = d.centro
    local area
    if d.raio and d.raio > 0 then
        area = AddBlipForRadius(c.x, c.y, c.z, d.raio)
        SetBlipColour(area, CORES[d.prioridade] or 5)
        SetBlipAlpha(area, 100)
        SetBlipHighDetail(area, true)
    end
    local centro = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(centro, d.sprite or 161)
    SetBlipColour(centro, CORES[d.prioridade] or 5)
    SetBlipScale(centro, d.prioridade == 'maxima' and 1.2 or 0.9)
    SetBlipAsShortRange(centro, false)
    -- alta e máxima piscam no mapa até alguém assumir
    if d.prioridade == 'alta' or d.prioridade == 'maxima' then SetBlipFlashes(centro, true) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s #%s · %s'):format(d.codigo, d.id, d.titulo))
    EndTextCommandSetBlipName(centro)

    local assumidos = d.policiais or {}
    alertas[d.id] = { area = area, centro = centro, pos = c, assumido = #assumidos > 0, dados = d }
    ultimoPendente = { id = d.id, expira = GetGameTimer() + Config.alertas.tempoAceitar * 1000 }

    local zona = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    if not zona or zona == 'NULL' or zona == '' then zona = 'Los Santos' end
    local rua = GetStreetNameFromHashKey(GetStreetNameAtCoord(c.x, c.y, c.z))
    SendNUIMessage({
        acao = 'cardNovo',
        card = {
            id = d.id, codigo = d.codigo, titulo = d.titulo, descricao = d.descricao,
            prioridade = d.prioridade, rua = rua ~= '' and rua or nil, zona = zona,
            exato = not d.raio or d.raio <= 0,
            distancia = math.floor(#(GetEntityCoords(cache.ped) - vec3(c.x, c.y, c.z))),
            tecla = Config.alertas.teclaAceitar,
            duracao = Config.alertas.tempoAceitar,
            policiais = assumidos,
            som = d.som ~= false and Config.alertas.som,
            max = Config.alertas.maxCards,
        },
    })
end)

-- distância ao vivo nos cards
CreateThread(function()
    while true do
        Wait(1000)
        if next(alertas) then
            local pos = GetEntityCoords(cache.ped)
            local dist = {}
            for id, a in pairs(alertas) do
                dist[#dist + 1] = { id = id, d = math.floor(#(pos - vec3(a.pos.x, a.pos.y, a.pos.z))) }
            end
            SendNUIMessage({ acao = 'cardDistancias', lista = dist })
            -- chegou na área: desliga a rota
            if rotaAtiva and alertas[rotaAtiva] then
                local a = alertas[rotaAtiva]
                local raio = (a.dados.raio or 0) > 0 and a.dados.raio * 0.5 or 25.0
                if #(pos - vec3(a.pos.x, a.pos.y, a.pos.z)) < raio then tirarRota() end
            end
        end
    end
end)

RegisterNetEvent('pa_policia:client:ocorrenciaAssumida', function(id, nome, quem)
    if GetInvokingResource() then return end
    if quem == cache.serverId then return end
    if ultimoPendente and ultimoPendente.id == id then ultimoPendente = nil end
    local a = alertas[id]
    if a and not a.assumido then
        a.assumido = true
        SetBlipColour(a.centro, 40)
        SetBlipFlashes(a.centro, false)
        if a.area then SetBlipAlpha(a.area, 50) end
    end
    SendNUIMessage({ acao = 'cardAssumido', id = id, nome = nome })
end)

RegisterNetEvent('pa_policia:client:fecharOcorrencia', function(id)
    if GetInvokingResource() then return end
    remover(id)
end)

lib.addKeybind({
    name = 'pa_policia_assumir',
    description = 'LSPD: assumir a ocorrência que acabou de chegar',
    defaultKey = Config.alertas.teclaAceitar,
    onPressed = function()
        if not ultimoPendente or GetGameTimer() > ultimoPendente.expira then return end
        if not PC.EmServico() then return end
        local id = ultimoPendente.id
        ultimoPendente = nil
        assumir(id)
    end,
})

-- /ocorrencias fica no painel (client/painel.lua)

---------------------------------------------------------------------
-- PÂNICO
---------------------------------------------------------------------
RegisterCommand('panico', function()
    if not PC.EmServico() then return end
    local ok, msg = lib.callback.await('pa_policia:server:panico', false)
    if ok then
        PC.Aviso('PÂNICO ENVIADO! Toda a LSPD recebeu sua posição.', 'error', 6000)
    elseif msg then
        PC.Aviso(msg, 'error')
    end
end, false)

lib.addKeybind({
    name = 'pa_policia_panico',
    description = 'LSPD: botão de pânico',
    defaultKey = Config.panico.tecla or '',
    onPressed = function() ExecuteCommand('panico') end,
})
