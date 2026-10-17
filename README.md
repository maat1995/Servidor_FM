# Pista & Asfalto RP

Servidor FiveM (base Qbox) focado no mundo dos carros: preparação, mecânica e oficinas.

## O que tem aqui

- `resources/[pista]/pista_tuning` — sistema de preparação
  - Peças como item (turbo, intercooler, chip Stage 1/2/3, kit de nitro)
  - Motor: guincho da oficina, motor pendurado, bancada, pistão forjado e cabeçote
  - Notebook de remap (turbo, ignição, limitador, mistura) com risco ao motor
  - Cada peça pede uma habilidade da árvore de Mecânica (pista_skills) ou mecânico especializado (cargo 3+)
  - Instalação pode falhar para quem não é especializado (a peça não é gasta)
  - Quem não é mecânico em serviço só prepara o próprio carro; no dos outros só remap e suspensão,
    e só com a `licenca_funcionamento`: emitida por advogado (`/emitirlicenca [id]`), no nome do jogador, vale 30 dias
- `resources/[pista]/pista_skills` — skills (tela no `/skills` ou F7)
  - Árvore de Mecânica: 10 níveis, 12 pontos, 15 habilidades em Motor, Chassi, Eletrônica e Passivas
  - XP por peça nova instalada, consertos, retífica, dinamômetro (`/dyno`), aprendiz, manuais técnicos
  - Pronto para o script de corridas: `exports.pista_skills:darXPCorrida(source, 'legal'|'ilegal', posicao, participantes)`
    e `exports.pista_skills:registrarTempo(source, 'pista', ms)` para time attack
  - Anti-farm: peça repetida no mesmo carro não dá XP, cooldowns por carro e limite diário
  - Ferramentas com desgaste (jogo de soquetes, torquímetro)
- `resources/[pista]/pa_hud` — HUD do servidor
  - Velocímetro com conta-giros, marcha, turbo (pressão do remap), nitro, gasolina e temperatura/vida do motor
  - Turbo e nitro só aparecem se a peça estiver instalada (pista_tuning); alerta de motor danificado, superaquecendo ou fora
  - Status (vida, colete, fome, sede, estresse) alinhados ao minimapa; fome/sede/colete somem quando cheios
  - Bússola com rua e bairro, indicador de voz (pma-voice) e aviso de XP/nível do pista_skills
  - `/hud`: km/h ou mph, tamanho, bússola, esconder status cheio e modo cinema (salvo no PC do jogador)
  - Outros scripts podem esconder a HUD: `exports.pa_hud:ocultar(true)`
  - Substitui o qbx_hud (`stop qbx_hud` no server.cfg): estresse (tiro, tela embaçada), indicador de cinto, `/banco` e `/dinheiro`
- `resources/[pista]/pa_cambio` — câmbio manual
  - Todo carro sai **manual**: liga em neutro (N), **Shift** sobe e **Ctrl** desce (N → Shift = 1ª, N → Ctrl = ré)
  - Em N o motor acelera mas o carro não anda; desligou ou saiu do carro, volta para N
  - Corte rápido na troca, limitador de giro e proteção contra reduzir com o giro alto
  - Câmbio automático é peça (`cambio_automatico`, autopeças) instalada pelo mecânico; tirar volta para o manual
  - Viaturas/ambulâncias (classe emergência), modelos de emprego e polícia/SAMU em serviço ficam automáticos
  - Teclas trocáveis em Configurações > Atalhos > FiveM; marcha (N/R/1…) aparece na pa_hud
