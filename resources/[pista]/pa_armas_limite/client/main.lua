-- Outros scripts (pa_roda) perguntam o grupo da arma: 'pistola', 'longa' ou nil
exports('grupo', function(nome) return GrupoArma(nome) or nil end)
exports('limites', function() return Config.limites end)
