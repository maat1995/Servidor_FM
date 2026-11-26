-- pa_hud - cliente

local KVP = 'pa_hud_opcoes'
local opcoes = {}
local ocultoPorScript = false
local inventarioAberto = false
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
    novo.tema = (t.tema == 'classico') and 'classico' or 'vice'
    novo.dinheiro = t.dinheiro == true
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
            statusAoMudar = Config.vice.statusAoMudar,
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

---------------------------------------------------------------------
-- Tema Vice: dinheiro, GPS, pontos na bússola e perseguição
---------------------------------------------------------------------
local function dinheiro()
    local m = (QBX and QBX.PlayerData and QBX.PlayerData.money) or {}
    return { mao = math.floor(m.cash or 0), banco = math.floor(m.bank or 0) }
end

local rotaPintada = 0
local function gps()
    if not IsWaypointActive() then return false end
    local blip = GetFirstBlipInfoId(8)
    if Config.vice.corRota and blip ~= 0 and blip ~= rotaPintada then
        rotaPintada = blip
        SetBlipRouteColour(blip, Config.vice.corRota)
    end
    local dist = GetGpsBlipRouteLength()
    if not dist or dist <= 0 then
        local c, w = GetEntityCoords(cache.ped), GetBlipInfoIdCoord(blip)
        dist = #(vec2(c.x, c.y) - vec2(w.x, w.y))
    end
    return { dist = math.floor(dist) }
end

-- Rumo de bússola (graus no sentido horário a partir do norte)
local function rumo(de, para)
    local h = math.deg(math.atan(-(para.x - de.x), para.y - de.y))
    return (360.0 - h) % 360.0
end

local pontosCache = { t = 0, lista = {} }
local function pontos()
    local agora = GetGameTimer()
    if agora - pontosCache.t < 500 then return pontosCache.lista end
    pontosCache.t = agora

    local c = GetEntityCoords(cache.ped)
    local lista = {}
    for _, p in ipairs(Config.vice.pontos) do
        local blip = GetFirstBlipInfoId(p.sprite)
        local n = 0
        while DoesBlipExist(blip) and n < 30 do
            n = n + 1
            local b = GetBlipInfoIdCoord(blip)
            local d = #(vec2(c.x, c.y) - vec2(b.x, b.y))
            if d <= Config.vice.raioPontos and d > 5.0 then
                lista[#lista + 1] = { r = math.floor(rumo(c, b)), cor = p.cor, forma = p.forma }
            end
            blip = GetNextBlipInfoId(p.sprite)
        end
    end
    if IsWaypointActive() then
        local w = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
        lista[#lista + 1] = { r = math.floor(rumo(c, w)), cor = '#ED93B1', forma = 'bandeira', gps = true }
    end
    pontosCache.lista = lista
    return lista
end

local perseguicaoScript = false
local perseguicaoCache = { t = 0, valor = false }
local function perseguicao()
    if perseguicaoScript then return true end
    local agora = GetGameTimer()
    if agora - perseguicaoCache.t < 1000 then return perseguicaoCache.valor end
    perseguicaoCache.t = agora

    local cfg = Config.vice.perseguicao
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job
    if cfg.ignorarPolicia and job and job.type == 'leo' and job.onduty then
        perseguicaoCache.valor = false
        return false
    end
    local c = GetEntityCoords(cache.ped)
    local achou = false
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if v ~= cache.vehicle and GetVehicleClass(v) == 18 and IsVehicleSirenOn(v)
            and #(GetEntityCoords(v) - c) <= cfg.raio then
            achou = true
            break
        end
    end
    perseguicaoCache.valor = achou
    return achou
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
        fome = limitar(LocalPlayer.state.hunger or meta.hunger or 100),
        sede = limitar(LocalPlayer.state.thirst or meta.thirst or 100),
        estresse = limitar(LocalPlayer.state.stress or meta.stress or 0),
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

    d.cinto = LocalPlayer.state.seatbelt == true or LocalPlayer.state.harness == true

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

        -- PA Dash: com o painel instalado (sem chip = modo básico)
        if prep.painel then
            local cfg = Config.dash
            local remap = type(prep.remap) == 'table' and prep.remap or {}
            local lim = tonumber(remap.limitador) or cfg.limitadorPadrao
            local r = d.rpm or 0.0
            local pedal = GetControlNormal(0, 71)
            d.dash = {
                stage = tonumber(prep.chip) or 0,
                completo = (tonumber(prep.chip) or 0) >= cfg.completoStage,
                rpm = ligado and math.floor(cfg.marchaLenta + math.max(0.0, r - 0.2) / 0.8 * (lim - cfg.marchaLenta)) or 0,
                limitador = lim,
                troca = lim - cfg.shiftAntes,
                faixa = cfg.faixaLeds,
                corte = ligado and r >= cfg.corte,
                afr = (ligado and pedal > 0.3) and (tonumber(remap.mistura) or 12.5) or 14.7,
            }
        end
    end

    return d
end

---------------------------------------------------------------------
-- Laço principal
---------------------------------------------------------------------
local function podeMostrar()
    return LocalPlayer.state.isLoggedIn
        and not ocultoPorScript
        and not inventarioAberto
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
                vice = opcoes.tema == 'vice' and {
                    dinheiro = dinheiro(),
                    gps = gps(),
                    pontos = opcoes.bussola and pontos() or {},
                    perseguicao = perseguicao(),
                } or false,
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
RegisterNetEvent('pa_hud:client:inventario', function(aberto) inventarioAberto = aberto == true end)
-- compatibilidade com scripts feitos para o qbx_hud
RegisterNetEvent('qbx_hud:client:hideHud', function() ocultoPorScript = true end)
RegisterNetEvent('qbx_hud:client:showHud', function() ocultoPorScript = false end)

---------------------------------------------------------------------
-- Exports: outros scripts podem esconder a HUD (cutscene, câmera, etc.)
---------------------------------------------------------------------
exports('ocultar', function(valor) ocultoPorScript = valor == true end)
exports('visivel', function() return podeMostrar() end)
-- Outros scripts (ex.: pa_policia) podem acender a perseguição na bússola
exports('perseguicao', function(valor) perseguicaoScript = valor == true end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    DisplayRadar(true)
    SetNuiFocus(false, false)
end)
