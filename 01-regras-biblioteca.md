---
number: 01
type: rules
status: completed
repo: geral
task: general
function: Regras da Biblioteca
stub: —
cluster: Regras da Biblioteca
updated: 2026-09-10
author: —
---
# Regras da Biblioteca

<!-- badge:auto -->
✅ **Concluido** | `geral` | 10/09/2026
<!-- /badge:auto -->

Referência humana — resumo condensado. Agentes seguem a versão operacional
completa em `~/.claude/skills/controle-documentacao/SKILL.md`; aqui é só o
que um humano precisa pra se situar rápido.

**Local:** raiz deste repo
**Índice:** [`INDEX.md`](INDEX.md) (tasks em andamento, gerado — não editar)
**Catálogo:** [`CATALOGO.md`](CATALOGO.md) (histórico completo, gerado — não editar)
**Sync:** `scripts/sync-all.ps1`

---

## Estrutura

```
Biblioteca/
├── INDEX.md                  # gerado
├── CATALOGO.md                # gerado
├── 01-regras-biblioteca.md
├── scripts/                    # sync-header, lint-clusters, build-index, sync-all, pre-commit-check
├── dashboard-visual/           # dashboard HTML gerado + skills locais (task-hub-*)
├── docs/screenshots/           # imagens do README
├── .claude/skills/             # controle-documentacao, delegar-task, testes-manuais etc.
├── _templates/                # task-code, task-planning, testes, resumo, handover-tecnico, progresso
├── task-code/
├── task-planning/
├── testes/
├── resumo/
├── handover-tecnico/
├── delegadas/                  # opcional - tasks passadas pra devs do time + devs.json (pagina Time do dashboard)
├── progresso/                  # doc de trabalho, sobrescrito, fora do indice numerado e do sync-all.ps1
├── reqs/                       # REQ/card original verbatim, fora do indice numerado
├── planos/                     # backup automatico de todo plano de ExitPlanMode (hook), fora do indice numerado
└── _archive/                   # docs substituidos ou anteriores a esta convencao
```

---

## Tipos

| Tipo | Conteúdo |
|------|----------|
| `task-code` | Card do seu rastreador de tarefas, especificação da branch |
| `task-planning` | Plano de execução; vários planos = seções no mesmo arquivo (`plan_active` indica qual) |
| `testes` | Unitários + manuais no mesmo doc, um por task |
| `resumo` | Dado factual pro dashboard — status/implementado/REQs/falta. **Um por task+repo**, nunca mais de um (ver "Regras de status" abaixo) |
| `handover-tecnico` | Módulo, playbook, contrato, convenções, debug consolidado |
| `delegada` | Task passada pra outro dev do time: análise (tela/repo/causa/atenção/dificuldade), dev, PRs e rodadas de review. **Um por task** (`repo:` lista todos os repos). Entra no índice, mas só aparece na página **Time** (`time.html`), nunca na grade principal. Fluxo na skill `delegar-task`; devs em `delegadas/devs.json` (botão "+ Dev") |
| `reqs` | Card/issue do seu rastreador de tarefas (+ item pai, se houver) colado verbatim — referência crua, fora do índice numerado e do `sync-all.ps1` |
| `planos` | Cópia bruta de cada plano aprovado em `ExitPlanMode` — sem vínculo com task/repo, backup histórico. Copiado automaticamente por hook (`~/.claude/settings.json`, `PermissionRequest` no matcher `ExitPlanMode`), não por ação manual do agente. Fora do índice numerado e do `sync-all.ps1` |
| `progresso` | Doc de trabalho por task, sobrescrito (não log) — reflete o estado atual da implementação, pra sobreviver a sessão cair no meio. Atualizado a cada divergência relevante do `task-planning`. Fora do índice numerado e do `sync-all.ps1`; arquivado em `_archive/progresso/` quando a task fecha |

