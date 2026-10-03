fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pista_guincho'
author 'Pista & Asfalto RP'
description 'Guincho plataforma (MTL Flatbed no lugar do flatbed original) que carrega carro quebrado'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}
client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
}
server_script 'server/main.lua'

-- O modelo do mod substitui o "flatbed" do jogo (pasta stream)

dependencies { 'ox_lib', 'ox_target', 'qbx_core' }
