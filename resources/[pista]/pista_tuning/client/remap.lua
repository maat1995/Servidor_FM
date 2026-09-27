-- pista_tuning - notebook de remap (tela NUI)

local aberto = nil -- { veh, netId, dados }

local function fecharTela()
    SetNuiFocus(false, false)
    SendNUIMessage({ acao = 'fechar' })
end

local function previa(valores)
    local dados = aberto and aberto.dados or {}
    local remap = NormalizarRemap(valores, dados)
    local chip = Config.efeitos.chip[dados.chip] or {}
    local r = CalcularRemap(remap, dados)
    local risco = r.risco
    -- as regras fixas também pesam (stage 2+ sem intercooler, stage 3 sem pistão)
    for _, regra in ipairs(Config.risco.regras) do
        if (dados.chip or 0) >= regra.chipMinimo and not dados[regra.semPeca] then
            risco = math.min(100.0, risco + regra.dano * 3.0)
        end
    end
    return {
        remap = remap,
        forca = (chip.forca or 0) + r.forca,
        vmax = (chip.vmax or 0) + r.vmax,
        giro = (chip.giro or 0) + r.giro,
        risco = risco,
    }
end

exports('usarNotebook', function()
    -- Dentro do carro conecta nele; a pé, no carro mais próximo
    local veh = cache.vehicle or VeiculoProximo()
    if not veh then
        return Avisar('Nenhum veículo por perto', 'error')
    end

    local netId = VehToNet(veh)
    local ok, info = lib.callback.await('pista_tuning:server:abrirRemap', false, netId)
    if not ok then
        return exports.qbx_core:Notify(info or 'Não foi possível conectar na ECU', 'error')
    end

    exports.ox_inventory:closeInventory()
    aberto = { veh = veh, netId = netId, dados = info.dados }

    local lim = table.clone(Config.remap.limites[info.dados.chip])
    lim.limitadorMax = LimitadorMaximo(info.dados) -- cabeçote libera mais giro
    SendNUIMessage({
        acao = 'abrir',
        placa = info.placa,
        modelo = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh))),
        stage = info.dados.chip,
        pecas = {
            turbo = info.dados.turbo == true,
            intercooler = info.dados.intercooler == true,
            pistao = info.dados.pistao == true,
            cabecote = info.dados.cabecote ~= nil,
        },
        faixas = Config.remap.faixas,
        limites = lim,
        padrao = Config.remap.padrao,
        atual = info.remap,
        previa = previa(info.remap),
    })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('previa', function(valores, cb)
    cb(previa(valores))
end)

RegisterNUICallback('fechar', function(_, cb)
    cb(1)
    fecharTela()
    aberto = nil
end)

RegisterNUICallback('gravar', function(valores, cb)
    cb(1)
    fecharTela()
    local sessao = aberto
    aberto = nil
    if not sessao or not DoesEntityExist(sessao.veh) then return end

    local gravou = Trabalhar(Config.remap.tempoGravar, 'Gravando mapa na ECU...', {
        anim = { dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', clip = 'base', flag = 49 },
        prop = { model = `prop_cs_tablet`, bone = 60309, pos = vec3(0.03, 0.002, -0.0), rot = vec3(10.0, 160.0, 0.0) },
    })
    if not gravou then
        return exports.qbx_core:Notify('Gravação cancelada, o mapa antigo continua', 'error')
    end

    local ok, msg = lib.callback.await('pista_tuning:server:gravarRemap', false, sessao.netId, valores)
    exports.qbx_core:Notify(msg or '', ok and 'success' or 'error', 6000)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and aberto then
        SetNuiFocus(false, false)
    end
end)
