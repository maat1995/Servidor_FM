-- pa_medico · ambulância NPC
-- Só aparece quando não tem médico em serviço. Nasce numa rua perto, vem de sirene,
-- o socorrista desce, faz massagem cardíaca e o servidor reanima o jogador.

local ativo = false
local cancelado = false
local veiculo, socorrista, blip

local function carregarModelo(modelo)
    local hash = type(modelo) == 'string' and joaat(modelo) or modelo
    if not IsModelInCdimage(hash) then return nil end
    lib.requestModel(hash, 10000)
    return hash
end

---Acha um ponto de rua a uma certa distância do corpo para a ambulância nascer
local function pontoDeSaida(alvo)
    local dist = Config.npc.distanciaSaida
    for _ = 1, 24 do
        local ang = math.random() * math.pi * 2
        local x, y = alvo.x + math.cos(ang) * dist, alvo.y + math.sin(ang) * dist
        local achou, pos, heading = GetClosestVehicleNodeWithHeading(x, y, alvo.z, 1, 3.0, 0)
        if achou and #(pos - alvo) > dist * 0.5 and not IsSphereVisible(pos.x, pos.y, pos.z, 4.0) then
            return pos, heading
        end
    end
    local achou, pos, heading = GetNthClosestVehicleNodeWithHeading(alvo.x, alvo.y, alvo.z, 30, 1, 3.0, 0)
    if achou then return pos, heading end
    return nil
end

local function limpar(irEmbora)
    local v, p, b = veiculo, socorrista, blip
    veiculo, socorrista, blip = nil, nil, nil
    if b and DoesBlipExist(b) then RemoveBlip(b) end
    if not v and not p then return end

    CreateThread(function()
        if irEmbora and p and DoesEntityExist(p) and v and DoesEntityExist(v) then
            ClearPedTasks(p)
            if not IsPedInVehicle(p, v, false) then
                TaskEnterVehicle(p, v, 15000, -1, 2.0, 1, 0)
                local limite = GetGameTimer() + 15000
                while DoesEntityExist(p) and not IsPedInVehicle(p, v, false) and GetGameTimer() < limite do Wait(250) end
            end
            if DoesEntityExist(p) and IsPedInVehicle(p, v, false) then
                SetVehicleSiren(v, false)
                TaskVehicleDriveWander(p, v, 18.0, 786603)
            end
            Wait(25000)
        end
        if p and DoesEntityExist(p) then SetEntityAsNoLongerNeeded(p) DeleteEntity(p) end
        if v and DoesEntityExist(v) then SetEntityAsNoLongerNeeded(v) DeleteEntity(v) end
    end)
end

---Coloca o socorrista ajoelhado ao lado do peito do jogador, virado para ele.
---O eixo do corpo vem dos ossos (cabeça -> quadril), porque a animação de
---caído gira o corpo e o heading da entidade não diz para onde ele está deitado.
function PosicionarParaRCP(ped)
    local peito = GetPedBoneCoords(cache.ped, 24817, 0.0, 0.0, 0.0)   -- SKEL_Spine2
    local cabeca = GetPedBoneCoords(cache.ped, 31086, 0.0, 0.0, 0.0)  -- SKEL_Head
    local quadril = GetPedBoneCoords(cache.ped, 11816, 0.0, 0.0, 0.0) -- SKEL_Pelvis

    local eixo = vec2(cabeca.x - quadril.x, cabeca.y - quadril.y)
    if #eixo < 0.05 then eixo = vec2(0.0, 1.0) end
    eixo = eixo / #eixo
    local lado = vec2(-eixo.y, eixo.x)

    -- Usa o lado do corpo onde o socorrista já está (não atravessa o paciente)
    local atual = GetEntityCoords(ped)
    if (atual.x - peito.x) * lado.x + (atual.y - peito.y) * lado.y < 0 then lado = -lado end

    local distancia = Config.npc.distanciaRCP or 0.55
    local x, y = peito.x + lado.x * distancia, peito.y + lado.y * distancia
    local achou, chao = GetGroundZFor_3dCoord(x, y, peito.z + 1.0, false)
    local z = achou and chao or (GetEntityCoords(cache.ped).z - 1.0)

    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, GetHeadingFromVector_2d(peito.x - x, peito.y - y))
end

function CancelarAmbulanciaNpc()
    if not ativo then return end
    cancelado = true
end

local function falhou()
    limpar(false)
    lib.callback.await('pa_medico:server:npcCancelar', false)
    Desmaio.npc, Desmaio.status, Desmaio.progressoNpc, Desmaio.npcChegou = false, nil, nil, false
    lib.notify({ type = 'error', description = 'A ambulância não conseguiu chegar. Tente chamar de novo.' })
    ativo = false
end