**Camada (`repo:`):** não há mais subpasta `frontend/`/`backend/` — o
valor de `repo:` já basta pra qualquer script/dashboard diferenciar a
camada (convenção de nome: sufixo `-backend`, prefixo `mfe-`/`mobile-` =
frontend). `meu-app-frontend` e `meu-app-backend` moram os dois na mesma
pasta do tipo, só o `repo:` muda.

---

## Nomenclatura

Sem número sequencial no nome do arquivo (`number:` no frontmatter já
cobre isso — ver "Frontmatter" abaixo). `task-code`/`task-planning`/
`resumo` não repetem o tipo no nome; `testes`/`handover-tecnico` levam o
tipo no **final** do nome (vocabulário mais genérico, vale deixar
explícito):

```
task-code/task-planning/resumo:  {taskId|pseudo_task|general}-{slug}.md
testes:                          {taskId|pseudo_task|general}-{slug}-testes.md
handover-tecnico:                {taskId|pseudo_task|general}-{slug}-handover-tecnico.md
```

Ex.: `101034-terminal-side-sheet.md` (task-code), `101034-side-sheet-testes.md`
(testes), `901-checkpoint-melhorias-biblioteca-handover-tecnico.md`
(handover-tecnico, `task: general` com `pseudo_task: 901`).

**Colisão backend+frontend com o mesmo slug:** como a pasta não diferencia
mais camada, se backend e frontend da mesma task gerariam o mesmo nome de
arquivo, sufixar com `-backend`/`-frontend` no final do nome — ex.:
`103269-consulta-road-backend.md` e `103269-consulta-road-frontend.md`.
Sem colisão real, não sufixar à toa.

Exceção: `reqs/` usa `{taskId}-{slug}.md` — sem número sequencial, sem frontmatter obrigatório (é cópia de referência, não doc de ciclo de vida).

Exceção: `planos/` usa `{yyyy-MM-dd_HHmmss}-{nome-original-do-plano}.md` — nome gerado pelo hook, sem número sequencial, sem frontmatter.

---

## Fluxo obrigatório do agente (criar um doc novo)

Passo a passo completo em `~/.claude/skills/controle-documentacao/SKILL.md`
("Fluxo obrigatorio do agente") — não duplicado aqui pra não divergir das
duas versões quando o fluxo mudar. Resumo pra humano: ler `INDEX.md` pro
próximo número, copiar o template certo, preencher só YAML+corpo, salvar
na pasta certa, rodar `sync-all.ps1`.

---

## Regras de status

`draft` → `in_progress` → `completed` | `superseded` | `archived`

| Campo/valor | O que é |
|---|---|
| `superseded` | Substituído por outro doc — `related:` aponta pro novo |
| `archived` | Histórico encerrado sem substituto, ou seção antiga dentro de um planning consolidado |
| `cluster:` | Nome curto de agrupamento pra tasks `task: general` — vira o título do card no dashboard E a chave de agrupamento (em vez de "Geral" solto). Mesmo texto em todo doc do mesmo assunto |
| `pseudo_task:` | Opcional, só pra `task: general` — número curto sequencial na faixa **900+** (contador próprio, separado do `number:` global; ver `INDEX.md`, campo "Próximo pseudo_task") pra achar o card pela busca do dashboard também por número, não só pelo nome do `cluster`. Aparece no título do card como `Cluster (#N)`. Faixa 900+ desde 2026-08-24 — nunca colide visualmente com task id real (ids de work item costumam ter 5-6 dígitos, ex. `104691`) e filtra só digitando "9" na busca |
| `pr_pending` / `pr_merged` / `pr_rejected` | URL do PR — preenchidos por um sweep automático (`gh pr view`) rodado pelo `build-dashboard.ps1`, não à mão. Ao mergear, o sweep também fecha `status: completed` sozinho |
| `plan_active` | Só em `task-planning` com múltiplos planos — indica qual seção está em execução |

