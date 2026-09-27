# Pista & Asfalto RP

Servidor FiveM (base Qbox) focado no mundo dos carros: preparação, mecânica e oficinas.

## O que tem aqui

- `resources/[pista]/pista_tuning` — sistema de preparação
  - Peças como item (turbo, intercooler, chip Stage 1/2/3, kit de nitro)
  - Motor: guincho da oficina, motor pendurado, bancada, pistão forjado e cabeçote
  - Notebook de remap (turbo, ignição, limitador, mistura) com risco ao motor
  - Skill de preparação (XP) + mecânico especializado (cargo 3+)
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

- `/setskill [id] [nivel]` · `/minhaskill`
- `/pegarcoords` — mostra e copia a posição
- `/ajustegancho x y z` · `/ajusteempurrar x y z rz`
