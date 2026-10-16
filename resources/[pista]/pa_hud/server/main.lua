-- pa_hud - servidor: estresse e saldo (vieram do qbx_hud, que foi desligado)
-- Os eventos mantêm o nome antigo para os scripts que já usam (comida, bebida, cigarro...)

local function valorValido(v)
    return type(v) == 'number' and v == v and v > 0 and v <= 100
end

local function mudarEstresse(src, delta, avisoTexto, cor)
    if not Config.estresse.ativo then return end
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    if delta > 0 and Config.estresse.policiaSemEstresse and player.PlayerData.job.type == 'leo' then return end

    local atual = player.PlayerData.metadata.stress or 0
    local novo = math.max(0, math.min(100, atual + delta))
    if novo == atual then return end

    player.Functions.SetMetaData('stress', novo)
    TriggerClientEvent('hud:client:UpdateStress', src, novo)
    exports.qbx_core:Notify(src, avisoTexto, 'inform', 2500, nil, nil, { '#141517', '#ffffff' }, 'brain', cor)
end

RegisterNetEvent('hud:server:GainStress', function(qtd)
    if not valorValido(qtd) then return end
    mudarEstresse(source, qtd, 'Sentindo-se mais estressado', '#C53030')
end)

RegisterNetEvent('hud:server:RelieveStress', function(qtd)
    if not valorValido(qtd) then return end
    mudarEstresse(source, -qtd, 'Sentindo-se mais relaxado', '#0F52BA')
end)

-- Esconde a HUD com o inventário aberto
AddEventHandler('ox_inventory:openedInventory', function(src)
    TriggerClientEvent('pa_hud:client:inventario', src, true)
end)

AddEventHandler('ox_inventory:closedInventory', function(src)
    TriggerClientEvent('pa_hud:client:inventario', src, false)
end)

-- /banco e /dinheiro
local function formatar(v)
    local s = tostring(math.floor(v or 0))
    return (s:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', ''))
end

lib.addCommand('banco', { help = 'Ver saldo no banco' }, function(source)
    local p = exports.qbx_core:GetPlayer(source)
    if not p then return end
    exports.qbx_core:Notify(source, ('Banco: $%s'):format(formatar(p.PlayerData.money.bank)), 'inform', 5000)
end)

lib.addCommand('dinheiro', { help = 'Ver dinheiro na mão' }, function(source)
    local p = exports.qbx_core:GetPlayer(source)
    if not p then return end
    exports.qbx_core:Notify(source, ('Dinheiro: $%s'):format(formatar(p.PlayerData.money.cash)), 'inform', 5000)
end)
