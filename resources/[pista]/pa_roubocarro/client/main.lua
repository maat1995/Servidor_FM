-- pa_roubocarro · cliente · estado e avisos gerais
RCc = {
    contrato = nil,   -- contrato ativo (dados públicos do servidor)
    modelos = {},     -- [hash] = true dos modelos aceitos no contrato de rua
}

function RCc.Notificar(texto, tipo, duracao)
    lib.notify({ title = 'Tablet de roubo', description = texto, type = tipo or 'inform', duration = duracao or 6000 })
end

function RCc.Veiculo(net)
    if not net or not NetworkDoesNetworkIdExist(net) then return nil end
    local veh = NetworkGetEntityFromNetworkId(net)
    if veh == 0 or not DoesEntityExist(veh) then return nil end
    return veh
end

-- convite de dupla
RegisterNetEvent('pa_roubocarro:client:convite', function(nome, tempo)
    if GetInvokingResource() then return end
    RCc.Notificar(('%s chamou você para uma dupla de roubo. Aceite pelo tablet ou com /aceitardupla (%ds).'):format(nome, tempo), 'inform', tempo * 1000)
end)

RegisterCommand('aceitardupla', function()
    TriggerServerEvent('pa_roubocarro:server:aceitarConvite')
end, false)

-- alarme do carro (todo mundo ouve)
RegisterNetEvent('pa_roubocarro:client:alarme', function(net)
    if GetInvokingResource() then return end
    local veh = RCc.Veiculo(net)
    if not veh then return end
    SetVehicleAlarm(veh, true)
    StartVehicleAlarm(veh)
end)

-- carro comprado com chassi riscado: GPS para a retirada
RegisterNetEvent('pa_roubocarro:client:retirada', function(c)
    if GetInvokingResource() then return end
    SetNewWaypoint(c.x, c.y)
end)

-- /rc_ponto (admin)
RegisterNetEvent('pa_roubocarro:client:copiar', function(texto)
    if GetInvokingResource() then return end
    lib.setClipboard(texto)
    RCc.Notificar(('Copiado: %s'):format(texto), 'success')
    print(texto)
end)
