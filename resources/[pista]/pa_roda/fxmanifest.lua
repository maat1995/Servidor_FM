fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pa_roda'
author 'Pista & Asfalto RP'
description 'Roda de armas e itens no estilo GTA 6 (segura Z)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'ox_lib',
    'ox_inventory',
}
