-- pa_medico · atendimento do médico (servidor)
-- Ficha do paciente, reanimar e tratar na rua (com itens) ou no hospital (sem itens).
-- Tudo é conferido aqui: emprego, distância, estado do paciente, itens e o tempo da animação.

local BAG_MORTE = 'qbx_medical:deathState'
local BAG_SANGUE = 'qbx_medical:bleedLevel'
local BAG_FERIDA = 'qbx_medical:injuries:'
local CAIDO, MORTO = 2, 3

local A = Config.atendimento

local PARTES = {
    { 'HEAD', 'Cabeça' }, { 'NECK', 'Pescoço' }, { 'SPINE', 'Coluna' },
    { 'UPPER_BODY', 'Tórax' }, { 'LOWER_BODY', 'Abdômen' },
    { 'LARM', 'Braço esquerdo' }, { 'LHAND', 'Mão esquerda' }, { 'LFINGER', 'Dedos esquerdos' },
    { 'RARM', 'Braço direito' }, { 'RHAND', 'Mão direita' }, { 'RFINGER', 'Dedos direitos' },
    { 'LLEG', 'Perna esquerda' }, { 'LFOOT', 'Pé esquerdo' },
    { 'RLEG', 'Perna direita' }, { 'RFOOT', 'Pé direito' },
}
local NIVEIS = { 'Leve', 'Moderado', 'Grave', 'Crítico' }
local SANGUE = { [0] = 'Sem sangramento', 'Pouco', 'Sangrando', 'Muito', 'Hemorragia' }

---@type table<number, {alvo: number, tipo: string, inicio: number, duracao: number}>
local emAndamento = {}

local function medicoEmServico(src)
    local p = exports.qbx_core:GetPlayer(src)
    return p and p.PlayerData.job.type == Config.tipoEmprego and p.PlayerData.job.onduty
end

local function nomeDe(src)
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return ('ID %s'):format(src) end
    return ('%s %s'):format(p.PlayerData.charinfo.firstname, p.PlayerData.charinfo.lastname)
end

local function perto(a, b, dist)
    if GetPlayerRoutingBucket(a) ~= GetPlayerRoutingBucket(b) then return false end
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return false end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= dist
end

local function desmaiado(src)
    local e = Player(src).state[BAG_MORTE]
    return e == CAIDO or e == MORTO
end

local function hospitalDe(src)
    local c = GetEntityCoords(GetPlayerPed(src))
    for _, h in ipairs(A.hospital.locais) do
        if #(c - h.coords) <= h.raio then return h end
    end
end

local function vidaPct(src)
    local ped = GetPlayerPed(src)
    local vida, max = GetEntityHealth(ped), GetEntityMaxHealth(ped)
    if max <= 100 then max = 200 end
    return math.floor(math.max(0, math.min(100, (vida - 100) / (max - 100) * 100)) + 0.5)
end

