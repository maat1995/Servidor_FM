# pa_roubocarro

Roubo de carros sob encomenda do Pista & Asfalto RP.

## Instalação

1. O item `tablet_roubo` já está no `ox_inventory/data/items.lua`.
2. **pa_bitcoin**: coloque o `tablet_roubo` na loja do PC (catálogo de itens ilegais), igual ao `tablet_desmanche`.
   O tablet abre pelo export `pa_roubocarro.usarTablet`, não pelo `pa_bitcoin.usarTablet`.
3. `ensure pa_roubocarro` (já entra pelo `ensure [pista]`). As tabelas são criadas sozinhas.
4. Ajuste os pontos de `Config.locais`, `Config.entregas` e `Config.retirada` no jogo com `/rc_ponto` (admin).

## Fluxo

- Tablet > Contrato: escolhe a classe liberada pelo nível.
  - Classe D: qualquer carro da lista na rua. Pegou dirigindo, conta.
  - Classes C a S: o carro está estacionado num ponto. O GPS mostra uma área; chegando perto, ela encolhe.
- Arrombar: olho no carro > "Arrombar (encomenda)". Precisa de `lockpick` ou `advancedlockpick`; errar pode quebrar.
- Alarme por classe (chance) avisa a polícia com o alerta `10-16E`. A e S têm rastreador: desligue pelo tablet dentro do carro.
- Entrega: o ponto aparece depois do roubo. Carro amassado paga menos (mínimo 40%).
- Dupla: 70% para quem entregou, 30% para o parceiro.
- Carros entregues ficam 24h no tablet para comprar com moedas (chassi riscado).

## Integrações

- `exports.pa_roubocarro:chassiRiscado(placa)` → usado na vistoria da pa_policia (regra `chassi_riscado`).
- Polícia: `exports.pa_policia:alerta` / `fecharAlerta`.
- Chaves: `exports.qbx_vehiclekeys:GiveKeys`.
