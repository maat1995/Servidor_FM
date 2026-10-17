-- pa_policia · cliente · tablet (MDT)

local aberto = false
local tablet

-- só esses callbacks podem ser chamados pela tela
local PERMITIDOS = {
    ocorrencias = 'pa_policia:server:ocorrencias',
    buscar = 'pa_policia:mdt:buscar',
    proximos = 'pa_policia:mdt:proximos',
    ficha = 'pa_policia:mdt:ficha',
    multar = 'pa_policia:mdt:multar',
    cancelarMulta = 'pa_policia:mdt:cancelarMulta',
    aplicarPena = 'pa_policia:mdt:aplicarPena',
    emitirLicenca = 'pa_policia:mdt:emitirLicenca',
    revogarLicenca = 'pa_policia:mdt:revogarLicenca',
    mandadoPrisao = 'pa_policia:mdt:mandadoPrisao',
    mandadoBusca = 'pa_policia:mdt:mandadoBusca',
    mandados = 'pa_policia:mdt:mandados',
    encerrarMandado = 'pa_policia:mdt:encerrarMandado',
    veiculo = 'pa_policia:mdt:veiculo',
    marcarPlaca = 'pa_policia:mdt:marcarPlaca',
    liberarPatio = 'pa_policia:mdt:liberarPatio',
    bos = 'pa_policia:mdt:bos',
    bo = 'pa_policia:mdt:bo',
    criarBo = 'pa_policia:mdt:criarBo',
    salvarArtigo = 'pa_policia:mdt:salvarArtigo',
    removerArtigo = 'pa_policia:mdt:removerArtigo',
    equipe = 'pa_policia:mdt:equipe',
    contratar = 'pa_policia:mdt:contratar',
    setGrau = 'pa_policia:mdt:setGrau',
    demitir = 'pa_policia:mdt:demitir',
    caixa = 'pa_policia:mdt:caixa',
    apreensoes = 'pa_policia:mdt:apreensoes',
    pericias = 'pa_policia:mdt:pericias',
    soltarPreso = 'pa_policia:mdt:soltarPreso',
}

local function animTablet(ligar)
    if ligar then
        lib.requestAnimDict('amb@code_human_in_bus_passenger_idles@female@tablet@base')
        lib.requestModel(`prop_cs_tablet`)
        tablet = CreateObject(`prop_cs_tablet`, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(tablet, cache.ped, GetPedBoneIndex(cache.ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
        SetModelAsNoLongerNeeded(`prop_cs_tablet`)
        if not cache.vehicle then
            TaskPlayAnim(cache.ped, 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 3.0, 3.0, -1, 49, 0, false, false, false)
        end
    else
        if tablet and DoesEntityExist(tablet) then DeleteEntity(tablet) end
        tablet = nil
        StopAnimTask(cache.ped, 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 1.0)
    end
end

local function fechar()
    if not aberto then return end
    aberto = false
    SetNuiFocus(false, false)
    SendNUIMessage({ acao = 'fecharMdt' })
    animTablet(false)
end

local function abrir(opcoes)
    if aberto then return end
    if not PC.EmServico() then return PC.Aviso('O tablet só funciona em serviço.', 'error') end
    if LocalPlayer.state.pa_algema then return end
    local dados = lib.callback.await('pa_policia:mdt:abrir', false)
    if not dados then return end
    aberto = true
    animTablet(true)
    SetNuiFocus(true, true)
    SendNUIMessage({ acao = 'abrirMdt', dados = dados, opcoes = opcoes or {} })
end

AddEventHandler('pa_policia:client:abrirMdt', abrir)
AddEventHandler('pa_policia:client:saiuServico', fechar)
RegisterCommand('mdt', function() abrir() end, false)

lib.addKeybind({
    name = 'pa_policia_mdt',
    description = 'LSPD: tablet policial (MDT)',
    defaultKey = Config.teclas.tablet,
    onPressed = function()
        if aberto then fechar() else abrir() end
    end,
})

RegisterNUICallback('fechar', function(_, cb)
    fechar()
    cb(true)
end)

RegisterNUICallback('mdt', function(data, cb)
    local nome = PERMITIDOS[data and data.cb]
    if not nome or not aberto then return cb({}) end
    local args = data.args or {}
    local r = table.pack(lib.callback.await(nome, false, table.unpack(args, 1, #args)))
    local lista = {}
    for i = 1, r.n do lista[i] = r[i] == nil and false or r[i] end
    cb(lista)
end)

RegisterNUICallback('assumir', function(data, cb)
    if data and data.id then PC.AssumirOcorrencia(data.id) end
    cb(true)
end)

RegisterNUICallback('gps', function(data, cb)
    if data and data.x then SetNewWaypoint(data.x + 0.0, data.y + 0.0) end
    cb(true)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and aberto then
        SetNuiFocus(false, false)
        animTablet(false)
    end
end)
