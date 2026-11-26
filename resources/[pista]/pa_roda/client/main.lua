-- pa_roda - roda de armas e itens (estilo GTA 6)

local ox = exports.ox_inventory
local aberta = false
local abertaEm = 0
local defs = nil
local listaFora, ordemPref = {}, {}

for _, n in ipairs(Config.itensFora) do listaFora[n] = true end
for i, n in ipairs(Config.itensPreferidos) do ordemPref[n] = i end

local dinheiroMao, dinheiroSujo = {}, {}
for _, n in ipairs(Config.dinheiro.mao) do dinheiroMao[n] = true end
for _, n in ipairs(Config.dinheiro.sujo) do dinheiroSujo[n] = true end

local OUTROS = { WEAPON_STUNGUN = true, WEAPON_STUNGUN_MP = true, WEAPON_FLAREGUN = true }

local function itensDef()
    if not defs then defs = ox:Items() or {} end
    return defs
end

local function grupoArma(nome)
    if GetResourceState('pa_armas_limite') == 'started' then
        local ok, g = pcall(function() return exports.pa_armas_limite:grupo(nome) end)
        if ok then return g end
    end
    local n = nome:upper()
    if n:find('PISTOL') or n:find('REVOLVER') then return 'pistola' end
    if n:find('SMG') or n:find('RIFLE') or n:find('SHOTGUN') or n:find('SNIPER') or n:find('CARBINE') or n:find('_MG') then return 'longa' end
end

local function imagem(nome, d)
    if d and d.client and d.client.image then return d.client.image end
    return ('nui://ox_inventory/web/images/%s.png'):format(nome)
end

local function contarItem(itens, nome)
    if not nome then return 0 end
    local t = 0
    for _, it in pairs(itens) do
        if it.name == nome then t = t + (it.count or 0) end
    end
    return t
end

---------------------------------------------------------------------
-- Monta o que aparece na roda
---------------------------------------------------------------------
local function entradaArma(it, d, itens, atual)
    local e = {
        slot = it.slot,
        nome = it.name,
        label = it.metadata and it.metadata.label or it.label or (d and d.label) or it.name,
        img = imagem(it.name, d),
        naMao = atual and atual.slot == it.slot or false,
    }
    if d.throwable then
        e.qtd = it.count or 1
    elseif d.ammoname then
        local pente = it.metadata and it.metadata.ammo or 0
        if e.naMao then
            local ok, clip = GetAmmoInClip(cache.ped, joaat(it.name))
            if ok then pente = clip end
        end
        e.pente = pente
        e.reserva = contarItem(itens, d.ammoname)
    end
    if it.metadata and it.metadata.durability then e.durabilidade = math.floor(it.metadata.durability) end
    return e
end

