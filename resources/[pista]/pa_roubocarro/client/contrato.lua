-- pa_roubocarro · cliente · contrato: área no mapa, arrombar, pegar o carro, rastreador e entrega

local blips = {}
local encolheu = false
local textoAberto = false

-- dificuldade do arrombamento por classe
local ARROMBAR = {
    D = { 'easy', 'easy', 'medium' },
    C = { 'easy', 'medium', 'medium' },
    B = { 'medium', 'medium', 'hard' },
    A = { 'medium', 'hard', 'hard' },
    S = { 'hard', 'hard', 'hard' },
}

local function limparBlip(nome)
    if blips[nome] and DoesBlipExist(blips[nome]) then RemoveBlip(blips[nome]) end
    blips[nome] = nil
end

local function limparTudo()
    for nome in pairs(blips) do limparBlip(nome) end
    encolheu = false
    if textoAberto then lib.hideTextUI() textoAberto = false end
end

local function nomeBlip(blip, texto)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(texto)
    EndTextCommandSetBlipName(blip)
end

local function desenharArea(c, raio, rotulo)
    limparBlip('area')
    limparBlip('centro')
    local area = AddBlipForRadius(c.x, c.y, c.z, raio)
    SetBlipColour(area, 27)
    SetBlipAlpha(area, 110)
    SetBlipHighDetail(area, true)
    blips.area = area
    local centro = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(centro, 523)
    SetBlipColour(centro, 27)
    SetBlipScale(centro, 0.8)
    nomeBlip(centro, rotulo)
    blips.centro = centro
end

local function desenharEntrega(e)
    limparBlip('area')
    limparBlip('centro')
    if blips.entrega then return end
    local b = AddBlipForCoord(e.x, e.y, e.z)
    SetBlipSprite(b, 524)
    SetBlipColour(b, 2)
    SetBlipRoute(b, true)
    SetBlipRouteColour(b, 2)
    nomeBlip(b, 'Entrega da encomenda')
    blips.entrega = b
end

---------------------------------------------------------------------
-- RECEBER O CONTRATO
---------------------------------------------------------------------
RegisterNetEvent('pa_roubocarro:client:contrato', function(ct)
    if GetInvokingResource() then return end
    local antes = RCc.contrato
    RCc.contrato = ct
    RCc.modelos = {}
    for _, m in ipairs(ct.modelos or {}) do RCc.modelos[joaat(m)] = true end

    if ct.pego and ct.entrega then
        desenharEntrega(ct.entrega)
    elseif ct.area and (not antes or antes.id ~= ct.id) then
        desenharArea(ct.area, ct.area.raio, ('Encomenda: %s'):format((ct.modelo or ''):upper()))
    end
    RCc.AtualizarTabletAberto()
end)

RegisterNetEvent('pa_roubocarro:client:fimContrato', function(motivo)
    if GetInvokingResource() then return end
    RCc.contrato = nil
    RCc.modelos = {}
    limparTudo()
    if motivo then RCc.Notificar(motivo, 'inform', 8000) end
    RCc.AtualizarTabletAberto()
end)

---------------------------------------------------------------------
-- ÁREA ENCOLHE QUANDO CHEGA PERTO (carro estacionado)
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local ct = RCc.contrato
        if ct and ct.modo == 'local' and not ct.pego and ct.area and not encolheu then
            local pos = GetEntityCoords(cache.ped)
            if #(pos - vec3(ct.area.x, ct.area.y, ct.area.z)) < ct.area.raio then
                local veh = RCc.Veiculo(ct.localNet)
                if veh then
                    local v = GetEntityCoords(veh)
                    local ang = math.random() * math.pi * 2
                    local d = math.random() * Config.area.raioPerto * 0.6
                    desenharArea(vec3(v.x + math.cos(ang) * d, v.y + math.sin(ang) * d, v.z), Config.area.raioPerto,
                        ('Encomenda: %s'):format((ct.modelo or ''):upper()))
                    encolheu = true
                    RCc.Notificar('Você está perto. A área ficou menor.', 'inform')
                end
            end
            Wait(1000)
        else
            Wait(2000)
        end
    end
end)

---------------------------------------------------------------------
-- ARROMBAR (olho no carro)
---------------------------------------------------------------------
local function carroValido(veh)
    local ct = RCc.contrato
    if not ct or ct.pego then return false end
    if ct.modo == 'local' then
        return NetworkGetEntityIsNetworked(veh) and NetworkGetNetworkIdFromEntity(veh) == ct.localNet
    end
    return RCc.modelos[GetEntityModel(veh)] == true
end

local arrombando = false

