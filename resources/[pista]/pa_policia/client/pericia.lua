-- pa_policia · cliente · perícia
-- Todos: deixam cápsula ao atirar, sangue ao se ferir e digital no volante sem luva.
-- Polícia: vê as evidências com a lanterna (ou bem de perto), coleta com [E] e analisa no laboratório.

local evidencias = {}   -- [id] = { id, tipo, coords, rotulo }

---------------------------------------------------------------------
-- QUEM DEIXA EVIDÊNCIA
---------------------------------------------------------------------
local function semLuva()
    local arms = GetPedDrawableVariation(cache.ped, 3)
    local lista = IsPedMale(cache.ped) and Config.pericia.semLuva.male or Config.pericia.semLuva.female
    return lista[arms] == true
end

-- tiro
CreateThread(function()
    local ultimo = 0
    while true do
        local espera = 500
        if cache.weapon and cache.weapon ~= `WEAPON_UNARMED` then
            espera = 0
            if IsPedShooting(cache.ped) and GetGameTimer() - ultimo > 1000 then
                ultimo = GetGameTimer()
                local c = GetOffsetFromEntityInWorldCoords(cache.ped, math.random(-10, 10) / 10, math.random(5, 15) / 10, 0.0)
                local ok, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
                TriggerServerEvent('pa_policia:server:tiro', vec3(c.x, c.y, ok and z or c.z - 0.9), {
                    silenciado = IsPedCurrentWeaponSilenced(cache.ped),
                    veiculo = cache.vehicle and PC.InfoVeiculo(cache.vehicle) or nil,
                })
            end
        end
        Wait(espera)
    end
end)

-- sangue
AddEventHandler('gameEventTriggered', function(nome, args)
    if nome ~= 'CEventNetworkEntityDamage' then return end
    if args[1] ~= cache.ped then return end
    local arma = args[7]
    if not arma or arma == `WEAPON_UNARMED` or arma == `WEAPON_FALL` then return end
    if math.random(100) > Config.pericia.chanceSangue then return end
    local c = GetEntityCoords(cache.ped)
    local ok, z = GetGroundZFor_3dCoord(c.x, c.y, c.z, false)
    TriggerServerEvent('pa_policia:server:sangue', vec3(c.x, c.y, ok and z or c.z - 0.9))
end)

-- digital no volante
lib.onCache('seat', function(banco)
    if banco ~= -1 then return end
    Wait(500)
    if cache.vehicle and semLuva() then
        TriggerServerEvent('pa_policia:server:digital', NetworkGetNetworkIdFromEntity(cache.vehicle))
    end
end)

-- nadar lava a pólvora da mão
CreateThread(function()
    while true do
        Wait(3000)
        if IsPedSwimming(cache.ped) then TriggerServerEvent('pa_policia:server:lavouMao') end
    end
end)

---------------------------------------------------------------------
-- POLÍCIA: VER E COLETAR
---------------------------------------------------------------------
RegisterNetEvent('pa_policia:client:evidencia', function(e)
    if GetInvokingResource() then return end
    evidencias[e.id] = e
end)

RegisterNetEvent('pa_policia:client:evidencias', function(lista)
    if GetInvokingResource() then return end
    evidencias = {}
    for _, e in ipairs(lista) do evidencias[e.id] = e end
end)

RegisterNetEvent('pa_policia:client:removerEvidencia', function(id)
    if GetInvokingResource() then return end
    evidencias[id] = nil
end)

AddEventHandler('pa_policia:client:saiuServico', function() evidencias = {} end)

