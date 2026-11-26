Config = {}

-- Tecla da roda (segura para abrir, solta para escolher).
-- O TAB já abre o inventário (ox_inventory), por isso a roda fica no Z.
-- Cada jogador pode trocar em Configurações > Atalhos > FiveM > "Roda de armas e itens"
Config.tecla = 'Z'

-- Escurece e desfoca o fundo enquanto a roda está aberta
Config.desfoque = true

-- Deixa o personagem andar com a roda aberta (como no GTA 6). false = fica parado
Config.andarAberta = true

-- Aba Itens: itens que aparecem primeiro (se o jogador tiver). O resto entra pela ordem do inventário
Config.itensPreferidos = {
    'bandage', 'firstaid', 'ifaks', 'painkillers',
    'water', 'water_bottle', 'sandwich', 'burger', 'coffee', 'kurkakola',
    'lockpick', 'phone', 'radio',
}

-- Itens que nunca aparecem na aba Itens
Config.itensFora = { 'money', 'black_money', 'markedbills', 'id_card', 'driver_license' }

-- Arma de "outros" (canto de cima à esquerda): taser, sinalizador e o que não for pistola/longa
-- Armas brancas e de arremesso têm espaço próprio
