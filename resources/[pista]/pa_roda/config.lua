Config = {}

-- Tecla da roda. O inventário completo passou para o I (ox.cfg: inventory:keys)
-- Cada jogador pode trocar em Configurações > Atalhos > FiveM > "Roda de armas e itens"
Config.tecla = 'TAB'

-- 'alternar' = aperta para abrir e aperta de novo para fechar (clique escolhe)
-- 'segurar'  = segura para abrir e solta para escolher (igual ao GTA)
Config.modo = 'alternar'

-- Espaços do inventário que são favoritos: aparecem primeiro na aba Itens
Config.favoritos = 5

-- Itens de dinheiro (mostrados embaixo da roda)
Config.dinheiro = {
    mao = { 'money', 'cash' },
    sujo = { 'black_money', 'dirty_money', 'markedbills' },
}

-- Mostra no F8 por que a roda não abriu (deixe false depois de testar)
Config.debug = true

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
