fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'pa_roubocarro'
author 'Pista & Asfalto RP'
description 'Roubo de carros sob encomenda: tablet comprado com BTC, contratos por nível (classe D até S), solo ou em dupla, moedas para comprar o carro com chassi riscado e melhorias.'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/contrato.lua',
    'client/tablet.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/contrato.lua',
    'server/tablet.lua',
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
