---
name: mock-completo
description: >
  Garante que um mock criado para teste local cubra o fluxo INTEIRO da
  task, não só o endpoint mais novo. Use sempre que for criar ou ajustar
  dado mockado para o usuário testar uma feature localmente antes do
  backend/endpoint real estar disponível (PR não mergeado, deploy
  pendente). Trigger: usuário pede "mock", "dado mockado", "testar sem o
  backend", ou quando você mesmo decidir mockar algo pra desbloquear
  teste local.
---

# Mock completo

Mock parcial é pior que nenhum mock — o usuário clica, quebra, e volta
pra você pra completar o que devia ter sido feito de uma vez.

## Regra central

**Mapear o fluxo inteiro antes de escrever qualquer mock.** Listar TODOS
os endpoints/hooks/funções que a interação do usuário vai disparar ao
testar a feature — não só o endpoint novo mais óbvio. Um mock "pra
testar a feature X" cobre a feature inteira, incluindo toda chamada
disparada por clique/navegação dentro dela, mesmo que essas chamadas
sejam pra endpoints antigos e não relacionados diretamente à mudança.

Exemplo real: mockar só o endpoint novo de uma lista não bastou porque
clicar num item da lista mockada também disparava 3 outras chamadas
(detalhe, resumo, info complementar) — todas precisavam estar mockadas e
usando os MESMOS IDs fake entre si, senão o clique quebrava.

## Checklist antes de considerar o mock pronto

- [ ] Listei todo endpoint/hook/função que qualquer clique/navegação
      dentro do fluxo sob teste vai disparar — não só o mais novo
- [ ] IDs/chaves fake são os MESMOS em todos os mocks relacionados (um
      mock de lista que referencia `id: 'x'` exige que o mock do
      endpoint de detalhe também reconheça esse mesmo `'x'`)
- [ ] Dado mockado tem variedade suficiente pra provar que a UI se
      comporta certo em todos os casos que importam (se o objetivo é
      confirmar que um badge de status muda de cor, o mock precisa ter
      pelo menos um exemplo de cada status possível — não só um)
- [ ] Percorri mentalmente o fluxo como o usuário vai percorrer (cada
      clique, cada tela) e confirmei que NENHUM passo bate num endpoint
      real não mockado

## Ajuste pedido durante o teste

Ajuste do usuário durante o teste = ajustar o MESMO mock completo, não
só o ponto reclamado. Depois de qualquer ajuste, reconferir o checklist
inteiro de novo — não deixar a cobertura regredir pra parcial.

## Remoção

Marcar o mock com um comentário amarrado a uma condição de remoção clara
(ex.: "remover quando PR #NNN mergear"). Remover o mock por completo quando
a condição for satisfeita — não deixar comentado/parcial, não ficar
remendando indefinidamente. Se a task tem `progresso/` ou `resumo/` na
Biblioteca, anotar lá que existe mock pendente de remoção.
