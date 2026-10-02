-- pista_tuning - cliente

STATE_KEY = 'pista_tuning'
local meuNivel = 0

---------------------------------------------------------------------
-- Nível do jogador (cache para menus e ox_target)
---------------------------------------------------------------------
local function atualizarNivel()
    meuNivel = lib.callback.await('pista_tuning:server:meuNivel', false) or 0
end

RegisterNetEvent('pista_tuning:client:atualizarNivel', atualizarNivel)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', atualizarNivel)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function() SetTimeout(500, atualizarNivel) end)
RegisterNetEvent('QBCore:Client:SetDuty', function() SetTimeout(500, atualizarNivel) end)
AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then SetTimeout(1000, atualizarNivel) end
end)

function MeuNivel() return meuNivel end
exports('nivelLocal', function() return meuNivel end)

---------------------------------------------------------------------
-- Utilidades compartilhadas entre os arquivos do cliente
---------------------------------------------------------------------
function Avisar(msg, tipo, tempo)
    exports.qbx_core:Notify(msg or '', tipo or 'inform', tempo)
end

function TemItem(item)
    return (exports.ox_inventory:Search('count', item) or 0) > 0
end

function TemFerramenta(chave)
    return TemItem(Config.ferramentas[chave].item)
end

function NaOficina(coords)
    for _, o in ipairs(Config.oficinas) do
        if #(coords - o.coords) <= o.raio then return true end
    end
    return false
end

function VeiculoProximo()
    return lib.getClosestVehicle(GetEntityCoords(cache.ped), 4.0, false)
end

function DadosDo(veh)
    return Entity(veh).state[STATE_KEY] or {}
end

--- Barra de progresso com animação. opts: { anim, prop, capo = veh }
function Trabalhar(duracao, label, opts)
    opts = opts or {}
    if opts.capo then SetVehicleDoorOpen(opts.capo, 4, false, false) end
    local ok = lib.progressCircle({
        duration = duracao,
        label = label,
        position = 'bottom',
        useWhileDead = false,
        canCancel = not opts.semCancelar,
        disable = { move = true, car = true, combat = true },
        anim = opts.anim or { dict = 'mini@repair', clip = 'fixing_a_ped' },
        prop = opts.prop,
    })
    -- o capô continua aberto depois do serviço; o mecânico fecha quando terminar
    return ok
end

---------------------------------------------------------------------
-- Aplicar a preparação na handling
---------------------------------------------------------------------
local base = {} -- valores originais por veículo, para não acumular

local CAMPOS = {
    forca = 'fInitialDriveForce',
    vmax = 'fInitialDriveMaxFlatVel',
    giro = 'fDriveInertia',
}

local function somarEfeitos(dados)
    local total = { forca = 0.0, vmax = 0.0, giro = 0.0 }
    local function soma(e)
        if not e then return end
        for k in pairs(total) do total[k] = total[k] + (e[k] or 0.0) end
    end
    if dados.turbo then soma(Config.efeitos.turbo) end
    if dados.intercooler then soma(Config.efeitos.intercooler) end
    soma(EfeitosMotor(dados))
    if dados.chip then soma(Config.efeitos.chip[dados.chip]) end
    if dados.remap then soma(CalcularRemap(dados.remap, dados)) end
    return total
end

