-- pa_policia · cliente · posição dos widgets (radar, avisos e painel)
-- Cada jogador arrasta os widgets para onde quiser; fica salvo no PC dele (KVP).

local KVP = 'pa_policia_widgets'
local editando = false

RegisterNUICallback('widgetsPedir', function(_, cb)
    cb(GetResourceKvpString(KVP) or '{}')
end)

local function editar()
    if editando then return end
    editando = true
    SetNuiFocus(true, true)
    SendNUIMessage({ acao = 'widgetsEditar' })
end

local function sair()
    editando = false
    SetNuiFocus(false, false)
end

RegisterNUICallback('widgetsSalvar', function(dados, cb)
    SetResourceKvp(KVP, json.encode(dados or {}))
    sair()
    lib.notify({ title = Config.Titulo, description = 'Posição dos widgets salva.', type = 'success' })
    cb(true)
end)

RegisterNUICallback('widgetsCancelar', function(_, cb)
    sair()
    cb(true)
end)

RegisterCommand('moverhudpolicia', editar, false)
AddEventHandler('pa_policia:client:moverWidgets', editar)