**Um `resumo` por task+repo — regra, não sugestão.** O dashboard guarda só **um** `resumo` por card (`Select-Object -First 1`); um segundo resumo pro mesmo `cluster`+`repo` (ou `task`+`repo`) fica **invisível no dashboard, sem aviso**. Já aconteceu (8 resumos sumiram silenciosamente em 13/08/2026, regularizado no dia seguinte). Antes de criar um `resumo` novo: `grep -rl "^task: {taskId}" resumo/` ou `grep -rln "^cluster: {cluster}" resumo/*/*.md` — só criar se vier vazio. `scripts/lint-clusters.ps1` bloqueia o `sync-all.ps1` se detectar essa colisão.

---

## Regra absoluta — nunca corpo completo no repo do projeto

| Permitido | Proibido |
|-----------|----------|
| Stub em `docs/{frontend\|backend}/` do repo do projeto (`stub:` no YAML) | Corpo completo de handover/planning/testes/task-code gravado no repo do projeto |

Stub existe pros dois lados — frontend (`docs/frontend/`) e backend (`docs/backend/`), não só frontend.

---

## Buscar na Biblioteca

Não ler `INDEX.md` inteiro pra achar histórico — ele só tem "Próximo número" +
tasks em andamento. Histórico completo é `CATALOGO.md` (grep pontual, não
leitura integral). Pra saber "o que já foi feito sobre X", buscar em
`resumo/` primeiro — é o tipo compacto, factual, feito pra isso. Só cair pro
conjunto completo (`task-code`+`task-planning`+`testes`+`handover-tecnico`)
se o resumo não bastar.

---

## Templates

Campos base dos 5 templates com ciclo de vida em `_templates/`:

```
number, type, status, repo, task, function, titulo_busca, stub, related, updated, author
```

`task-planning.md` soma `plan_active`. `cluster`, `pseudo_task` e
`pr_pending`/`pr_merged`/`pr_rejected` **não** vêm nos templates — são
exceções aplicadas depois (cluster + pseudo_task na hora de rotular uma
task `general`; os `pr_*` só são escritos pelo sweep automático, nunca à
mão). `titulo_busca` é **obrigatório** — título curto do que foi
**feito**, com as palavras-chave da tarefa (nomes de tela/endpoint/
funcionalidade), pra bater o olho no card e já entender do que se trata
sem ler mais nada. Vira o título do card no dashboard — o `taskLabel`
antigo ("Task NNN — Backend") desce pra subtítulo, junto do repo.

`progresso.md` é o 6º template, mas fora desse padrão — frontmatter
mínimo (`task`, `repo`, `updated`), sem `number:`.

---

## Automação

| Script | Função |
|--------|--------|
| `sync-header.ps1` | YAML → tabela no corpo |
| `lint-clusters.ps1` | Trava o sync se houver `cluster` divergente num grupo, ou mais de um `resumo` ativo no mesmo cluster/task+repo |
| `build-index.ps1` | Gera `INDEX.md` + `CATALOGO.md` |
| `dashboard-visual/scripts/build-dashboard.ps1` | Gera o dashboard (`dashboard.html`, `paleta.html`, `archive.html`, `pendencias.html`, `nova-task.html`, `time.html`, `summaries/*.html`) |
| `sync-all.ps1` | Roda os 4 acima em ordem (aborta em `sync-header`/`lint-clusters` se achar problema) — sempre rodar depois de editar |
| `.git/hooks/pre-commit` → `pre-commit-check.ps1` | Trava o commit se um `.md` estiver corrompido/anormal — automático, não precisa lembrar |

O agente **não** edita tabela, `INDEX.md` nem `CATALOGO.md` manualmente.

---

## Ver também

[`README.md`](README.md) — visão geral e tour do dashboard, com screenshots.
[`dashboard-visual/CLAUDE.md`](dashboard-visual/CLAUDE.md) — como o dashboard
funciona por dentro (favoritos, resumo, página de Arquivo, skills locais
`task-hub-resume`/`task-hub-qa`).

<!-- meta:auto -->
<details>
<summary>Metadados</summary>

| Campo | Valor |
|---|---|
| Numero | 01 |
| Tipo | Regras |
| Task | **Geral** |
| Stub | — |
| Autor | — |

</details>
<!-- /meta:auto -->
