-- pa_medico · atendimento do médico (cliente)
-- Médico: olho no paciente > "Atender paciente" abre a ficha com os procedimentos.
-- Paciente: recebe o resultado (vida, sangramento) mandado pelo servidor.

local A = Config.atendimento

local PROCEDIMENTOS = {
    reanimar = {
        titulo = 'Reanimar',
        icone = 'heart-pulse',
        rua = 'Desfibrilador + 1 adrenalina · acorda com %s%% de vida',
        hosp = 'Equipamento do hospital · acorda com %s%% de vida',
        barra = 'Reanimando',
        anim = { dict = 'mini@cpr@char_a@cpr_str', clip = 'cpr_pumpchest', flag = 1 },
        rcp = true,
    },
    bandagem = {
        titulo = 'Estancar sangramento',
        icone = 'bandage',
        rua = '1 bandagem · tira um nível de sangramento e +%s%% de vida',
        hosp = 'Material do hospital · tira um nível de sangramento',
        barra = 'Fazendo curativo',
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
    },
    trauma = {
        titulo = 'Tratamento na rua',
        icone = 'kit-medical',
        rua = '1 kit de trauma · vida até %s%%, ferimentos leves e moderados',
        barra = 'Tratando o paciente',
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
    },
    hospital = {
        titulo = 'Tratamento completo (hospital)',
        icone = 'hospital',
        hosp = 'Cura todos os ferimentos, inclusive graves · vida 100%',
        barra = 'Tratamento no hospital',
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
    },
}
local ORDEM = { 'reanimar', 'bandagem', 'trauma', 'hospital' }
local COR_NIVEL = { '#97C459', '#FAC775', '#EF9F27', '#E24B4A' }

local ocupado = false

local function emServico()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.type == Config.tipoEmprego and job.onduty
end

local function pedDoJogador(serverId)
    local idx = GetPlayerFromServerId(serverId)
    if idx == -1 then return nil end
    return GetPlayerPed(idx)
end

local function descricao(tipo, hospital)
    local p = PROCEDIMENTOS[tipo]
    if tipo == 'reanimar' then
        return hospital and p.hosp:format(A.hospital.reanimar.vida) or p.rua:format(A.reanimar.vida)
    elseif tipo == 'bandagem' then
        return hospital and p.hosp or p.rua:format(A.bandagem.vida)
    elseif tipo == 'trauma' then
        return p.rua:format(A.trauma.vida)
    end
    return p.hosp
end

---------------------------------------------------------------------
-- FAZER O PROCEDIMENTO
---------------------------------------------------------------------
local abrirFicha

local function fazer(alvo, tipo)
    if ocupado then return end
    local proc = PROCEDIMENTOS[tipo]
    local ok, duracao = lib.callback.await('pa_medico:server:iniciar', false, alvo, tipo)
    if not ok then
        return lib.notify({ type = 'error', description = duracao or 'Não deu para fazer agora.' })
    end

    ocupado = true
    local pedAlvo = pedDoJogador(alvo)
    if proc.rcp and pedAlvo then
        lib.requestAnimDict(proc.anim.dict)
        PosicionarParaRCP(cache.ped, pedAlvo)
    elseif pedAlvo then
        TaskTurnPedToFaceEntity(cache.ped, pedAlvo, 800)
        Wait(800)
    end

    local completou = lib.progressCircle({
        duration = duracao * 1000,
        label = proc.barra,
        position = 'bottom',
        canCancel = true,
        useWhileDead = false,
        disable = { move = true, car = true, combat = true },
        anim = proc.anim,
    })
    ClearPedTasks(cache.ped)

    if not completou then
        lib.callback.await('pa_medico:server:cancelar', false)
        lib.notify({ type = 'error', description = 'Procedimento cancelado.' })
        ocupado = false
        return
    end

    local feito, msg = lib.callback.await('pa_medico:server:concluir', false, alvo, tipo)
    ocupado = false
    lib.notify({ type = feito and 'success' or 'error', description = msg or (feito and 'Feito.' or 'Não deu certo.') })

    -- Reabre a ficha para o próximo passo do atendimento
    if feito then
        Wait(600)
        abrirFicha(alvo)
    end
end

