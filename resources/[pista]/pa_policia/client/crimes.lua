-- pa_policia · cliente · crimes que avisam a polícia sozinhos
-- Detecta o crime de quem comete; o servidor sorteia a testemunha e manda o aviso para a LSPD.

local CORES = {
    { 'preto', 15, 15, 15 }, { 'branco', 235, 235, 235 }, { 'prata', 160, 162, 165 }, { 'cinza', 90, 92, 95 },
    { 'vermelho', 170, 20, 20 }, { 'vinho', 90, 15, 25 }, { 'laranja', 220, 110, 20 }, { 'amarelo', 230, 200, 30 },
    { 'verde', 30, 120, 40 }, { 'verde-escuro', 20, 60, 30 }, { 'azul', 25, 60, 170 }, { 'azul-claro', 90, 160, 220 },
    { 'azul-marinho', 15, 25, 70 }, { 'roxo', 90, 40, 130 }, { 'rosa', 220, 110, 160 }, { 'marrom', 95, 60, 35 },
    { 'bege', 200, 180, 140 }, { 'dourado', 190, 150, 60 },
}

local function nomeCor(r, g, b)
    local melhor, menor = 'cinza', math.huge
    for _, c in ipairs(CORES) do
        local d = (c[2] - r) ^ 2 + (c[3] - g) ^ 2 + (c[4] - b) ^ 2
        if d < menor then melhor, menor = c[1], d end
    end
    return melhor
end

--- modelo, cor e placa parcial (testemunha só pega o começo)
function PC.InfoVeiculo(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local modelo = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
    if not modelo or modelo == 'NULL' then modelo = GetDisplayNameFromVehicleModel(GetEntityModel(veh)) end
    local r, g, b = GetVehicleColor(veh)
    local placa = (GetVehicleNumberPlateText(veh) or ''):gsub('%s', '')
    return { modelo = modelo, cor = nomeCor(r, g, b), placa = #placa >= 3 and (placa:sub(1, 3) .. '***') or nil }
end

local function avisar(tipo, veh)
    if PC.EmServico() then return end
    TriggerServerEvent('pa_policia:server:crime', tipo, { veiculo = veh and PC.InfoVeiculo(veh) or nil })
end

local function ativo(tipo)
    return Config.crimes[tipo] and Config.crimes[tipo].ativo
end

---------------------------------------------------------------------
-- ROUBO DE VEÍCULO (tirar alguém do carro / quebrar o vidro)
---------------------------------------------------------------------
CreateThread(function()
    local ultimo = 0
    while true do
        local espera = 500
        if ativo('rouboVeiculo') and not cache.vehicle then
            local alvo = GetVehiclePedIsTryingToEnter(cache.ped)
            if alvo ~= 0 then
                espera = 100
                local arrancando = IsPedJacking(cache.ped)
                local quebrando = GetVehicleDoorLockStatus(alvo) == 2 and IsPedTryingToEnterALockedVehicle(cache.ped)
                if (arrancando or quebrando) and GetGameTimer() - ultimo > 20000 then
                    ultimo = GetGameTimer()
                    avisar('rouboVeiculo', alvo)
                end
            end
        end
        Wait(espera)
    end
end)

---------------------------------------------------------------------
-- BRIGA E ATROPELAMENTO (quando EU causo o dano)
---------------------------------------------------------------------
local GRUPO_MELEE = `GROUP_MELEE`
local GRUPO_DESARMADO = `GROUP_UNARMED`
local ATROPELOU = { [`WEAPON_RUN_OVER_BY_CAR`] = true, [`WEAPON_RAMMED_BY_CAR`] = true }

AddEventHandler('gameEventTriggered', function(nome, args)
    if nome ~= 'CEventNetworkEntityDamage' then return end
    local vitima, atacante, arma = args[1], args[2], args[7]
    if vitima == cache.ped or not DoesEntityExist(vitima) or not IsEntityAPed(vitima) then return end
    if GetPedType(vitima) == 28 then return end -- animal (caça não é crime)

    local fuiEu = atacante == cache.ped or (cache.vehicle and atacante == cache.vehicle and cache.seat == -1)
    if not fuiEu then return end

    if ATROPELOU[arma] or (cache.vehicle and atacante == cache.vehicle) then
        if ativo('atropelamento') and GetEntitySpeed(cache.vehicle or 0) * 3.6 > 25 then
            avisar('atropelamento', cache.vehicle)
        end
        return
    end
    local grupo = GetWeapontypeGroup(arma)
    if (grupo == GRUPO_MELEE or grupo == GRUPO_DESARMADO) and ativo('briga') then
        avisar('briga')
    end
end)

---------------------------------------------------------------------
-- DIREÇÃO PERIGOSA (muito rápido na cidade)
---------------------------------------------------------------------
local function naCidade(c)
    -- área urbana de Los Santos (fora das rodovias e do interior)
    return c.y < 1200.0 and c.y > -3500.0 and c.x > -2200.0 and c.x < 1600.0
end

CreateThread(function()
    local cfg = Config.crimes.direcaoPerigosa
    if not cfg or not cfg.ativo then return end
    local desde
    while true do
        local espera = 1000
        local veh = cache.vehicle
        if veh and cache.seat == -1 and GetVehicleClass(veh) ~= 18 and not PC.EmServico() then
            espera = 500
            local vel = GetEntitySpeed(veh) * 3.6
            if vel >= cfg.velocidade and naCidade(GetEntityCoords(veh)) then
                desde = desde or GetGameTimer()
                if GetGameTimer() - desde >= cfg.segundos * 1000 then
                    desde = nil
                    avisar('direcaoPerigosa', veh)
                end
            else
                desde = nil
            end
        else
            desde = nil
        end
        Wait(espera)
    end
end)
