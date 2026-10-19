-- Junta as fichas dos nativos (data/nativos.lua) com as do config (addons)
-- e transforma cada ficha nos valores de handling.

Fichas = {}          -- [HANDLING] = ficha
ModeloHandling = {}  -- [hash do modelo] = HANDLING

local function copiar(t)
    local n = {}
    for k, v in pairs(t) do n[k] = v end
    return n
end

for h, f in pairs(Nativos) do
    local ficha = copiar(f)
    ficha.handling = h
    Fichas[h] = ficha
    for _, m in ipairs(f.modelos) do ModeloHandling[joaat(m)] = h end
end

for modelo, f in pairs(Config.fichas or {}) do
    modelo = modelo:lower()
    local hash = joaat(modelo)
    local h = f.handling and f.handling:upper() or ModeloHandling[hash] or modelo:upper()
    local ficha = copiar(f)
    ficha.handling = h
    ficha.auto = nil
    ficha.addon = Nativos[h] == nil
    ficha.modelos = Fichas[h] and Fichas[h].modelos or { modelo }
    local tem = false
    for _, m in ipairs(ficha.modelos) do if m == modelo then tem = true end end
    if not tem then ficha.modelos[#ficha.modelos + 1] = modelo end
    Fichas[h] = ficha
    ModeloHandling[hash] = h
end

for _, modelo in ipairs(Config.ignorar or {}) do
    local h = ModeloHandling[joaat(modelo:lower())]
    if h then
        for _, m in ipairs(Fichas[h].modelos) do ModeloHandling[joaat(m)] = nil end
        Fichas[h] = nil
    end
end

---------------------------------------------------------------------
-- Alvo da ficha (o que a calibração tenta acertar)
---------------------------------------------------------------------
-- marco = velocidade do teste de aceleração (100 km/h, ou 60 para carro muito fraco)
function AlvoDaFicha(f)
    local vmax = f.vmax * Config.escalaVelocidade
    local marco, tempo
    if f.zero100 and vmax >= 125 then
        marco, tempo = 100, f.zero100
    else
        marco, tempo = 60, f.zero60 or (f.zero100 and f.zero100 * 0.45) or 12.0
    end
    return { vmax = vmax, marco = marco, tempo = tempo / Config.escalaAceleracao }
end

-- 0-100 "equivalente" (o tempo cresce quase em linha reta com a velocidade no começo)
function Tempo100(alvo)
    return alvo.tempo * 100.0 / alvo.marco
end

---------------------------------------------------------------------
-- Valores de handling de uma ficha
---------------------------------------------------------------------
-- calib = dados calibrados (data/calibracao.json), pode ser nil
function ValoresDaFicha(h, calib)
    local f = Fichas[h]
    if not f then return nil end
    local alvo = AlvoDaFicha(f)
    local c = calib and calib.carros and calib.carros[h]
    local kForca = calib and calib.kForca or Config.kForca
    local kVel = calib and calib.kVel or Config.kVel

    local forca, flat
    if c and c.forca and c.alvo then
        -- calibrado. Se a ficha/escala mudou depois, corrige na proporção
        forca = c.forca * (Tempo100(c.alvo) / Tempo100(alvo))
        flat = c.flatvel * (alvo.vmax / c.alvo.vmax)
    else
        forca = kForca / Tempo100(alvo)
        flat = kVel * alvo.vmax
    end

    local p = Config.pneus[f.pneu] or Config.pneus.medio
    local floats = {
        fInitialDriveForce = forca,
        fInitialDriveMaxFlatVel = flat,
        fTractionCurveMax = p.aderencia,
        fTractionCurveMin = p.aderenciaMin,
        fBrakeForce = p.freio,
    }
    if Config.aplicarPeso and f.kg then floats.fMass = f.kg + 0.0 end
    if c and c.arrasto then floats.fInitialDragCoeff = c.arrasto end

    local ints = {}
    if Config.aplicarMarchas and f.marchas then
        ints.nInitialDriveGears = math.max(1, math.min(f.marchas, Config.maxMarchas))
    end
    return floats, ints, alvo
end