local function montar()
    local itens = ox:GetPlayerItems() or {}
    local d = itensDef()
    local atual = ox:getCurrentWeapon()

    local g = { longa = {}, pistola = {}, branca = {}, arremesso = {}, outros = {} }
    local usaveis = {}
    local bolso = {}
    local dinheiro = { mao = 0, sujo = 0 }

    local ordenados = {}
    for _, it in pairs(itens) do ordenados[#ordenados + 1] = it end
    table.sort(ordenados, function(a, b) return a.slot < b.slot end)

    for _, it in ipairs(ordenados) do
        local def = d[it.name]
        if def and def.weapon then
            local grp = grupoArma(it.name)
            if not grp then
                if def.throwable then grp = 'arremesso'
                elseif OUTROS[it.name:upper()] or def.ammoname then grp = 'outros'
                else grp = 'branca' end
            end
            g[grp][#g[grp] + 1] = entradaArma(it, def, itens, atual)
        elseif def then
            local label = it.metadata and it.metadata.label or it.label or def.label or it.name
            if dinheiroMao[it.name] then dinheiro.mao = dinheiro.mao + (it.count or 0) end
            if dinheiroSujo[it.name] then dinheiro.sujo = dinheiro.sujo + (it.count or 0) end

            -- Bolso: tudo que não é arma (só para ver)
            if not dinheiroMao[it.name] then
                bolso[#bolso + 1] = { slot = it.slot, nome = it.name, label = label, qtd = it.count, img = imagem(it.name, def) }
            end

            if not def.ammo and not def.component and not listaFora[it.name] and not it.name:find('^ammo') then
                local c = def.client
                local usavel = (c and (c.status or c.usetime or c.export or c.event or c.anim)) or def.export
                local favorito = it.slot <= Config.favoritos
                if favorito or usavel or ordemPref[it.name] then
                    usaveis[#usaveis + 1] = {
                        slot = it.slot, nome = it.name, qtd = it.count, label = label,
                        img = imagem(it.name, def),
                        favorito = favorito or nil,
                        semUso = not (usavel or ordemPref[it.name]) or nil,
                        ordem = favorito and it.slot or ordemPref[it.name] and (10 + ordemPref[it.name]) or (100 + it.slot),
                    }
                end
            end
        end
    end
    table.sort(usaveis, function(a, b) return a.ordem < b.ordem end)

    -- Posições (sentido horário, começando em cima)
    local armas = {
        { tipo = 'longa',     opcoes = { g.longa[1] } },
        { tipo = 'longa',     opcoes = { g.longa[2] } },
        { tipo = 'pistola',   opcoes = { g.pistola[1] } },
        { tipo = 'pistola',   opcoes = { g.pistola[2] } },
        { tipo = 'desarmado', opcoes = { { desarmado = true, label = 'Desarmado', naMao = atual == nil } } },
        { tipo = 'arremesso', opcoes = g.arremesso },
        { tipo = 'branca',    opcoes = g.branca },
        { tipo = 'outros',    opcoes = g.outros },
    }
    -- excesso (quem tinha mais armas antes do limite) vai para "outros"
    for i = 3, #g.longa do table.insert(armas[8].opcoes, g.longa[i]) end
    for i = 3, #g.pistola do table.insert(armas[8].opcoes, g.pistola[i]) end

    local itensRoda = {}
    for i = 1, 8 do itensRoda[i] = { tipo = 'item', opcoes = { usaveis[i] } } end
    -- itens a mais entram como opções extras do último espaço (rolar o mouse troca)
    for i = 9, #usaveis do table.insert(itensRoda[8].opcoes, usaveis[i]) end

    local naMao
    if atual then
        local def = d[atual.name]
        naMao = { label = atual.metadata and atual.metadata.label or atual.label or (def and def.label) or atual.name }
        for _, pos in ipairs(armas) do
            for _, e in ipairs(pos.opcoes) do
                if e and e.slot == atual.slot then naMao.pente, naMao.reserva, naMao.qtd = e.pente, e.reserva, e.qtd end
            end
        end
    end

    return { armas = armas, itens = itensRoda, bolso = bolso, dinheiro = dinheiro, naMao = naMao }
end

---------------------------------------------------------------------
-- Abrir / fechar
---------------------------------------------------------------------
local function podeAbrir()
    local motivo
    local st = LocalPlayer.state
    if aberta then motivo = 'já aberta'
    elseif IsPauseMenuActive() then motivo = 'menu de pausa'
    elseif IsNuiFocused() then motivo = 'outra tela com foco (NUI)'
    elseif st.invOpen then motivo = 'inventário aberto'
    elseif st.invBusy then motivo = 'inventário ocupado'
    elseif st.isDead or st.dead or IsEntityDead(cache.ped) then motivo = 'morto'
    elseif IsPedCuffed(cache.ped) then motivo = 'algemado' end
    if motivo and Config.debug then print(('[pa_roda] não abriu: %s'):format(motivo)) end
    return not motivo
end

local function fechar()
    if not aberta then return end
    aberta = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ acao = 'fechar' })
    if Config.desfoque then TriggerScreenblurFadeOut(150) end
end

local function abrir()
    if not podeAbrir() then return end
    local ok, dados = pcall(montar)
    if not ok then
        print(('^1[pa_roda] erro ao montar a roda: %s^0'):format(dados))
        return
    end
    aberta = true
    abertaEm = GetGameTimer()
    if Config.debug then print('[pa_roda] roda aberta') end
    SendNUIMessage({ acao = 'abrir', dados = dados, tecla = Config.tecla, modo = Config.modo })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(Config.andarAberta)
    if Config.desfoque then TriggerScreenblurFadeIn(150) end

    CreateThread(function()
        while aberta do
            DisableControlAction(0, 1, true)    -- câmera
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)   -- atirar
            DisableControlAction(0, 25, true)   -- mirar
            DisableControlAction(0, 37, true)   -- roda nativa
            DisableControlAction(0, 140, true)  -- soco
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 14, true)   -- rolar arma
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 16, true)
            DisableControlAction(0, 17, true)
            DisableControlAction(0, 106, true)  -- mouse no veículo
            if not Config.andarAberta then
                DisableControlAction(0, 30, true)
                DisableControlAction(0, 31, true)
                DisableControlAction(0, 21, true)
                DisableControlAction(0, 22, true)
            end
            if IsEntityDead(cache.ped) then fechar() end
            Wait(0)
        end
    end)
end

-- O nome do atalho mudou (pa_roda_tab) para o FiveM usar a tecla nova de padrão
lib.addKeybind({
    name = 'pa_roda_tab',
    description = 'Roda de armas e itens',
    defaultKey = Config.tecla,
    onPressed = function()
        if Config.debug then print('[pa_roda] tecla apertada') end
        if aberta then
            -- modo alternar: apertar de novo fecha (ignora o mesmo toque que abriu)
            if Config.modo == 'alternar' and GetGameTimer() - abertaEm > 200 then fechar() end
            return
        end
        abrir()
    end,
    onReleased = function()
        if aberta and Config.modo == 'segurar' then SendNUIMessage({ acao = 'soltar' }) end
    end,
})

-- Teste sem tecla: /roda abre e o clique escolhe
RegisterCommand('roda', function() abrir() end, false)

---------------------------------------------------------------------
-- Escolha feita na roda
---------------------------------------------------------------------
RegisterNUICallback('escolher', function(data, cb)
    cb('ok')
    fechar()
    if type(data) ~= 'table' then return end

    if data.desarmado then
        if ox:getCurrentWeapon() then TriggerEvent('ox_inventory:disarm') end
        return
    end

    local slot = tonumber(data.slot)
    if not slot then return end
    local atual = ox:getCurrentWeapon()
    if atual and atual.slot == slot then return end -- já está na mão

    -- confere se o item ainda está no mesmo lugar
    local itens = ox:GetPlayerItems() or {}
    local it = itens[slot]
    if not it or (data.nome and it.name ~= data.nome) then return end

    SetTimeout(50, function() ox:useSlot(slot) end)
end)

RegisterNUICallback('mochila', function(_, cb)
    cb('ok')
    fechar()
    SetTimeout(100, function() ox:openInventory() end)
end)

RegisterNUICallback('cancelar', function(_, cb)
    cb('ok')
    fechar()
end)

AddEventHandler('ox_inventory:updateInventory', function() defs = nil end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if aberta then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        TriggerScreenblurFadeOut(0)
    end
end)
