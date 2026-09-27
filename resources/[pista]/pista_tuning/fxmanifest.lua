fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pista_tuning'
author 'Pista & Asfalto RP'
description 'Sistema de preparação: peças como item, remap no notebook, instalado por mecânico especializado ou quem tem skill'
version '0.3.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/remap.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    '@qbx_core/modules/lib.lua',
    'client/main.lua',
    'client/nitro.lua',
    'client/remap.lua',
    'client/motor.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_inventory',
    'ox_target',
}