function IniciarAmbulanciaNpc()
    if ativo then return end
    ativo, cancelado = true, false

    CreateThread(function()
        local alvo = GetEntityCoords(cache.ped)
        local modeloVeiculo = carregarModelo(Config.npc.veiculo)
        local modeloPed = carregarModelo(Config.npc.socorrista)
        if not modeloVeiculo or not modeloPed then return falhou() end

        local saida, heading = pontoDeSaida(alvo)
        if not saida then return falhou() end

        veiculo = CreateVehicle(modeloVeiculo, saida.x, saida.y, saida.z + 0.5, heading, true, false)
        if not veiculo or veiculo == 0 then return falhou() end
        SetEntityAsMissionEntity(veiculo, true, true)
        SetVehicleOnGroundProperly(veiculo)
        SetVehicleEngineOn(veiculo, true, true, false)
        SetVehicleDoorsLocked(veiculo, 2)
        if Config.npc.sirene then SetVehicleSiren(veiculo, true) end

        socorrista = CreatePedInsideVehicle(veiculo, 26, modeloPed, -1, true, false)
        SetEntityAsMissionEntity(socorrista, true, true)
        SetBlockingOfNonTemporaryEvents(socorrista, true)
        SetPedFleeAttributes(socorrista, 0, false)
        SetPedCanBeDraggedOut(socorrista, false)
        SetPedKeepTask(socorrista, true)
        SetDriverAbility(socorrista, 1.0)
        SetDriverAggressiveness(socorrista, 0.6)
        SetModelAsNoLongerNeeded(modeloVeiculo)
        SetModelAsNoLongerNeeded(modeloPed)

        blip = AddBlipForEntity(veiculo)
        SetBlipSprite(blip, 56)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 0.8)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Ambulância')
        EndTextCommandSetBlipName(blip)

        -- Vai até a rua mais perto do corpo
        local _, destino = GetClosestVehicleNode(alvo.x, alvo.y, alvo.z, 1, 3.0, 0)
        destino = destino or alvo
        TaskVehicleDriveToCoordLongrange(socorrista, veiculo, destino.x, destino.y, destino.z, 26.0, 787004, 12.0)

        local limite = GetGameTimer() + Config.npc.tempoMaxViagem * 1000
        while not cancelado do
            if not DoesEntityExist(veiculo) or not DoesEntityExist(socorrista) or IsEntityDead(socorrista) then
                return falhou()
            end
            local dist = #(GetEntityCoords(veiculo) - alvo)
            if dist < 22.0 then break end
            if GetGameTimer() > limite then
                -- Ficou preso no caminho: aparece perto do corpo
                local _, perto, h = GetClosestVehicleNodeWithHeading(alvo.x, alvo.y, alvo.z, 1, 3.0, 0)
                perto = perto or alvo
                SetEntityCoords(veiculo, perto.x, perto.y, perto.z + 0.5, false, false, false, false)
                SetEntityHeading(veiculo, h or 0.0)
                SetVehicleOnGroundProperly(veiculo)
                break
            end
            Wait(500)
        end
        if cancelado then ativo = false return limpar(true) end

        -- Para e desce
        TaskVehicleTempAction(socorrista, veiculo, 27, 3000)
        Wait(1200)
        TaskLeaveVehicle(socorrista, veiculo, 0)
        local t = GetGameTimer() + 6000
        while IsPedInAnyVehicle(socorrista, false) and GetGameTimer() < t and not cancelado do Wait(200) end
        if cancelado then ativo = false return limpar(true) end

        -- Anda até o paciente
        alvo = GetEntityCoords(cache.ped)
        TaskGoToEntity(socorrista, cache.ped, -1, 1.1, 2.5, 1073741824, 0)
        t = GetGameTimer() + 25000
        while #(GetEntityCoords(socorrista) - alvo) > 1.6 and GetGameTimer() < t and not cancelado do Wait(250) end
        if cancelado then ativo = false return limpar(true) end
        if #(GetEntityCoords(socorrista) - alvo) > 1.6 then
            local frente = GetOffsetFromEntityInWorldCoords(cache.ped, 0.9, 0.0, 0.0)
            SetEntityCoords(socorrista, frente.x, frente.y, frente.z - 1.0, false, false, false, false)
        end

        -- Massagem cardíaca: ajoelha encostado no peito, de frente para o corpo
        ClearPedTasks(socorrista)
        lib.requestAnimDict('mini@cpr@char_a@cpr_str')
        PosicionarParaRCP(socorrista)
        TaskPlayAnim(socorrista, 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest', 8.0, -8.0, -1, 1, 0, false, false, false)

        Desmaio.npcChegou = true
        Desmaio.status = Config.textos.ambulanciaChegou
        local inicio = GetGameTimer()
        local duracao = Config.npc.tempoRCP * 1000
        while GetGameTimer() - inicio < duracao and not cancelado do
            Desmaio.progressoNpc = (GetGameTimer() - inicio) / duracao
            Wait(100)
        end
        Desmaio.progressoNpc = nil
        if cancelado then ativo = false return limpar(true) end

        -- O servidor confere o tempo e reanima
        local ok = false
        for _ = 1, 5 do
            ok = lib.callback.await('pa_medico:server:npcConcluir', false)
            if ok then break end
            Wait(1000)
        end
        RemoveAnimDict('mini@cpr@char_a@cpr_str')
        ativo = false
        if ok then
            limpar(true)
        else
            falhou()
        end
    end)
end