local function texto3d(c, txt)
    SetTextScale(0.3, 0.3)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextColour(255, 255, 255, 215)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(txt)
    SetDrawOrigin(c.x, c.y, c.z + 0.25, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local coletando = false

-- lanterna acesa: lanterna na mão mirando ou lanterna presa na arma ligada
local function lanternaAcesa()
    if IsFlashLightOn(cache.ped) then return true end
    return cache.weapon == `WEAPON_FLASHLIGHT` and IsPlayerFreeAiming(cache.playerId)
end

-- a evidência está dentro do facho? (cone a partir da câmera, para onde a lanterna aponta)
local function noFacho(origem, direcao, alvo)
    local v = alvo - origem
    local d = #v
    if d > Config.pericia.distanciaVer or d < 0.01 then return false, d end
    local cos = (v.x * direcao.x + v.y * direcao.y + v.z * direcao.z) / d
    return cos >= math.cos(math.rad(Config.pericia.anguloLanterna)), d
end

local function direcaoCamera()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    return vec3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
end

CreateThread(function()
    while true do
        local espera = 1000
        if next(evidencias) and PC.Pode('pericia') then
            local pos = GetEntityCoords(cache.ped)
            local perto = false
            for _, e in pairs(evidencias) do
                if #(pos - e.coords) < 30.0 then perto = true break end
            end
            if perto then espera = 200 end
            if perto and lanternaAcesa() then
                espera = 0
                local cam = GetGameplayCamCoord()
                local dir = direcaoCamera()
                local maisPerto, distPerto
                for _, e in pairs(evidencias) do
                    local visivel = noFacho(cam, dir, e.coords)
                    if visivel then
                        local dPed = #(pos - e.coords)
                        -- brilho pequeno no chão, como metal/sangue refletindo a luz
                        if e.tipo == 'sangue' then
                            DrawMarker(23, e.coords.x, e.coords.y, e.coords.z + 0.02, 0, 0, 0, 0, 0, 0, 0.18, 0.18, 0.18, 120, 0, 0, 170, false, false, 2, false, nil, nil, false)
                        else
                            DrawMarker(28, e.coords.x, e.coords.y, e.coords.z + 0.03, 0, 0, 0, 0, 0, 0, 0.035, 0.035, 0.035, 255, 205, 90, 230, false, false, 2, false, nil, nil, false)
                        end
                        if dPed < 2.5 then texto3d(e.coords, e.rotulo) end
                        if dPed < 1.5 and (not distPerto or dPed < distPerto) then maisPerto, distPerto = e, dPed end
                    end
                end
                if maisPerto and not coletando then
                    texto3d(maisPerto.coords + vec3(0, 0, 0.15), '[E] Coletar')
                    if IsControlJustPressed(0, 38) then
                        coletando = true
                        local alvo = maisPerto
                        CreateThread(function()
                            if lib.progressCircle({ duration = 2500, label = 'Coletando evidência...', position = 'bottom', canCancel = true,
                                disable = { move = true, combat = true }, anim = { dict = 'pickup_object', clip = 'pickup_low' } }) then
                                local ok, msg = lib.callback.await('pa_policia:server:coletar', false, alvo.id, PC.NomeDaArea(alvo.coords))
                                PC.Resultado(ok, msg)
                            end
                            coletando = false
                        end)
                    end
                end
            end
        end
        Wait(espera)
    end
end)

---------------------------------------------------------------------
-- LABORATÓRIO
---------------------------------------------------------------------
AddEventHandler('pa_policia:client:laboratorio', function()
    local sacos = lib.callback.await('pa_policia:server:sacosParaAnalise', false) or {}
    if #sacos == 0 then return PC.Aviso('Você não tem evidências para analisar.', 'inform') end
    local opcoes = {}
    for _, s in ipairs(sacos) do
        opcoes[#opcoes + 1] = {
            title = s.label, description = s.descricao, icon = 'vial',
            onSelect = function()
                if lib.progressCircle({ duration = 8000, label = 'Analisando...', position = 'bottom', canCancel = true,
                    disable = { move = true, combat = true }, anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' } }) then
                    local ok, msg = lib.callback.await('pa_policia:server:analisar', false, s.slot)
                    if msg then PC.Aviso(msg, ok and 'success' or 'error', 12000) end
                end
            end,
        }
    end
    lib.registerContext({ id = 'pa_policia_lab', title = 'Laboratório da LSPD', options = opcoes })
    lib.showContext('pa_policia_lab')
end)