---------------------------------------------------------------------
-- FICHA DO PACIENTE
---------------------------------------------------------------------
abrirFicha = function(alvo)
    if not emServico() then
        return lib.notify({ type = 'error', description = 'Você não está em serviço no SAMU.' })
    end
    local f = lib.callback.await('pa_medico:server:ficha', false, alvo)
    if not f then
        return lib.notify({ type = 'error', description = 'Não deu para examinar esse paciente.' })
    end

    local opcoes = {}

    -- Situação geral
    local estado = f.desmaiado and 'Desmaiado' or 'Consciente'
    opcoes[#opcoes + 1] = {
        title = ('%s · %s'):format(f.nome, estado),
        description = f.hospital and ('No hospital (%s)'):format(f.hospital) or 'Atendimento na rua',
        icon = f.desmaiado and 'bed-pulse' or 'user',
        iconColor = f.desmaiado and '#E24B4A' or '#97C459',
        progress = f.vida,
        colorScheme = f.vida >= 70 and 'green' or (f.vida >= 35 and 'yellow' or 'red'),
        metadata = {
            { label = 'Vida', value = ('%s%%'):format(f.vida) },
            { label = 'Sangramento', value = f.sangueTexto },
        },
        readOnly = true,
    }

    -- Ferimentos
    if #f.ferimentos == 0 then
        opcoes[#opcoes + 1] = { title = 'Sem ferimentos', icon = 'check', iconColor = '#97C459', readOnly = true }
    else
        local meta = {}
        for _, x in ipairs(f.ferimentos) do
            meta[#meta + 1] = { label = x.parte, value = x.texto }
        end
        opcoes[#opcoes + 1] = {
            title = ('Ferimentos (%s)'):format(#f.ferimentos),
            description = f.pior >= 3 and 'Tem ferimento grave: só o hospital trata' or 'Dá para tratar na rua',
            icon = 'user-injured',
            iconColor = COR_NIVEL[f.pior] or '#B4B2A9',
            metadata = meta,
            readOnly = true,
        }
    end

    -- Procedimentos
    for _, tipo in ipairs(ORDEM) do
        local p = PROCEDIMENTOS[tipo]
        local estadoProc = f.procedimentos[tipo]
        local mostrar = true
        -- Esconde o que não faz sentido agora
        if tipo == 'reanimar' and not f.desmaiado then mostrar = false end
        if tipo ~= 'reanimar' and f.desmaiado then mostrar = false end
        if tipo == 'trauma' and f.hospital then mostrar = false end
        if tipo == 'hospital' and not f.hospital then mostrar = false end
        if tipo == 'bandagem' and f.sangue <= 0 then mostrar = false end

        if mostrar then
            opcoes[#opcoes + 1] = {
                title = p.titulo,
                description = estadoProc.ok and descricao(tipo, f.hospital ~= nil) or estadoProc.motivo,
                icon = p.icone,
                iconColor = estadoProc.ok and '#85B7EB' or '#888780',
                disabled = not estadoProc.ok,
                onSelect = function() CreateThread(function() fazer(alvo, tipo) end) end,
            }
        end
    end

    lib.registerContext({ id = 'pa_medico_ficha', title = 'Ficha do paciente', options = opcoes })
    lib.showContext('pa_medico_ficha')
end

CreateThread(function()
    if GetResourceState('ox_target') ~= 'started' then return end
    exports.ox_target:addGlobalPlayer({
        {
            name = 'pa_medico_atender',
            icon = 'fas fa-user-doctor',
            label = 'Atender paciente',
            distance = A.distancia,
            canInteract = function() return emServico() and not ocupado end,
            onSelect = function(dados)
                local id = GetPlayerServerId(NetworkGetPlayerIndexFromPed(dados.entity))
                if id and id > 0 then abrirFicha(id) end
            end,
        },
    })
end)

---------------------------------------------------------------------
-- PACIENTE
---------------------------------------------------------------------
local NOMES = {
    reanimar = 'reanimação', bandagem = 'curativo', trauma = 'tratamento', hospital = 'tratamento completo',
}

RegisterNetEvent('pa_medico:client:sendoAtendido', function(medico, tipo)
    if GetInvokingResource() then return end
    lib.notify({
        id = 'pa_medico_atendido',
        type = 'inform',
        icon = 'user-doctor',
        description = ('%s está fazendo o %s.'):format(medico, NOMES[tipo] or 'atendimento'),
        duration = 6000,
    })
end)

RegisterNetEvent('pa_medico:client:atendimentoCancelado', function()
    if GetInvokingResource() then return end
    lib.notify({ id = 'pa_medico_atendido', type = 'error', description = 'O médico parou o atendimento.' })
end)

local function vidaAtualPct()
    local max = GetEntityMaxHealth(cache.ped)
    if max <= 100 then max = 200 end
    return (GetEntityHealth(cache.ped) - 100) / (max - 100) * 100, max
end

local function definirVidaPct(pct)
    local _, max = vidaAtualPct()
    pct = math.max(1, math.min(100, pct))
    SetEntityHealth(cache.ped, math.floor(100 + (max - 100) * pct / 100))
end

RegisterNetEvent('pa_medico:client:aplicar', function(d)
    if GetInvokingResource() then return end
    -- Depois de reanimar, espera o qbx_medical terminar de levantar o personagem
    if d.definir then Wait(600) end

    -- Reanimado na rua: devolve os ferimentos graves e o sangramento (só o hospital cura)
    if d.manter then
        for parte, ferida in pairs(d.manter.feridas or {}) do
            LocalPlayer.state:set('qbx_medical:injuries:' .. parte, ferida, true)
        end
        if (d.manter.sangue or 0) > 0 then
            LocalPlayer.state:set('qbx_medical:bleedLevel', d.manter.sangue, true)
        end
        if next(d.manter.feridas or {}) then
            Wait(100)
            pcall(function() exports.qbx_medical:MakePedLimp() end)
        end
    end

    if d.tirarSangue and d.tirarSangue > 0 then
        pcall(function() exports.qbx_medical:RemoveBleed(d.tirarSangue) end)
    end

    local atual = vidaAtualPct()
    if d.definir and d.vida then
        definirVidaPct(d.vida)
    elseif d.vidaMinima then
        if atual < d.vidaMinima then definirVidaPct(d.vidaMinima) end
    elseif d.somarVida then
        definirVidaPct(atual + d.somarVida)
    end
end)
