fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pa_handling'
author 'Pista & Asfalto RP'
description 'Handling realista: cada carro com a ficha do carro real em que foi inspirado, calibrada automaticamente no jogo (/calibrar).'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'data/nativos.lua',
    'shared/fichas.lua',
}

client_scripts {
    'client/main.lua',
    'client/calibracao.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'qbx_core',
}
