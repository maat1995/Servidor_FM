Config = {}

-- Quantas armas de cada grupo o jogador pode carregar no inventário
Config.limites = {
    pistola = 2,
    longa = 2,      -- submetralhadora, rifle, escopeta, sniper, metralhadora e pesadas
}

-- Nomes que aparecem nos avisos
Config.nomes = {
    pistola = { um = 'pistola', varios = 'pistolas' },
    longa = { um = 'arma longa', varios = 'armas longas' },
}

-- Jobs que não têm limite (ex.: { police = true }). Vazio = todo mundo tem limite
Config.isentos = {}

-- Pistolas
Config.pistolas = {
    'WEAPON_PISTOL', 'WEAPON_PISTOL_MK2', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL', 'WEAPON_PISTOL50',
    'WEAPON_SNSPISTOL', 'WEAPON_SNSPISTOL_MK2', 'WEAPON_HEAVYPISTOL', 'WEAPON_VINTAGEPISTOL',
    'WEAPON_MARKSMANPISTOL', 'WEAPON_REVOLVER', 'WEAPON_REVOLVER_MK2', 'WEAPON_DOUBLEACTION',
    'WEAPON_CERAMICPISTOL', 'WEAPON_NAVYREVOLVER', 'WEAPON_GADGETPISTOL', 'WEAPON_PISTOLXM3',
    'WEAPON_RAYPISTOL',
}

-- Armas longas (sub, rifle, escopeta, sniper, metralhadora e pesadas)
Config.longas = {
    -- submetralhadoras
    'WEAPON_MICROSMG', 'WEAPON_MINISMG', 'WEAPON_SMG', 'WEAPON_SMG_MK2', 'WEAPON_ASSAULTSMG',
    'WEAPON_COMBATPDW', 'WEAPON_MACHINEPISTOL', 'WEAPON_TECPISTOL', 'WEAPON_GUSENBERG',
    -- rifles
    'WEAPON_ASSAULTRIFLE', 'WEAPON_ASSAULTRIFLE_MK2', 'WEAPON_CARBINERIFLE', 'WEAPON_CARBINERIFLE_MK2',
    'WEAPON_ADVANCEDRIFLE', 'WEAPON_SPECIALCARBINE', 'WEAPON_SPECIALCARBINE_MK2', 'WEAPON_BULLPUPRIFLE',
    'WEAPON_BULLPUPRIFLE_MK2', 'WEAPON_COMPACTRIFLE', 'WEAPON_MILITARYRIFLE', 'WEAPON_HEAVYRIFLE',
    'WEAPON_TACTICALRIFLE', 'WEAPON_BATTLERIFLE',
    -- escopetas
    'WEAPON_PUMPSHOTGUN', 'WEAPON_PUMPSHOTGUN_MK2', 'WEAPON_SAWNOFFSHOTGUN', 'WEAPON_ASSAULTSHOTGUN',
    'WEAPON_BULLPUPSHOTGUN', 'WEAPON_MUSKET', 'WEAPON_HEAVYSHOTGUN', 'WEAPON_DBSHOTGUN',
    'WEAPON_AUTOSHOTGUN', 'WEAPON_COMBATSHOTGUN',
    -- snipers
    'WEAPON_SNIPERRIFLE', 'WEAPON_HEAVYSNIPER', 'WEAPON_HEAVYSNIPER_MK2', 'WEAPON_MARKSMANRIFLE',
    'WEAPON_MARKSMANRIFLE_MK2', 'WEAPON_PRECISIONRIFLE',
    -- metralhadoras e pesadas
    'WEAPON_MG', 'WEAPON_COMBATMG', 'WEAPON_COMBATMG_MK2', 'WEAPON_MINIGUN', 'WEAPON_RPG',
    'WEAPON_GRENADELAUNCHER', 'WEAPON_COMPACTLAUNCHER', 'WEAPON_HOMINGLAUNCHER', 'WEAPON_EMPLAUNCHER',
    'WEAPON_RAILGUN', 'WEAPON_RAILGUNXM3', 'WEAPON_RAYCARBINE', 'WEAPON_RAYMINIGUN',
}

-- Armas novas (addon) que não estão nas listas são separadas pelo nome:
-- tem PISTOL ou REVOLVER = pistola; tem SMG, PDW, RIFLE, CARBINE, SHOTGUN, SNIPER, MG = longa
Config.detectarPeloNome = true

-- Nunca contam no limite (mesmo que o nome pareça de arma de fogo)
Config.livres = { 'WEAPON_STUNGUN', 'WEAPON_STUNGUN_MP', 'WEAPON_FLAREGUN' }

-- Quando um script entrega uma arma direto (roubo, fabricação) e passa do limite,
-- a arma cai no chão ao lado do jogador
Config.derrubarExcesso = true
