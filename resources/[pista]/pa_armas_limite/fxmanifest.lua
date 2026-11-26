fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pa_armas_limite'
author 'Pista & Asfalto RP'
description 'Limite de armas no inventário: 2 pistolas e 2 armas longas (estilo GTA 6)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'qbx_core',
}
