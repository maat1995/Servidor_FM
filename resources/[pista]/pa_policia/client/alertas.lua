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

local function remover(id)
    local a = alertas[id]
    if not a then return end
    if a.area and DoesBlipExist(a.area) then RemoveBlip(a.area) end
    if a.centro and DoesBlipExist(a.centro) then RemoveBlip(a.centro) end
    alertas[id] = nil
    if ultimoPendente and ultimoPendente.id == id then ultimoPendente = nil end
end

local function limparTodos()
    for id in pairs(alertas) do remover(id) end
end
AddEventHandler('pa_policia:client:saiuServico', limparTodos)

local function assumir(id)
    local ok, centro = lib.callback.await('pa_policia:server:assumir', false, id)
    if not ok then return PC.Aviso(('A ocorrência #%s não existe mais.'):format(id), 'error') end
    local a = alertas[id]
    if a then
        a.assumido = true
        SetBlipColour(a.centro, 2)
        if a.area then SetBlipColour(a.area, 2) end
    end
    SetNewWaypoint(centro.x, centro.y)
    PC.Aviso(('Você assumiu a ocorrência #%s. GPS marcado.'):format(id), 'success')
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
    if d.prioridade == 'maxima' then SetBlipFlashes(centro, true) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s #%s · %s'):format(d.codigo, d.id, d.titulo))
    EndTextCommandSetBlipName(centro)

    alertas[d.id] = { area = area, centro = centro, pos = c, assumido = #(d.policiais or {}) > 0, dados = d }
    ultimoPendente = { id = d.id, expira = GetGameTimer() + Config.alertas.tempoAceitar * 1000 }

    if d.som ~= false and Config.alertas.som then
        if d.prioridade == 'maxima' then
            PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
            PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
        else
            PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', false)
        end
    end

    local texto = ('%s\nRegião: %s\n[%s] assumir'):format(d.descricao or '', nomeDaArea(c), Config.alertas.teclaAceitar)
    lib.notify({
        id = 'pa_policia_alerta_' .. d.id,
        title = ('%s #%s · %s'):format(d.codigo, d.id, d.titulo),
        description = texto:gsub('^\n', ''),
        type = d.prioridade == 'baixa' and 'inform' or 'error',
        icon = d.prioridade == 'maxima' and 'triangle-exclamation' or 'tower-broadcast',
        duration = Config.alertas.tempoAceitar * 1000,
        position = 'top-right',
    })
end)

RegisterNetEvent('pa_policia:client:ocorrenciaAssumida', function(id, nome, quem)
    if GetInvokingResource() then return end
    if quem == cache.serverId then return end
    if ultimoPendente and ultimoPendente.id == id then ultimoPendente = nil end
    local a = alertas[id]
    if a and not a.assumido then
        a.assumido = true
        SetBlipColour(a.centro, 40)
        if a.area then SetBlipAlpha(a.area, 50) end
    end
    lib.notify({ type = 'inform', description = ('#%s assumida por %s.'):format(id, nome) })
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

---------------------------------------------------------------------
-- /ocorrencias
---------------------------------------------------------------------
RegisterCommand('ocorrencias', function()
    if not PC.EmServico() then return PC.Aviso('Só policiais em serviço.', 'error') end
    local lista = lib.callback.await('pa_policia:server:ocorrencias', false) or {}
    if #lista == 0 then return PC.Aviso('Nenhuma ocorrência aberta.', 'inform') end
    local opcoes = {}
    for _, o in ipairs(lista) do
        local quem = #o.policiais > 0 and ('Com: ' .. table.concat(o.policiais, ', ')) or 'Ninguém assumiu'
        opcoes[#opcoes + 1] = {
            title = ('%s #%s · %s'):format(o.codigo, o.id, o.titulo),
            description = ('%s · %s · há %d min'):format(nomeDaArea(o.centro), quem, math.floor((GetCloudTimeAsInt() - o.criado) / 60)),
            icon = o.prioridade == 'maxima' and 'triangle-exclamation' or 'tower-broadcast',
            iconColor = (o.prioridade == 'alta' or o.prioridade == 'maxima') and '#E24B4A' or nil,
            arrow = true,
            onSelect = function()
                lib.registerContext({
                    id = 'pa_policia_ocorrencia',
                    title = ('#%s · %s'):format(o.id, o.titulo),
                    menu = 'pa_policia_ocorrencias',
                    options = {
                        { title = 'Assumir e marcar GPS', icon = 'location-arrow', onSelect = function() assumir(o.id) end },
                        { title = 'Só marcar GPS', icon = 'map-pin', onSelect = function() SetNewWaypoint(o.centro.x, o.centro.y) end },
                        { title = 'Encerrar ocorrência', icon = 'check', onSelect = function()
                            local ok, msg = lib.callback.await('pa_policia:server:encerrar', false, o.id)
                            PC.Resultado(ok, ok and 'Ocorrência encerrada.' or msg)
                        end },
                    },
                })
                lib.showContext('pa_policia_ocorrencia')
            end,
        }
    end
    lib.registerContext({ id = 'pa_policia_ocorrencias', title = 'Ocorrências abertas', options = opcoes })
    lib.showContext('pa_policia_ocorrencias')
end, false)

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
