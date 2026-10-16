-- pa_medico · cliente do paciente
-- Tela de desmaio, tecla G para chamar o SAMU e segurar E para acordar no hospital.

local BAG = 'qbx_medical:deathState'
local VIVO, CAIDO, MORTO = 1, 2, 3

local estadoAtual = LocalPlayer.state[BAG] or VIVO
local rodando = false

-- Informações mostradas na tela (lidas também pelo npc.lua)
Desmaio = {
    fim = 0,             -- GetGameTimer() em que o tempo acaba
    status = nil,        -- texto de status (chamado, médico a caminho, ambulância...)
    npc = false,
    progressoNpc = nil,  -- 0..1 durante a massagem cardíaca
}

local function desmaiado()
    return estadoAtual == CAIDO or estadoAtual == MORTO
end

function EstaDesmaiado() return desmaiado() end

local function nui(dados)
    SendNUIMessage(dados)
end

local function sincronizar()
    local info = lib.callback.await('pa_medico:server:estado', false)
    if not info then return end
    Desmaio.fim = GetGameTimer() + info.restante * 1000
    Desmaio.npc = info.npc
    if info.npc then
        Desmaio.status = Config.textos.ambulanciaNpc
    elseif info.medico then
        Desmaio.status = Config.textos.medicoACaminho:format(info.medico)
    elseif info.chamou then
        Desmaio.status = Config.textos.chamado
    end
end

local function respostaChamado(ok, tipo, extra)
    if ok and tipo == 'medico' then
        Desmaio.status = Config.textos.chamado
    elseif ok and tipo == 'npc' then
        Desmaio.status = Config.textos.ambulanciaNpc
        Desmaio.npc = true
    elseif tipo == 'espera' then
        lib.notify({ type = 'error', description = Config.textos.esperaChamado:format(extra) })
    elseif tipo == 'semEquipe' then
        lib.notify({ type = 'error', description = Config.textos.semEquipe })
    end
end

local function chamar()
    respostaChamado(lib.callback.await('pa_medico:server:chamar', false))
end

RegisterNetEvent('pa_medico:client:chamouPeloCelular', function(ok, tipo, extra)
    if GetInvokingResource() then return end
    respostaChamado(ok, tipo, extra)
end)

RegisterNetEvent('pa_medico:client:medicoACaminho', function(nome)
    if GetInvokingResource() then return end
    if not desmaiado() then return end
    Desmaio.status = Config.textos.medicoACaminho:format(nome)
    lib.notify({ type = 'success', description = Desmaio.status })
end)

---------------------------------------------------------------------
-- ACORDAR NO HOSPITAL
---------------------------------------------------------------------
local acordando = false

local function acordarNoHospital()
    if acordando then return end
    acordando = true

    if not lib.callback.await('pa_medico:server:podeAcordar', false) then
        sincronizar()
        acordando = false
        return
    end

    -- O hospital do qbx_medical só funciona no estado "morto"; se ainda estiver caído, passa para morto
    if exports.qbx_medical:IsLaststand() then
        SetEntityHealth(cache.ped, 0)
        local limite = GetGameTimer() + 5000
        while not exports.qbx_medical:IsDead() and GetGameTimer() < limite do Wait(100) end
    end

    exports.qbx_medical:AllowRespawn()
    local ok = lib.callback.await('qbx_medical:server:respawn', false)
    if ok then
        if QBX.PlayerData.metadata and QBX.PlayerData.metadata.ishandcuffed then
            TriggerEvent('police:client:GetCuffed', -1)
        end
        TriggerEvent('police:client:DeEscort')
        LocalPlayer.state.invBusy = false
    else
        exports.qbx_medical:DisableRespawn()
    end
    acordando = false
end

---------------------------------------------------------------------
-- LAÇO ENQUANTO DESMAIADO
---------------------------------------------------------------------
local function laco()
    if rodando then return end
    rodando = true

    -- Quem decide quando pode ir para o hospital é o pa_medico
    exports.qbx_medical:DisableRespawn()
    Desmaio.status, Desmaio.npc, Desmaio.progressoNpc = nil, false, nil
    Desmaio.fim = GetGameTimer() + Config.tempoDesmaiado * 1000
    sincronizar()

    nui({ acao = 'mostrar', titulo = Config.textos.desmaiado })

    local segurando = 0
    local ultimoEnvio = 0
    local ultimaSync = GetGameTimer()

    while desmaiado() do
        local agora = GetGameTimer()
        local restante = math.max(0, math.ceil((Desmaio.fim - agora) / 1000))
        local liberado = restante <= 0 and not Desmaio.npc

        -- G: chamar o SAMU
        if not Desmaio.npc and (IsControlJustPressed(0, Config.teclas.chamar) or IsDisabledControlJustPressed(0, Config.teclas.chamar)) then
            CreateThread(chamar)
        end

        -- E: acordar no hospital (só depois do tempo)
        local apertandoE = IsControlPressed(0, Config.teclas.hospital) or IsDisabledControlPressed(0, Config.teclas.hospital)
        if liberado and apertandoE and not acordando then
            segurando += GetFrameTime()
            if segurando >= Config.segurarHospital then
                segurando = 0
                CreateThread(acordarNoHospital)
            end
        else
            segurando = 0
        end

        if agora - ultimoEnvio > 100 then
            ultimoEnvio = agora
            nui({
                acao = 'atualizar',
                restante = restante,
                liberado = liberado,
                segurando = liberado and (segurando / Config.segurarHospital) or 0,
                status = Desmaio.status,
                npc = Desmaio.npc,
                rcp = Desmaio.progressoNpc,
                podeChamar = not Desmaio.npc,
                textos = {
                    chamar = Config.textos.chamar,
                    hospital = Config.textos.acordarHospital,
                    aguardar = Config.textos.aguardarTempo,
                },
            })
        end

        -- Ressincroniza o relógio de vez em quando (o servidor é quem manda)
        if agora - ultimaSync > 30000 then
            ultimaSync = agora
            CreateThread(sincronizar)
        end

        Wait(0)
    end

    nui({ acao = 'esconder' })
    Desmaio.status, Desmaio.npc, Desmaio.progressoNpc = nil, false, nil
    exports.qbx_medical:AllowRespawn()
    if CancelarAmbulanciaNpc then CancelarAmbulanciaNpc() end
    rodando = false
end

AddStateBagChangeHandler(BAG, ('player:%s'):format(cache.serverId), function(_, _, valor)
    estadoAtual = valor
    if desmaiado() then CreateThread(laco) end
end)

RegisterNetEvent('pa_medico:client:npcDespachado', function()
    if GetInvokingResource() then return end
    Desmaio.npc = true
    Desmaio.status = Config.textos.ambulanciaNpc
    IniciarAmbulanciaNpc()
end)

-- Reinício do recurso no meio de um desmaio
CreateThread(function()
    estadoAtual = LocalPlayer.state[BAG] or VIVO
    if desmaiado() then laco() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if desmaiado() then exports.qbx_medical:AllowRespawn() end
end)

exports('EstaDesmaiado', EstaDesmaiado)
