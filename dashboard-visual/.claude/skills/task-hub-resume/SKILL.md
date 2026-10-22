---
name: task-hub-resume
description: Use no inicio de uma sessao em dashboard-visual (Biblioteca) - resolve a task selecionada (por comando copiado do dashboard.html, numero digitado, ou menu interativo) e executa a rotina de retomada (checkpoint, branch, docs).
---

# task-hub-resume

## Passo 0 — Resolver a task selecionada

O caminho principal e o **dashboard** (`dashboard.html`, gerado por
`scripts\build-dashboard.ps1` e atualizado a cada sessao pelo hook
`SessionStart`): o usuario abre esse arquivo no navegador, ve todas as
tasks (Ativas/Completas), e clica em "Copiar comando" na task desejada.
O comando copiado tem este formato:

```
powershell -NoProfile -Command "cd '<pasta-da-biblioteca>\dashboard-visual'; claude 'retomar task <task> no repo <repo>'"
```

(o `<pasta-da-biblioteca>` real vem do próprio comando copiado do dashboard —
gerado dinamicamente, nunca hardcoded. Envolvido em `powershell -NoProfile
-Command` pra funcionar colado tanto no cmd.exe quanto no PowerShell — `;`
sozinho como separador quebra no cmd.exe, que tentava dar `cd` num caminho
com o resto do comando grudado junto)

Se a primeira mensagem do usuario na sessao bater com esse padrao (ou uma
variacao proxima — "retomar task X no repo Y", "task X repo Y", etc.),
extrair `task` e `repo` direto da frase e ir pra Rotina de retomada — nao
precisa de menu nem confirmacao extra, o usuario ja escolheu no dashboard.

**Caminhos alternativos** (quando o usuario abre a sessao sem vir do
dashboard): a sessao tambem comeca com uma listagem numerada de tasks
pendentes no contexto (texto simples, referencia passiva). Se a primeira
mensagem for so um numero solto, resolve direto pela posicao na listagem.
Se for algo generico ("menu", "tasks", "lista", vazio), chamar
`AskUserQuestion` pra apresentar as tasks como opcoes de seta/Enter — ver
"Menu interativo" abaixo.

### Menu interativo (fallback sem dashboard)