- `resources/[pista]/pa_medico` — desmaio e resgate (SAMU)
  - Caiu (qbx_medical): começa a contar o tempo de desmaio (`Config.tempoDesmaiado`, 5 min)
  - **G** chama o SAMU: os médicos em serviço recebem um alerta com a **área aproximada** do corpo (círculo no mapa, não o ponto exato)
  - Celular: ligar para **192** no NPWD faz o mesmo; quem liga bem chama para a própria posição (amigo caído do lado)
  - Médico assume com **Y** no aviso ou pelo `/chamados` (GPS na área); o paciente vê quem está a caminho
  - Atendimento: olho no paciente > **Atender paciente** abre a ficha (vida, sangramento e ferimentos por parte do corpo)
    - **Na rua** (com itens): reanimar (`desfibrilador` + 1 `adrenalina`, acorda com 25%), estancar sangramento (`bandage`)
      e tratamento (`kit_trauma`: vida até 100%, ferimentos leves e moderados). Reanimar na rua mantém os ferimentos graves
    - **No hospital** (Pillbox e Paleto, sem itens): reanimar (acorda com 50%) e tratamento completo (cura tudo, vida 100%)
    - Itens no armário do SAMU (qbx_ambulancejob); tudo conferido no servidor (emprego, distância, itens e tempo)
  - Sem médico em serviço: vem uma **ambulância NPC** de sirene, o socorrista faz massagem cardíaca e reanima (cobra `Config.npc.preco`)
  - Tempo acabou: **segurar E** acorda no hospital **perdendo tudo** (inventário limpo + internação do qbx_ambulancejob); antes disso o servidor bloqueia
  - Ninguém é mandado para o hospital sozinho: enquanto não segurar E, um médico ainda pode chegar
- `resources/[pista]/pa_policia` — polícia da LSPD (substitui o qbx_police e o xt-prison)
  - 7 patentes (Cadete, Oficial 1 e 2, Sargento, Tenente, Diretor, Chefe), cada uma libera ações (`Config.permissoes`)
  - Bater ponto na DP de Mission Row, arsenal por patente, armário pessoal, garagem de viaturas e vestiário
  - Central de alertas para os outros scripts (`exports.pa_policia:alerta`): área aproximada no mapa, **Y** assume, `/ocorrencias`, botão de pânico e **190** no celular
  - Abordagem no olho: algemar (atrás ou à frente), conduzir, viatura, revista e apreensão (ilegais, dinheiro sujo, armas sem porte vão para o depósito de evidências); **X** = mãos para cima
  - Tablet (**F5**): fichas, multas, código penal (o Chefe edita), BO, mandados (busca no pa_casas e prisão), licença de caça e porte, placas procuradas, equipe e caixa da LSPD
  - Prisão em Bolingbroke: pena em meses (1 mês = 1 min on-line), pertences devolvidos na saída, trabalhos reduzem a pena, fuga gera alerta e mandado
  - Fiscalização: blitz com cones/barreiras/tapete de pregos, vistoria das peças do pista_tuning (laudo do dinamômetro vale como vistoria), radares fixos com ANPR, radar móvel e pátio (comum ou retido) com o guincho
  - Perícia: cápsulas com número de série, sangue e digitais no volante; coleta com saco de evidência e laudo no laboratório da DP
- `resources/[ox]/ox_inventory` — itens, autopeças do mecânico e ícones
- `resources/[qbx]/qbx_ambulancejob` — versão oficial com um ajuste: com o pa_medico ligado ele não manda alerta automático nem desenha a tela de morte
- `resources/[qbx]/qbx_customs` — desempenho restrito a quem tem skill/mecânico
- `server.cfg.example` — configuração do servidor **sem** chave e senha

## Instalação

1. Base Qbox instalada pelo txAdmin.
2. Copie a pasta `resources` por cima da base.
3. Copie `server.cfg.example` para `server.cfg` e preencha a chave do Cfx.re e a senha do MariaDB.
4. Garanta `ensure [pista]` no `server.cfg`.

## Comandos (admin)

- `/emitirlicenca [id]` (advogado ou admin)
- `/setskill [id] [nivel]` · `/darxp [id] [xp]` · `/resetskill [id]` (devolve os pontos) · `/minhaskill`
- `/pegarcoords` — mostra e copia a posição
- `/ajustegancho x y z` · `/ajusteempurrar x y z rz`
