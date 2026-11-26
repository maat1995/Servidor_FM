-- Separa as armas em grupos (pistola / longa). Usado pelo servidor, pelo cliente e pela pa_roda.
local grupoDe = {}
local livres = {}

for _, n in ipairs(Config.pistolas) do grupoDe[n:upper()] = 'pistola' end
for _, n in ipairs(Config.longas) do grupoDe[n:upper()] = 'longa' end
for _, n in ipairs(Config.livres) do livres[n:upper()] = true end

function GrupoArma(nome)
    if type(nome) ~= 'string' then return end
    nome = nome:upper()
    if livres[nome] or not nome:find('^WEAPON_') then return end
    local g = grupoDe[nome]
    if g or not Config.detectarPeloNome then return g end

    if nome:find('MACHINEPISTOL') or nome:find('TECPISTOL') then g = 'longa'
    elseif nome:find('PISTOL') or nome:find('REVOLVER') then g = 'pistola'
    elseif nome:find('SMG') or nome:find('PDW') or nome:find('RIFLE') or nome:find('CARBINE')
        or nome:find('SHOTGUN') or nome:find('SNIPER') or nome:find('_MG') then g = 'longa' end
    grupoDe[nome] = g or false
    return g
end

