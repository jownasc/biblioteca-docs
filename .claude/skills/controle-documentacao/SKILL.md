---
name: controle-documentacao
description: >-
  Controle de documentacao na Biblioteca (git em Documentos/Biblioteca).
  Use para handover, handoff, task-code, plano de execucao, testes (unitarios+manuais no mesmo doc),
  ou doc tecnica para agentes. NUNCA gravar corpo completo em docs/ do repo — so biblioteca + stub.
  Apos salvar qualquer documento, rodar scripts/sync-all.ps1. NUNCA editar INDEX.md nem tabela manualmente.
---

# Controle de documentacao

**Biblioteca:** raiz do repo onde esta skill mora (a pasta real dela e'
`<Biblioteca>\.claude\skills\controle-documentacao`). Instalada global
(junction em `~/.claude/skills`, feito pelo `install-global.ps1`): resolver
com `(Get-Item "$HOME\.claude\skills\controle-documentacao").Target` e
subir 3 niveis.  
**Regras detalhadas:** `01-regras-biblioteca.md`  
**Templates:** `_templates/{tipo}.md`

## Primeiro: doc novo ou atualizacao de um que ja existe?

**Atualizando um doc que ja existe** (a maioria do dia a dia — "atualiza
esse resumo", "marca como completed", "anota esse achado no handover"):
nao repetir o fluxo de criacao abaixo.

1. Abrir o arquivo direto (ja se sabe path/nome — nao precisa de
   `INDEX.md` pro proximo numero, nao precisa copiar template).
2. Editar so o que mudou (corpo + campos do YAML relevantes,
   `updated:` = hoje).
3. Se o evento bater com uma linha da tabela "Gatilhos automaticos"
   abaixo, seguir exatamente o que ela pede — **inclusive** o last check
   do Gate REQ+parent quando o gatilho for esse especificamente (ex.:
   fechar a task). O que NAO se repete numa atualizacao comum: o Gate de
   CRIACAO ("antes de criar ou aprovar task-planning") e o grep
   anti-duplicata de `resumo` ("antes de criar um resumo NOVO") — os dois
   so valem pra doc que ainda nao existe.
4. Rodar `sync-all.ps1`.

Isso e tudo. So seguir o fluxo completo abaixo se for CRIAR um doc que
ainda nao existe (numero novo, arquivo novo).

**Criando um doc novo:** seguir o fluxo obrigatorio abaixo.

## Fluxo obrigatorio do agente

```
1. Ler INDEX.md (proximo numero) — nao editar
2. Copiar template do tipo em _templates/
3. Preencher APENAS frontmatter YAML + corpo (H1 em diante)
4. NAO escrever tabela de metadados — gerada pelo script
5. Salvar em `{tipo}/` — sem subpasta frontend/backend, `repo:` no frontmatter ja diferencia a camada
6. Rodar: powershell -ExecutionPolicy Bypass -File scripts/sync-all.ps1
```

## Buscar/pesquisar na Biblioteca (custo de tokens)

`INDEX.md` só traz o cabeçalho (proximo numero) + "Em andamento agora" (pequeno,
so ativas) — nao ler por completo pra achar histórico, cresce pra sempre. Catálogo
completo (tudo, agrupado por tipo) mora em `CATALOGO.md`, separado — só grep/busca
pontual ali, nunca leitura integral por padrão.

Pra achar o que já foi feito sobre um assunto, **buscar em `resumo/` primeiro** —
é o tipo desenhado pra isso (compacto, factual, já formatado pra consumo por
máquina, não precisa ler prosa de handover/planning pra entender o essencial). Só
cair pro conjunto completo (`task-code`+`task-planning`+`testes`+`handover-tecnico`)
se o resumo não tiver a resposta.

## Tipos de documento

| Tipo | Pasta | Quando |
|------|-------|--------|
| `task-code` | `task-code/` | Card Azure / spec da branch |
| `task-planning` | `task-planning/` | Plano de execucao; multiplos planos = secoes no mesmo arquivo |
| `testes` | `testes/` | **Um doc por task** — unitarios + manuais juntos |
| `resumo` | `resumo/` | **Um doc por task+repo** — dado factual pro dashboard visual (`dashboard-visual/`, dentro da propria Biblioteca): Status atual / O que foi implementado / REQs seguidas / O que falta. Nao precisa de prosa polida como os outros tipos — bullets factuais bastam, quem le e o gerador de HTML, nao um humano direto no `.md`. Atualizado a cada gatilho que toca a documentacao da task (ver Gatilhos automaticos), nao so no inicio/fim — fica fresco o tempo todo, nao so na conclusao. |
| `handover-tecnico` | `handover-tecnico/` | Playbook, modulo, contrato API, convencoes |
| `progresso` | `progresso/` — **fora** do fluxo normal (sem `number:`, nao entra em `sync-all.ps1`/`INDEX.md`/`CATALOGO.md`/dashboard) | Doc de trabalho, sobrescrito (nao log): reflete o AGORA da implementacao. Ver secao "Progresso — execucao continua" abaixo |
| `rules` | raiz | So `01-regras-biblioteca.md` |
| `reqs` | `reqs/` (plano) | Card/REQ original verbatim, incluindo o parent (Feature/Epic) quando houver — referencia crua, fora do indice numerado e do `sync-all.ps1` |
| `delegada` | `delegadas/` | Task passada pra **outro dev do time** (o usuario nao implementa) — analise, dev, PRs e rodadas de review. **Um doc por task** (nao por repo: `repo:` lista todos os repos separados por espaco). Tem `number:` e passa pelo `sync-all.ps1`, mas **nunca** vira card do dashboard principal — aparece so' em `time.html` (pagina Time). Sem `resumo`/`task-code`/`task-planning` proprios. Campos extras: `dev` (id de `delegadas/devs.json`), `dificuldade`, `estimativa`, `delegada_em`. Corpo e fluxo: skill `delegar-task` (a tabela `## Analise` tem rotulos fixos lidos pelo gerador). `delegadas/devs.json` so' via botao "+ Dev" (`scripts/time-dev.ps1`), nunca a mao |

**Camada (`repo:`):** nao existe mais subpasta frontend/backend — `repo:`
no frontmatter ja basta pra qualquer script/dashboard diferenciar a
camada (convencao de nome: sufixo `-backend`, prefixo `mfe-`/`mobile-` =
frontend). Ex.: `repo: meu-app-frontend` e `repo: meu-app-backend`
moram os dois em `testes/`, so o `repo:` muda.

Exemplo: `testes/101034-side-sheet-testes.md`

**Nome:** sem numero sequencial (o `number:` do frontmatter ja cobre
isso). `task-code`/`task-planning`/`resumo` nao repetem o tipo no nome;
`testes`/`handover-tecnico` levam o tipo no final:
`{taskId|pseudo_task|general}-{slug}.md` (task-code/task-planning/resumo)
ou `{taskId|pseudo_task|general}-{slug}-{tipo}.md` (testes/handover-tecnico).

**Colisao backend+frontend com o mesmo slug:** como as pastas nao
diferenciam mais camada, se backend e frontend da mesma task gerariam o
MESMO nome de arquivo, sufixar com `-backend`/`-frontend` no final do
nome (antes de checar `INDEX.md`/salvar) — ex.:
`103269-consulta-road-backend.md` e `103269-consulta-road-frontend.md`.
Sem colisao real, nao sufixar a toa.

Exceção: `reqs` usa `{taskId}-{slug}.md`, sem prefixo numerico e sem YAML frontmatter obrigatorio — e copia de referencia, nao doc de ciclo de vida. Um unico arquivo por task, com secoes:

```markdown
# REQ {reqId} — {titulo}

{texto do card colado verbatim}

## Task Code {taskId} — {titulo} (conteudo tecnico)

{texto do Task Code colado verbatim, se for work item separado do REQ — ver Gate abaixo}

## Parent — {parentId} ({Feature|Epic})

{texto do parent colado verbatim, se o REQ tiver parent no Azure DevOps}
```

O parent costuma trazer o objetivo de negocio mais amplo que o REQ filho nao repete (ex: "o usuario precisa ver X na tela") — e frequentemente a fonte real do sinal de escopo full-stack ou do formato de artefato esperado. Nao pular a secao `## Parent` so porque o REQ filho parece autoexplicativo.

**Task Code e REQ costumam ser work items diferentes, nao o mesmo texto em dois lugares.** Achado real (task 107859, 17/09/2026): um `task-planning` inteiro (6 REQs, 4 fases) foi escrito sem nunca ler o `Task Code` no Azure — so REQ + parent. Quando os 6 Task Codes foram lidos depois, cada um trouxe conteudo que a REQ nao tinha: repositorios exatos, tabelas/colunas, e principalmente **perguntas de produto em aberto** ("Duvidas -> produto... nao decidir sozinho o que estiver em aberto aqui") que mudavam decisoes ja tomadas no plano — uma delas ja tinha virado codigo commitado. REQ e Task Code normalmente tem hierarquia Feature -> REQ -> Task Code (Task Code e FILHO do REQ, seu `System.Parent` aponta pro REQ) — sao work items com Description separada, nao apelidos do mesmo item.

## Gate — REQ, Task Code e parent originais antes de task-planning (bloqueia, nao pular)

Antes de criar ou aprovar um `task-planning`, tres coisas precisam estar salvas em `reqs/{taskId}-{slug}.md`, coladas verbatim — nao resumidas, nao substituidas por investigacao de codigo:

1. O card/REQ original (Azure DevOps, Jira, etc.)
2. **O Task Code** — busca-lo (`wit_work_item`/MCP do Azure DevOps, ou pedir pro usuario colar se a tool travar/nao existir) **mesmo que o usuario nao tenha pedido pra criar um `task-code/` de proposito** — e passo automatico do gate, igual a REQ. So pular se o work item da task realmente nao tiver um Task Code separado (REQ e Task Code sao o mesmo item)
3. Se o REQ tiver work item parent (Feature/Epic): o texto do parent, na secao `## Parent` do mesmo arquivo

O `task-code/` (doc de ciclo de vida, quando criado) referencia esse arquivo por link no campo `REQ original` — nao copia o texto de novo.

- [ ] `reqs/{taskId}-{slug}.md` existe, com o card do REQ colado verbatim — se nao, voltar e pedir ao usuario antes de seguir para `task-planning`
- [ ] **O Task Code foi buscado e colado verbatim** na secao `## Task Code {taskId}` do mesmo arquivo — nao pular so porque a REQ parece suficiente; o Task Code costuma ter tabelas/repos/duvidas de produto que a REQ nao repete
- [ ] Se o REQ tem parent no Azure DevOps: secao `## Parent` no mesmo arquivo tem o texto do parent colado verbatim — perguntar ao usuario se ha parent antes de assumir que nao ha
- [ ] Se a demanda gera artefato de arquivo (relatorio/export), o formato esperado esta declarado no `task-code` a partir do REQ, do Task Code ou do parent original — nao inferido por investigacao de codigo
- [ ] Se o Task Code tiver secao "Duvidas -> produto"/pendencia explicita de confirmar com alguem: registrar como bloqueio no `task-planning` (nao so como risco de documentacao) — nao implementar a parte afetada antes da resposta
- [ ] **Last check final** (rodar de novo antes de `status: completed`): reabrir `reqs/{taskId}-{slug}.md` (REQ + Task Code + parent) e confirmar, item por item, que backend E frontend cobrem o que foi pedido

**Excecao — demanda sem REQ/card formal (`task: general`):** nao ha card do Azure DevOps pra colar. Neste caso o gate acima nao bloqueia, mas o pedido original do usuario (o texto que ele digitou no chat, print, mensagem no Teams, etc.) ainda precisa ser registrado verbatim em `reqs/{taskId|slug}-{slug}.md` — usar o slug da demanda como identificador quando nao houver taskId numerico. Nao pular a captura so porque "e informal": foi falta de fonte registrada, e nao falta de REQ formal, que causou o erro do task 103264 (PDF em vez de Excel).

## Status — atualizar conforme andamento

| Status | Quando marcar |
|--------|----------------|
| `draft` | Criando task-code ou planning inicial |
| `in_progress` | Implementacao ou testes em curso |
| `completed` | Testes OK + usuario pediu commit/entrega/PR |
| `superseded` | Substituido por outro doc (`related` aponta o novo) |
| `archived` | Secao/plano antigo dentro de um planning consolidado |

### Gatilhos automaticos (agente deve atualizar YAML)

Esta tabela e' o **contrato da Biblioteca com o fluxo de desenvolvimento**.
A Biblioteca nao depende de nenhuma skill de fluxo especifica (triagem,
plano, TDD, review, git): qualquer fluxo — o do seu `CLAUDE.md`, um
publico como o superpowers, ou nenhum — so' precisa reconhecer o evento
da coluna da esquerda e aplicar a acao da direita (ou chamar esta skill
pra aplicar). Os nomes de skill citados abaixo sao exemplos, nao
requisitos.

| Evento | Acao |
|--------|------|
| Usuario aprova task-code | `status: in_progress` no `task-code` e no planning |
| Agente inicia implementacao de um plano | `plan_active: plano-N` no task-planning |
| Plano N concluido | Secao com `**Status da secao:** concluido`; proximo plano se houver |
| Testes unitarios rodados | Atualizar doc `testes/` (mesmo arquivo) |
| Testes manuais OK | Preencher resultados no mesmo `testes/` |
| Usuario pede mensagem de commit ou fecha entrega | `status: completed` no `testes/`, no `task-planning` **e no `task-code`** — o `task-code` nao fica preso em `draft`/`Rascunho` so porque nenhum gatilho anterior o tocou |
| **Agente monta commit + texto/link de PR pro usuario** (pela skill de git/PR do seu fluxo, se houver) — o pedido em si ja e' o gatilho, nao esperar o usuario confirmar que abriu de verdade. Link nesse momento normalmente e' o `.../pull/new/<branch>` do push (agente **nunca** roda `gh pr create` por conta propria, so' se o usuario disser algo inequivoco tipo "abre o PR voce mesmo") | Registrar o link **na hora**, no `resumo` dessa task+repo: `pr_pending` no frontmatter + a URL completa em algum lugar do corpo (Status atual ou nota curta) — precisa ser a URL inteira, nao só `PR #NNN` em texto solto, senao o card nunca mostra o pill (`Get-Signals` so' acha PR via regex na URL completa). Quando o usuario informar depois o link real do PR ja criado, atualizar `pr_pending` pra essa URL (e' ela que alimenta o sweep automatico de merge, ver `dashboard-visual/scripts/build-dashboard.ps1`, logica do sweep). Se a task tiver mais de um PR (repo espelho, fix de review em branch separada, etc.), cada PR novo e' *outro* evento deste gatilho — nao só o primeiro. Motivo: PR #295 (fix de review da task 104691) ficou sem nenhum registro por dias, so' apareceu quando foi cobrado manualmente — o gatilho de "Task resolvida? = sim" abaixo so' cobre o *ultimo* PR que fecha a task, nao os PRs intermediarios. |
| Usuario confirma que a task esta resolvida (pos-PR — ex.: responde "sim" a "Task resolvida?") | Confirmar que o(s) link(s) de PR ja registrados (gatilho acima) estao como `pr_merged` (nao mais `pr_pending`); rodar o last check do Gate — REQ e parent; `status: completed` no task-code/planning/testes; `sync-all.ps1`. Se task-code nao existe ainda (fluxo ad-hoc sem spec previo): criar agora, salvando o REQ/pedido original em `reqs/` retroativamente |
| Usuario diz que a task **nao** esta resolvida | Perguntar o que falta; manter `status: in_progress`; registrar a lacuna no doc — nao fechar |
| PR de dev do time abre/mergeia numa task `delegada` | Nada manual: URL vai pra `## PRs` + `pr_pending` (skill `delegar-task` no modo revisar, ou botao "Buscar PRs" / `scripts/delegadas-prs.ps1`); o sweep do `build-dashboard.ps1` marca `status: completed` quando todos mergeiam. Delegada **nao** dispara o toque no `resumo` (linha "Qualquer atualizacao" abaixo) |
| Implementacao diverge do que o `task-planning` descreve (mudou de abordagem no meio do caminho) | Atualizar `progresso/{taskId}-{slug}.md` na hora (ver secao "Progresso — execucao continua" abaixo) — nao esperar um marco grande pra registrar |
| **Qualquer** atualizacao de `task-code`/`task-planning`/`testes`/`handover-tecnico` de uma task (nao so no inicio ou no fim) | Dar um toque no `resumo` dessa task+repo: criar se ainda nao existir, senao atualizar pelo menos **Status atual** e **O que falta**. **"Status atual" e' um snapshot, nao um log — reescrever pro estado atual (branch, PR numero+estado, o que esta pendente, poucas linhas/bullets), nunca acrescentar mais um paragrafo de narrativa da rodada.** Historico rodada-a-rodada (o que foi reportado, causa raiz, fix, verificacao) fica em `testes/` (secao `## Ajustes QA — rodada N`) ou `handover-tecnico/` quando o assunto merece narrativa funda — nao duplicar em `resumo/`. Motivo: task 104691 acumulou 2 rodadas de QA direto em "Status atual" sem nunca reescrever, virou 80+ linhas de historico misturada com estado atual, exatamente o tipo de bloco que a pagina de resumo (agora "o principal" que mostra o quadro completo da task) mais expõe. Nao esperar o fim da task pra manter o resumo fresco — ele e' consultado a qualquer momento (dashboard visual em `dashboard-visual/`), nao so na conclusao. **"Ainda nao existir" e' verificavel, nao suposicao** — antes de criar um `resumo` novo, rodar `grep -rl "^task: {taskId}" resumo/` (task numerica) ou `grep -rln "^cluster: {cluster}" resumo/*/*.md` (task `general`) no repo da Biblioteca; só criar se vier vazio. Pular esse grep foi a causa raiz de 8 resumos duplicados ficarem escondidos do dashboard (colisao de `cluster`+`repo`, regularizada em 2026-08-14) — `build-dashboard.ps1` so mostra 1 resumo por task+repo, sem avisar quando ha mais de um. |

## Frontmatter (fonte unica — sem duplicar na tabela)

```yaml
---
number: 28
type: task-planning
status: in_progress
repo: meu-app-frontend
task: 101034
function: Resumo de uma linha para o INDEX
titulo_busca: Reativacao toggle inline metricas  # OBRIGATORIO (nao "opcional — preencher se sobrar tempo"). Titulo curto do que foi FEITO (nao do card/task) — vira o TITULO do card no dashboard, o `taskLabel` antigo (ex. "Task 108364 — Backend") desce pra subtitulo. Escrever com as palavras-chave da tarefa (nomes de tela/endpoint/funcionalidade), pra bater o olho e já saber do que se trata sem ler mais nada — não repetir "Task NNN"/nome de repo (isso já está no subtítulo), não copiar o `function:` inteiro. 3-8 palavras, sem artigo/preambulo ("Reativacao toggle inline X", nao "Isso implementa a reativacao..."). Doc sem esse campo preenchido = titulo do card cai pro `taskLabel` antigo (funciona, mas nao é mais o padrão esperado).
stub: —
cluster: —             # opcional, so pra `task: general` — nome curto (2-4 palavras) que o dashboard usa como titulo do card no lugar de "Geral" E como chave de agrupamento (substitui o fallback por `related`/path — ver dashboard-visual/CLAUDE.md). Manter o MESMO texto em todo doc do mesmo assunto — e' isso que agrupa os docs no mesmo card.
pseudo_task: —         # opcional, so pra `task: general` — numero curto e sequencial na faixa 900+ (contador proprio, separado do `number:` global; ver INDEX.md campo "Proximo pseudo_task") pra dar uma forma facil de achar por busca no dashboard alem do nome do cluster - a faixa 900+ nunca colide visualmente com task id real (ids de work item costumam ter 5-6 digitos) e filtra so digitando "9" na busca. So atribuir quando quem cria o doc realmente quer esse atalho numerico (nem todo `task: general` precisa).
pr_pending: —          # opcional — url do PR quando aberto e ainda sem confirmacao de merge (logica do sweep automatico em dashboard-visual/scripts/build-dashboard.ps1)
plan_active: plano-1          # so task-planning com multiplos planos
related:
  - task-code/101034-terminal-side-sheet.md
  - testes/101034-side-sheet-testes.md
updated: YYYY-MM-DD
author: Seu Nome
---
```

Corpo comeca com `# Titulo` — **sem** tabela. Script gera tabela + secao `## Documentos relacionados` a partir do YAML.

## Task planning — multiplos planos

Um arquivo, secoes `## Plano 1`, `## Plano 2`, etc.

**Antes de implementar:** ler o arquivo, listar planos e **perguntar ao usuario** qual executar (ou confirmar `plan_active`).

Cada secao:

```markdown
## Plano 2 — CRUD medio

**Status da secao:** estagnado | em andamento | concluido
```

Planos concluidos: nao apagar — marcar secao como concluida.

## Handover tecnico — citar a fonte da regra/decisao

Sempre que um `handover-tecnico` explicar uma regra de negocio (RN) ou
decisao tecnica que vem de um REQ/task-code/parent, citar o trecho
original em blockquote (`>`) logo abaixo do titulo do item — nao so
descrever com as proprias palavras. Formato:

```markdown
**N. "Termo do requirement" → o que foi implementado**

> REQ NNNNN, secao/CA-XX: "trecho exato entre aspas, com **negrito** na
> parte que motivou a decisao."

Explicacao/motivo/risco depois da citacao.
```

O trecho citado vem de `reqs/{taskId}-{slug}.md` (REQ ou secao `## Parent`,
ver Gate acima) — copiar de la, nao reconstruir de memoria.

Vale tambem pra respostas do PO registradas no mesmo doc (citar a resposta
literal quando fizer diferenca pra quem for ler depois).

**Contraponto — nao empilhar contexto que so quem viveu a sessao entende.**
A citacao acima e' pra rastreabilidade da REGRA, nao desculpa pra copiar
narrativa de decisao passo a passo. `handover-tecnico`/`testes`/`task-code`
sao lidos por quem NAO tem o contexto desta conversa — cortar historico de
tentativa/erro, jargao interno da Biblioteca, e qualquer coisa que so faz
sentido pra quem estava na sessao. Se o "Resumo executivo" (ou o veredito,
no caso de `testes`) nao basta pra entender sem abrir o resto do doc, o
resto esta detalhado demais.

**Nunca citar/parafrasear o pedido do usuario.** `handover-tecnico`/
`testes`/`task-code` vao pra terceiros — ninguem alem do usuario precisa
saber o que ele pediu pra chegar num resultado. Descrever o achado
("investigacao encontrou X, corrigido com Y") como fato tecnico, nunca
como resposta a uma instrucao ("pedido explicitamente", aspas com o texto
do pedido, "conforme solicitado"). Vale tambem pra `progresso/` se algum
dia esse doc vazar pra fora da sessao.

**Tom profissional, nao robotico.** Esses 3 tipos vao pra terceiros —
escrever como documentacao tecnica de verdade: sem girias/contracoes
informais (`pra`, `pro`, `né`), mas tambem sem virar telegrafico/robotico
(frases completas, natural de ler). `progresso/` e' o unico tipo isento
disso — e' rascunho de trabalho, nao sai da sessao.

**Sem "nos"/"nosso".** A documentacao e' do usuario, o agente so' ajuda a
produzir — nunca escrever "nos resolvemos"/"nossa abordagem"/"decidimos".
Voz neutra/passiva ("o fix corrige X", "a investigacao encontrou Y") ou,
quando fizer sentido atribuir a alguem, o usuario na terceira pessoa —
nunca primeira pessoa do plural.

## Testes — um documento por task

- Nao criar `test-manual` e `test-unit` separados
- Se ja existe `testes/NN-testes-{task}.md` → **atualizar**, nao criar outro
- Secoes: `## Testes unitarios` e `## Testes manuais`

Skills: `testes-manuais` (incluida, back e front) e a skill de testes unitarios do seu fluxo, se houver → gravar no mesmo `testes/`.

## Progresso — execucao continua

Tipo `progresso` (`progresso/{taskId}-{slug}.md`) e' **fora** do fluxo
normal: sem `number:`, nao passa por `sync-all.ps1`, nao entra em
`INDEX.md`/`CATALOGO.md`/dashboard. Nao e' artefato de entrega — e' rascunho
de trabalho, sobrescrito (nao log), pra sobreviver a sessao cair no meio
(terminal travar, computador reiniciar) sem perder o raciocinio.

- Atualizar sempre que a implementacao divergir do que o `task-planning`
  descreve — sem esperar um marco grande. So salvar o arquivo direto, sem
  rodar `sync-all.ps1` (e' isso que da a velocidade).
- Sobrescrever, nao acrescentar — reflete so o AGORA (Fazendo agora /
  Ultima decisao / Proximo passo, ver `_templates/progresso.md`).
- Ao retomar uma task, ler `progresso/{taskId}-{slug}.md` **antes** de
  confiar so no `task-planning` — se existir, e' ele que tem o estado
  real, o planning pode estar defasado.
- Ao fechar a task (`status: completed`): mover o arquivo pra
  `_archive/progresso/`, com uma nota de 1 linha (motivo do arquivamento +
  task) — nao apagar, nao deixar solto em `progresso/`.

## Apos salvar (checklist)

- [ ] `updated` no YAML = hoje
- [ ] `status` correto
- [ ] `titulo_busca` preenchido — obrigatório, palavras-chave da tarefa, curto (ver bloco de Frontmatter)
- [ ] `related` com links relativos na biblioteca
- [ ] Rodar `scripts/sync-all.ps1`
- [ ] Stub no repo se `stub:` preenchido (`docs/{stub}`)

## Regra absoluta — repo

| Permitido | Proibido |
|-----------|----------|
| Stub em `docs/{frontend\|backend}/` | Corpo do handover no repo |

## Novo documento — proximo numero

Consultar `INDEX.md` campo **Proximo numero**. Usar esse valor no `number:` do YAML.

Se for `task: general` e o assunto merecer um atalho numerico pra busca
(ver `pseudo_task` no bloco de Frontmatter acima), consultar tambem o
campo **Proximo pseudo_task** do mesmo `INDEX.md` — e' um contador
separado do `number:`, nao confundir os dois.
