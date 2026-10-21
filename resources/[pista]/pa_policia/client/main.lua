-- pa_policia · cliente · base
-- Estado do policial, pontos da DP (ox_target), garagem de viaturas, blips dos colegas e menu F6.

PC = {
    dados = nil,      -- { grau, patente, servico, perms }
    viatura = nil,
}

local blipsColegas = {}

---------------------------------------------------------------------
-- ESTADO
---------------------------------------------------------------------
function PC.EhPolicia()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.name == Config.job
end

function PC.EmServico()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.name == Config.job and job.onduty == true
end

function PC.Grau()
    local job = QBX.PlayerData and QBX.PlayerData.job
    if not job or job.name ~= Config.job then return -1 end
    return job.grade and job.grade.level or 0
end

function PC.Pode(acao)
    if not PC.EmServico() then return false end
    local min = Config.permissoes[acao]
    return min ~= nil and PC.Grau() >= min
end

function PC.Aviso(msg, tipo, dur)
    lib.notify({ title = Config.Titulo, description = msg, type = tipo or 'inform', duration = dur })
end

function PC.Resultado(ok, msg)
    if msg then PC.Aviso(msg, ok and 'success' or 'error') end
    return ok
end

local function limparColegas()
    for _, b in pairs(blipsColegas) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    blipsColegas = {}
end

local function aoMudarServico()
    if not PC.EmServico() then
        limparColegas()
        TriggerEvent('pa_policia:client:saiuServico')
    end
end

RegisterNetEvent('QBCore:Client:SetDuty', function() Wait(200) aoMudarServico() end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function() Wait(200) aoMudarServico() end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() limparColegas() end)

---------------------------------------------------------------------
-- BLIPS DOS COLEGAS
---------------------------------------------------------------------
RegisterNetEvent('pa_policia:client:colegas', function(lista)
    if GetInvokingResource() then return end
    if not PC.EmServico() then return limparColegas() end
    local vistos = {}
    for _, c in ipairs(lista) do
        if c.s ~= cache.serverId then
            vistos[c.s] = true
            local b = blipsColegas[c.s]
            if not b or not DoesBlipExist(b) then
                b = AddBlipForCoord(c.x, c.y, c.z)
                SetBlipColour(b, 38)
                SetBlipScale(b, 0.8)
                SetBlipAsShortRange(b, false)
                SetBlipCategory(b, 7)
                blipsColegas[c.s] = b
            else
                SetBlipCoords(b, c.x, c.y, c.z)
            end
            SetBlipSprite(b, c.v and 56 or 1)
            ShowHeadingIndicatorOnBlip(b, true)
            SetBlipRotation(b, math.floor(c.h))
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(c.n)
            EndTextCommandSetBlipName(b)
        end
    end
    for s, b in pairs(blipsColegas) do
        if not vistos[s] then
            if DoesBlipExist(b) then RemoveBlip(b) end
            blipsColegas[s] = nil
        end
    end
end)

---------------------------------------------------------------------
-- DP: BLIP E PONTOS
---------------------------------------------------------------------
local function zona(nome, coords, opcoes)
    exports.ox_target:addSphereZone({
        name = 'pa_policia_' .. nome,
        coords = coords,
        radius = 1.2,
        debug = Config.Debug,
        options = opcoes,
    })
end

local function abrir(qual)
    local ok, extra = lib.callback.await('pa_policia:server:abrir', false, qual)
    if not ok then return PC.Aviso(extra or 'Não foi possível abrir.', 'error') end
    if qual == 'arsenal' and extra then
        exports.ox_inventory:openInventory('shop', { type = extra })
    end
end

