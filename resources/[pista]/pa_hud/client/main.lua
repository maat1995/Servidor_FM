-- pa_hud - cliente

local KVP = 'pa_hud_opcoes'
local opcoes = {}
local ocultoPorScript = false
local visivelAntes = nil
local nitroAoVivo = { veh = 0, valor = 0.0, t = 0 }
local ruaCache = { nome = '', zona = '', t = 0 }

---------------------------------------------------------------------
-- Opções do jogador (salvas no PC dele)
---------------------------------------------------------------------
local function carregarOpcoes()
    for k, v in pairs(Config.padrao) do opcoes[k] = v end
    local salvo = GetResourceKvpString(KVP)
    if not salvo then return end
    local ok, t = pcall(json.decode, salvo)
    if ok and type(t) == 'table' then
        for k in pairs(Config.padrao) do
            if t[k] ~= nil and type(t[k]) == type(Config.padrao[k]) then opcoes[k] = t[k] end
        end
    end
end

local function validarOpcoes(t)
    local novo = {}
    novo.unidade = (t.unidade == 'mph') and 'mph' or 'kmh'
    novo.escala = math.floor(math.max(70, math.min(130, tonumber(t.escala) or 100)))
    novo.bussola = t.bussola == true
    novo.esconderCheio = t.esconderCheio == true
    novo.oculto = t.oculto == true
    return novo
end

local function enviarConfig()
    SendNUIMessage({
        acao = 'config',
        opcoes = opcoes,
        cfg = {
            rpmVermelho = Config.rpmVermelho,
            limiteCheio = Config.limiteCheio,
            alertaStatus = Config.alertaStatus,
            temperatura = Config.temperatura,
            motorAlerta = Config.motorAlerta,
        },
    })
end

---------------------------------------------------------------------
-- Posição do minimapa (para alinhar as barras de status)
---------------------------------------------------------------------
local function ancoraMinimapa()
    SetScriptGfxAlign(string.byte('L'), string.byte('B'))
    local _, y1 = GetScriptGfxPosition(-0.0045, 0.002 + (-0.188888))
    local x1, _ = GetScriptGfxPosition(-0.0045, 0.002)
    local x2, y2 = GetScriptGfxPosition(-0.0045 + 0.150, 0.002)
    ResetScriptGfxAlign()
    return { esquerda = x1, largura = x2 - x1, topo = y1, base = y2 }
end

local ultimaAncora = ''
local function enviarAncora()
    local a = ancoraMinimapa()
    local chave = ('%.4f|%.4f|%.4f|%.4f'):format(a.esquerda, a.largura, a.topo, a.base)
    if chave ~= ultimaAncora then
        ultimaAncora = chave
        SendNUIMessage({ acao = 'ancora', ancora = a })
    end
end

---------------------------------------------------------------------
-- Coleta de dados
---------------------------------------------------------------------
local DIRECOES = { 'N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO' }

local function bussola(ped)
    local graus = (360.0 - GetEntityHeading(ped)) % 360.0
    local i = math.floor((graus + 22.5) / 45.0) % 8

    local agora = GetGameTimer()
    if agora - ruaCache.t > 1000 then
        ruaCache.t = agora
        local c = GetEntityCoords(ped)
        local r1, r2 = GetStreetNameAtCoord(c.x, c.y, c.z)
        local nome = GetStreetNameFromHashKey(r1)
        local cruza = r2 ~= 0 and GetStreetNameFromHashKey(r2) or ''
        if cruza ~= '' then nome = nome .. ' x ' .. cruza end
        ruaCache.nome = nome
        ruaCache.zona = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    end

    return { indice = i, graus = math.floor(graus), rua = ruaCache.nome, zona = ruaCache.zona }
end

local function limitar(v) return math.max(0, math.min(100, math.floor(v + 0.5))) end

local function status(ped)
    local vida = 0
    if not IsEntityDead(ped) then
        local max = GetEntityMaxHealth(ped) - 100
        vida = (GetEntityHealth(ped) - 100) / (max > 0 and max or 100) * 100
    end
    local meta = (QBX and QBX.PlayerData and QBX.PlayerData.metadata) or {}
    return {
        vida = limitar(vida),
        colete = limitar(GetPedArmour(ped)),
        fome = limitar(meta.hunger or 100),
        sede = limitar(meta.thirst or 100),
        estresse = limitar(meta.stress or 0),
    }
end

local function voz()
    local prox = LocalPlayer.state.proximity
    return {
        modo = prox and prox.index or prox and prox.mode or 2,
        falando = NetworkIsPlayerTalking(PlayerId()),
    }
end

local function tipoVeiculo(classe)
    if classe == 13 then return 'bike' end
    if classe == 14 then return 'barco' end
    if classe == 15 or classe == 16 then return 'aereo' end
    return 'carro'
end

