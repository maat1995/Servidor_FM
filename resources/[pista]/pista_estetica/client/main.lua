-- pista_estetica - cliente: cabine de pintura e oficina de estética

local sessao = nil   -- { tipo, veh, props, original = {}, labels = {}, categoria }
local paletaHex = nil -- [id] = '#rrggbb' (lida do próprio jogo uma vez)

---------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------
local function Avisar(msg, tipo, tempo)
    exports.qbx_core:Notify(msg or '', tipo or 'inform', tempo)
end

local function souMecanico()
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job
    if not job or job.name ~= Config.job then return false end
    return job.onduty or not Config.precisaServico
end

local function controle(ent)
    local limite = GetGameTimer() + 2000
    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < limite do
        Wait(10)
        NetworkRequestControlOfEntity(ent)
    end
    return NetworkHasControlOfEntity(ent)
end

local function serial(v)
    if type(v) == 'table' then return json.encode(v) end
    return tostring(v)
end

local function hex(r, g, b)
    return ('#%02x%02x%02x'):format(math.floor(r), math.floor(g), math.floor(b))
end

local function nomeMod(veh, mod, i)
    local label = GetModTextLabel(veh, mod, i)
    local texto = label and GetLabelText(label) or 'NULL'
    if texto == 'NULL' or texto == '' then
        return ('%s %d'):format(Listas.pecas[mod] or 'Opção', i + 1)
    end
    return texto
end

---------------------------------------------------------------------
-- Paleta de cores do GTA: o jogo não diz a cor de cada id, então pinta
-- o carro com cada uma no mesmo frame, lê o RGB e devolve o original.
---------------------------------------------------------------------
local function lerPaleta(veh, props)
    if paletaHex then return paletaHex end
    paletaHex = {}
    ClearVehicleCustomPrimaryColour(veh)
    for _, g in ipairs(Listas.cores) do
        for _, c in ipairs(g.cores) do
            SetVehicleColours(veh, c[1], c[1])
            local r, gg, b = GetVehicleColor(veh)
            if r and (r + gg + b) > 0 or c[1] == 0 or c[1] == 12 or c[1] == 21 or c[1] == 147 then
                paletaHex[c[1]] = hex(r or 0, gg or 0, b or 0)
            end
        end
    end
    lib.setVehicleProperties(veh, props)
    return paletaHex
end

