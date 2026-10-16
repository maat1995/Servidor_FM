fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pa_cambio'
author 'Pista & Asfalto RP'
description 'Câmbio manual: todo carro sai manual (liga em neutro, Shift sobe e Ctrl desce marcha). O câmbio automático é uma peça instalada pelo mecânico (pista_tuning).'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
}

dependencies {
    'ox_lib',
    'qbx_core',
}
