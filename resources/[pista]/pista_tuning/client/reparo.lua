-- pista_tuning - consertos (pneu, funilaria, kits) e empurrar o carro

local ANIM_RODA = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' }
local ANIM_LATARIA = { dict = 'mini@repair', clip = 'fixing_a_ped' }
local ocupado = false

-- Rodas: osso -> índice do pneu no GTA
local PNEUS = {
    { bone = 'wheel_lf', pneu = 0, nome = 'dianteiro esquerdo' },
    { bone = 'wheel_rf', pneu = 1, nome = 'dianteiro direito' },
    { bone = 'wheel_lm1', pneu = 2, nome = 'do meio esquerdo' },
    { bone = 'wheel_rm1', pneu = 3, nome = 'do meio direito' },
    { bone = 'wheel_lr', pneu = 4, nome = 'traseiro esquerdo' },
    { bone = 'wheel_rr', pneu = 5, nome = 'traseiro direito' },
}
local function ossos(lista)
    local r = {}
    for i, v in ipairs(lista) do r[i] = v.bone end
    return r
end

local function maisPerto(veh, lista, coords)
    coords = coords or GetEntityCoords(cache.ped)
    local melhor, melhorDist
    for _, v in ipairs(lista) do
        local osso = GetEntityBoneIndexByName(veh, v.bone)
        if osso ~= -1 then
            local d = #(GetWorldPositionOfEntityBone(veh, osso) - coords)
            if not melhorDist or d < melhorDist then melhor, melhorDist = v, d end
        end
    end
    return melhor
end

local function pelaBone(veh, lista, osso, coords)
    if osso then
        for _, v in ipairs(lista) do
            if GetEntityBoneIndexByName(veh, v.bone) == osso then return v end
        end
    end
    return maisPerto(veh, lista, coords)
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

function MecanicoEmServico()
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job
    return job ~= nil and job.name == Config.elevador.job and job.onduty == true
end

local function executar(fn, ...)
    if ocupado then return end
    ocupado = true
    local args = { ... }
    CreateThread(function()
        local ok, err = pcall(fn, table.unpack(args))
        if not ok then print('[pista_tuning] erro no conserto: ' .. tostring(err)) end
        ocupado = false
    end)
end