local function veiculo(veh)
    local tipo = tipoVeiculo(GetVehicleClass(veh))
    local ligado = GetIsVehicleEngineRunning(veh)
    local d = {
        tipo = tipo,
        velocidade = GetEntitySpeed(veh),
        ligado = ligado,
        rpm = ligado and GetVehicleCurrentRpm(veh) or 0.0,
    }

    if tipo == 'aereo' then
        d.marcha = math.floor(GetEntityHeightAboveGround(veh))
    else
        local m = GetVehicleCurrentGear(veh)
        local manual = GetResourceState('pa_cambio') == 'started' and exports.pa_cambio:marcha(veh)
        if manual then d.marcha = manual -- câmbio manual: N, R, 1, 2...
        elseif not ligado then d.marcha = '-'
        elseif m == 0 then d.marcha = 'R'
        else d.marcha = tostring(m) end
    end

    if tipo == 'bike' then return d end

    d.gasolina = limitar(Entity(veh).state.fuel or GetVehicleFuelLevel(veh))
    d.temperatura = math.floor(GetVehicleEngineTemperature(veh))
    d.motor = limitar(GetVehicleEngineHealth(veh) / 10.0)

    local prep = Entity(veh).state.pista_tuning
    if type(prep) == 'table' then
        if prep.turbo then
            local max = (type(prep.remap) == 'table' and tonumber(prep.remap.turbo)) or Config.turboPadraoBar
            local p = math.max(0.0, math.min(1.0, GetVehicleTurboPressure(veh)))
            d.turbo = { bar = p * max, max = max }
        end
        if prep.nitro then
            local carga = prep.nitroCarga or 0.0
            if nitroAoVivo.veh == veh and GetGameTimer() - nitroAoVivo.t < 1500 then
                carga = nitroAoVivo.valor
            end
            d.nitro = limitar(carga / Config.nitroCarga * 100)
        end
        if prep.motor or prep.motorQuebrado then d.semMotor = true end
    end

    return d
end

---------------------------------------------------------------------
-- Laço principal
---------------------------------------------------------------------
local function podeMostrar()
    return LocalPlayer.state.isLoggedIn
        and not ocultoPorScript
        and not opcoes.oculto
        and not IsPauseMenuActive()
        and not IsScreenFadedOut()
end

CreateThread(function()
    carregarOpcoes()
    Wait(500)
    enviarConfig()

    local ultimaAncoraT = 0
    while true do
        local espera = Config.intervalo.ape
        local mostrar = podeMostrar()

        if mostrar then
            local ped = cache.ped
            local veh = cache.vehicle
            if veh then espera = Config.intervalo.carro end

            DisplayRadar(veh and true or Config.radarAPe)

            local agora = GetGameTimer()
            if agora - ultimaAncoraT > 2000 then
                ultimaAncoraT = agora
                enviarAncora()
            end

            SendNUIMessage({
                acao = 'atualizar',
                radar = (veh and true or Config.radarAPe) and true or false,
                status = status(ped),
                voz = voz(),
                bussola = opcoes.bussola and bussola(ped) or false,
                veiculo = veh and veiculo(veh) or false,
            })
        elseif visivelAntes ~= false then
            SendNUIMessage({ acao = 'esconder' })
            if not LocalPlayer.state.isLoggedIn or opcoes.oculto or ocultoPorScript then DisplayRadar(false) end
        end

        visivelAntes = mostrar
        Wait(espera)
    end
end)

-- Esconde os textos nativos que a HUD substitui
CreateThread(function()
    while true do
        for _, id in ipairs(Config.esconderNativos) do HideHudComponentThisFrame(id) end
        Wait(0)
    end
end)

---------------------------------------------------------------------
-- Integrações
---------------------------------------------------------------------
-- pista_tuning avisa a carga do nitro enquanto o jogador segura a tecla
AddEventHandler('pista_tuning:client:nitro', function(veh, carga)
    nitroAoVivo.veh, nitroAoVivo.valor, nitroAoVivo.t = veh, carga, GetGameTimer()
end)

RegisterNetEvent('pista_skills:client:ganhouXP', function(arvore, qtd, motivo)
    if not Config.xpNaTela then return end
    SendNUIMessage({
        acao = 'aviso', tipo = 'xp',
        texto = ('+%d XP %s'):format(tonumber(qtd) or 0, Config.nomesArvore[arvore] or arvore or ''),
        detalhe = motivo,
    })
end)

RegisterNetEvent('pista_skills:client:subiuNivel', function(arvore, nivel)
    if not Config.xpNaTela then return end
    SendNUIMessage({
        acao = 'aviso', tipo = 'nivel',
        texto = ('%s nível %d'):format(Config.nomesArvore[arvore] or arvore or '', tonumber(nivel) or 0),
    })
end)

---------------------------------------------------------------------
-- Opções (/hud)
---------------------------------------------------------------------
RegisterCommand(Config.comando, function()
    SetNuiFocus(true, true)
    SendNUIMessage({ acao = 'abrirOpcoes', opcoes = opcoes })
end, false)

RegisterNUICallback('salvarOpcoes', function(data, cb)
    opcoes = validarOpcoes(type(data) == 'table' and data or {})
    SetResourceKvp(KVP, json.encode(opcoes))
    SetNuiFocus(false, false)
    enviarConfig()
    visivelAntes = nil
    cb('ok')
end)

RegisterNUICallback('fechar', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

---------------------------------------------------------------------
-- Exports: outros scripts podem esconder a HUD (cutscene, câmera, etc.)
---------------------------------------------------------------------
exports('ocultar', function(valor) ocultoPorScript = valor == true end)
exports('visivel', function() return podeMostrar() end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    DisplayRadar(true)
    SetNuiFocus(false, false)
end)
