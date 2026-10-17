-- pa_policia · cliente · prisão (Bolingbroke)

local preso = false
local restante = 0
local zonas = {}

local function formatar(seg)
    seg = math.max(0, math.floor(seg))
    return ('%d:%02d'):format(math.floor(seg / 60), seg % 60)
end

local function mostrarTempo()
    lib.showTextUI(('Pena: %s'):format(formatar(restante)), { position = 'top-center', icon = 'lock' })
end

local function criarTrabalhos()
    for i, ponto in ipairs(Config.prisao.trabalho.pontos) do
        zonas[#zonas + 1] = exports.ox_target:addSphereZone({
            coords = ponto.coords,
            radius = 1.5,
            debug = Config.Debug,
            options = {
                {
                    name = 'pa_policia_trabalho_' .. i, icon = 'fa-solid fa-broom', label = ponto.label .. ' (reduz a pena)',
                    canInteract = function() return preso end,
                    onSelect = function()
                        local a = ponto.anim
                        if lib.progressCircle({
                            duration = Config.prisao.trabalho.tempo, label = ponto.label .. '...', position = 'bottom',
                            canCancel = true, disable = { move = true, car = true, combat = true },
                            anim = a and { dict = a[1], clip = a[2], flag = 1 } or nil,
                        }) then
                            local ok, msg = lib.callback.await('pa_policia:server:trabalho', false, i)
                            PC.Resultado(ok, msg)
                        end
                    end,
                },
            },
        })
    end
end

local function removerTrabalhos()
    for _, z in ipairs(zonas) do exports.ox_target:removeZone(z) end
    zonas = {}
end

RegisterNetEvent('pa_policia:client:preso', function(d)
    if GetInvokingResource() then return end
    restante = d.restante
    local e = d.entrada
    DoScreenFadeOut(600)
    Wait(700)
    if cache.vehicle then TaskLeaveVehicle(cache.ped, cache.vehicle, 16); Wait(200) end
    DetachEntity(cache.ped, true, false)
    ClearPedTasksImmediately(cache.ped)
    SetEntityCoords(cache.ped, e.x, e.y, e.z, false, false, false, false)
    SetEntityHeading(cache.ped, e.w)
    Wait(800)
    DoScreenFadeIn(800)

    if not preso then
        preso = true
        criarTrabalhos()
        CreateThread(function()
            local ultimoSeg = GetGameTimer()
            local ultimaFuga = 0
            while preso do
                Wait(1000)
                if GetGameTimer() - ultimoSeg >= 1000 then
                    restante = math.max(0, restante - 1)
                    ultimoSeg = GetGameTimer()
                end
                mostrarTempo()
                -- fuga
                if #(GetEntityCoords(cache.ped) - Config.prisao.centro) > Config.prisao.raio and GetGameTimer() - ultimaFuga > 5000 then
                    ultimaFuga = GetGameTimer()
                    local fugiu = lib.callback.await('pa_policia:server:fuga', false)
                    if fugiu then
                        PC.Aviso('Você fugiu da prisão! A polícia foi avisada e há um mandado contra você.', 'error', 10000)
                    end
                end
            end
            lib.hideTextUI()
        end)
    end
    if d.primeiraVez then
        PC.Aviso(('Bem-vindo(a) a Bolingbroke. Pena: %s. Trabalhe no pátio para reduzir.'):format(formatar(restante)), 'inform', 10000)
    end
end)

RegisterNetEvent('pa_policia:client:tempoPena', function(seg)
    if GetInvokingResource() then return end
    restante = seg
end)

RegisterNetEvent('pa_policia:client:solto', function(saida)
    if GetInvokingResource() then return end
    preso = false
    removerTrabalhos()
    lib.hideTextUI()
    if saida then
        DoScreenFadeOut(600)
        Wait(700)
        SetEntityCoords(cache.ped, saida.x, saida.y, saida.z, false, false, false, false)
        SetEntityHeading(cache.ped, saida.w)
        Wait(500)
        DoScreenFadeIn(800)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and preso then lib.hideTextUI() end
end)
