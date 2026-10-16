fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pa_medico'
author 'Pista & Asfalto RP'
description 'Desmaio e resgate: tempo de desmaio, chamado ao SAMU (tecla G ou 192 no celular) com localização aproximada, ambulância NPC quando não tem médico e acordar no hospital perdendo tudo.'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/npc.lua',
    'client/medico.lua',
}

server_scripts {
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
    'qbx_core',
    'qbx_medical',
}
