-- pa_policia · cliente · painel do policial (F6)
-- Painel lateral no visual da LSPD: status, atalhos, ocorrências e blitz.

local aberto = false

local function dadosPainel()
    local d = lib.callback.await('pa_policia:server:painel', false)
    if not d then return nil end
    local pos = GetEntityCoords(cache.ped)
    for _, o in ipairs(d.ocorrencias or {}) do
        o.distancia = math.floor(#(pos - vec3(o.centro.x, o.centro.y, o.centro.z)))
        o.local_ = PC.NomeDaArea(o.centro)
        o.minutos = math.max(0, math.floor((GetCloudTimeAsInt() - o.criado) / 60))
    end
    d.radar = PC.RadarLigado and PC.RadarLigado() or false
    d.objetos = {}
    for _, o in ipairs(Config.objetos.lista) do d.objetos[#d.objetos + 1] = { id = o.id, label = o.label, tapete = o.tapete } end
    return d
end

local function fechar()
    if not aberto then return end
    aberto = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ acao = 'painelFechar' })
end

local function abrir(vista)
    if not PC.EhPolicia() then return end
    local d = dadosPainel()
    if not d then return end
    aberto = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true) -- dá para andar com o painel aberto
    SendNUIMessage({ acao = 'painelAbrir', dados = d, vista = vista })
    CreateThread(function()
        while aberto do
            -- com o painel aberto não atira nem mexe a câmera
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            Wait(0)
        end
    end)
end

lib.addKeybind({
    name = 'pa_policia_menu',
    description = 'LSPD: painel do policial',
    defaultKey = Config.teclas.menu,
    onPressed = function()
        if aberto then fechar() else abrir() end
    end,
})

AddEventHandler('pa_policia:client:saiuServico', fechar)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and aberto then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end)

-- /ocorrencias abre o painel direto na lista
RegisterCommand('ocorrencias', function()
    if not PC.EmServico() then return PC.Aviso('Só policiais em serviço.', 'error') end
    abrir('ocorrencias')
end, false)

---------------------------------------------------------------------
-- AÇÕES DO PAINEL
---------------------------------------------------------------------
local ACOES = {}

ACOES.fechar = function() fechar() end

ACOES.widgets = function()
    fechar()
    Wait(50)
    TriggerEvent('pa_policia:client:moverWidgets')
end

ACOES.atualizar = function()
    local d = dadosPainel()
    if d then SendNUIMessage({ acao = 'painelDados', dados = d }) end
end

ACOES.tablet = function()
    fechar()
    Wait(50)
    TriggerEvent('pa_policia:client:abrirMdt')
end

ACOES.radar = function()
    ExecuteCommand('radar')
    Wait(100)
    ACOES.atualizar()
end

ACOES.panico = function()
    ExecuteCommand('panico')
    fechar()
end

ACOES.limpar = function()
    local ok, msg = lib.callback.await('pa_policia:server:limparCena', false)
    PC.Resultado(ok, msg)
end

ACOES.objeto = function(dados)
    fechar()
    Wait(50)
    TriggerEvent('pa_policia:client:colocarObjeto', dados.id)
end

ACOES.assumir = function(dados)
    PC.AssumirOcorrencia(dados.id)
    ACOES.atualizar()
end

ACOES.dp = function()
    local c = Config.dp.centro
    SetNewWaypoint(c.x, c.y)
    PC.Aviso('GPS marcado para a DP de Mission Row.', 'inform')
end

ACOES.gps = function(dados)
    if dados.x then SetNewWaypoint(dados.x + 0.0, dados.y + 0.0) end
end

ACOES.encerrar = function(dados)
    local ok, msg = lib.callback.await('pa_policia:server:encerrar', false, dados.id)
    PC.Resultado(ok, ok and 'Ocorrência encerrada.' or msg)
    ACOES.atualizar()
end

RegisterNUICallback('painel', function(dados, cb)
    cb(true)
    local fn = dados and ACOES[dados.acao]
    if fn and aberto then fn(dados) end
end)
