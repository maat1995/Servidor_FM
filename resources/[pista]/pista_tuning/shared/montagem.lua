-- Montagem do motor: ganhos, riscos e limites (cliente e servidor usam o mesmo cálculo)

--- Tipo do pistão ('taxado', 'forjado' ou nil). Carros antigos tinham pistao = true (forjado).
function TipoPistao(dados)
    local p = dados and dados.pistao
    if p == true then return 'forjado' end
    if p == 'taxado' or p == 'forjado' then return p end
    return nil
end

local function somar(total, e, fator)
    if not e then return end
    fator = fator or 1.0
    total.forca = total.forca + (e.forca or 0.0) * fator
    total.vmax = total.vmax + (e.vmax or 0.0) * fator
    total.giro = total.giro + (e.giro or 0.0) * fator
end

--- Ganho de pistão + cabeçote + combinações (sem chip/turbo/remap)
function EfeitosMotor(dados)
    local m = Config.montagem
    local total = { forca = 0.0, vmax = 0.0, giro = 0.0 }
    if not dados then return total end
    local pistao = TipoPistao(dados)
    local turbo = dados.turbo == true

    if pistao == 'taxado' then
        somar(total, m.pistao.taxado, turbo and m.taxadoComTurbo or 1.0)
    elseif pistao == 'forjado' then
        somar(total, m.pistao.forjado)
    end

    if dados.cabecote == 1 then
        somar(total, m.cabecote[1])
    elseif dados.cabecote == 2 then
        somar(total, m.cabecote[2], pistao and 1.0 or m.corridaSemPistao)
    end

    if dados.cabecote == 2 and pistao == 'taxado' and not turbo then somar(total, m.combos.aspiradoPista) end
    if dados.cabecote == 2 and pistao == 'forjado' and turbo then somar(total, m.combos.turboPista) end
    return total
end

--- Riscos fixos da montagem (valem em giro alto). Lista de { dano, aviso }.
function RiscosMontagem(dados)
    local d = Config.risco.danos
    local lista = {}
    if not dados then return lista end
    local pistao = TipoPistao(dados)
    if (dados.chip or 0) >= 2 and dados.turbo and not dados.intercooler then
        lista[#lista + 1] = { dano = d.semIntercooler, aviso = 'Motor esquentando: falta intercooler' }
    end
    if (dados.chip or 0) >= 3 and pistao ~= 'forjado' then
        lista[#lista + 1] = { dano = d.stage3SemForjado, aviso = 'Motor sofrendo: Stage 3 sem pistão forjado' }
    end
    if pistao == 'taxado' and dados.turbo then
        lista[#lista + 1] = { dano = d.taxadoComTurbo, aviso = 'Batida de pino: pistão taxado com turbo' }
    end
    if dados.cabecote == 2 and not pistao then
        lista[#lista + 1] = { dano = d.corridaSemPistao, aviso = 'Cabeçote de corrida forçando motor original' }
    end
    return lista
end

--- Motor quebrado: o que ainda falta fazer na bancada (lista de textos, na ordem)
function PendentesMotor(dados)
    local q = dados and dados.motorQuebrado
    if type(q) ~= 'table' then return {} end
    local lista = {}
    if q.retifica then lista[#lista + 1] = 'retífica' end
    if q.pistao then lista[#lista + 1] = 'pistões novos' end
    if q.bielas then lista[#lista + 1] = 'bielas novas' end
    return lista
end

--- Nome da montagem, para mostrar nos menus
function NomeMontagem(dados)
    local pistao = TipoPistao(dados)
    local turbo = dados and dados.turbo
    if pistao == 'taxado' and dados.cabecote == 2 and not turbo then return 'Aspirado de pista' end
    if pistao == 'taxado' and not turbo then return 'Aspirado de rua' end
    if pistao == 'forjado' and dados.cabecote == 2 and turbo then return 'Turbo de pista' end
    if pistao == 'forjado' and turbo then return 'Turbo de rua' end
    if pistao == 'taxado' and turbo then return 'Montagem errada (taxado com turbo)' end
    if turbo then return 'Turbo com motor original' end
    return 'Original'
end