local function paletaParaTela()
    local grupos = {}
    for _, g in ipairs(Listas.cores) do
        local cores = {}
        for _, c in ipairs(g.cores) do
            cores[#cores + 1] = { id = c[1], label = c[2], hex = paletaHex and paletaHex[c[1]] or nil }
        end
        grupos[#grupos + 1] = { grupo = g.grupo, cores = cores }
    end
    return grupos
end

---------------------------------------------------------------------
-- Ler / aplicar cada ajuste
---------------------------------------------------------------------
local function lerPintura(qual)
    local veh = sessao.veh
    if qual == 'primaria' or qual == 'secundaria' then
        local prim = qual == 'primaria'
        local custom = prim and GetIsVehiclePrimaryColourCustom(veh) or (not prim and GetIsVehicleSecondaryColourCustom(veh))
        if custom then
            local r, g, b
            if prim then r, g, b = GetVehicleCustomPrimaryColour(veh) else r, g, b = GetVehicleCustomSecondaryColour(veh) end
            local acabamento = prim and GetVehicleModColor_1(veh) or GetVehicleModColor_2(veh)
            return { m = 'rgb', r = r, g = g, b = b, f = acabamento or 0 }
        end
        local p, s = GetVehicleColours(veh)
        return { m = 'cor', id = prim and p or s }
    end
    local perolado, roda = GetVehicleExtraColours(veh)
    if qual == 'perolado' then return perolado end
    if qual == 'roda' then return roda end
    if qual == 'interior' then return GetVehicleInteriorColour(veh) end
    if qual == 'painel' then return GetVehicleDashboardColour(veh) end
end

local function aplicarPintura(qual, v)
    local veh = sessao.veh
    if qual == 'primaria' or qual == 'secundaria' then
        local prim = qual == 'primaria'
        if type(v) ~= 'table' then return end
        if v.m == 'rgb' then
            local f = math.max(0, math.min(5, tonumber(v.f) or 0))
            if prim then
                SetVehicleModColor_1(veh, f, 0, 0)
                SetVehicleCustomPrimaryColour(veh, v.r, v.g, v.b)
            else
                SetVehicleModColor_2(veh, f, 0)
                SetVehicleCustomSecondaryColour(veh, v.r, v.g, v.b)
            end
        else
            local p, s = GetVehicleColours(veh)
            if prim then
                ClearVehicleCustomPrimaryColour(veh)
                SetVehicleColours(veh, v.id, s)
            else
                ClearVehicleCustomSecondaryColour(veh)
                SetVehicleColours(veh, p, v.id)
            end
        end
        return
    end
    local perolado, roda = GetVehicleExtraColours(veh)
    if qual == 'perolado' then SetVehicleExtraColours(veh, v, roda) end
    if qual == 'roda' then SetVehicleExtraColours(veh, perolado, v) end
    if qual == 'interior' then SetVehicleInteriorColour(veh, v) end
    if qual == 'painel' then SetVehicleDashboardColour(veh, v) end
end

local function lerValor(id)
    local veh = sessao.veh
    local a, b = id:match('^(%a+):?(.*)$')
    if a == 'mod' then return GetVehicleMod(veh, tonumber(b)) end
    if id == 'roda:tipo' then return GetVehicleWheelType(veh) end
    if id == 'roda:modelo' then return GetVehicleMod(veh, 23) end
    if id == 'roda:pneu' then return GetVehicleModVariation(veh, 23) == true or GetVehicleModVariation(veh, 23) == 1 end
    if id == 'fumaca:ativa' then return IsToggleModOn(veh, 20) == true or IsToggleModOn(veh, 20) == 1 end
    if id == 'fumaca:cor' then local r, g, bb = GetVehicleTyreSmokeColor(veh) return { r, g, bb } end
    if id == 'xenon:ativo' then return IsToggleModOn(veh, 22) == true or IsToggleModOn(veh, 22) == 1 end
    if id == 'xenon:cor' then
        local c = GetVehicleXenonLightsColor(veh)
        return (c == 255 or c == -1 or c == nil) and -1 or c
    end
    if id == 'neon:cor' then local r, g, bb = GetVehicleNeonLightsColour(veh) return { r, g, bb } end
    if a == 'neon' then return IsVehicleNeonLightEnabled(veh, tonumber(b)) == true or IsVehicleNeonLightEnabled(veh, tonumber(b)) == 1 end
    if id == 'insulfilm' then return GetVehicleWindowTint(veh) end
    if id == 'placa' then return GetVehicleNumberPlateTextIndex(veh) end
    if id == 'adesivo' then return GetVehicleLivery(veh) end
    if a == 'extra' then return IsVehicleExtraTurnedOn(veh, tonumber(b)) == true or IsVehicleExtraTurnedOn(veh, tonumber(b)) == 1 end
    if id == 'buzina' then return GetVehicleMod(veh, 14) end
    if a == 'pint' then return lerPintura(b) end
end

local function aplicarValor(id, v)
    local veh = sessao.veh
    local a, b = id:match('^(%a+):?(.*)$')
    SetVehicleModKit(veh, 0)
    if a == 'mod' then
        SetVehicleMod(veh, tonumber(b), tonumber(v) or -1, false)
    elseif id == 'roda:tipo' then
        SetVehicleWheelType(veh, tonumber(v))
        SetVehicleMod(veh, 23, -1, false)
    elseif id == 'roda:modelo' then
        SetVehicleMod(veh, 23, tonumber(v) or -1, lerValor('roda:pneu'))
    elseif id == 'roda:pneu' then
        SetVehicleMod(veh, 23, GetVehicleMod(veh, 23), v == true)
    elseif id == 'fumaca:ativa' then
        ToggleVehicleMod(veh, 20, v == true)
    elseif id == 'fumaca:cor' then
        ToggleVehicleMod(veh, 20, true)
        SetVehicleTyreSmokeColor(veh, v[1], v[2], v[3])
    elseif id == 'xenon:ativo' then
        ToggleVehicleMod(veh, 22, v == true)
    elseif id == 'xenon:cor' then
        ToggleVehicleMod(veh, 22, true)
        SetVehicleXenonLightsColor(veh, v == -1 and 255 or v)
    elseif id == 'neon:cor' then
        SetVehicleNeonLightsColour(veh, v[1], v[2], v[3])
    elseif a == 'neon' then
        SetVehicleNeonLightEnabled(veh, tonumber(b), v == true)
    elseif id == 'insulfilm' then
        SetVehicleWindowTint(veh, tonumber(v))
    elseif id == 'placa' then
        SetVehicleNumberPlateTextIndex(veh, tonumber(v))
    elseif id == 'adesivo' then
        SetVehicleLivery(veh, tonumber(v))
    elseif a == 'extra' then
        SetVehicleExtra(veh, tonumber(b), v ~= true) -- o GTA usa "desligar"
    elseif id == 'buzina' then
        SetVehicleMod(veh, 14, tonumber(v) or -1, false)
        StartVehicleHorn(veh, 1200, `HELDDOWN`, false)
    elseif a == 'pint' then
        aplicarPintura(b, v)
    end
end

--- Guarda como estava antes (só na primeira vez que o grupo aparece)
local function registrar(id, label)
    if sessao.original[id] == nil then sessao.original[id] = serial(lerValor(id)) end
    sessao.labels[id] = label
end

---------------------------------------------------------------------
-- Grupos de cada categoria (o que a tela mostra)
---------------------------------------------------------------------
local function grupoMod(veh, mod)
    local n = GetNumVehicleMods(veh, mod)
    if n <= 0 then return nil end
    local id = 'mod:' .. mod
    registrar(id, Listas.pecas[mod] or ('Peça ' .. mod))
    local opcoes = { { v = -1, label = 'Original de fábrica' } }
    for i = 0, n - 1 do opcoes[#opcoes + 1] = { v = i, label = nomeMod(veh, mod, i) } end
    return { id = id, label = Listas.pecas[mod], tipo = 'lista', opcoes = opcoes, atual = lerValor(id) }
end

local function grupo(id, label, tipo, opcoes)
    registrar(id, label)
    return { id = id, label = label, tipo = tipo, opcoes = opcoes, atual = lerValor(id) }
end

local function listaCores(lista)
    local r = {}
    for _, c in ipairs(lista) do r[#r + 1] = { v = { c[2], c[3], c[4] }, label = c[1], hex = hex(c[2], c[3], c[4]) } end
    return r
end

local function gruposDa(cat)
    local veh = sessao.veh
    local g = {}
    local function add(x) if x then g[#g + 1] = x end end

    for _, c in ipairs(Listas.categorias) do
        if c.id == cat and c.mods then
            for _, mod in ipairs(c.mods) do add(grupoMod(veh, mod)) end
        end
    end

    if cat == 'rodas' then
        local tipos = {}
        for _, t in ipairs(Listas.tiposRoda) do tipos[#tipos + 1] = { v = t[1], label = t[2] } end
        add(grupo('roda:tipo', 'Tipo de roda', 'chips', tipos))
        local n = GetNumVehicleMods(veh, 23)
        local modelos = { { v = -1, label = 'Original de fábrica' } }
        for i = 0, n - 1 do modelos[#modelos + 1] = { v = i, label = nomeMod(veh, 23, i) } end
        add(grupo('roda:modelo', 'Modelo da roda', 'lista', modelos))
        add(grupo('roda:pneu', 'Pneu de faixa branca / personalizado', 'toggle'))
        add(grupo('fumaca:ativa', 'Fumaça colorida no pneu', 'toggle'))
        add(grupo('fumaca:cor', 'Cor da fumaça', 'cores', listaCores(Listas.fumacaCores)))
    elseif cat == 'luzes' then
        add(grupo('xenon:ativo', 'Farol de xenon', 'toggle'))
        local xenon = {}
        for _, x in ipairs(Listas.xenon) do xenon[#xenon + 1] = { v = x[1], label = x[2], hex = x[3] } end
        add(grupo('xenon:cor', 'Cor do xenon', 'cores', xenon))
        for _, lado in ipairs(Listas.neonLados) do
            add(grupo('neon:' .. lado[1], 'Neon ' .. lado[2]:lower(), 'toggle'))
        end
        add(grupo('neon:cor', 'Cor do neon', 'cores', listaCores(Listas.neonCores)))
    elseif cat == 'vidros' then
        local op = {}
        for _, t in ipairs(Listas.insulfilm) do op[#op + 1] = { v = t[1], label = t[2] } end
        add(grupo('insulfilm', 'Insulfilm', 'lista', op))
    elseif cat == 'placa' then
        local op = {}
        for _, p in ipairs(Listas.placas) do op[#op + 1] = { v = p[1], label = p[2] } end
        table.insert(g, 1, grupo('placa', 'Modelo da placa', 'lista', op))
    elseif cat == 'adesivos' then
        local n = GetVehicleLiveryCount(veh)
        if n and n > 0 then
            local op = {}
            for i = 0, n - 1 do
                local nome = GetLabelText(GetLiveryName(veh, i) or '')
                op[#op + 1] = { v = i, label = (nome ~= 'NULL' and nome ~= '') and nome or ('Adesivo %d'):format(i + 1) }
            end
            add(grupo('adesivo', 'Adesivo', 'lista', op))
        else
            local m = grupoMod(veh, 48)
            if m then m.label = 'Adesivo' sessao.labels['mod:48'] = 'Adesivo' end
            add(m)
        end
    elseif cat == 'extras' then
        for i = 1, 14 do
            if DoesExtraExist(veh, i) then add(grupo('extra:' .. i, ('Extra %d'):format(i), 'toggle')) end
        end
    elseif cat == 'buzina' then
        local n = GetNumVehicleMods(veh, 14)
        if n > 0 then
            local op = { { v = -1, label = 'Original de fábrica' } }
            for i = 0, n - 1 do op[#op + 1] = { v = i, label = Listas.buzinas[i] or ('Buzina %d'):format(i + 1) } end
            add(grupo('buzina', 'Buzina (toca ao escolher)', 'lista', op))
        end
    end
    return g
end

local function categoriasDisponiveis()
    local lista = {}
    for _, c in ipairs(Listas.categorias) do
        if #gruposDa(c.id) > 0 then lista[#lista + 1] = { id = c.id, label = c.label } end
    end
    return lista
end

local ALVOS_PINTURA = {
    { id = 'pint:primaria',   label = 'Cor principal',  tipo = 'cor',     camera = 'geral' },
    { id = 'pint:secundaria', label = 'Cor secundária', tipo = 'cor',     camera = 'geral' },
    { id = 'pint:perolado',   label = 'Perolado',       tipo = 'paleta',  camera = 'geral' },
    { id = 'pint:roda',       label = 'Cor das rodas',  tipo = 'paleta',  camera = 'rodas' },
    { id = 'pint:interior',   label = 'Interior',       tipo = 'paleta',  camera = 'interior' },
    { id = 'pint:painel',     label = 'Painel',         tipo = 'paleta',  camera = 'interior' },
}

local function valoresPintura()
    local r = {}
    for _, a in ipairs(ALVOS_PINTURA) do
        registrar(a.id, a.label)
        r[a.id] = lerValor(a.id)
    end
    return r
end

---------------------------------------------------------------------
-- Carrinho
---------------------------------------------------------------------
local function carrinho()
    local itens, total = {}, 0
    for id, orig in pairs(sessao.original) do
        if serial(lerValor(id)) ~= orig then
            local preco = Config.precos[id:match('^(%a+)')] or 0
            itens[#itens + 1] = { id = id, label = sessao.labels[id] or id, preco = preco }
            total = total + preco
        end
    end
    table.sort(itens, function(x, y) return x.label < y.label end)
    return { itens = itens, total = total }
end

---------------------------------------------------------------------
-- Câmera: gira em volta do carro e vai até a parte escolhida
---------------------------------------------------------------------
local cam = nil
local camAtual, camAlvo = nil, nil
local dims = nil

local PRESETS = {
    geral    = { yaw = -40, pitch = 12, dist = 1.00, foco = function(mi, ma) return vec3(0.0, 0.0, 0.1) end },
    frente   = { yaw = -25, pitch = 8,  dist = 0.80, foco = function(mi, ma) return vec3(0.0, ma.y * 0.65, 0.0) end },
    traseira = { yaw = 200, pitch = 10, dist = 0.80, foco = function(mi, ma) return vec3(0.0, mi.y * 0.65, 0.15) end },
    lateral  = { yaw = -90, pitch = 8,  dist = 0.95, foco = function(mi, ma) return vec3(0.0, 0.0, 0.1) end },
    rodas    = { yaw = -70, pitch = 2,  dist = 0.50, foco = 'roda' },
    luzes    = { yaw = -30, pitch = 2,  dist = 0.85, foco = function(mi, ma) return vec3(0.0, ma.y * 0.5, mi.z * 0.4) end },
    vidros   = { yaw = -80, pitch = 6,  dist = 0.80, foco = function(mi, ma) return vec3(0.0, 0.0, 0.45) end },
    motor    = { yaw = 0,   pitch = 40, dist = 0.60, foco = function(mi, ma) return vec3(0.0, ma.y * 0.55, 0.35) end },
    placa    = { yaw = 180, pitch = 6,  dist = 0.45, foco = function(mi, ma) return vec3(0.0, mi.y, mi.z * 0.3) end },
    interior = { fixo = true },
}

local function focoDa(preset)
    local veh = sessao.veh
    if preset.foco == 'roda' then
        local osso = GetEntityBoneIndexByName(veh, 'wheel_lf')
        if osso ~= -1 then
            return GetOffsetFromEntityGivenWorldCoords(veh, GetWorldPositionOfEntityBone(veh, osso))
        end
        return vec3(dims.min.x, dims.max.y * 0.6, dims.min.z * 0.5)
    end
    return preset.foco(dims.min, dims.max)
end

local function irPara(nome)
    if not sessao then return end
    local p = PRESETS[nome] or PRESETS.geral
    local veh = sessao.veh
    -- capô aberto só no motor; faróis e motor ligados nas luzes (o neon só acende assim)
    if nome == 'motor' then SetVehicleDoorOpen(veh, 4, false, false) else SetVehicleDoorShut(veh, 4, false) end
    if nome == 'luzes' then
        SetVehicleEngineOn(veh, true, true, false)
        SetVehicleLights(veh, 2)
    else
        SetVehicleLights(veh, 0)
    end
    if p.fixo then
        camAlvo = { fixo = true }
        return
    end
    camAlvo = { yaw = p.yaw, pitch = p.pitch, dist = p.dist, foco = focoDa(p) }
    if not camAtual or camAtual.fixo then camAtual = table.clone(camAlvo) end
end

local function iniciarCamera()
    local veh = sessao.veh
    local mi, ma = GetModelDimensions(GetEntityModel(veh))
    dims = { min = mi, max = ma, base = math.max(ma.y - mi.y, (ma.x - mi.x) * 1.6) * 0.75 + 2.2 }
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 50.0)
    camAtual = nil
    irPara('geral')
    RenderScriptCams(true, true, 600, true, true)

    CreateThread(function()
        while cam and sessao do
            HideHudAndRadarThisFrame()
            local veh2 = sessao.veh
            if camAlvo and camAlvo.fixo then
                -- dentro do carro, do banco do passageiro olhando o painel
                local pos = GetOffsetFromEntityInWorldCoords(veh2, 0.45, -0.25, 0.55)
                local olha = GetOffsetFromEntityInWorldCoords(veh2, -0.25, 0.80, 0.30)
                SetCamCoord(cam, pos.x, pos.y, pos.z)
                PointCamAtCoord(cam, olha.x, olha.y, olha.z)
            elseif camAlvo and camAtual then
                local k = 0.12
                local dy = (camAlvo.yaw - camAtual.yaw + 180.0) % 360.0 - 180.0
                camAtual.yaw = camAtual.yaw + dy * k
                camAtual.pitch = camAtual.pitch + (camAlvo.pitch - camAtual.pitch) * k
                camAtual.dist = camAtual.dist + (camAlvo.dist - camAtual.dist) * k
                camAtual.foco = camAtual.foco + (camAlvo.foco - camAtual.foco) * k
                local yaw, pitch = math.rad(camAtual.yaw), math.rad(camAtual.pitch)
                local d = dims.base * camAtual.dist
                local f = camAtual.foco
                local pos = GetOffsetFromEntityInWorldCoords(veh2,
                    f.x + math.sin(yaw) * math.cos(pitch) * d,
                    f.y + math.cos(yaw) * math.cos(pitch) * d,
                    f.z + math.sin(pitch) * d)
                local olha = GetOffsetFromEntityInWorldCoords(veh2, f.x, f.y, f.z)
                SetCamCoord(cam, pos.x, pos.y, pos.z)
                PointCamAtCoord(cam, olha.x, olha.y, olha.z)
            end
            Wait(0)
        end
    end)
end

local function pararCamera()
    if not cam then return end
    RenderScriptCams(false, true, 600, true, true)
    DestroyCam(cam, false)
    cam = nil
end

---------------------------------------------------------------------
-- Abrir / fechar
---------------------------------------------------------------------
local function encerrar(manter)
    if not sessao then return end
    local s = sessao
    SetNuiFocus(false, false)
    SendNUIMessage({ acao = 'fechar' })
    if not manter and DoesEntityExist(s.veh) then
        lib.setVehicleProperties(s.veh, s.props)
    end
    if DoesEntityExist(s.veh) then
        SetVehicleLights(s.veh, 0)
        SetVehicleDoorShut(s.veh, 4, false)
        FreezeEntityPosition(s.veh, false)
    end
    pararCamera()
    sessao = nil
end

local function abrir(tipo, veh)
    if sessao then return end
    if tipo == 'estetica' and not Config.esteticaLigada then
        return Avisar('A oficina de estética ainda não está liberada', 'error')
    end
    if not veh or not DoesEntityExist(veh) then return Avisar('Nenhum carro aqui', 'error') end
    local ok, err = lib.callback.await('pista_estetica:server:abrir', false, VehToNet(veh), tipo)
    if not ok then return Avisar(err or 'Não foi possível abrir', 'error') end
    if not controle(veh) then return Avisar('Não foi possível mexer no carro, tente de novo', 'error') end

    SetVehicleModKit(veh, 0)
    FreezeEntityPosition(veh, true)
    sessao = { tipo = tipo, veh = veh, props = lib.getVehicleProperties(veh), original = {}, labels = {} }

    local dados = {
        acao = 'abrir',
        tipo = tipo,
        placa = qbx and qbx.getVehiclePlate and qbx.getVehiclePlate(veh) or GetVehicleNumberPlateText(veh),
        modelo = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh))),
        precos = Config.precos,
    }
    if tipo == 'pintura' then
        lerPaleta(veh, sessao.props)
        dados.paleta = paletaParaTela()
        dados.alvos = ALVOS_PINTURA
        dados.valores = valoresPintura()
    else
        dados.categorias = categoriasDisponiveis()
    end
    dados.carrinho = carrinho()

    iniciarCamera()
    SendNUIMessage(dados)
    SetNuiFocus(true, true)
end

---------------------------------------------------------------------
-- Tela -> jogo
---------------------------------------------------------------------
RegisterNUICallback('categoria', function(d, cb)
    if not sessao then return cb({}) end
    local cat
    for _, c in ipairs(Listas.categorias) do if c.id == d.id then cat = c end end
    irPara(cat and cat.camera or 'geral')
    sessao.categoria = d.id
    cb({ grupos = gruposDa(d.id), carrinho = carrinho() })
end)

RegisterNUICallback('alvo', function(d, cb)
    if not sessao then return cb({}) end
    for _, a in ipairs(ALVOS_PINTURA) do
        if a.id == d.id then irPara(a.camera) end
    end
    cb({})
end)

RegisterNUICallback('escolher', function(d, cb)
    if not sessao or type(d.grupo) ~= 'string' then return cb({}) end
    aplicarValor(d.grupo, d.valor)
    local resposta = { carrinho = carrinho() }
    if sessao.tipo == 'pintura' then
        resposta.valores = valoresPintura()
    elseif sessao.categoria then
        resposta.grupos = gruposDa(sessao.categoria)
    end
    cb(resposta)
end)

RegisterNUICallback('camMover', function(d, cb)
    cb(1)
    if camAlvo and not camAlvo.fixo then
        camAlvo.yaw = camAlvo.yaw - (tonumber(d.dx) or 0) * 0.3
        camAlvo.pitch = math.max(-5.0, math.min(70.0, camAlvo.pitch + (tonumber(d.dy) or 0) * 0.2))
    end
end)

RegisterNUICallback('camZoom', function(d, cb)
    cb(1)
    if camAlvo and not camAlvo.fixo then
        camAlvo.dist = math.max(0.3, math.min(1.8, camAlvo.dist + (tonumber(d.delta) or 0) * 0.0008))
    end
end)

RegisterNUICallback('cancelar', function(_, cb)
    cb(1)
    encerrar(false)
end)

RegisterNUICallback('clientes', function(_, cb)
    local ids = {}
    for _, p in ipairs(lib.getNearbyPlayers(GetEntityCoords(cache.ped), Config.distanciaCliente, false)) do
        ids[#ids + 1] = GetPlayerServerId(p.id)
    end
    cb(lib.callback.await('pista_estetica:server:clientes', false, ids) or {})
end)

--- Depois de pago: a cabine pinta / o mecânico monta, e o carro é salvo
local function trabalhar(s)
    local veh = s.veh
    if s.tipo == 'pintura' then
        lib.requestNamedPtfxAsset('scr_paintnspray', 3000)
        local pintando = true
        CreateThread(function()
            while pintando and DoesEntityExist(veh) do
                local c = GetEntityCoords(veh)
                for _, off in ipairs({ vec3(2.2, 0.0, 0.3), vec3(-2.2, 0.0, 0.3), vec3(0.0, 2.8, 0.3), vec3(0.0, -2.8, 0.3) }) do
                    local p = GetOffsetFromEntityInWorldCoords(veh, off.x, off.y, off.z)
                    UseParticleFxAsset('scr_paintnspray')
                    StartParticleFxNonLoopedAtCoord('scr_respray_smoke', p.x, p.y, p.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
                end
                if camAlvo and not camAlvo.fixo then camAlvo.yaw = camAlvo.yaw + 6.0 end
                Wait(1200)
            end
        end)
        lib.progressCircle({
            duration = Config.tempos.pintura, label = 'Cabine pintando o carro...', position = 'bottom',
            canCancel = false, disable = { move = true, car = true, combat = true },
        })
        pintando = false
        RemoveNamedPtfxAsset('scr_paintnspray')
    else
        pararCamera()
        lib.progressCircle({
            duration = Config.tempos.estetica, label = 'Montando as peças...', position = 'bottom',
            canCancel = false, disable = { move = true, car = true, combat = true },
            anim = not cache.vehicle and { dict = 'mini@repair', clip = 'fixing_a_ped' } or nil,
        })
    end
    if DoesEntityExist(veh) then
        TriggerServerEvent('pista_estetica:server:salvar', lib.getVehicleProperties(veh))
    end
end

RegisterNUICallback('cobrar', function(d, cb)
    if not sessao then return cb({ ok = false, msg = 'Sessão encerrada' }) end
    local c = carrinho()
    if #c.itens == 0 then return cb({ ok = false, msg = 'Nada foi mudado' }) end
    local chaves = {}
    for _, it in ipairs(c.itens) do chaves[#chaves + 1] = it.id end
    local ok, msg = lib.callback.await('pista_estetica:server:cobrar', false, VehToNet(sessao.veh), sessao.tipo, d.alvo, chaves)
    cb({ ok = ok, msg = msg })
    if not ok then return end
    Avisar(msg, 'success')
    local s = sessao
    SetNuiFocus(false, false)
    SendNUIMessage({ acao = 'fechar' })
    CreateThread(function()
        trabalhar(s)
        encerrar(true)
        Avisar(s.tipo == 'pintura' and 'Pintura pronta!' or 'Estética pronta!', 'success')
    end)
end)

---------------------------------------------------------------------
-- Cliente: aceitar ou recusar a cobrança
---------------------------------------------------------------------
local pedidoAberto = false
lib.callback.register('pista_estetica:client:confirmar', function(info)
    if pedidoAberto then return false end
    pedidoAberto = true
    local respondeu = false
    SetTimeout(Config.tempoResposta * 1000, function()
        if not respondeu then lib.closeAlertDialog() end
    end)
    local r = lib.alertDialog({
        header = 'Cobrança da oficina',
        content = ('**%s** está cobrando **$%d** pelo serviço de %s no carro **%s** (%d %s).\n\nAceita pagar?')
            :format(info.mecanico, info.total, info.servico, info.placa, info.itens, info.itens == 1 and 'item' or 'itens'),
        centered = true,
        cancel = true,
        labels = { confirm = 'Pagar', cancel = 'Recusar' },
    })
    respondeu = true
    pedidoAberto = false
    return r == 'confirm'
end)

---------------------------------------------------------------------
-- Locais: [E] com o carro dentro (mecânico a pé)
---------------------------------------------------------------------
local function carroNoLocal(l)
    -- o mecânico está dirigindo o carro, parado no local
    local veh = cache.vehicle
    if veh and cache.seat == -1 and #(GetEntityCoords(veh) - l.coords.xyz) <= (l.raio or 4.0) then return veh end
    return nil
end

CreateThread(function()
    for _, l in ipairs(Config.locais) do
        if l.tipo == 'estetica' and not Config.esteticaLigada then goto proximo end
        local b = Config.blips[l.tipo]
        if b then
            local blip = AddBlipForCoord(l.coords.x, l.coords.y, l.coords.z)
            SetBlipSprite(blip, b.sprite)
            SetBlipColour(blip, b.cor)
            SetBlipScale(blip, b.escala)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(b.label)
            EndTextCommandSetBlipName(blip)
        end

        local mostrando = false
        local proxima, vehCache = 0, nil
        lib.points.new({
            coords = l.coords.xyz,
            distance = (l.raio or 4.0) + 4.0,
            nearby = function()
                if GetGameTimer() >= proxima then
                    proxima = GetGameTimer() + 300
                    vehCache = (not sessao and souMecanico()) and carroNoLocal(l) or nil
                end
                local veh = (not sessao and vehCache and DoesEntityExist(vehCache)) and vehCache or nil
                if not veh then
                    if mostrando then lib.hideTextUI() mostrando = false end
                    return
                end
                if not mostrando then
                    lib.showTextUI(('[E] %s'):format(l.label), {
                        position = 'left-center',
                        icon = l.tipo == 'pintura' and 'fa-solid fa-spray-can' or 'fa-solid fa-wand-magic-sparkles',
                    })
                    mostrando = true
                end
                if IsControlJustReleased(0, 38) then
                    lib.hideTextUI()
                    mostrando = false
                    abrir(l.tipo, veh)
                end
            end,
            onExit = function()
                if mostrando then lib.hideTextUI() mostrando = false end
            end,
        })
        ::proximo::
    end
end)

-- /estetica [pintura|estetica] (admin): abre no carro mais perto, em qualquer lugar
RegisterNetEvent('pista_estetica:client:abrirTeste', function(tipo)
    if not cache.vehicle or cache.seat ~= -1 then return Avisar('Entre no carro, no banco do motorista', 'error') end
    abrir(tipo, cache.vehicle)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if sessao then encerrar(false) end
end)