local function ferimentos(src)
    local estado = Player(src).state
    local lista, pior = {}, 0
    for _, p in ipairs(PARTES) do
        local f = estado[BAG_FERIDA .. p[1]]
        if f and f.severity then
            lista[#lista + 1] = { parte = p[2], nivel = f.severity, texto = NIVEIS[f.severity] or '?' }
            if f.severity > pior then pior = f.severity end
        end
    end
    table.sort(lista, function(a, b) return a.nivel > b.nivel end)
    return lista, pior
end

local function contar(src, item)
    return exports.ox_inventory:Search(src, 'count', item) or 0
end

---Regras de cada procedimento: o que pede e se pode ser feito agora
local function avaliar(medico, alvo, tipo)
    local caido = desmaiado(alvo)
    local hosp = hospitalDe(alvo) ~= nil
    local it = A.itens

    if tipo == 'reanimar' then
        if not caido then return false, 'O paciente está acordado.' end
        if hosp then return true, nil, A.hospital.reanimar.duracao end
        if contar(medico, it.desfibrilador) < 1 then return false, 'Precisa de um desfibrilador.' end
        if contar(medico, it.adrenalina) < 1 then return false, 'Precisa de adrenalina.' end
        return true, nil, A.reanimar.duracao
    end

    if caido then return false, 'Reanime o paciente primeiro.' end

    if tipo == 'bandagem' then
        if (Player(alvo).state[BAG_SANGUE] or 0) <= 0 then return false, 'Não está sangrando.' end
        if not hosp and contar(medico, it.bandagem) < 1 then return false, 'Precisa de bandagem.' end
        return true, nil, A.bandagem.duracao
    elseif tipo == 'trauma' then
        if hosp then return false, 'No hospital use o tratamento completo.' end
        if contar(medico, it.trauma) < 1 then return false, 'Precisa de um kit de trauma.' end
        return true, nil, A.trauma.duracao
    elseif tipo == 'hospital' then
        if not hosp then return false, 'Só dentro do hospital.' end
        return true, nil, A.hospital.tratamento.duracao
    end
    return false, 'Procedimento desconhecido.'
end

---------------------------------------------------------------------
-- FICHA
---------------------------------------------------------------------
lib.callback.register('pa_medico:server:ficha', function(src, alvo)
    alvo = tonumber(alvo)
    if not alvo or alvo == src or not medicoEmServico(src) then return nil end
    if not exports.qbx_core:GetPlayer(alvo) or not perto(src, alvo, A.distancia + 2.0) then return nil end

    local lista, pior = ferimentos(alvo)
    local sangue = Player(alvo).state[BAG_SANGUE] or 0
    local hosp = hospitalDe(alvo)

    local procedimentos = {}
    for _, tipo in ipairs({ 'reanimar', 'bandagem', 'trauma', 'hospital' }) do
        local ok, motivo = avaliar(src, alvo, tipo)
        procedimentos[tipo] = { ok = ok, motivo = motivo }
    end

    return {
        nome = nomeDe(alvo),
        desmaiado = desmaiado(alvo),
        vida = desmaiado(alvo) and 0 or vidaPct(alvo),
        sangue = sangue,
        sangueTexto = SANGUE[sangue] or '?',
        ferimentos = lista,
        pior = pior,
        hospital = hosp and hosp.nome or nil,
        procedimentos = procedimentos,
    }
end)

---------------------------------------------------------------------
-- PROCEDIMENTOS
---------------------------------------------------------------------
lib.callback.register('pa_medico:server:iniciar', function(src, alvo, tipo)
    alvo = tonumber(alvo)
    if not alvo or alvo == src or type(tipo) ~= 'string' then return false end
    if not medicoEmServico(src) then return false, 'Você não está em serviço.' end
    if not perto(src, alvo, A.distancia) then return false, 'Chegue mais perto do paciente.' end

    local ok, motivo, duracao = avaliar(src, alvo, tipo)
    if not ok then return false, motivo end

    emAndamento[src] = { alvo = alvo, tipo = tipo, inicio = os.time(), duracao = duracao }
    TriggerClientEvent('pa_medico:client:sendoAtendido', alvo, nomeDe(src), tipo)
    return true, duracao
end)

lib.callback.register('pa_medico:server:cancelar', function(src)
    local a = emAndamento[src]
    emAndamento[src] = nil
    if a then TriggerClientEvent('pa_medico:client:atendimentoCancelado', a.alvo) end
    return true
end)

lib.callback.register('pa_medico:server:concluir', function(src, alvo, tipo)
    local a = emAndamento[src]
    emAndamento[src] = nil
    alvo = tonumber(alvo)
    if not a or a.alvo ~= alvo or a.tipo ~= tipo then return false end
    if os.time() - a.inicio < a.duracao - 1 then return false, 'Procedimento interrompido.' end
    if not medicoEmServico(src) then return false end
    if not perto(src, alvo, A.distancia + 1.0) then return false, 'O paciente se afastou.' end

    local ok, motivo = avaliar(src, alvo, tipo)
    if not ok then return false, motivo end

    local it = A.itens
    local hosp = hospitalDe(alvo)

    if tipo == 'reanimar' then
        if not hosp and not exports.ox_inventory:RemoveItem(src, it.adrenalina, 1) then
            return false, 'Precisa de adrenalina.'
        end
        -- Na rua, reanimar não cura: guarda ferimentos graves e o sangramento para devolver depois
        -- (o Revive do qbx_medical zera tudo). No hospital sai sem nada.
        local manter
        if not hosp then
            local estado = Player(alvo).state
            manter = { feridas = {}, sangue = estado[BAG_SANGUE] or 0 }
            for _, p in ipairs(PARTES) do
                local f = estado[BAG_FERIDA .. p[1]]
                if f and f.severity and f.severity >= 3 then manter.feridas[p[1]] = f end
            end
        end
        exports.qbx_medical:Revive(alvo)
        local vida = hosp and A.hospital.reanimar.vida or A.reanimar.vida
        TriggerClientEvent('pa_medico:client:aplicar', alvo, { vida = vida, definir = true, manter = manter })
        return true, ('Paciente reanimado com %s%% de vida.'):format(vida)

    elseif tipo == 'bandagem' then
        if not hosp and not exports.ox_inventory:RemoveItem(src, it.bandagem, 1) then
            return false, 'Precisa de bandagem.'
        end
        TriggerClientEvent('pa_medico:client:aplicar', alvo, {
            somarVida = A.bandagem.vida,
            tirarSangue = A.bandagem.sangramento,
        })
        return true, 'Sangramento estancado.'

    elseif tipo == 'trauma' then
        if not exports.ox_inventory:RemoveItem(src, it.trauma, 1) then
            return false, 'Precisa de um kit de trauma.'
        end
        exports.qbx_medical:HealPartially(alvo)
        TriggerClientEvent('pa_medico:client:aplicar', alvo, { vidaMinima = A.trauma.vida })
        local _, pior = ferimentos(alvo)
        if pior >= 3 then
            return true, 'Tratado na rua. Ainda tem ferimento grave: leve ao hospital.'
        end
        return true, 'Paciente tratado.'

    elseif tipo == 'hospital' then
        local preco = A.hospital.preco or 0
        if preco > 0 then
            local p = exports.qbx_core:GetPlayer(alvo)
            if p and not (p.Functions.RemoveMoney('bank', preco, 'hospital') or p.Functions.RemoveMoney('cash', preco, 'hospital')) then
                exports.qbx_core:Notify(alvo, 'Tratamento do hospital sem pagamento (sem saldo).', 'error')
            elseif p then
                exports.qbx_core:Notify(alvo, ('Tratamento do hospital: $%s'):format(preco), 'inform')
            end
        end
        exports.qbx_medical:Heal(alvo)
        TriggerClientEvent('pa_medico:client:aplicar', alvo, { vida = 100, definir = true, tirarSangue = 4 })
        return true, 'Tratamento completo: paciente 100%.'
    end
    return false
end)

AddEventHandler('playerDropped', function()
    emAndamento[source] = nil
end)
