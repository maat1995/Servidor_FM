# pa_policia — LSPD

Polícia completa do Pista & Asfalto RP. Substitui o **qbx_police** e o **xt-prison** (os dois ficam com `stop` no server.cfg).
As tabelas do banco são criadas sozinhas quando o script liga (`sql/pa_policia.sql` é só referência).

## Patentes (qbx_core/shared/jobs.lua)
| Grau | Patente | O que libera (soma com as de baixo) |
|---|---|---|
| 0 | Cadete | ponto, alertas, algemar, conduzir, revistar, multar até $2.000 |
| 1 | Oficial 1 | prender (código penal), apreender, BO, pátio, perícia |
| 2 | Oficial 2 | blitz (cones, barreiras, tapete de pregos), radar móvel, vistoria, marcar placa |
| 3 | Sargento | mandados (busca e prisão), licença de caça e porte de arma |
| 4 | Tenente | revogar licença, liberar carro retido, cancelar multa, soltar preso |
| 5 | Diretor | contratar, promover até Sargento, demitir |
| 6 | Chefe | caixa da LSPD, editar o código penal, promover até Diretor |

Tudo isso fica em `Config.permissoes` e `Config.tetoMulta` (config.lua).
O emprego agora começa **fora de serviço**: bata o ponto na recepção da DP de Mission Row.

## Teclas e comandos
| Tecla / comando | O quê |
|---|---|
| **F6** | painel da LSPD (status, tablet, ocorrências, blitz, radar, limpar cena, GPS da DP, pânico); dá para andar com ele aberto |
| **F5** / `/mdt` | tablet policial |
| **Y** | assumir a ocorrência que acabou de chegar |
| `/ocorrencias` | abre o painel direto na lista de ocorrências (assumir, GPS, encerrar) |
| `/panico` | botão de pânico (dá para pôr numa tecla em Configurações > Atalhos > FiveM) |
| `/radar` | radar móvel da viatura (frente e trás, placa procurada pisca) |
| `/blitz` | colocar cones, barreiras, iluminação e tapete de pregos |
| `/distintivo 1-ADAM-12` | número do distintivo |
| `/moverhudpolicia` (ou **Mover widgets** no F6) | arrastar radar, avisos e painel para onde quiser; roda do mouse muda o tamanho. Fica salvo no PC de cada jogador |
| **X** (todos) | mãos para cima: deixa ser revistado sem algema |
| `/pospolicia` (admin) | copia a posição atual em `vec4(...)` para ajustar o config |
| **190** no celular | chamado para a polícia (área aproximada de quem ligou) |

No olho (ox_target): jogador → algemar, algema com mãos à frente, conduzir, colocar na viatura, revistar, apreender, teste de pólvora, ficha no tablet.
Veículo → tirar do veículo, vistoria, pátio/reter, coletar digital do volante, consultar placa.

## Avisos de crime
- Cada ocorrência chega como um card no canto da tela (código, título, suspeito/veículo, rua, distância ao vivo) com som de rádio por prioridade.
- **Y** assume: traça a rota no GPS até a área (some quando você chega). Alta e máxima piscam no mapa até alguém assumir.
- Crimes que avisam sozinhos (`Config.crimes`): tiro, tiro de dentro de veículo, roubo de veículo, briga, atropelamento e direção perigosa na cidade.
  Cada um tem chance de testemunha, espera e raio próprios; avisos iguais perto um do outro viram um só.

## Perícia
- Cápsulas e sangue **só aparecem no facho da lanterna**: lanterna na mão mirando ou lanterna presa na arma ligada.

## Para outros scripts
```lua
exports.pa_policia:policiaisEmServico()          -- número
exports.pa_policia:temPoliciaMinima(3)           -- true/false
exports.pa_policia:temPermissao(src, 'licencas') -- patente + em serviço
exports.pa_policia:alerta({ codigo = '10-31', titulo = 'Roubo de veículo', descricao = '...',
    coords = coords, raio = 150, prioridade = 'alta' })  -- raio 0 / exato = true: ponto exato
exports.pa_policia:crime(src, 'rouboVeiculo', { veiculo = { modelo = 'Sultan', cor = 'prata', placa = '45A***' } })
exports.pa_policia:multar(citizenid, valor, motivo)
exports.pa_policia:prender(src, meses)
```
Prioridades: `baixa`, `media`, `alta`, `maxima` (pisca e faz som de emergência).

## O que já está ligado
- **Roubos** (`pa_roubo_*`): contam os policiais e mandam o alerta pela central (o Fleeca vai como prioridade máxima).
- **pa_casas**: o mandado de busca sai pelo tablet (Sargento+) e continua funcionando pelo `/mandado`.
- **pa_caca**: a licença de caça sai pelo tablet; o `/licencacaca` segue a patente da LSPD.
- **pa_medico**: o pânico de um policial desmaiado também chama o SAMU; acordar no hospital solta a algema.
- **pista_tuning / pa_dinamometro**: a vistoria lê as peças do carro; laudo do dinamômetro com menos de 15 dias deixa chip, remap e motor de corrida regulares (nitro e chip Stage 3 nunca).
- **pista_guincho**: com mecânico em serviço, o carro apreendido espera o guincho levar até o pátio da DP (15 min, depois vai sozinho).
- **qbx_garages**: pátio comum = Impound Lot com taxa; carro **retido** só sai quando um Tenente+ libera no tablet.
- **Renewed-Banking**: multas, taxas e licenças vão para a conta `police` (caixa da LSPD).

## Prisão
- Pena aplicada no tablet com o preso perto e **dentro da DP** (`Config.prisao.exigirNaDP`).
- 1 mês = 1 minuto on-line (`Config.prisao.minutosPorMes`). Só corre com o preso on-line.
- Ilegais vão para o depósito de evidências; o resto do inventário volta na saída.
- Trabalhos no pátio de Bolingbroke tiram 1 mês cada. Saiu da área = fuga: alerta máximo e mandado de prisão automático.

## Ajustes que podem ser necessários
- **Coordenadas da DP** (`Config.dp`): estão nas posições padrão do Qbox para Mission Row. Se o interior não bater, fique no ponto certo e use `/pospolicia`.
- **Luvas** (`Config.pericia.semLuva`): número dos braços sem luva (componente 3). Se alguma luva deixar digital, tire o número da lista.
- Tecla **X** (mãos para cima) e **F5/F6** podem ser trocadas em Configurações > Atalhos > FiveM.
