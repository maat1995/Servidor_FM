-- pa_handling - calibração automática
-- O próprio script dirige: acelera em linha reta, mede o 0-100 e a velocidade
-- final, corrige a handling e repete até bater com a ficha.

local cfg = Config.calibracao
local rodando = false
local cancelar = false

local function avisar(msg, tipo)
    exports.qbx_core:Notify(msg, tipo or 'inform', 6000)
    print('[pa_handling] ' .. msg)
end

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

local function carregarModelo(modelo)
    local hash = joaat(modelo)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    RequestModel(hash)
    local limite = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > limite then return nil end
        Wait(50)
    end
    return hash
end

---------------------------------------------------------------------
-- Uma medição: arranca parado, acelera tudo em linha reta
---------------------------------------------------------------------
-- Volta o carro para o começo da reta quando passa da distância, mantendo a
-- velocidade, então qualquer reta de uns 400 m serve.
local function medir(hash, origem, heading, alvo)
    local ped = cache.ped
    local veh = CreateVehicle(hash, origem.x, origem.y, origem.z + 0.3, heading, true, false)
    local limite = GetGameTimer() + 5000
    while not DoesEntityExist(veh) do
        if GetGameTimer() > limite then return nil, nil, 'não foi possível criar o carro' end
        Wait(0)
    end
    SetVehicleOnGroundProperly(veh)
    SetEntityInvincible(veh, true)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleFuelLevel(veh, 100.0)
    SetVehicleNumberPlateText(veh, 'CALIBRA')
    SetVehicleModKit(veh, 0)
    local st = Entity(veh).state
    st:set('pa_cambio_auto', true, true)  -- câmbio automático no teste
    st:set('fuel', 100.0, true)
    TriggerServerEvent('pa_handling:server:chaves', VehToNet(veh))
    TaskWarpPedIntoVehicle(ped, veh, -1)
    Wait(300)
    SetVehicleEngineOn(veh, true, true, false)
    ModifyVehicleTopSpeed(veh, 1.0)
    Wait(1500) -- assentar na suspensão
    local arrastoLido = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDragCoeff')

    local frente = vector3(-math.sin(math.rad(heading)), math.cos(math.rad(heading)), 0.0)
    local direita = vector3(frente.y, -frente.x, 0.0)
    local zBase = GetEntityCoords(veh).z - origem.z

    local inicio = GetGameTimer()
    local tMarco, vMax = nil, 0.0
    local amostras = {} -- velocidade a cada segundo
    local proxAmostra = inicio + 1000
    local erro

    while true do
        Wait(0)
        if cancelar then erro = 'cancelado'; break end
        if not DoesEntityExist(veh) or GetPedInVehicleSeat(veh, -1) ~= ped then
            erro = 'saiu do carro'; break
        end
        local agora = GetGameTimer()
        local t = (agora - inicio) / 1000.0

        if not GetIsVehicleEngineRunning(veh) then SetVehicleEngineOn(veh, true, true, false) end
        SetControlNormal(0, 71, 1.0) -- acelera tudo
        SetControlNormal(0, 72, 0.0)

        -- mantém reto (direção e distância da linha)
        local pos = GetEntityCoords(veh)
        local d = pos - origem
        local andou = d.x * frente.x + d.y * frente.y
        local lateral = d.x * direita.x + d.y * direita.y
        local erroAng = ((GetEntityHeading(veh) - heading + 540.0) % 360.0) - 180.0
        SetControlNormal(0, 59, clamp(erroAng * 0.05 - lateral * 0.08, -0.6, 0.6))
        if math.abs(erroAng) > 25.0 then erro = 'o carro rodou (reta irregular?)'; break end

        -- fim da reta: volta para o começo com a mesma velocidade
        if andou > cfg.distancia then
            local vel = GetEntityVelocity(veh)
            local v = vel.x * frente.x + vel.y * frente.y
            local dz = pos.z - origem.z - zBase
            SetEntityCoordsNoOffset(veh, origem.x, origem.y, origem.z + zBase + math.max(dz, 0.0), false, false, false)
            SetEntityHeading(veh, heading)
            SetEntityVelocity(veh, frente.x * v, frente.y * v, vel.z)
        end

        local kmh = GetEntitySpeed(veh) * 3.6
        if kmh > vMax then vMax = kmh end
        if not tMarco and kmh >= alvo.marco then tMarco = t end

        if agora >= proxAmostra then
            proxAmostra = agora + 1000
            amostras[#amostras + 1] = kmh
            local n = #amostras
            -- velocidade final: parou de subir (menos de 0,5 km/h em 4 s)
            if tMarco and n >= 5 and amostras[n] - amostras[n - 4] < 0.5 then break end
        end
        if t > cfg.tempoMax then break end
    end

    SetControlNormal(0, 71, 0.0)
    if DoesEntityExist(veh) then
        TaskLeaveVehicle(ped, veh, 16)
        Wait(100)
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end
    SetEntityCoords(ped, origem.x, origem.y, origem.z, false, false, false, false)
    SetEntityHeading(ped, heading)
    return tMarco, vMax, erro, arrastoLido
end

---------------------------------------------------------------------
-- Calibra uma handling: mede, corrige e repete
---------------------------------------------------------------------
local function calibrarHandling(h, origem, heading)
    local f = Fichas[h]
    local hash
    for _, m in ipairs(f.modelos) do
        hash = carregarModelo(m)
        if hash then break end
    end
    if not hash then return { erro = 'modelo não encontrado' } end

    local floats, _, alvo = ValoresDaFicha(h, Calib)
    local forca, flat = floats.fInitialDriveForce, floats.fInitialDriveMaxFlatVel
    local arrasto = Calib.carros[h] and Calib.carros[h].arrasto
    local arrastoOriginal
    local ultimo, melhor = nil, nil

    for tentativa = 1, cfg.tentativas do
        local forcar = { fInitialDriveForce = forca, fInitialDriveMaxFlatVel = flat }
        if arrasto then forcar.fInitialDragCoeff = arrasto end
        AplicarHandling(h, forcar)

        local t, v, erro, arrastoLido = medir(hash, origem, heading, alvo)
        arrastoOriginal = arrastoOriginal or arrastoLido
        if erro then
            SetModelAsNoLongerNeeded(hash)
            return { erro = erro, parar = erro == 'cancelado' }
        end

        local tReal = t or (cfg.tempoMax * 1.5) -- nem chegou no marco
        local erroT = tReal / alvo.tempo - 1.0
        local erroV = v / alvo.vmax - 1.0
        print(('[pa_handling] %s tentativa %d: 0-%d %.2fs (alvo %.2f) | máx %.0f km/h (alvo %.0f)')
            :format(h, tentativa, alvo.marco, tReal, alvo.tempo, v, alvo.vmax))

        local resultado = {
            forca = forca, flatvel = flat, arrasto = arrasto,
            medido = { tempo = t, vmax = v, marco = alvo.marco },
            alvo = { tempo = alvo.tempo, vmax = alvo.vmax, marco = alvo.marco },
            tentativas = tentativa,
            ok = math.abs(erroT) <= cfg.toleranciaTempo and math.abs(erroV) <= cfg.toleranciaVel,
        }
        local nota = math.abs(erroT) + math.abs(erroV)
        if not melhor or nota < melhor.nota then melhor = { nota = nota, r = resultado } end
        if resultado.ok then break end

        -- corrige a aceleração (o tempo cai quase na proporção da força)
        local fatorT = clamp(tReal / alvo.tempo, 0.5, 2.0)
        if ultimo and fatorT > 1.0 and forca > ultimo.forca * 1.15 and tReal > ultimo.tempo * 0.97 then
            -- aumentou a força e não melhorou: limite de aderência, não insiste
            resultado.limiteAderencia = true
        else
            forca = forca * fatorT
        end

        -- corrige a velocidade final
        local fatorV = alvo.vmax / math.max(v, 1.0)
        if ultimo and fatorV > 1.02 and flat > ultimo.flat * 1.02 and v < ultimo.vmax * 1.01 then
            -- subiu a marcha final e não andou mais: é o arrasto que segura
            local base = arrasto or arrastoOriginal
            if base and base > 0.0 then arrasto = base * 0.7 end
        end
        flat = flat * clamp(fatorV, 0.25, 4.0)

        ultimo = { forca = resultado.forca, flat = resultado.flatvel, tempo = tReal, vmax = v }
    end

    SetModelAsNoLongerNeeded(hash)
    return melhor.r
end

---------------------------------------------------------------------
-- Lista do que calibrar
---------------------------------------------------------------------
local function listaPara(arg, extra)
    local lista = {}
    if arg == 'todos' or arg == 'pendentes' then
        for h in pairs(Fichas) do
            local c = Calib.carros[h]
            if arg == 'todos' or not (c and c.ok) then lista[#lista + 1] = h end
        end
    elseif arg == 'classe' then
        local classe = tonumber(extra)
        for h, f in pairs(Fichas) do
            if f.classe == classe then lista[#lista + 1] = h end
        end
    elseif arg == 'amostra' then
        -- um carro de ficha real por faixa de pneu: rápido, só para acertar o chute geral
        local vistos = {}
        local ordem = {}
        for h in pairs(Fichas) do ordem[#ordem + 1] = h end
        table.sort(ordem)
        for _, h in ipairs(ordem) do
            local f = Fichas[h]
            if f.real and not vistos[f.pneu] then
                vistos[f.pneu] = true
                lista[#lista + 1] = h
            end
        end
    else
        local h = ModeloHandling[joaat(arg)]
        if h then lista[1] = h end
    end
    table.sort(lista)
    return lista
end

---------------------------------------------------------------------
-- /calibrar <modelo | amostra | pendentes | todos | classe N | parar>
---------------------------------------------------------------------
RegisterCommand('calibrar', function(_, args)
    local arg = (args[1] or ''):lower()
    if arg == 'parar' then
        if rodando then cancelar = true; avisar('Parando depois do carro atual...') end
        return
    end
    if rodando then return avisar('A calibração já está rodando. Use /calibrar parar', 'error') end
    if arg == '' then
        return avisar('Use: /calibrar <modelo | amostra | pendentes | todos | classe N | parar>', 'inform')
    end
    if cache.vehicle then return avisar('Saia do carro e fique a pé no começo da reta', 'error') end

    local lista = listaPara(arg, args[2])
    if #lista == 0 then return avisar('Nada para calibrar com "' .. arg .. '"', 'error') end

    local pode, msg = lib.callback.await('pa_handling:server:iniciar', false)
    if not pode then return avisar(msg or 'Sem permissão', 'error') end

    rodando, cancelar = true, false
    local origem = GetEntityCoords(cache.ped) - vector3(0.0, 0.0, 0.9)
    local heading = GetEntityHeading(cache.ped)
    avisar(('Calibrando %d carro(s). Não mexa no teclado; /calibrar parar para interromper.'):format(#lista))

    CreateThread(function()
        local feitos, certos = 0, 0
        for i, h in ipairs(lista) do
            if cancelar then break end
            exports.qbx_core:Notify(('Calibrando %s (%d/%d)'):format(h, i, #lista), 'inform', 3000)
            local r = calibrarHandling(h, origem, heading)
            if r.parar then break end
            if r.erro then
                print(('[pa_handling] %s: %s'):format(h, r.erro))
                if r.erro == 'saiu do carro' then break end
            else
                feitos = feitos + 1
                if r.ok then certos = certos + 1 end
                TriggerServerEvent('pa_handling:server:resultado', h, r)
            end
        end
        rodando = false
        TriggerServerEvent('pa_handling:server:terminar')
        avisar(('Calibração terminada: %d medido(s), %d dentro da tolerância'):format(feitos, certos), 'success')
    end)
end, false)
