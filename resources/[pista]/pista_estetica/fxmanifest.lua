fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pista_estetica'
author 'Pista & Asfalto RP'
description 'Cabine de pintura e oficina de estética com tela própria (mecânico faz, cliente paga)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/cores.lua',
    'client/main.lua',
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
}