---------------------------------------------------------------------
-- Funilaria: o GTA só repõe porta/capô/porta-malas consertando o carro todo,
-- então guarda o que não é lataria (motor, tanque, pneus, rodas do elevador),
-- conserta e devolve esse estado.
---------------------------------------------------------------------
local function consertarLataria(veh)
    local motor, tanque = GetVehicleEngineHealth(veh), GetVehiclePetrolTankHealth(veh)
    local combustivel, sujeira = GetVehicleFuelLevel(veh), GetVehicleDirtLevel(veh)
    local pneus = {}
    for _, p in ipairs(PNEUS) do
        if IsVehicleTyreBurst(veh, p.pneu, false) then
            pneus[#pneus + 1] = { p.pneu, IsVehicleTyreBurst(veh, p.pneu, true) }
        end
    end

    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    RemoveDecalsFromVehicle(veh)

    SetVehicleBodyHealth(veh, 1000.0)
    SetVehicleEngineHealth(veh, motor)
    SetVehiclePetrolTankHealth(veh, tanque)
    SetVehicleFuelLevel(veh, combustivel)
    SetVehicleDirtLevel(veh, sujeira)
    for _, p in ipairs(pneus) do SetVehicleTyreBurst(veh, p[1], p[2], 1000.0) end
    -- rodas tiradas no elevador continuam fora
    for chave in pairs(Entity(veh).state.pista_rodas or {}) do
        BreakOffVehicleWheel(veh, tonumber(chave:sub(2)), false, true, true, false)
    end
end

---------------------------------------------------------------------
-- Conserto genérico: valida no servidor, faz a animação, gasta o item e aplica
---------------------------------------------------------------------
local function consertar(veh, tipo, label, anim, aplicar)
    local netId = VehToNet(veh)
    local pode, erro = lib.callback.await('pista_tuning:server:podeReparar', false, netId, tipo)
    if not pode then return Avisar(erro or 'Não dá para fazer isso agora', 'error') end
    exports.ox_inventory:closeInventory()
    if not Trabalhar(Config.reparo[tipo].tempo, label, { anim = anim }) then
        return Avisar('Cancelado', 'error')
    end
    local ok, msg = lib.callback.await('pista_tuning:server:reparar', false, netId, tipo)
    if not ok then return Avisar(msg or 'Não foi possível consertar', 'error') end
    if not controle(veh) then return Avisar('Não foi possível mexer no carro, tente de novo', 'error') end
    aplicar()
    return true
end

local function trocarPneu(veh, roda)
    if consertar(veh, 'pneu', ('Trocando o pneu %s...'):format(roda.nome), ANIM_RODA, function()
        SetVehicleTyreFixed(veh, roda.pneu)
    end) then Avisar('Pneu trocado', 'success') end
end

local function funilaria(veh)
    if consertar(veh, 'funilaria', 'Funilaria: desamassando, recolocando peças e pintando...', ANIM_LATARIA, function()
        consertarLataria(veh)
    end) then Avisar('Lataria, vidros, portas, capô e porta-malas como novos', 'success') end
end

local function precisaFunilaria(veh)
    if GetVehicleBodyHealth(veh) < 995.0 then return true end
    for i = 0, 5 do
        if IsVehicleDoorDamaged(veh, i) then return true end -- porta, capô ou porta-malas faltando
    end
    return false
end

---------------------------------------------------------------------
-- Alt no carro
---------------------------------------------------------------------
CreateThread(function()
    exports.ox_target:addGlobalVehicle({
        {
            name = 'pista_reparo_pneu',
            icon = 'fa-solid fa-circle-dot',
            label = 'Trocar pneu',
            bones = ossos(PNEUS),
            distance = 2.5,
            canInteract = function(entity, _, coords, _, osso)
                if ocupado or cache.vehicle or not TemItem(Config.reparo.pneu.item) then return false end
                local roda = pelaBone(entity, PNEUS, osso, coords)
                return roda ~= nil and IsVehicleTyreBurst(entity, roda.pneu, false)
            end,
            onSelect = function(data)
                local roda = maisPerto(data.entity, PNEUS, data.coords)
                if roda then executar(trocarPneu, data.entity, roda) end
            end,
        },
        {
            name = 'pista_reparo_funilaria',
            icon = 'fa-solid fa-spray-can',
            label = 'Fazer funilaria',
            distance = 3.0,
            canInteract = function(entity)
                return not ocupado and not cache.vehicle and MecanicoEmServico()
                    and TemItem(Config.reparo.funilaria.item) and precisaFunilaria(entity)
            end,
            onSelect = function(data) executar(funilaria, data.entity) end,
        },
    })
end)

---------------------------------------------------------------------
-- Itens usados pelo inventário
---------------------------------------------------------------------
local function kitMotor(tipo)
    if cache.vehicle then return Avisar('Saia do veículo', 'error') end
    local veh = VeiculoProximo()
    if not veh then return Avisar('Nenhum veículo por perto', 'error') end
    local vida = Config.reparo[tipo].vidaMotor
    if DadosDo(veh).motorQuebrado or GetVehicleEngineHealth(veh) < Config.motorQuebrado.limiar then
        return Avisar('O motor quebrou: kit não resolve. Tire o motor, retifique e troque pistões e bielas.', 'error', 7000)
    end
    if GetVehicleEngineHealth(veh) >= vida then
        return Avisar('O motor está melhor do que esse kit consegue deixar', 'error')
    end
    SetVehicleDoorOpen(veh, 4, false, false)
    executar(function()
        if consertar(veh, tipo, 'Fazendo um conserto rápido no motor...', ANIM_LATARIA, function()
            SetVehicleEngineHealth(veh, vida)
            SetVehicleUndriveable(veh, false)
        end) then
            Avisar('O motor voltou a funcionar, mas leve o carro a uma oficina', 'success', 6000)
        end
    end)
end

exports('usarKitEmergencia', function() kitMotor('emergencia') end)
exports('usarKitAvancado', function() kitMotor('avancado') end)
exports('usarRetifica', function() RetificarMotorProximo() end)

local function dicaAlt(texto)
    return function()
        exports.ox_inventory:closeInventory()
        Avisar(texto, 'inform', 7000)
    end
end
exports('usarPneu', dicaAlt('Mire no pneu furado com o Alt e escolha "Trocar pneu" (precisa do macaco).'))
exports('usarFunilaria', dicaAlt('Mire no carro com o Alt e escolha "Fazer funilaria".'))

---------------------------------------------------------------------
-- Empurrar o carro
---------------------------------------------------------------------
local empurrando = nil -- { veh, frente }
local ANIM_EMPURRAR = { dict = 'missfinale_c2ig_11', clip = 'pushcar_offcliff_m' }

--- Carro que dá para empurrar daqui, e se estou na frente ou atrás
local function carroParaEmpurrar()
    if cache.vehicle or IsPedRagdoll(cache.ped) or IsPedSwimming(cache.ped) then return nil end
    local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 4.0, false)
    if not veh then return nil end
    local classe = GetVehicleClass(veh)
    if classe == 8 or classe == 13 or classe == 14 or classe == 15 or classe == 16 then return nil end -- moto, bike, barco, avião
    if GetPedInVehicleSeat(veh, -1) ~= 0 or GetIsVehicleEngineRunning(veh) then return nil end
    if Entity(veh).state.pista_elevador then return nil end

    local min, max = GetModelDimensions(GetEntityModel(veh))
    local off = GetOffsetFromEntityGivenWorldCoords(veh, GetEntityCoords(cache.ped))
    if math.abs(off.x) > (max.x - min.x) / 2 + 0.4 then return nil end
    if off.y > max.y - 0.6 and off.y < max.y + 1.2 then return veh, true, min, max end
    if off.y < min.y + 0.6 and off.y > min.y - 1.2 then return veh, false, min, max end
    return nil