local function menuMultasCidadao()
    local multas = lib.callback.await('pa_policia:server:minhasMultas', false)
    if not multas or #multas == 0 then return PC.Aviso('Você não tem multas pendentes.', 'success') end
    local total = 0
    local opcoes = {}
    for _, m in ipairs(multas) do
        total += m.valor
        opcoes[#opcoes + 1] = { title = ('$%d'):format(m.valor), description = m.motivo, readOnly = true, icon = 'receipt' }
    end
    table.insert(opcoes, 1, {
        title = ('Pagar tudo ($%d)'):format(total),
        icon = 'money-bill',
        onSelect = function()
            local ok, msg = lib.callback.await('pa_policia:server:pagarMultas', false)
            PC.Resultado(ok, msg)
        end,
    })
    lib.registerContext({ id = 'pa_policia_multas', title = 'Multas pendentes', options = opcoes })
    lib.showContext('pa_policia_multas')
end

CreateThread(function()
    local dp = Config.dp
    local blip = AddBlipForCoord(dp.centro.x, dp.centro.y, dp.centro.z)
    SetBlipSprite(blip, dp.blip.sprite)
    SetBlipColour(blip, dp.blip.cor)
    SetBlipScale(blip, dp.blip.escala)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(dp.nome)
    EndTextCommandSetBlipName(blip)

    zona('servico', dp.servico, {
        {
            name = 'pa_policia_ponto', icon = 'fa-solid fa-clipboard-user', label = 'Bater ponto (LSPD)',
            canInteract = function() return PC.EhPolicia() end,
            onSelect = function()
                local ok, msg = lib.callback.await('pa_policia:server:servico', false)
                if not ok and msg then PC.Aviso(msg, 'error') end
            end,
        },
        {
            name = 'pa_policia_multas', icon = 'fa-solid fa-receipt', label = 'Pagar multas',
            onSelect = menuMultasCidadao,
        },
    })
    zona('arsenal', dp.arsenal, {
        { name = 'pa_policia_arsenal', icon = 'fa-solid fa-gun', label = 'Arsenal', canInteract = PC.EmServico, onSelect = function() abrir('arsenal') end },
    })
    zona('armario', dp.armario, {
        { name = 'pa_policia_armario', icon = 'fa-solid fa-box-archive', label = 'Armário pessoal', canInteract = PC.EmServico, onSelect = function() abrir('armario') end },
    })
    zona('evidencias', dp.evidencias, {
        { name = 'pa_policia_evidencias', icon = 'fa-solid fa-boxes-stacked', label = 'Depósito de evidências',
          canInteract = function() return PC.Pode('apreender') end, onSelect = function() abrir('evidencias') end },
    })
    zona('laboratorio', dp.laboratorio, {
        { name = 'pa_policia_lab', icon = 'fa-solid fa-microscope', label = 'Laboratório (analisar evidências)',
          canInteract = function() return PC.Pode('pericia') end, onSelect = function() TriggerEvent('pa_policia:client:laboratorio') end },
    })
    zona('roupas', dp.roupas, {
        { name = 'pa_policia_roupas', icon = 'fa-solid fa-shirt', label = 'Vestiário', canInteract = PC.EhPolicia,
          onSelect = function() TriggerEvent('illenium-appearance:client:openClothingShopMenu') end },
    })
    local g = dp.garagem.menu
    zona('garagem', vec3(g.x, g.y, g.z), {
        { name = 'pa_policia_garagem', icon = 'fa-solid fa-car-side', label = 'Garagem de viaturas', canInteract = PC.EmServico, onSelect = function() TriggerEvent('pa_policia:client:garagem') end },
    })
end)

---------------------------------------------------------------------
-- GARAGEM DE VIATURAS
---------------------------------------------------------------------
local function vagaLivre()
    for _, v in ipairs(Config.dp.garagem.vagas) do
        if not IsAnyVehicleNearPoint(v.x, v.y, v.z, 2.5) then return v end
    end
end

local function tirarViatura(modelo)
    if PC.viatura and DoesEntityExist(PC.viatura) then
        return PC.Aviso('Devolva a viatura que você já tirou.', 'error')
    end
    local vaga = vagaLivre()
    if not vaga then return PC.Aviso('Todas as vagas estão ocupadas.', 'error') end
    local net = lib.callback.await('pa_policia:server:tirarViatura', false, modelo, vaga)
    if not net then return PC.Aviso('Viatura indisponível para sua patente.', 'error') end
    local veh = lib.waitFor(function()
        local e = NetworkGetEntityFromNetworkId(net)
        if e ~= 0 and DoesEntityExist(e) then return e end
    end, 'viatura não apareceu', 5000)
    PC.viatura = veh
    SetVehicleFuelLevel(veh, 100.0)
    Entity(veh).state:set('fuel', 100, true)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleLivery(veh, 0)
    TaskWarpPedIntoVehicle(cache.ped, veh, -1)
    TriggerEvent('vehiclekeys:client:SetOwner', GetVehicleNumberPlateText(veh))
end

AddEventHandler('pa_policia:client:garagem', function()
    local opcoes = {}
    local grau = PC.Grau()
    for _, v in ipairs(Config.viaturas) do
        local pode = grau >= v.grade
        opcoes[#opcoes + 1] = {
            title = v.nome,
            description = pode and v.modelo or ('A partir de %s'):format(Config.patentes[v.grade]),
            icon = 'car',
            disabled = not pode,
            onSelect = function() tirarViatura(v.modelo) end,
        }
    end
    lib.registerContext({ id = 'pa_policia_garagem', title = 'Viaturas da LSPD', options = opcoes })
    lib.showContext('pa_policia_garagem')
end)

-- Devolver a viatura: [E] no ponto de guardar
CreateThread(function()
    local ponto = Config.dp.garagem.guardar
    local mostrando = false
    while true do
        local espera = 1000
        if PC.EmServico() and cache.vehicle and cache.seat == -1 then
            local dist = #(GetEntityCoords(cache.ped) - ponto)
            if dist < 25.0 then
                espera = 0
                DrawMarker(36, ponto.x, ponto.y, ponto.z + 0.5, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 1.2, 60, 140, 255, 160, true, true, 2, false, nil, nil, false)
                if dist < 4.0 then
                    if not mostrando then lib.showTextUI('[E] Devolver viatura'); mostrando = true end
                    if IsControlJustPressed(0, 38) then
                        local net = NetworkGetNetworkIdFromEntity(cache.vehicle)
                        local ok, msg = lib.callback.await('pa_policia:server:guardarViatura', false, net)
                        PC.Resultado(ok, msg)
                        if ok then PC.viatura = nil end
                    end
                elseif mostrando then
                    lib.hideTextUI(); mostrando = false
                end
            end
        end
        if espera > 0 and mostrando then lib.hideTextUI(); mostrando = false end
        Wait(espera)
    end
end)

-- O menu do policial (F6) fica em client/painel.lua

---------------------------------------------------------------------
-- ADMIN: copiar posição
---------------------------------------------------------------------
RegisterNetEvent('pa_policia:client:copiarPosicao', function()
    if GetInvokingResource() then return end
    local c = GetEntityCoords(cache.ped)
    local h = GetEntityHeading(cache.ped)
    local texto = ('vec4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, h)
    lib.setClipboard(texto)
    print('[pa_policia] ' .. texto)
    PC.Aviso(texto .. ' (copiado)', 'inform', 8000)
end)