local function arrombar(veh)
    if arrombando then return end
    local ct = RCc.contrato
    if not ct then return end
    if not NetworkGetEntityIsNetworked(veh) then NetworkRegisterEntityAsNetworked(veh) end
    local net = NetworkGetNetworkIdFromEntity(veh)
    arrombando = true

    lib.requestAnimDict('veh@break_in@0h@p_m_one@')
    TaskPlayAnim(cache.ped, 'veh@break_in@0h@p_m_one@', 'low_force_entry_ds', 3.0, 3.0, -1, 17, 0, false, false, false)
    local sucesso = lib.skillCheck(ARROMBAR[ct.classe] or ARROMBAR.C, { 'w', 'a', 's', 'd' })
    ClearPedTasks(cache.ped)
    RemoveAnimDict('veh@break_in@0h@p_m_one@')

    local ok, msg = lib.callback.await('pa_roubocarro:server:arrombar', false, net, sucesso)
    arrombando = false
    if ok then
        SetVehicleDoorsLocked(veh, 1)
        RCc.Notificar('Porta aberta. Entre e leve o carro.', 'success')
    elseif msg then
        RCc.Notificar(msg, 'error')
    end
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'pa_roubocarro_arrombar',
        icon = 'fa-solid fa-unlock',
        label = 'Arrombar (encomenda)',
        distance = 2.0,
        canInteract = function(veh)
            return not arrombando and carroValido(veh) and GetVehicleDoorLockStatus(veh) >= 2
        end,
        onSelect = function(data) arrombar(data.entity) end,
    },
})

---------------------------------------------------------------------
-- PEGOU O CARRO (entrou dirigindo)
---------------------------------------------------------------------
CreateThread(function()
    local ultimoTeste, ultimoVeh = 0, 0
    while true do
        local ct = RCc.contrato
        if ct and not ct.pego and cache.vehicle and cache.seat == -1 then
            local veh = cache.vehicle
            if carroValido(veh) and (veh ~= ultimoVeh or GetGameTimer() - ultimoTeste > 5000) then
                ultimoVeh, ultimoTeste = veh, GetGameTimer()
                if not NetworkGetEntityIsNetworked(veh) then NetworkRegisterEntityAsNetworked(veh) end
                SetEntityAsMissionEntity(veh, true, true)
                lib.callback.await('pa_roubocarro:server:pegou', false, NetworkGetNetworkIdFromEntity(veh))
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

---------------------------------------------------------------------
-- RASTREADOR (botão no tablet)
---------------------------------------------------------------------
function RCc.DesligarRastreador(etapas)
    local ct = RCc.contrato
    if not ct or not ct.rastreador then return RCc.Notificar('Nada para desligar.', 'error') end
    if not cache.vehicle or NetworkGetNetworkIdFromEntity(cache.vehicle) ~= ct.alvoNet then
        return RCc.Notificar('Entre no carro da encomenda para desligar.', 'error')
    end
    local lista = {}
    for i = 1, etapas or 5 do lista[i] = i <= 2 and 'medium' or 'hard' end
    lib.progressBar({ duration = 2500, label = 'Procurando o módulo do rastreador...', canCancel = true, disable = { combat = true } })
    local sucesso = lib.skillCheck(lista, { '1', '2', '3', '4' })
    local ok, msg = lib.callback.await('pa_roubocarro:server:rastreador', false, sucesso)
    RCc.Notificar(msg or (ok and 'Rastreador desligado.' or 'Falhou.'), ok and 'success' or 'error')
end

---------------------------------------------------------------------
-- ENTREGA
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local ct = RCc.contrato
        local espera = 1000
        if ct and ct.pego and ct.entrega then
            local e = vec3(ct.entrega.x, ct.entrega.y, ct.entrega.z)
            local dist = #(GetEntityCoords(cache.ped) - e)
            if dist < 40.0 then
                espera = 0
                DrawMarker(1, e.x, e.y, e.z - 1.0, 0, 0, 0, 0, 0, 0, Config.raioEntrega * 2, Config.raioEntrega * 2, 0.6,
                    80, 200, 120, 90, false, false, 2, false, nil, nil, false)
                local noCarro = cache.vehicle and cache.seat == -1 and NetworkGetNetworkIdFromEntity(cache.vehicle) == ct.alvoNet
                if dist < Config.raioEntrega and noCarro then
                    if not textoAberto then lib.showTextUI('[E] Entregar o carro') textoAberto = true end
                    if IsControlJustReleased(0, 38) then
                        lib.hideTextUI() textoAberto = false
                        local props = lib.getVehicleProperties(cache.vehicle)
                        local ok, msg = lib.callback.await('pa_roubocarro:server:entregar', false, props)
                        if not ok and msg then RCc.Notificar(msg, 'error') end
                        Wait(1500)
                    end
                elseif textoAberto then
                    lib.hideTextUI() textoAberto = false
                end
            elseif textoAberto then
                lib.hideTextUI() textoAberto = false
            end
        end
        Wait(espera)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then limparTudo() end
end)