end

local function pararDeEmpurrar()
    if not empurrando then return end
    local veh = empurrando.veh
    empurrando = nil
    DetachEntity(cache.ped, true, false)
    StopAnimTask(cache.ped, ANIM_EMPURRAR.dict, ANIM_EMPURRAR.clip, 2.0)
    if DoesEntityExist(veh) then SetVehicleSteeringAngle(veh, 0.0) end
end

--- Dica no canto da tela (não briga com o texto do elevador)
local function dica(texto)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(texto)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function comecarAEmpurrar(veh, frente, min, max)
    if not controle(veh) then return Avisar('Não foi possível empurrar esse carro agora', 'error') end
    lib.requestAnimDict(ANIM_EMPURRAR.dict)
    local ped = cache.ped
    -- pé no chão: a raiz do personagem fica ~1 m acima do chão
    local z = min.z + 1.0
    if frente then
        AttachEntityToEntity(ped, veh, 0, 0.0, max.y + 0.35, z, 0.0, 0.0, 180.0, false, false, false, true, 2, true)
    else
        AttachEntityToEntity(ped, veh, 0, 0.0, min.y - 0.35, z, 0.0, 0.0, 0.0, false, false, false, true, 2, true)
    end
    TaskPlayAnim(ped, ANIM_EMPURRAR.dict, ANIM_EMPURRAR.clip, 2.0, -8.0, -1, 35, 0, false, false, false)
    empurrando = { veh = veh, frente = frente }
    local textoControles = ('[W] Empurrar  [A/D] Virar  [%s] Soltar'):format(Config.empurrar.tecla)

    CreateThread(function()
        local angulo = 0.0
        local proximoControle = 0
        while empurrando and empurrando.veh == veh do
            if not DoesEntityExist(veh) or GetPedInVehicleSeat(veh, -1) ~= 0 or GetIsVehicleEngineRunning(veh)
                or IsPedRagdoll(ped) or IsEntityDead(ped) then
                break
            end
            if GetGameTimer() > proximoControle then
                proximoControle = GetGameTimer() + 1000
                NetworkRequestControlOfEntity(veh)
            end

            DisableControlAction(0, 30, true) -- andar para os lados
            DisableControlAction(0, 31, true) -- andar para frente/trás
            for c = 32, 35 do DisableControlAction(0, c, true) end -- W A S D (lidos abaixo)
            DisableControlAction(0, 21, true) -- correr
            DisableControlAction(0, 22, true) -- pular
            DisableControlAction(0, 23, true) -- entrar no carro
            DisableControlAction(0, 24, true) -- atacar
            dica(textoControles)

            -- volante
            local alvo = 0.0
            local inverte = Config.empurrar.inverterVolante and -1.0 or 1.0
            if frente then inverte = -inverte end
            if IsDisabledControlPressed(0, 34) then alvo = Config.empurrar.angulo * inverte end   -- A
            if IsDisabledControlPressed(0, 35) then alvo = -Config.empurrar.angulo * inverte end  -- D
            angulo = angulo + (alvo - angulo) * 0.1
            SetVehicleSteeringAngle(veh, angulo)

            if IsDisabledControlPressed(0, 32) then -- W
                if not IsEntityPlayingAnim(ped, ANIM_EMPURRAR.dict, ANIM_EMPURRAR.clip, 3) then
                    TaskPlayAnim(ped, ANIM_EMPURRAR.dict, ANIM_EMPURRAR.clip, 2.0, -8.0, -1, 35, 0, false, false, false)
                end
                SetVehicleForwardSpeed(veh, frente and -Config.empurrar.velocidade or Config.empurrar.velocidade)
            end
            Wait(0)
        end
        if empurrando and empurrando.veh == veh then pararDeEmpurrar() end
    end)
