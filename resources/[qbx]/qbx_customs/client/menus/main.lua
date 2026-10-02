mainLastIndex = 1
vehicle = 0
mainMenuId = 'customs-main'
local inMenu = false
local dragcam = require('client.dragcam')
local startDragCam = dragcam.startDragCam
local stopDragCam = dragcam.stopDragCam
local config = require 'config.client'
openedWithExports = false

local menu = {
    id = mainMenuId,
    canClose = true,
    disableInput = false,
    title = locale("menus.main.title"),
    position = 'top-left',
    options = {},
}

local function main()
    -- Pista & Asfalto: sem conserto instantâneo aqui. Pneu, lataria, funilaria e motor
    -- são consertados com os itens do pista_tuning (mecânico).

    local options = {}

    -- Pista & Asfalto: desempenho só para mecânico especializado ou quem tem skill de preparação
    local podeDesempenho = GetResourceState('pista_tuning') ~= 'started' or exports.pista_tuning:nivelLocal() >= 1
    if podeDesempenho then
        options[#options + 1] = {
            label = locale('menus.main.performance'),
            close = true,
            args = {
                menu = 'client.menus.performance',
            }
        }
    end

    local resto = {
        {
            label = locale('menus.main.parts'),
            close = true,
            args = {
                menu = 'client.menus.parts',
            }
        },
        {
            label = locale('menus.main.colors'),
            close = true,
            args = {
                menu = 'client.menus.colors',
            }
        },
    }
    for _, opt in ipairs(resto) do options[#options + 1] = opt end

    if DoesExtraExist(vehicle, 1) then
        options[#options + 1] = {
            label = locale('menus.main.extras'),
            close = true,
            args = {
                menu = 'client.menus.extras',
            }
        }
    end

    return options
end

local function disableControls()
    inMenu = true
    CreateThread(function()
        while inMenu do
            Wait(0)
            DisableControlAction(0, 71, true) -- accelerating
            DisableControlAction(0, 72, true) -- decelerating
            for i = 81, 85 do -- radio stuff
                DisableControlAction(0, i, true)
            end
            DisableControlAction(0, 106, true) -- turning vehicle wheels
        end
    end)
end

local function repair()
    local success = lib.callback.await('qbx_customs:server:repair', false, GetVehicleBodyHealth(vehicle))
    if success then
        exports.qbx_core:Notify(locale('notifications.success.repaired'), 'success')
        qbx.playAudio({
            audioName = 'PICK_UP',
            audioRef = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
        })
        SetVehicleBodyHealth(vehicle, 1000.0)
        SetVehicleEngineHealth(vehicle, 1000.0)
        local fuelLevel = GetVehicleFuelLevel(vehicle)
        SetVehicleFixed(vehicle)
        SetVehicleFuelLevel(vehicle, fuelLevel)
    else
        exports.qbx_core:Notify(locale('notifications.error.money'), 'error')
    end

    menu.options = main()
    lib.setMenuOptions(menu.id, menu.options)
    lib.showMenu(menu.id, 1)
end

local function onSubmit(selected, _, args)
    if menu.options[selected].label == locale('menus.main.repair') then
        lib.hideMenu(false)
        repair()
        return
    end
    local menuId = require(args.menu)()
    lib.showMenu(menuId, 1)
end

menu.onSelected = function(selected)
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    mainLastIndex = selected
end

menu.onClose = function()
    inMenu = false
    stopDragCam()
    if not openedWithExports then
        lib.showTextUI(locale('textUI.tune'), {
            icon = 'fa-solid fa-car',
            position = 'left-center',
        })
    end
    TriggerServerEvent('qbx_customs:server:saveVehicleProps')
end

lib.callback.register('qbx_customs:client:vehicleProps', function()
    return lib.getVehicleProperties(vehicle)
end)

exports('OpenMenu', function()
    openedWithExports = true
    if not cache.vehicle or inMenu then return false end
    vehicle = cache.vehicle
    SetVehicleModKit(vehicle, 0)
    menu.options = main()
    lib.registerMenu(menu, onSubmit)
    lib.showMenu(menu.id, 1)
    disableControls()
    startDragCam(vehicle)
    return true
end)

return function()
    openedWithExports = false
    if not cache.vehicle or inMenu then return end
    vehicle = cache.vehicle
    SetVehicleModKit(vehicle, 0)
    menu.options = main()
    lib.registerMenu(menu, onSubmit)
    lib.showMenu(menu.id, 1)
    disableControls()
    startDragCam(vehicle)
end