local function aplicarPreparacao(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local dados = DadosDo(veh)

    local modelo = GetEntityModel(veh)
    if not base[veh] or base[veh].modelo ~= modelo then
        base[veh] = { modelo = modelo }
        for _, campo in pairs(CAMPOS) do
            base[veh][campo] = GetVehicleHandlingFloat(veh, 'CHandlingData', campo)
        end
    end

    local efeitos = somarEfeitos(dados)
    for chave, campo in pairs(CAMPOS) do
        SetVehicleHandlingFloat(veh, 'CHandlingData', campo, base[veh][campo] * (1.0 + efeitos[chave]))
    end
    ModifyVehicleTopSpeed(veh, 1.0) -- força o jogo a recalcular a velocidade final

    SetVehicleModKit(veh, 0)
    -- O upgrade de motor nativo (1 a 5) não existe aqui: potência vem do chip, pistão e cabeçote
    if Config.removerMotorNativo and GetVehicleMod(veh, 11) ~= -1 then
        SetVehicleMod(veh, 11, -1, false)
    end
    if Config.ativarTurboVisual and dados.turbo then ToggleVehicleMod(veh, 18, true) end

    -- Freio (12) e transmissão (13): só o que foi instalado pelos kits
    if Config.controlarFreioCambio then
        for _, par in ipairs({ { 12, dados.freio }, { 13, dados.cambio } }) do
            local mod, nivel = par[1], par[2]
            local alvo = -1
            if nivel then alvo = math.min(nivel, GetNumVehicleMods(veh, mod) - 1) end
            if GetVehicleMod(veh, mod) ~= alvo then SetVehicleMod(veh, mod, alvo, false) end
        end
        -- Suspensão nativa (15) não existe: só a regulável (client/suspensao.lua)
        if GetVehicleMod(veh, 15) ~= -1 then SetVehicleMod(veh, 15, -1, false) end
    end
    if AplicarSuspensao then AplicarSuspensao(veh, dados) end

    SetVehicleUndriveable(veh, dados.motor ~= nil)
end

local function carregarEAplicar(veh)
    if not Entity(veh).state[STATE_KEY] then
        lib.callback.await('pista_tuning:server:carregar', false, VehToNet(veh))
        Wait(200) -- espera o state bag chegar
    end
    aplicarPreparacao(veh)
    if DadosDo(veh).motor then
        Avisar('Esse carro está sem motor', 'error', 5000)
    end
end

lib.onCache('seat', function(seat)
    if seat == -1 and cache.vehicle then
        CreateThread(function() carregarEAplicar(cache.vehicle) end)
    end
end)

-- Recarregou o script com alguém já dirigindo
CreateThread(function()
    Wait(1500)
    if cache.vehicle and cache.seat == -1 then carregarEAplicar(cache.vehicle) end
end)

-- Peça instalada/removida enquanto eu dirijo (ou recarga de nitro)
AddStateBagChangeHandler(STATE_KEY, nil, function(bagName)
    local veh = GetEntityFromStateBagName(bagName)
    if veh == 0 then return end
    SetTimeout(0, function()
        if veh == cache.vehicle and cache.seat == -1 then aplicarPreparacao(veh) end
    end)
end)

-- Carro sem motor não liga
CreateThread(function()
    while true do
        local espera = 1000
        local veh = cache.vehicle
        if veh and cache.seat == -1 and DadosDo(veh).motor then
            espera = 0
            SetVehicleEngineOn(veh, false, true, true)
            SetVehicleUndriveable(veh, true)
        end
        Wait(espera)
    end
end)

---------------------------------------------------------------------
-- Risco de quebrar o motor
---------------------------------------------------------------------
CreateThread(function()
    local ultimoAviso = 0
    while true do
        Wait(Config.risco.intervalo)
        local veh = cache.vehicle
        if veh and cache.seat == -1 then
            local dados = Entity(veh).state[STATE_KEY]
            if dados and (dados.chip or dados.pistao or dados.cabecote) and GetIsVehicleEngineRunning(veh) and GetVehicleCurrentRpm(veh) >= Config.risco.rpmMinimo then
                local risco = dados.remap and CalcularRemap(dados.remap, dados).risco or 0.0
                if risco > 0.0 then
                    SetVehicleEngineHealth(veh, math.max(0.0, GetVehicleEngineHealth(veh) - (risco / 100.0) * Config.remap.danoMaximo))
                    if risco >= 50.0 and GetGameTimer() - ultimoAviso > 30000 then
                        ultimoAviso = GetGameTimer()
                        Avisar(('Mapa agressivo: risco ao motor %d%%'):format(math.floor(risco)), 'error', 5000)
                    end
                end
                for _, regra in ipairs(RiscosMontagem(dados)) do
                    SetVehicleEngineHealth(veh, math.max(0.0, GetVehicleEngineHealth(veh) - regra.dano))
                    if GetGameTimer() - ultimoAviso > 30000 then
                        ultimoAviso = GetGameTimer()
                        Avisar(regra.aviso, 'error', 5000)
                    end
                end
            end
        end
    end
end)

---------------------------------------------------------------------
-- Usar peça (chamado pelo ox_inventory)
---------------------------------------------------------------------
exports('usarPeca', function(data)
    local itemName = data.name
    local peca = Config.itens[itemName]
    if not peca then return end

    -- Pistão e cabeçote vão no motor aberto (client/motor.lua)
    if peca.motor then return InstalarNoMotorProximo(itemName) end

    if cache.vehicle then return Avisar('Saia do veículo para instalar a peça', 'error') end
    local veh = VeiculoProximo()
    if not veh then return Avisar('Nenhum veículo por perto', 'error') end
    if Config.pecasExternasSoNaOficina and not NaOficina(GetEntityCoords(veh)) then
        return Avisar('Isso só pode ser feito dentro da oficina', 'error')
    end

    local netId = VehToNet(veh)
    local pode, erro = lib.callback.await('pista_tuning:server:podeInstalar', false, netId, itemName)
    if not pode then return Avisar(erro or 'Não foi possível instalar', 'error') end

    exports.ox_inventory:closeInventory()
    if not Trabalhar(peca.tempo, ('Instalando %s...'):format(peca.label), { capo = veh }) then
        return Avisar('Instalação cancelada', 'error')
    end

    local ok, msg = lib.callback.await('pista_tuning:server:instalar', false, netId, itemName)
    Avisar(msg, ok and 'success' or 'error')
end)

---------------------------------------------------------------------
-- Transmissão: instala igual turbo (em qualquer lugar, com soquetes)
---------------------------------------------------------------------
exports('usarCambio', function(data)
    local item = data.name
    local kit = Config.kitsCambio[item]
    if not kit then return end
    if cache.vehicle then return Avisar('Saia do veículo para trocar a transmissão', 'error') end
    local veh = VeiculoProximo()
    if not veh then return Avisar('Nenhum veículo por perto', 'error') end

    local netId = VehToNet(veh)
    local pode, erro = lib.callback.await('pista_tuning:server:podeInstalarCambio', false, netId, item)
    if not pode then return Avisar(erro or 'Não foi possível instalar', 'error') end

    exports.ox_inventory:closeInventory()
    if not Trabalhar(Config.cambio.tempo, ('Instalando %s...'):format(kit.label:lower()), { capo = veh }) then
        return Avisar('Instalação cancelada', 'error')
    end
    local ok, msg = lib.callback.await('pista_tuning:server:instalarCambio', false, netId, item)
    Avisar(msg, ok and 'success' or 'error', 6000)
end)

---------------------------------------------------------------------
-- Menu "Ver preparação" (olho do ox_target no carro)
---------------------------------------------------------------------
function TextoSlot(slot, valor)
    if valor == nil or valor == false then return 'Original' end
    if slot == 'chip' then return ('Stage %d'):format(valor) end
    if slot == 'cabecote' then return valor == 2 and 'De corrida' or 'Retrabalhado' end
    if slot == 'pistao' then return valor == 'taxado' and 'Taxado' or 'Forjado' end
    return 'Instalado'
end

function SlotEhDoMotor(slot)
    for _, p in pairs(Config.itens) do
        if p.slot == slot then return p.motor == true end
    end
    return false
end

local abrirMenu

local function removerPeca(veh, slot, label)
    local confirma = lib.alertDialog({
        header = 'Remover peça',
        content = ('Remover %s deste carro? A peça volta para o seu inventário.'):format(label),
        centered = true,
        cancel = true,
        labels = { confirm = 'Remover', cancel = 'Cancelar' },
    })
    if confirma ~= 'confirm' then return abrirMenu(veh) end

    if not Trabalhar(8000, ('Removendo %s...'):format(label), { capo = veh }) then
        return Avisar('Remoção cancelada', 'error')
    end
    local ok, msg = lib.callback.await('pista_tuning:server:remover', false, VehToNet(veh), slot)
    Avisar(msg, ok and 'success' or 'error')
    if ok then abrirMenu(veh) end
end

abrirMenu = function(veh)
    lib.callback.await('pista_tuning:server:carregar', false, VehToNet(veh))
    Wait(150)
    local dados = DadosDo(veh)
    local opcoes = {}

    if dados.motor then
        opcoes[#opcoes + 1] = {
            title = 'Carro sem motor',
            description = 'O motor está fora do carro, na oficina',
            icon = 'fa-solid fa-triangle-exclamation',
            iconColor = '#f85149',
            readOnly = true,
        }
    else
        local motor = math.floor(GetVehicleEngineHealth(veh) / 10)
        opcoes[#opcoes + 1] = {
            title = ('Motor: %d%%'):format(math.max(0, motor)),
            icon = 'fa-solid fa-heart-pulse',
            progress = math.max(0, motor),
            colorScheme = motor > 60 and 'green' or motor > 30 and 'yellow' or 'red',
            readOnly = true,
        }
    end

    opcoes[#opcoes + 1] = {
        title = ('Montagem: %s'):format(NomeMontagem(dados)),
        icon = 'fa-solid fa-screwdriver-wrench', readOnly = true,
    }

    for _, s in ipairs(Config.slots) do
        local valor = dados[s.id]
        local instalado = valor ~= nil and valor ~= false
        local interna = SlotEhDoMotor(s.id)
        local descricao = TextoSlot(s.id, valor)
        if s.id == 'nitro' and instalado then
            descricao = ('Instalado - carga %d%%'):format(math.floor(dados.nitroCarga or 0))
        end
        local podeRemover = instalado and not interna
        opcoes[#opcoes + 1] = {
            title = s.label,
            description = descricao,
            icon = instalado and 'fa-solid fa-circle-check' or 'fa-regular fa-circle',
            iconColor = instalado and '#3fb950' or '#8b949e',
            disabled = not podeRemover,
            onSelect = podeRemover and function() removerPeca(veh, s.id, s.label) end or nil,
            metadata = podeRemover and { 'Clique para remover' }
                or (instalado and interna) and { 'Peça interna: tire e abra o motor' } or nil,
        }
    end

    if Config.controlarFreioCambio then
        local nomes = { [0] = 'Rua', [1] = 'Esportivo', [2] = 'Competição' }
        local descFreio = dados.freio and nomes[dados.freio] or 'Original'
        if dados.freioObra then
            local feitas = 0
            for _ in pairs(dados.freioObra.rodas or {}) do feitas = feitas + 1 end
            descFreio = descFreio .. (' | kit sendo instalado: %d/4 rodas'):format(feitas)
        end
        opcoes[#opcoes + 1] = { title = 'Freio', description = descFreio, icon = 'fa-solid fa-circle-stop', readOnly = true }
        opcoes[#opcoes + 1] = {
            title = 'Transmissão',
            description = dados.cambio and nomes[dados.cambio] or 'Original',
            icon = 'fa-solid fa-gears',
            readOnly = true,
        }

        local descSusp = 'Original'
        if dados.suspensao then
            local s = NormalizarSusp(dados.susp)
            descSusp = ('Regulável | altura %+.1f cm | cambagem %.1f° / %.1f°'):format(s.altura, s.cambagemD, s.cambagemT)
        elseif dados.suspObra then
            local feitas = 0
            for _ in pairs(dados.suspObra.rodas or {}) do feitas = feitas + 1 end
            descSusp = ('Regulável sendo instalada: %d/4 rodas'):format(feitas)
        end
        opcoes[#opcoes + 1] = {
            title = 'Suspensão',
            description = descSusp,
            icon = 'fa-solid fa-arrows-up-down',
            readOnly = not dados.suspensao,
            metadata = dados.suspensao and { 'Clique para regular' } or nil,
            onSelect = dados.suspensao and function() AbrirSuspensao(veh) end or nil,
        }
    end

    if dados.chip then
        local r = dados.remap
        local risco = r and CalcularRemap(r, dados).risco or 0
        opcoes[#opcoes + 1] = {
            title = 'Mapa da ECU',
            description = r and ('Turbo %.1f bar | Ignição %+d° | Limitador %d rpm | AFR %.1f'):format(r.turbo, r.ignicao, r.limitador, r.mistura)
                or 'Mapa original (use o notebook de remap para ajustar)',
            icon = 'fa-solid fa-laptop-code',
            progress = r and math.floor(risco) or nil,
            colorScheme = risco < 30 and 'green' or risco < 60 and 'yellow' or 'red',
            metadata = r and { ('Risco ao motor: %d%%'):format(math.floor(risco)) } or nil,
            readOnly = true,
        }
    end

    lib.registerContext({
        id = 'pista_tuning_menu',
        title = ('Preparação - %s'):format(qbx.getVehiclePlate(veh) or ''),
        options = opcoes,
    })
    lib.showContext('pista_tuning_menu')
end

CreateThread(function()
    exports.ox_target:addGlobalVehicle({
        {
            name = 'pista_tuning_ver',
            icon = 'fa-solid fa-gauge-high',
            label = 'Ver preparação',
            distance = 3.0,
            canInteract = function()
                return meuNivel >= 1 and not cache.vehicle
            end,
            onSelect = function(data)
                abrirMenu(data.entity)
            end,
        },
        {
            name = 'pista_tuning_capo',
            icon = 'fa-solid fa-car-side',
            label = 'Abrir / fechar capô',
            distance = 3.0,
            canInteract = function(entity)
                return not cache.vehicle and GetIsDoorValid(entity, 4)
            end,
            onSelect = function(data)
                local veh = data.entity
                local limite = GetGameTimer() + 1000
                NetworkRequestControlOfEntity(veh)
                while not NetworkHasControlOfEntity(veh) and GetGameTimer() < limite do Wait(10) end
                if GetVehicleDoorAngleRatio(veh, 4) > 0.1 then
                    SetVehicleDoorShut(veh, 4, false)
                else
                    SetVehicleDoorOpen(veh, 4, false, false)
                end
            end,
        },
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        exports.ox_target:removeGlobalVehicle({ 'pista_tuning_ver', 'pista_tuning_capo' })
    end
end)