end

lib.addKeybind({
    name = 'pista_empurrar',
    description = 'Empurrar / soltar o carro',
    defaultKey = Config.empurrar.tecla,
    onPressed = function()
        if empurrando then return pararDeEmpurrar() end
        local veh, frente, min, max = carroParaEmpurrar()
        if not veh then return end
        comecarAEmpurrar(veh, frente, min, max)
    end,
})

-- Aviso em cima do para-choque quando o carro está quebrado (a tecla funciona
-- em qualquer carro desligado; o aviso só aparece no que precisa de ajuda)
local function carroQuebrado(veh)
    local d = DadosDo(veh)
    return GetVehicleEngineHealth(veh) <= 300.0 or d.motor ~= nil or d.motorQuebrado ~= nil
end

CreateThread(function()
    local alvo, alvoFrente, alvoMin, alvoMax
    local proximaBusca = 0
    while true do
        local espera = 500
        if not empurrando then
            if GetGameTimer() >= proximaBusca then
                proximaBusca = GetGameTimer() + 250
                local veh, frente, min, max = carroParaEmpurrar()
                if veh and carroQuebrado(veh) then
                    alvo, alvoFrente, alvoMin, alvoMax = veh, frente, min, max
                else
                    alvo = nil
                end
            end
            if alvo and DoesEntityExist(alvo) then
                espera = 0
                local y = alvoFrente and alvoMax.y + 0.1 or alvoMin.y - 0.1
                local p = GetOffsetFromEntityInWorldCoords(alvo, 0.0, y, 0.2)
                SetDrawOrigin(p.x, p.y, p.z, 0)
                SetTextScale(0.33, 0.33)
                SetTextFont(4)
                SetTextColour(255, 255, 255, 230)
                SetTextOutline()
                SetTextCentre(true)
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(('[%s] Empurrar o carro'):format(Config.empurrar.tecla))
                EndTextCommandDisplayText(0.0, 0.0)
                ClearDrawOrigin()
            end
        end
        Wait(espera)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    pararDeEmpurrar()
    exports.ox_target:removeGlobalVehicle({ 'pista_reparo_pneu', 'pista_reparo_funilaria' })
end)
