Config = {}

Config.modelo = `flatbed`         -- o mod substitui o flatbed original
Config.job = 'mechanic'           -- quem pode carregar/descarregar
Config.precisaServico = true
Config.tempo = 6000               -- ms para prender ou soltar o carro
Config.distanciaAtras = 9.0       -- o carro precisa estar até essa distância atrás do guincho

-- Onde o carro fica em cima da plataforma (ajuste com /ajusteguincho x y z)
Config.posicao = vec3(0.0, -2.35, 1.15)
