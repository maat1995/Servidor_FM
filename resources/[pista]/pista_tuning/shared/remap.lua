-- Cálculo do remap (usado no cliente e no servidor, para dar sempre o mesmo resultado)

local function arred(v, passo)
    return math.floor(v / passo + 0.5) * passo
end

local function limitar(v, min, max)
    if v < min then return min end
    if v > max then return max end
    return v
end

--- Limitador máximo: o do stage do chip + o extra do cabeçote.
function LimitadorMaximo(dados)
    local lim = dados and dados.chip and Config.remap.limites[dados.chip]
    if not lim then return Config.remap.padrao.limitador end
    local extra = dados.cabecote and Config.remap.limitadorExtraCabecote[dados.cabecote] or 0
    return lim.limitadorMax + extra
end

--- Garante que os valores estão dentro do que o chip/peças permitem.
---@param valores table? {turbo, ignicao, limitador, mistura}
---@param dados table dados do carro (chip, turbo, ...)
---@return table? remap normalizado, ou nil se não tem chip
function NormalizarRemap(valores, dados)
    local stage = dados and dados.chip
    local lim = stage and Config.remap.limites[stage]
    if not lim then return nil end

    local f = Config.remap.faixas
    local p = Config.remap.padrao
    valores = valores or {}

    local turbo = tonumber(valores.turbo) or p.turbo
    local ignicao = tonumber(valores.ignicao) or p.ignicao
    local limitador = tonumber(valores.limitador) or p.limitador
    local mistura = tonumber(valores.mistura) or p.mistura

    return {
        turbo = dados.turbo and arred(limitar(turbo, f.turbo.min, lim.turboMax), f.turbo.passo) or 0.0,
        ignicao = arred(limitar(ignicao, f.ignicao.min, lim.ignicaoMax), f.ignicao.passo),
        limitador = arred(limitar(limitador, f.limitador.min, LimitadorMaximo(dados)), f.limitador.passo),
        mistura = arred(limitar(mistura, f.mistura.min, f.mistura.max), f.mistura.passo),
    }
end

--- Efeito do remap: ganhos (em fração) e risco (0 a 100).
---@param remap table? já normalizado
---@param dados table
---@return table {forca, vmax, giro, risco}
function CalcularRemap(remap, dados)
    local r = { forca = 0.0, vmax = 0.0, giro = 0.0, risco = 0.0 }
    if not remap or not dados or not dados.chip then return r end

    local t, i, l, m = remap.turbo or 0.0, remap.ignicao or 0, remap.limitador or 7000, remap.mistura or 12.5

    -- Pressão do turbo
    r.forca = r.forca + t * 0.10
    r.giro = r.giro + t * 0.02
    local riscoTurbo = t * t * 12.0
    if dados.intercooler then riscoTurbo = riscoTurbo * 0.5 end

    -- Avanço de ignição
    r.forca = r.forca + i * 0.008
    r.giro = r.giro + i * 0.004
    local riscoMecanico = i > 0 and (i * i * 0.6) or 0.0

    -- Limitador de giro
    r.vmax = r.vmax + ((l - 7000) / 1000.0) * 0.03
    riscoMecanico = riscoMecanico + math.max(0, l - 7500) / 100.0 * 1.2
    if dados.pistao then riscoMecanico = riscoMecanico * 0.5 end

    -- Mistura ar/combustível
    r.forca = r.forca + (m - 12.5) * 0.03
    local riscoMistura = 0.0
    if m > 12.5 then
        riscoMistura = (m - 12.5) ^ 2 * 6.0
    else
        riscoMistura = -(12.5 - m) * 8.0 -- mistura rica protege o motor
    end

    r.risco = limitar(riscoTurbo + riscoMecanico + riscoMistura, 0.0, 100.0)
    return r
end
