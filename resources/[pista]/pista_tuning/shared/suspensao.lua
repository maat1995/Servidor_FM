-- pista_tuning - suspensão regulável: valores e conversão (cliente e servidor)

-- campo do painel -> faixa do Config.suspensao.faixas
local FAIXA_DO_CAMPO = {
    altura = 'altura', compressao = 'compressao', retorno = 'retorno',
    molaD = 'mola', molaT = 'mola', barraD = 'barra', barraT = 'barra',
    cambagemD = 'cambagem', cambagemT = 'cambagem', bitolaD = 'bitola', bitolaT = 'bitola',
}
CAMPOS_SUSP = FAIXA_DO_CAMPO

--- Prende cada valor dentro da faixa e no passo certo. Valores faltando viram o padrão.
function NormalizarSusp(v)
    v = type(v) == 'table' and v or {}
    local cfg = Config.suspensao
    local r = {}
    for campo, faixa in pairs(FAIXA_DO_CAMPO) do
        local f = cfg.faixas[faixa]
        local n = tonumber(v[campo]) or cfg.padrao[campo]
        n = math.max(f.min, math.min(f.max, n))
        n = f.min + math.floor((n - f.min) / f.passo + 0.5) * f.passo
        r[campo] = math.max(f.min, math.min(f.max, n))
    end
    return r
end

--- Mola/barra dianteira e traseira viram força total + divisão (bias) do GTA.
--- base = { force, biasSusp, roll, biasRoll, comp, rebound }
function HandlingDaSusp(s, base)
    local function dividir(total, bias, d, t)
        local frente, tras = bias * d, (1.0 - bias) * t
        local soma = frente + tras
        if soma <= 0.0001 then return 0.0, bias end
        -- força média ponderada pela divisão original; nova divisão pelo peso de cada eixo
        return total * soma, frente / soma
    end
    local mola, biasMola = dividir(base.force, base.biasSusp, s.molaD / 100.0, s.molaT / 100.0)
    local barra, biasBarra = dividir(base.roll, base.biasRoll, s.barraD / 100.0, s.barraT / 100.0)
    return {
        fSuspensionForce = mola,
        fSuspensionBiasFront = biasMola,
        fAntiRollBarForce = barra,
        fAntiRollBarBiasFront = biasBarra,
        fSuspensionCompDamp = base.comp * s.compressao / 100.0,
        fSuspensionReboundDamp = base.rebound * s.retorno / 100.0,
    }
end
