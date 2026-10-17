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
                TriggerServerEvent('pa_policia:server:tiro', vec3(c.x, c.y, ok and z or c.z - 0.9))
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

CreateThread(function()
    while true do
        local espera = 1000
        if next(evidencias) and PC.Pode('pericia') then
            local pos = GetEntityCoords(cache.ped)
            local lanterna = cache.weapon == `WEAPON_FLASHLIGHT` and IsPlayerFreeAiming(cache.playerId)
            local maisPerto, distPerto
            for _, e in pairs(evidencias) do
                local d = #(pos - e.coords)
                if d < 25.0 then espera = 0 end
                if (lanterna and d < 25.0) or d < 2.5 then
                    local cor = e.tipo == 'sangue' and { 200, 20, 20 } or { 230, 190, 40 }
                    DrawMarker(28, e.coords.x, e.coords.y, e.coords.z + 0.05, 0, 0, 0, 0, 0, 0, 0.12, 0.12, 0.12, cor[1], cor[2], cor[3], 200, false, false, 2, false, nil, nil, false)
                    if d < 6.0 then texto3d(e.coords, e.rotulo) end
                    if d < 1.5 and (not distPerto or d < distPerto) then maisPerto, distPerto = e, d end
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
