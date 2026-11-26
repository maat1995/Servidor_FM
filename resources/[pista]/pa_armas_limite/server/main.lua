-- pa_armas_limite: no máximo 2 pistolas e 2 armas longas no inventário (estilo GTA 6)

local ox = exports.ox_inventory
local grupo = GrupoArma

local function isento(src)
    if not next(Config.isentos) then return false end
    local p = exports.qbx_core:GetPlayer(src)
    local job = p and p.PlayerData.job
    return job and Config.isentos[job.name] == true or false
end

local function contar(inv, g)
    local total = 0
    for _, item in pairs(ox:GetInventoryItems(inv) or {}) do
        if grupo(item.name) == g then total = total + (item.count or 1) end
    end
    return total
end

local function aviso(src, texto)
    if type(src) ~= 'number' or src <= 0 then return end
    exports.qbx_core:Notify(src, texto, 'error', 4500)
end

local function textoCheio(g)
    local n = Config.nomes[g]
    local lim = Config.limites[g]
    return ('Você já carrega %d %s. Guarde uma antes de pegar outra.'):format(lim, lim == 1 and n.um or n.varios)
end

--- Pode receber `qtd` dessa arma? (outros scripts podem perguntar antes de entregar)
local function podeCarregar(inv, nome, qtd)
    local g = grupo(nome)
    if not g then return true end
    if type(inv) == 'number' and isento(inv) then return true end
    return contar(inv, g) + (qtd or 1) <= Config.limites[g], g
end
exports('podeCarregar', podeCarregar)

---------------------------------------------------------------------
-- Pegar do chão, baú, porta-malas, outro jogador
---------------------------------------------------------------------
ox:registerHook('swapItems', function(p)
    if p.toType ~= 'player' or p.fromInventory == p.toInventory then return true end
    local item = p.fromSlot
    if type(item) ~= 'table' then return true end
    local g = grupo(item.name)
    if not g then return true end

    -- Troca de lugar com outra arma do mesmo grupo: o total não muda
    if p.action == 'swap' and type(p.toSlot) == 'table' and grupo(p.toSlot.name) == g then return true end

    local ok = podeCarregar(p.toInventory, item.name, p.count)
    if ok then return true end

    if p.action == 'give' then
        aviso(p.source, ('Essa pessoa já carrega o máximo de %s.'):format(Config.nomes[g].varios))
        aviso(p.toInventory, textoCheio(g))
    else
        aviso(p.source, textoCheio(g))
    end
    return false
end, {})

---------------------------------------------------------------------
-- Comprar na loja
---------------------------------------------------------------------
ox:registerHook('buyItem', function(p)
    local ok, g = podeCarregar(p.toInventory, p.itemName, p.count)
    if ok then return true end
    aviso(p.source, textoCheio(g))
    return false
end, {})

---------------------------------------------------------------------
-- Scripts que entregam a arma direto (AddItem): o excesso cai no chão
---------------------------------------------------------------------
ox:registerHook('createItem', function(p)
    if not Config.derrubarExcesso then return end
    local inv = p.inventoryId
    local item = p.item
    if type(inv) ~= 'number' or type(item) ~= 'table' then return end
    local g = grupo(item.name)
    if not g or isento(inv) then return end

    local meta = p.metadata
    SetTimeout(300, function()
        if contar(inv, g) <= Config.limites[g] then return end

        -- acha a arma recém-criada (mesmo número de série) ou a última desse nome
        local alvo
        for _, s in pairs(ox:GetInventoryItems(inv) or {}) do
            if s.name == item.name then
                if meta and meta.serial and s.metadata and s.metadata.serial == meta.serial then alvo = s break end
                if not alvo or s.slot > alvo.slot then alvo = s end
            end
        end
        if not alvo then return end

        local ped = GetPlayerPed(inv)
        if ped == 0 then return end
        local c = GetEntityCoords(ped)
        if ox:RemoveItem(inv, alvo.name, 1, alvo.metadata, alvo.slot) then
            ox:CustomDrop('Arma', { { alvo.name, 1, alvo.metadata } }, vec3(c.x, c.y, c.z - 0.95))
            aviso(inv, ('Você não tem espaço para mais %s. A arma ficou no chão.'):format(Config.nomes[g].varios))
        end
    end)
end, {})

lib.addCommand('armas', { help = 'Ver quantas armas você carrega' }, function(source)
    local p, l = contar(source, 'pistola'), contar(source, 'longa')
    exports.qbx_core:Notify(source, ('Pistolas %d/%d  ·  Armas longas %d/%d'):format(
        p, Config.limites.pistola, l, Config.limites.longa), 'inform', 5000)
end)
