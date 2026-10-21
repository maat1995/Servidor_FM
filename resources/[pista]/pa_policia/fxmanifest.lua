fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'pa_policia'
author 'Pista & Asfalto RP'
description 'Polícia da LSPD: serviço, central de alertas, abordagem, tablet (MDT), prisão em Bolingbroke, fiscalização veicular (blitz, vistoria, radares, pátio) e perícia. Substitui o qbx_police e o xt-prison.'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/alertas.lua',
    'client/abordagem.lua',
    'client/mdt.lua',
    'client/prisao.lua',
    'client/veicular.lua',
    'client/pericia.lua',
    'client/crimes.lua',
    'client/painel.lua',
    'client/widgets.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/alertas.lua',
    'server/abordagem.lua',
    'server/mdt.lua',
    'server/prisao.lua',
    'server/veicular.lua',
    'server/pericia.lua',
    'server/crimes.lua',
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
    'ox_target',
    'ox_inventory',
}