**Paginacao (a tool aceita no maximo 4 opcoes por pergunta):**
- Ate 4 tasks restantes na listagem → uma pergunta com todas elas.
- Mais de 4 restantes → uma pergunta com as 3 primeiras (mais recentes) +
  uma 4a opcao **"Mostrar mais tasks"** (description: "Ver as proximas
  tasks da lista"). Se o usuario escolher essa opcao, repetir o processo
  com o proximo lote de 3 (+ "Mostrar mais" de novo se ainda houver mais,
  ou so as restantes se ja couberem em 4).

Cada opcao real de task: `label` curto (ex. `Task 103269 (meu-app-backend)`),
`description` = o resto da linha da listagem (a funcao/titulo completo).
`header`: "Task". `multiSelect`: false.

Se a listagem nao estiver mais visivel no contexto (sessao retomada,
compactada etc.), rodar de novo antes de montar o menu:

```powershell
powershell -ExecutionPolicy Bypass -File "..\scripts\status.ps1" -Numbered
```

(caminho relativo à raiz da Biblioteca — rodar a partir de `dashboard-visual/`)

Depois de escolhida uma task real (pelo menu ou por numero digitado
direto), seguir pra Rotina de retomada abaixo.

## Rotina de retomada

Executar via tool calls normais, nao como script fechado - cada passo pode
precisar de julgamento.

1. **Path do repo:** ler `reposBasePath` em `biblioteca.config.json` (raiz
   da Biblioteca) e montar `<reposBasePath>\<repo>` - e onde os repos de
   projeto ficam, independente de onde este dashboard mora
   (`Biblioteca\dashboard-visual`). Nao perguntar o path a cada vez, ele
   vem do config; so perguntar se o campo estiver vazio (ver skill
   `biblioteca-setup`).
2. **Checkpoint da task que estava ali antes:** `git -C <path> status --porcelain`.
   Se houver mudancas nao commitadas E a branch atual nao for ja a da task
   selecionada: `git -C <path> stash push -u -m "checkpoint/<task-atual>: <descricao curta>"`
   - `<task-atual>` e a task que estava em andamento naquele repo antes da
   troca, nao a que esta sendo selecionada agora. Avisar o que foi
   guardado (nao fazer isso em silencio).
3. **Branch da task selecionada:** `git -C <path> branch -a` procurando o
   padrao `<tipo>/<taskId>[-slug]`.
   - Existe local ou remota -> antes de reusar, checar
     `gh pr list --head <branch> --state all` (mesma checagem do gate de
     Branch do `CLAUDE.md` do time). PR ja merged/closed -> nao dar
     checkout na branch antiga; tratar como "nao existe nenhuma" abaixo
     (criar nova a partir do branch base) e avisar o usuario que a antiga
     foi descartada por ja ter sido mergeada/fechada.
   - Sem PR merged/closed, existe local -> `git checkout <branch>`.
   - Sem PR merged/closed, so existe remota -> `git checkout -b <branch> origin/<branch>`.
   - Nao existe nenhuma -> primeira vez nessa task. Criar a partir do
     branch base do projeto (`defaultBranch` em `biblioteca.config.json`;
     sem esse campo, usar `main`) seguindo a convencao; `<tipo>` vem do
     task-planning da Biblioteca se estiver declarado la - se nao achar,
     perguntar antes de inventar.
   - Guardar o nome resolvido (o passo 7 grava no `resumo`).
4. **Restaurar checkpoint da task selecionada, se houver:** `git -C <path> stash list`
   procurando um stash rotulado `checkpoint/<taskId selecionada>: ...` de
   uma pausa anterior (pode nao ser o mais recente da lista - combinar
   pelo rotulo, nao pela posicao). Se achar, `git stash pop`.
5. **Reler os dados da task:** checar primeiro se existe
   `progresso/{taskId}-{slug}.md` na Biblioteca (tipo `progresso`, ver
   `controle-documentacao`) — se existir, e' ele que tem o estado real da
   implementacao (pode divergir do `task-planning`, que so' reflete o
   plano original). Depois abrir os demais docs relacionados
   (`task-code`/`task-planning`/`testes`/`reqs`, o que existir via
   `related:` no frontmatter) e resumir o que ja foi feito, o que falta,
   e qualquer pendencia registrada (ex: "aguardando resposta do PO").
6. **Reportar:** branch atual, o que foi restaurado (stash aplicado ou
   nao) e o resumo da task - pronto pra continuar trabalhando.
7. **Manter o doc `resumo`:** ver skill `controle-documentacao` (tipo
   `resumo`, um por task+repo). Se nao existir `resumo/{camada}/{taskId}-
   {slug}.md` pra essa task+repo, criar agora. Atualizar as
   secoes **Status atual** e **O que falta** com o que foi levantado no
   passo 5 - bullets factuais, sem prosa polida (esse doc e' fonte de
   dado pro `dashboard.html`, nao leitura direta). Gravar tambem o campo
   `branch:` no frontmatter com o nome resolvido no passo 3 (aparece no
   topo da pagina de resumo) - atualizar sempre, mesmo se o valor nao
   mudou desde a ultima retomada. Nao precisa reescrever **O que foi
   implementado**/**REQs seguidas** aqui - isso e' o gate de fechamento
   do `controle-documentacao` que finaliza. Rodar `sync-all.ps1` da Biblioteca depois.

## Convencao do rotulo de checkpoint

`checkpoint/<taskId>: <descricao curta>` - task sem id real (`task: general`
na Biblioteca) usa o slug do arquivo em vez de um numero.

## O que esta skill NAO faz

Nao duplica logica de documentacao (isso e a skill `controle-documentacao`)
nem convencoes proprias de branch/commit/PR do seu workflow de Git alem do
minimo do passo 3 acima - se seu time tem uma skill dedicada a isso, conecte
ela em vez de reescrever aqui. So orquestra a navegacao entre tasks usando o
que ja existe.
