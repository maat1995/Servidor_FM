# pa_handling — handling realista

Cada carro tem a **ficha do carro real** em que foi inspirado (potência, peso, tração,
marchas, 0-100 e velocidade final). O script transforma a ficha em handling de fábrica
para todos os carros daquele modelo. A preparação do `pista_tuning` continua somando
em cima, então um popular preparado fica "bom para um popular", não um supercarro.

## Instalação

1. A pasta já está em `resources/[pista]` (o `ensure [pista]` liga sozinho).
2. No `server.cfg`, dê a permissão de calibrar para os admins:
   `add_ace group.admin pa_handling.admin allow`
3. Reinicie o **servidor inteiro** (não só o recurso), para nenhum carro ficar com a handling antiga.

## Calibração automática (`/calibrar`)

O GTA não tem uma fórmula exata de handling → desempenho. Por isso o script **mede no jogo**:
o carro arranca sozinho, acelera em linha reta, mede o 0-100 e a velocidade final, corrige e
repete até bater com a ficha (até 4 tentativas). Resultado salvo em `data/calibracao.json`.

1. Vá a pé até o começo de uma reta plana de uns 400 m (a pista do aeroporto LSIA é ideal).
2. Olhe para a direção em que o carro deve andar.
3. Rode um dos comandos (você vai para um mundo separado, sem trânsito):

| Comando | O que faz |
|---|---|
| `/calibrar amostra` | 1 carro por faixa (~9 carros, poucos minutos). Acerta o chute de todos os outros. **Comece por aqui.** |
| `/calibrar blista` | Só esse modelo |
| `/calibrar classe 0` | Uma classe do GTA (0 compactos, 1 sedãs, 2 SUV, 3 coupés, 4 muscle, 5 clássicos, 6 esportivos, 7 super, 9 off-road, 12 vans) |
| `/calibrar pendentes` | Tudo que ainda não ficou dentro da tolerância |
| `/calibrar todos` | Todos (~450 carros, leva horas; dá para deixar rodando) |
| `/calibrar parar` | Para depois do carro atual |

Não mexa no teclado durante o teste. O F8 mostra cada medição.
No console do servidor: `handling_resetar BLISTA` (ou `tudo`) apaga a calibração.

## Fichas

- **Nativos:** `data/nativos.lua`, gerado por `tools/gerar_nativos.py`.
  - ~200 carros com ficha real escrita à mão (ex.: Panto = Smart ForTwo, Sultan = Lancer Evo IX).
  - O resto ganha ficha automática: mantém a ordem original dentro da classe, espremida na faixa realista.
  - Para mudar um nativo, edite o gerador e rode `python tools/gerar_nativos.py`, ou sobrescreva no `config.lua`.
- **Addons (carros brasileiros etc.):** `Config.fichas` no `config.lua`. Basta cv, kg, tração,
  marchas, 0-100, velocidade final e a faixa de pneu. Depois `/calibrar <modelo>`.

`/ficha` dentro do carro mostra a ficha técnica (qualquer jogador).

## Ajustes gerais (config.lua)

- `Config.escalaVelocidade`: 1.0 = real. Use 0.85 se 400 km/h ficar demais para o mapa.
- `Config.escalaAceleracao`: deixa todo mundo mais rápido/lento no 0-100.
- `Config.pneus`: aderência e freio de cada faixa (popular, médio, esportivo, super...).
- `Config.aplicarPeso` / `Config.aplicarMarchas`.

## Integrações

- `pa_cambio`: o carro de teste roda em automático (`pa_cambio_auto`).
- `pista_skills` (`/dyno`): a potência medida parte do cv real da ficha × o ganho da preparação.
- Export: `exports.pa_handling:ficha(veh)` → ficha + `forcaBase` (força de fábrica, sem preparação).
