-- pa_medico · cliente do médico
-- Recebe os chamados com a ÁREA aproximada do corpo, assume com Y ou pelo /chamados
-- e reanima/trata pelo olho (ox_target) usando o kit do qbx_ambulancejob.

local alertas = {}       -- [id] = { area, centro, pos, assumido }
local ultimoPendente     -- { id, expira }

local function emServico()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.type == Config.tipoEmprego and job.onduty
end

local function nomeDaArea(c)
    local zona = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    if not zona or zona == 'NULL' or zona == '' then zona = 'Los Santos' end
    return zona
end

local function removerAlerta(id)
    local a = alertas[id]
    if not a then return end
    if DoesBlipExist(a.area) then RemoveBlip(a.area) end
    if DoesBlipExist(a.centro) then RemoveBlip(a.centro) end
    alertas[id] = nil
    if ultimoPendente and ultimoPendente.id == id then ultimoPendente = nil end
end

local function limparTodos()
    for id in pairs(alertas) do removerAlerta(id) end
end

local function corAlerta(id, cor)
    local a = alertas[id]
    if not a then return end
    SetBlipColour(a.area, cor)
    SetBlipColour(a.centro, cor)
end

local function aceitar(id)
    local ok, centro = lib.callback.await('pa_medico:server:aceitar', false, id)
    if not ok then
        lib.notify({ type = 'error', description = ('O chamado #%s não está mais livre.'):format(id) })
        return
    end
    if alertas[id] then alertas[id].assumido = true end
    corAlerta(id, 2)
    SetNewWaypoint(centro.x, centro.y)
    lib.notify({ type = 'success', description = Config.textos.voceAssumiu:format(id) })
end

RegisterNetEvent('pa_medico:client:alerta', function(dados)
    if GetInvokingResource() then return end
    if not emServico() then return end

    local c = dados.centro
    local area = AddBlipForRadius(c.x, c.y, c.z, Config.alerta.raio)
    SetBlipColour(area, 1)
    SetBlipAlpha(area, 110)
    SetBlipHighDetail(area, true)

    local centro = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(centro, 153)
    SetBlipColour(centro, 1)
    SetBlipScale(centro, 0.85)
    SetBlipAsShortRange(centro, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('SAMU #%s'):format(dados.id))
    EndTextCommandSetBlipName(centro)

    alertas[dados.id] = { area = area, centro = centro, pos = c, assumido = false }
    ultimoPendente = { id = dados.id, expira = GetGameTimer() + Config.alerta.tempoAceitar * 1000 }

    if Config.alerta.som then
        PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', false)
    end

    local titulo = dados.origem == 'telefone' and Config.textos.alertaTelefone or Config.textos.alertaTitulo
    lib.notify({
        id = 'pa_medico_alerta_' .. dados.id,
        title = ('%s #%s'):format(titulo, dados.id),
        description = ('Região: %s\n%s'):format(nomeDaArea(c),
            Config.textos.alertaAceitar:format(Config.alerta.teclaAceitar, Config.alerta.tempoAceitar)),
        type = 'error',
        icon = 'truck-medical',
        duration = Config.alerta.tempoAceitar * 1000,
        position = 'top-right',
    })
end)

RegisterNetEvent('pa_medico:client:chamadoAssumido', function(id, nome, medicoSrc)
    if GetInvokingResource() then return end
    if medicoSrc == cache.serverId then return end
    if ultimoPendente and ultimoPendente.id == id then ultimoPendente = nil end
    if alertas[id] then
        alertas[id].assumido = true
        corAlerta(id, 40)
        SetBlipAlpha(alertas[id].area, 60)
    end
    lib.notify({ type = 'inform', description = Config.textos.assumido:format(id, nome) })
end)

RegisterNetEvent('pa_medico:client:fecharAlerta', function(id, motivo)
    if GetInvokingResource() then return end
    local a = alertas[id]
    if not a then return end
    if a.assumido and motivo == 'atendido' then
        lib.notify({ type = 'success', description = Config.textos.pacienteAcordou:format(id) })
    end
    removerAlerta(id)
end)

-- Y: assume o último chamado que chegou (enquanto o aviso está na tela)
lib.addKeybind({
    name = 'pa_medico_aceitar',
    description = 'SAMU: assumir o chamado que acabou de chegar',
    defaultKey = Config.alerta.teclaAceitar,
    onPressed = function()
        if not ultimoPendente or GetGameTimer() > ultimoPendente.expira then return end
        if not emServico() then return end
        local id = ultimoPendente.id
        ultimoPendente = nil
        aceitar(id)
    end,
})

-- /chamados: lista de chamados abertos
local function abrirChamados()
    if not emServico() then
        return lib.notify({ type = 'error', description = 'Você não está em serviço no SAMU.' })
    end
    local lista = lib.callback.await('pa_medico:server:listar', false)
    local opcoes = {}
    for _, c in ipairs(lista) do
        local situacao = c.meu and 'Assumido por você' or (c.medico and ('Assumido por ' .. c.medico) or 'Livre')
        opcoes[#opcoes + 1] = {
            title = ('#%s · %s'):format(c.id, nomeDaArea(c.centro)),
            description = ('%s · %s · há %s min'):format(
                c.origem == 'telefone' and 'Telefone' or 'Desmaio', situacao, c.minutos),
            icon = c.medico and 'user-doctor' or 'truck-medical',
            iconColor = c.medico and '#97C459' or '#E24B4A',
            onSelect = function()
                if not c.medico then
                    aceitar(c.id)
                else
                    SetNewWaypoint(c.centro.x, c.centro.y)
                    lib.notify({ type = 'inform', description = 'GPS marcado na área do chamado.' })
                end
            end,
        }
    end
    if #opcoes == 0 then
        opcoes[1] = { title = 'Nenhum chamado aberto', disabled = true, icon = 'check' }
    end
    lib.registerContext({ id = 'pa_medico_chamados', title = 'Chamados do SAMU', options = opcoes })
    lib.showContext('pa_medico_chamados')
end

RegisterCommand('chamados', abrirChamados, false)
TriggerEvent('chat:addSuggestion', '/chamados', 'SAMU: lista de chamados abertos')

-- Saiu de serviço ou trocou de emprego: some com os chamados do mapa
RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    if not duty then limparTodos() end
end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    SetTimeout(500, function() if not emServico() then limparTodos() end end)
end)

---------------------------------------------------------------------
-- OLHO (ox_target) EM QUEM ESTÁ DESMAIADO
---------------------------------------------------------------------
CreateThread(function()
    if GetResourceState('ox_target') ~= 'started' then return end
    local function alvoDesmaiado(entidade)
        local id = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entidade))
        return id and id > 0 and Player(id).state.isDead
    end
    exports.ox_target:addGlobalPlayer({
        {
            name = 'pa_medico_reanimar',
            icon = 'fas fa-heart-pulse',
            label = 'Reanimar (kit de primeiros socorros)',
            distance = 2.0,
            canInteract = function(entidade)
                return emServico() and alvoDesmaiado(entidade)
            end,
            onSelect = function()
                TriggerEvent('hospital:client:RevivePlayer')
            end,
        },
        {
            name = 'pa_medico_tratar',
            icon = 'fas fa-bandage',
            label = 'Tratar ferimentos (bandagem)',
            distance = 2.0,
            canInteract = function(entidade)
                return emServico() and not alvoDesmaiado(entidade)
            end,
            onSelect = function()
                TriggerEvent('hospital:client:TreatWounds')
            end,
        },
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    limparTodos()
end)
