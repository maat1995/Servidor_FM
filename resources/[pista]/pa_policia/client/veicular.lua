-- pa_policia · cliente · fiscalização veicular
-- Blitz (objetos com prévia), tapete de pregos, vistoria, radares fixos, radar móvel e chamado do guincho.

local OBJ_BAG = 'pa_policia_obj'
local placasProcuradas = {}

RegisterNetEvent('pa_policia:client:placas', function(lista)
    if GetInvokingResource() then return end
    placasProcuradas = lista or {}
end)

local function trim(s) return ((s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

---------------------------------------------------------------------
-- BLITZ: colocar objeto com prévia
---------------------------------------------------------------------
local colocando = false

local function raycastFrente(dist)
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vec3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local destino = cam + dir * dist
    local ray = StartShapeTestLosProbe(cam.x, cam.y, cam.z, destino.x, destino.y, destino.z, 1 + 16, cache.ped, 4)
    local status, hit, coords
    repeat
        status, hit, coords = GetShapeTestResult(ray)
        Wait(0)
    until status ~= 1
    if hit == true or hit == 1 then return coords end
    return destino
end

local function colocar(cfg)
    if colocando then return end
    colocando = true
    lib.requestModel(cfg.modelo)
    local fantasma = CreateObject(cfg.modelo, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(fantasma, 160, false)
    SetEntityCollision(fantasma, false, false)
    FreezeEntityPosition(fantasma, true)
    local heading = GetEntityHeading(cache.ped)
    lib.showTextUI('[E] Colocar  ·  [Roda do mouse] Girar  ·  [Backspace] Cancelar', { position = 'left-center' })

    local final
    while true do
        Wait(0)
        DisableControlAction(0, 14, true)
        DisableControlAction(0, 15, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        local c = raycastFrente(7.0)
        local dist = #(c - GetEntityCoords(cache.ped))
        if dist > 6.0 then
            local dir = (c - GetEntityCoords(cache.ped)) / dist
            c = GetEntityCoords(cache.ped) + dir * 6.0
        end
        SetEntityCoords(fantasma, c.x, c.y, c.z, false, false, false, false)
        SetEntityHeading(fantasma, heading)
        PlaceObjectOnGroundProperly(fantasma)
        if IsDisabledControlPressed(0, 14) then heading = (heading + 4.0) % 360 end
        if IsDisabledControlPressed(0, 15) then heading = (heading - 4.0) % 360 end
        if IsControlJustPressed(0, 38) then
            final = GetEntityCoords(fantasma)
            break
        end
        if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 194) or cache.vehicle then break end
    end

    lib.hideTextUI()
    DeleteEntity(fantasma)
    SetModelAsNoLongerNeeded(cfg.modelo)
    if final then
        lib.requestAnimDict('pickup_object')
        TaskPlayAnim(cache.ped, 'pickup_object', 'pickup_low', 8.0, -8.0, 1000, 0, 0, false, false, false)
        Wait(700)
        local ok, msg = lib.callback.await('pa_policia:server:colocarObjeto', false, cfg.id, final, heading)
        if not ok then PC.Aviso(msg, 'error') end
    end
    colocando = false
end

AddEventHandler('pa_policia:client:menuBlitz', function()
    if not PC.Pode('objetos') then return end
    local opcoes = {}
    for _, o in ipairs(Config.objetos.lista) do
        opcoes[#opcoes + 1] = { title = o.label, icon = o.tapete and 'road-spikes' or 'road-barrier', onSelect = function() colocar(o) end }
    end
    lib.registerContext({ id = 'pa_policia_blitz', title = 'Blitz', options = opcoes })
    lib.showContext('pa_policia_blitz')
end)
RegisterCommand('blitz', function() TriggerEvent('pa_policia:client:menuBlitz') end, false)

-- painel F6: coloca direto o objeto escolhido
AddEventHandler('pa_policia:client:colocarObjeto', function(id)
    if not PC.Pode('objetos') then return end
    for _, o in ipairs(Config.objetos.lista) do
        if o.id == id then return colocar(o) end
    end
end)

-- recolher
CreateThread(function()
    local modelos = {}
    for _, o in ipairs(Config.objetos.lista) do modelos[#modelos + 1] = o.modelo end
    exports.ox_target:addModel(modelos, {
        {
            name = 'pa_policia_recolher', icon = 'fa-solid fa-hand', label = 'Recolher',
            distance = 3.0,
            canInteract = function(ent) return PC.EmServico() and Entity(ent).state[OBJ_BAG] ~= nil end,
            onSelect = function(data)
                local ok, msg = lib.callback.await('pa_policia:server:recolherObjeto', false, ObjToNet(data.entity))
                if not ok then PC.Aviso(msg, 'error') end
            end,
        },
    })
end)

---------------------------------------------------------------------
-- TAPETE DE PREGOS
---------------------------------------------------------------------
local modeloTapete
for _, o in ipairs(Config.objetos.lista) do if o.tapete then modeloTapete = o.modelo end end
local RODAS = { { 'wheel_lf', 0 }, { 'wheel_rf', 1 }, { 'wheel_lm1', 2 }, { 'wheel_rm1', 3 }, { 'wheel_lr', 4 }, { 'wheel_rr', 5 } }

CreateThread(function()
    if not modeloTapete then return end
    while true do
        local espera = 500
        local veh = cache.vehicle
        if veh and cache.seat == -1 then
            local pos = GetEntityCoords(veh)
            local tapete = GetClosestObjectOfType(pos.x, pos.y, pos.z, 20.0, modeloTapete, false, false, false)
            if tapete ~= 0 and Entity(tapete).state[OBJ_BAG] then
                espera = 0
                local tp = GetEntityCoords(tapete)
                for _, r in ipairs(RODAS) do
                    local bone = GetEntityBoneIndexByName(veh, r[1])
                    if bone ~= -1 and not IsVehicleTyreBurst(veh, r[2], false) then
                        local wp = GetWorldPositionOfEntityBone(veh, bone)
                        -- tapete é comprido: compara no eixo dele
                        local rel = GetOffsetFromEntityGivenWorldCoords(tapete, wp.x, wp.y, wp.z)
                        if math.abs(rel.x) < 2.0 and math.abs(rel.y) < 0.45 and math.abs(rel.z) < 1.2 and #(wp - tp) < 3.0 then
                            SetVehicleTyreBurst(veh, r[2], false, 1000.0)
                        end
                    end
                end
            end
        end
        Wait(espera)
    end
end)

---------------------------------------------------------------------
-- VISTORIA
---------------------------------------------------------------------
AddEventHandler('pa_policia:client:vistoria', function(veh)
    if lib.progressCircle({ duration = 6000, label = 'Vistoriando o veículo...', position = 'bottom', canCancel = true,
        disable = { move = true, combat = true }, anim = { dict = 'amb@code_human_police_investigate@idle_a', clip = 'idle_b' } }) == false then
        return
    end
    local ok, r = lib.callback.await('pa_policia:server:vistoria', false, NetworkGetNetworkIdFromEntity(veh))
    if not ok then return PC.Aviso(r, 'error') end

    local opcoes = {
        { title = ('Dono: %s'):format(r.dono), icon = 'user', readOnly = true },
        { title = r.laudo and ('Laudo do dinamômetro: %s %s'):format(r.laudo, r.laudoValido and '(válido)' or '(vencido)') or 'Sem laudo do dinamômetro',
          icon = 'file-lines', iconColor = r.laudoValido and '#97C459' or '#EF9F27', readOnly = true },
    }
    if r.procurado then
        table.insert(opcoes, 1, { title = 'PLACA PROCURADA', description = r.procurado, icon = 'triangle-exclamation', iconColor = '#E24B4A', readOnly = true })
    end
    if #r.itens == 0 then
        opcoes[#opcoes + 1] = { title = 'Nenhuma peça de preparação controlada', icon = 'circle-check', iconColor = '#97C459', readOnly = true }
    end
    for _, i in ipairs(r.itens) do
        opcoes[#opcoes + 1] = {
            title = i.label,
            description = i.irregular and (('Irregular · multa $%d%s'):format(i.multa, i.apreender and ' · apreensão' or '')) or 'Regular (com laudo)',
            icon = i.irregular and 'circle-xmark' or 'circle-check',
            iconColor = i.irregular and '#E24B4A' or '#97C459',
            readOnly = true,
        }
    end
    if r.multa > 0 then
        opcoes[#opcoes + 1] = { title = ('Multar o dono ($%d)'):format(r.multa), icon = 'receipt', onSelect = function()
            local ok2, msg = lib.callback.await('pa_policia:server:vistoriaAcao', false, 'multar')
            PC.Resultado(ok2, msg)
        end }
    end
    if r.apreender and PC.Pode('apreender') then
        opcoes[#opcoes + 1] = { title = 'Reter o veículo no pátio', icon = 'lock', iconColor = '#E24B4A', onSelect = function()
            local ok2, msg = lib.callback.await('pa_policia:server:vistoriaAcao', false, 'apreender')
            PC.Resultado(ok2, msg)
        end }
    end
    lib.registerContext({ id = 'pa_policia_vistoria', title = ('Vistoria · %s'):format(r.plate), options = opcoes })
    lib.showContext('pa_policia_vistoria')
end)

---------------------------------------------------------------------
-- RADARES FIXOS
---------------------------------------------------------------------
CreateThread(function()
    if not Config.radares.ativo then return end
    if Config.radares.blip then
        for _, r in ipairs(Config.radares.locais) do
            local b = AddBlipForCoord(r.coords.x, r.coords.y, r.coords.z)
            SetBlipSprite(b, 184)
            SetBlipScale(b, 0.6)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(('Radar %d km/h'):format(r.limite))
            EndTextCommandSetBlipName(b)
        end
    end
    local passou = {}
    while true do
        local espera = 1000
        local veh = cache.vehicle
        if veh and cache.seat == -1 then
            espera = 250
            local pos = GetEntityCoords(veh)
            for i, r in ipairs(Config.radares.locais) do
                local d = #(pos - r.coords)
                if d <= Config.radares.raio then
                    if not passou[i] or GetGameTimer() - passou[i] > 60000 then
                        passou[i] = GetGameTimer()
                        TriggerServerEvent('pa_policia:server:radar', i, GetEntitySpeed(veh) * 3.6)
                    end
                end
            end
        end
        Wait(espera)
    end
end)

RegisterNetEvent('pa_policia:client:flashRadar', function()
    if GetInvokingResource() then return end
    AnimpostfxPlay('CamPushInNeutral', 500, false)
    PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_Soundset_Franklin', true)
end)

---------------------------------------------------------------------
-- RADAR MÓVEL (/radar)
---------------------------------------------------------------------
local radarLigado = false
function PC.RadarLigado() return radarLigado end

-- carro mais perto na frente (ou atrás) da viatura, dentro de uma faixa que abre com a distância
local function veiculoNaDirecao(veh, frente)
    local melhor, menor
    local alcance = Config.radarMovel.distancia
    local minha = GetEntityCoords(veh)
    for _, outro in ipairs(GetGamePool('CVehicle')) do
        if outro ~= veh and DoesEntityExist(outro) then
            local pos = GetEntityCoords(outro)
            if #(pos - minha) <= alcance then
                local rel = GetOffsetFromEntityGivenWorldCoords(veh, pos.x, pos.y, pos.z)
                local y = frente and rel.y or -rel.y
                local largura = 3.5 + y * 0.12
                if y > 2.0 and math.abs(rel.x) <= largura and math.abs(rel.z) < 6.0 and (not menor or y < menor) then
                    melhor, menor = outro, y
                end
            end
        end
    end
    return melhor
end

local function infoVeiculo(ent)
    if not ent then return nil end
    local placa = trim(GetVehicleNumberPlateText(ent))
    return {
        placa = placa,
        vel = math.floor(GetEntitySpeed(ent) * 3.6),
        modelo = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(ent))),
        procurado = placasProcuradas[placa],
    }
end

RegisterCommand('radar', function()
    if not PC.Pode('radarMovel') then return PC.Aviso('Radar móvel: a partir de Oficial 2, em serviço.', 'error') end
    if not radarLigado and (not cache.vehicle or (GetVehicleClass(cache.vehicle) ~= 18 and not Entity(cache.vehicle).state.pa_viatura)) then
        return PC.Aviso('Use dentro de uma viatura.', 'error')
    end
    radarLigado = not radarLigado
    SendNUIMessage({ acao = 'radar', ligado = radarLigado })
    if not radarLigado then return end
    CreateThread(function()
        local alertados = {}
        while radarLigado do
            local veh = cache.vehicle
            if not veh or not PC.EmServico() then
                radarLigado = false
                break
            end
            local frente = infoVeiculo(veiculoNaDirecao(veh, true))
            local tras = infoVeiculo(veiculoNaDirecao(veh, false))
            for _, info in ipairs({ frente or false, tras or false }) do
                if info and info.procurado and not alertados[info.placa] then
                    alertados[info.placa] = true
                    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
                    PC.Aviso(('PLACA PROCURADA %s: %s'):format(info.placa, info.procurado), 'error', 8000)
                end
            end
            SendNUIMessage({ acao = 'radarDados', frente = frente, tras = tras, propria = math.floor(GetEntitySpeed(veh) * 3.6) })
            Wait(250)
        end
        SendNUIMessage({ acao = 'radar', ligado = false })
    end)
end, false)

---------------------------------------------------------------------
-- MECÂNICO: chamado do guincho
---------------------------------------------------------------------
RegisterNetEvent('pa_policia:client:chamadoGuincho', function(d)
    if GetInvokingResource() then return end
    local b = AddBlipForCoord(d.x, d.y, d.z)
    SetBlipSprite(b, 68)
    SetBlipColour(b, 47)
    SetBlipFlashes(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('Guincho LSPD · %s'):format(d.plate))
    EndTextCommandSetBlipName(b)
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', false)
    lib.notify({
        title = 'LSPD · guincho',
        description = ('Levar o carro %s até o pátio da DP de Mission Row. Local marcado no mapa.'):format(d.plate),
        type = 'inform', duration = 12000,
    })
    SetTimeout(Config.patio.tempoGuincho * 1000, function() if DoesBlipExist(b) then RemoveBlip(b) end end)
end)
