-- pa_policia · servidor · crimes que avisam a polícia sozinhos
-- O cliente de quem cometeu o crime avisa; aqui sorteamos a testemunha, limitamos o spam e agrupamos.

local espera = {}     -- [src..tipo] = os.time()
local recentes = {}   -- { tipo, coords, t }

local function limpar(texto, max)
    if type(texto) ~= 'string' then return nil end
    texto = texto:gsub('[%c<>]', ''):sub(1, max or 60)
    return texto ~= '' and texto or nil
end

local function descricao(tipo, src, info)
    info = type(info) == 'table' and info or {}
    local partes = {}
    local veic = type(info.veiculo) == 'table' and info.veiculo or nil
    if veic then
        local modelo, cor, placa = limpar(veic.modelo, 30), limpar(veic.cor, 20), limpar(veic.placa, 10)
        local v = table.concat({ modelo or 'Veículo', cor }, ' ')
        if placa then v = ('%s · placa %s'):format(v, placa) end
        partes[#partes + 1] = v
    end
    local ped = GetPlayerPed(src)
    if tipo ~= 'direcaoPerigosa' and ped ~= 0 then
        partes[#partes + 1] = ('Suspeito: %s'):format(GetEntityModel(ped) == `mp_f_freemode_01` and 'mulher' or 'homem')
    end
    return #partes > 0 and table.concat(partes, ' · ') or nil
end

--- Registra um crime cometido por src. Retorna o id do alerta (ou nil se ninguém viu)
function P.Crime(src, tipo, info)
    local cfg = Config.crimes and Config.crimes[tipo]
    if not cfg or not cfg.ativo then return end
    if P.EmServico(src) then return end
    if P.PoliciaisEmServico() == 0 then return end

    local chave = src .. ':' .. tipo
    if os.time() - (espera[chave] or 0) < cfg.espera then return end

    local chance = cfg.chance
    if tipo == 'tiro' and type(info) == 'table' and info.silenciado then chance = cfg.silenciadorAvisa or 0 end
    if math.random(100) > chance then
        espera[chave] = os.time() -- ninguém viu: só tenta de novo depois da espera
        return
    end

    local coords = P.Coords(src)
    local agora = os.time()
    for i = #recentes, 1, -1 do
        local r = recentes[i]
        if agora - r.t > Config.crimesAgrupar.segundos then
            table.remove(recentes, i)
        elseif r.tipo == tipo and #(r.coords - coords) < Config.crimesAgrupar.distancia then
            espera[chave] = agora
            return -- já tem um aviso igual aqui perto
        end
    end
    espera[chave] = agora
    recentes[#recentes + 1] = { tipo = tipo, coords = coords, t = agora }

    return P.Alerta({
        codigo = cfg.codigo,
        titulo = cfg.titulo,
        descricao = descricao(tipo, src, info),
        coords = coords,
        raio = cfg.raio,
        prioridade = cfg.prioridade,
        sprite = cfg.sprite,
    })
end
exports('crime', function(src, tipo, info) return P.Crime(src, tipo, info) end)

-- tiros chegam pela perícia (cápsula); os outros vêm daqui
local PELO_CLIENTE = { rouboVeiculo = true, briga = true, atropelamento = true, direcaoPerigosa = true }

RegisterNetEvent('pa_policia:server:crime', function(tipo, info)
    local src = source
    if not PELO_CLIENTE[tipo] then return end
    P.Crime(src, tipo, info)
end)

AddEventHandler('playerDropped', function()
    local src = tostring(source)
    for k in pairs(espera) do
        if k:sub(1, #src + 1) == src .. ':' then espera[k] = nil end
    end
end)
