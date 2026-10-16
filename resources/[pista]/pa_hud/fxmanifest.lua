fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pa_hud'
author 'Pista & Asfalto RP'
description 'HUD do servidor: velocímetro com turbo, nitro e motor (pista_tuning), status, bússola, voz e XP (pista_skills)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
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
    'qbx_core',
}
