-- pa_handling - cliente: aplica a handling de fábrica (realista) em todos os modelos

Calib = { carros = {} }
local aplicados = {} -- [HANDLING] = valores aplicados (para o export e o dinamômetro)

local function dbg(...)
    if Config.debug then print('[pa_handling]', ...) end
end

--- Aplica os valores de uma handling para todos os carros desse modelo (global)
function AplicarHandling(h, floatsForcados)
    local floats, ints, alvo = ValoresDaFicha(h, Calib)
    if not floats then return end
    if floatsForcados then
        for k, v in pairs(floatsForcados) do floats[k] = v end
    end
    for campo, valor in pairs(floats) do
        local ok, err = pcall(SetHandlingFloat, h, 'CHandlingData', campo, valor + 0.0)
        if not ok then dbg('falhou', h, campo, err) end
    end
    for campo, valor in pairs(ints) do
        pcall(SetHandlingInt, h, 'CHandlingData', campo, math.floor(valor))
    end
    aplicados[h] = { floats = floats, ints = ints, alvo = alvo }
end

function AplicarTudo()
    if not Config.ativo then return end
    local n = 0
    for h in pairs(Fichas) do
        AplicarHandling(h)
        n = n + 1
    end
    dbg(('handling aplicada em %d modelos'):format(n))
end

---------------------------------------------------------------------
-- Calibração vinda do servidor
---------------------------------------------------------------------
local function receberCalib(dados)
    Calib = dados or { carros = {} }
    Calib.carros = Calib.carros or {}
    AplicarTudo()
end

RegisterNetEvent('pa_handling:client:calib', function(dados)
    if GetInvokingResource() then return end
    receberCalib(dados)
end)

-- Um carro calibrado (durante a calibração de alguém)
RegisterNetEvent('pa_handling:client:carro', function(h, dados, kForca, kVel)
    if GetInvokingResource() then return end
    Calib.carros[h] = dados
    local mudouK = (kForca and kForca ~= Calib.kForca) or (kVel and kVel ~= Calib.kVel)
    Calib.kForca, Calib.kVel = kForca or Calib.kForca, kVel or Calib.kVel
    if mudouK then AplicarTudo() else AplicarHandling(h) end
end)

CreateThread(function()
    AplicarTudo() -- já aplica o chute inicial antes da resposta do servidor
    local dados = lib.callback.await('pa_handling:server:calib', false)
    receberCalib(dados)
end)

---------------------------------------------------------------------
-- Ao assumir o volante: o GTA recalcula a velocidade final pela handling nova
---------------------------------------------------------------------
lib.onCache('seat', function(seat)
    if seat ~= -1 or not cache.vehicle then return end
    local veh = cache.vehicle
    if ModeloHandling[GetEntityModel(veh)] then
        ModifyVehicleTopSpeed(veh, 1.0)
    end
end)

---------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------
--- Ficha do carro: real, cv, kg, tracao, marchas, zero100, vmax, pneu,
--- forcaBase (fInitialDriveForce de fábrica, sem preparação) e calibrado (bool)
local function fichaDoVeiculo(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local h = ModeloHandling[GetEntityModel(veh)]
    local f = h and Fichas[h]
    if not f then return nil end
    local ap = aplicados[h]
    local r = {}
    for k, v in pairs(f) do r[k] = v end
    r.modelos = nil
    r.forcaBase = ap and ap.floats.fInitialDriveForce
    r.vmaxBase = ap and ap.floats.fInitialDriveMaxFlatVel
    r.calibrado = Calib.carros[h] ~= nil and Calib.carros[h].ok == true
    return r
end
exports('ficha', fichaDoVeiculo)
exports('fichaDoModelo', function(modelo)
    local h = ModeloHandling[type(modelo) == 'string' and joaat(modelo) or modelo]
    return h and Fichas[h] or nil
end)

---------------------------------------------------------------------
-- /ficha: mostra a ficha técnica do carro em que você está
---------------------------------------------------------------------
local TRACAO = { D = 'dianteira', T = 'traseira', ['4x4'] = 'integral (4x4)' }

RegisterCommand('ficha', function()
    local veh = cache.vehicle
    if not veh then return exports.qbx_core:Notify('Entre em um carro para ver a ficha', 'error') end
    local f = fichaDoVeiculo(veh)
    if not f then return exports.qbx_core:Notify('Esse carro não tem ficha', 'inform') end
    local linhas = {}
    if f.real then
        linhas[#linhas + 1] = ('**%s**'):format(f.real)
        linhas[#linhas + 1] = ('%d cv · %d kg · tração %s%s'):format(f.cv or 0, f.kg or 0,
            TRACAO[f.tracao] or '?', f.marchas and (' · %d marchas'):format(f.marchas) or '')
    else
        linhas[#linhas + 1] = '**Ficha automática** (sem carro real cadastrado)'
    end
    local alvo = AlvoDaFicha(f)
    linhas[#linhas + 1] = ('0-%d km/h: %.1f s · Máx.: %d km/h'):format(alvo.marco, alvo.tempo, math.floor(alvo.vmax))
    linhas[#linhas + 1] = f.calibrado and 'Calibrado ✔' or 'Ainda não calibrado'
    lib.alertDialog({ header = 'Ficha técnica', content = table.concat(linhas, '  \n'), centered = true })
end, false)
