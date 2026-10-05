# Pista & Asfalto RP

Servidor FiveM (base Qbox) focado no mundo dos carros: preparação, mecânica e oficinas.

## O que tem aqui

- `resources/[pista]/pista_tuning` — sistema de preparação
  - Peças como item (turbo, intercooler, chip Stage 1/2/3, kit de nitro)
  - Motor: guincho da oficina, motor pendurado, bancada, pistão forjado e cabeçote
  - Notebook de remap (turbo, ignição, limitador, mistura) com risco ao motor
  - Cada peça pede uma habilidade da árvore de Mecânica (pista_skills) ou mecânico especializado (cargo 3+)
  - Instalação pode falhar para quem não é especializado (a peça não é gasta)
- `resources/[pista]/pista_skills` — skills (tela no `/skills` ou F7)
  - Árvore de Mecânica: 10 níveis, 12 pontos, 15 habilidades em Motor, Chassi, Eletrônica e Passivas
  - XP por peça nova instalada, consertos, retífica, dinamômetro (`/dyno`), aprendiz, manuais técnicos
  - Pronto para o script de corridas: `exports.pista_skills:darXPCorrida(source, 'legal'|'ilegal', posicao, participantes)`
    e `exports.pista_skills:registrarTempo(source, 'pista', ms)` para time attack
  - Anti-farm: peça repetida no mesmo carro não dá XP, cooldowns por carro e limite diário
  - Ferramentas com desgaste (jogo de soquetes, torquímetro)
- `resources/[ox]/ox_inventory` — itens, autopeças do mecânico e ícones
- `resources/[qbx]/qbx_customs` — desempenho restrito a quem tem skill/mecânico
- `server.cfg.example` — configuração do servidor **sem** chave e senha

## Instalação

1. Base Qbox instalada pelo txAdmin.
2. Copie a pasta `resources` por cima da base.
3. Copie `server.cfg.example` para `server.cfg` e preencha a chave do Cfx.re e a senha do MariaDB.
4. Garanta `ensure [pista]` no `server.cfg`.

## Comandos (admin)

- `/setskill [id] [nivel]` · `/darxp [id] [xp]` · `/resetskill [id]` (devolve os pontos) · `/minhaskill`
- `/pegarcoords` — mostra e copia a posição
- `/ajustegancho x y z` · `/ajusteempurrar x y z rz`
