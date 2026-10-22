---
name: delegar-task
description: Use quando o usuário (tech lead) quer passar uma task para outro dev do time — analisa a task (card/REQ/parent do rastreador + investigação de código só leitura), entrega a tabela Tela/Repo/Causa provável/Atenção/Dificuldade + "Onde mexe", e depois de saber qual dev pegou grava a task como `delegada` na Biblioteca (aparece na página Time do dashboard). Também cobre a revisão de PR de uma task delegada (a delegada vira a referência do review e a rodada fica registrada no doc) e a checagem de deploy quando o PR já mergeou. Dispara em: "analisa essa task pro time", "vou passar essa task pro fulano", "fulano pegou a 1234", "delegar task", "revisar o PR do fulano", botões "+ Analisar tasks"/"Revisar PRs" do time.html.
---

# Delegar task para o time

Fluxo de quem **não implementa**: analisa, delega, acompanha e revisa. Quem
implementa é outro dev. Por isso esta skill **nunca edita código, nunca
troca de branch, nunca commita** em repo de projeto — e substitui, nesse
fluxo, qualquer skill de triagem/implementação que o seu `CLAUDE.md` tenha.

**Biblioteca:** raiz do repo onde esta skill mora (pasta real:
`<Biblioteca>\.claude\skills\delegar-task`; instalada global via junction —
resolver com `(Get-Item "$HOME\.claude\skills\delegar-task").Target` e subir
3 níveis).
**Docs:** `delegadas/{taskId}-{slug}.md` (`type: delegada`) — template em
`_templates/delegada.md`. Pasta não existe ainda → criar (é ela que liga a
página Time do dashboard).
**Devs:** `delegadas/devs.json` — editado **só** pelo botão "+ Dev" do
`time.html` (`scripts/time-dev.ps1`), nunca à mão pelo agente. O `id` de
cada dev é o valor do campo `dev:` da delegada.
**Config:** `biblioteca.config.json` — `reposBasePath` (onde ficam os repos),
`defaultBranch` (branch base pra ler código; ausente → `develop`, ou `main`
se `develop` não existir), `githubOrg` (busca de PRs).

Antes de gravar qualquer arquivo na Biblioteca, invocar `controle-documentacao`.
Ela é a fonte de verdade de número, status e sync — esta skill só define o
que vai **dentro** da delegada.

## Modos

| Modo | Entrada | Saída |
|---|---|---|
| **analisar** | 1+ links/ids de work item | Tabela de análise no chat → pergunta qual dev pegou → modo delegar |
| **delegar** | "fulano pegou a X" (ou resposta do analisar) | `reqs/` + `delegadas/` gravados, mensagem pronta pro dev |
| **revisar** | 1+ links de PR | Review com a delegada como referência + rodada registrada no doc + checagem de deploy se mergeado |
| **atualizar** | "anota na X que...", "reatribui X pro Y", "X foi cancelada", "eu peguei a X" | Edição pontual da delegada |

PRs novos que o dev abriu não precisam de modo: o botão **Buscar PRs**
(`scripts/delegadas-prs.ps1`) acha pelo id da task + login do dev e registra
sozinho.

---

## Modo analisar

### 1. Fonte original (somente leitura)

Para cada task: buscar no rastreador (ex.: MCP `azure-devops`, `wit_work_item`
com `$expand=relations`) o card/REQ, o item técnico filho se houver, e o
**parent** (Feature/Epic) — mesmo Gate do `controle-documentacao`. **Nunca**
chamar ferramenta de escrita do rastreador, mesmo que apareça disponível.

Sem acesso ao rastreador → pedir pro usuário colar o texto. Não inventar
escopo a partir do título. Guardar o texto **verbatim** — ele vai pra
`reqs/` no modo delegar (não gravar ainda).

### 2. Contexto que já existe na Biblioteca

```bash
grep -rl "^task: {id}" delegadas/ resumo/ task-code/   # já foi delegada? já mexi nisso?
ls reqs/{id}-*                                         # REQ já salvo?
```

Já existe delegada ativa pra essa task → mostrar e perguntar se é
reatribuição ou nova rodada, nunca criar segunda delegada da mesma task.
`resumo/` de task parecida é ouro pra "Causa provável" — citar.

### 3. Investigação de código (sem tocar no repo)

Repos em `reposBasePath`. Ler sempre a branch base, não a que estiver
checada out:
`git -C <repo> fetch origin <base> --quiet`, depois
`git -C <repo> grep -n "<termo>" origin/<base>` /
`git -C <repo> show origin/<base>:<path>`. Nunca `checkout`/`switch`/`stash`.

Seguir o fluxo de ponta a ponta (tela → chamada HTTP → rota → regra de
negócio → acesso a dado) até achar **onde** o comportamento nasce. Se a
mudança cai em regra de negócio que o repo cobre com teste unitário, "spec
obrigatória" entra em Atenção.

### 4. Dificuldade e tempo

Estimativa pra um dev pleno que ainda não conhece o trecho:

| Dificuldade | Tempo | Sinal típico |
|---|---|---|
| Baixa | 1-2h | 1 camada, 1-2 arquivos, causa clara |
| Baixa a média | 2-4h | causa clara, 2 camadas ou teste pra atualizar |
| Média | 4-8h | 2+ camadas, regra de negócio a confirmar, query nova |
| Média a alta | 1-2 dias | migration, vários módulos, dado legado |
| Alta | 2+ dias | arquitetura nova, decisão de produto em aberto, risco em produção |

Dúvida de produto em aberto sempre aparece em **Atenção** e sobe a
dificuldade — não decidir pelo PO.

### 5. Saída no chat (formato fixo)

Uma tabela por bloco de até 3 tasks (uma coluna por task, cabeçalho
`{id}: {título curto}`), linhas sempre nesta ordem:

```markdown
|  | 1024: Exportar Excel | 1025: Filtro por período |
|---|---|---|
| **Tela** | Vendas > Resumo > Exportar | Vendas > Pedidos > Filtros |
| **Repo** | `meu-app-frontend` (front) | `meu-app-backend` (back) |
| **Causa provável** | Botão lê `storeId` da URL, mas o filtro grava `stores`... | `formatWithTime()` em `orders.service.ts` troca a hora... |
| **Atenção** | Testar as 4 abas | Registro que cruza meia-noite fica de fora (alinhar com o PO). Spec obrigatória |
| **Dificuldade** | Baixa (1-2h) | Baixa a média (2-4h) |
```

Depois da(s) tabela(s), por task:

```markdown
**1024 — Onde mexe:**
- Front: `summary/export-button.tsx` (ler `stores` em vez de `storeId`).

**Escopo:** entra X; fora Y.
```

Regras: nomes reais (arquivo, função, campo, endpoint), nunca "ajustar o
componente". "Causa provável" é hipótese com evidência, não certeza. Sem
solução pronta em código — o dev resolve; a análise aponta o caminho.

### 6. Quem pegou?

Perguntar por task, com opções: devs do `devs.json` (pelo `nome`) +
**"Ainda não atribuir"** + **"Eu mesmo"**.

- Dev escolhido → modo delegar com `status: in_progress`.
- "Ainda não atribuir" → modo delegar com `status: draft` e sem `dev:`
  (card na coluna "Sem dev").
- "Eu mesmo" → não cria delegada; seguir o fluxo normal do `CLAUDE.md`
  do usuário, reaproveitando a análise como ponto de partida.

---

## Modo delegar

1. Invocar `controle-documentacao`.
2. `reqs/{id}-{slug}.md` — REQ + item técnico + `## Parent` verbatim (se
   ainda não existe).
3. `delegadas/{id}-{slug}.md` a partir de `_templates/delegada.md`:
   - `number:` = "Proximo numero" do `INDEX.md`
   - `repo:` = todos os repos da análise, separados por espaço (único tipo
     da Biblioteca com mais de um repo nesse campo)
   - `dev:` = `id` do `devs.json`; `delegada_em:` = hoje
   - `dificuldade:`/`estimativa:` = os mesmos da tabela
   - `titulo_busca:` obrigatório (3-8 palavras, assunto)
   - `related:` = `reqs/{id}-{slug}.md`
   - Corpo: tabela `## Análise` (mesmas 5 linhas, **rótulos exatos**: Tela,
     Repo, Causa provável, Atenção, Dificuldade — o `time.html` lê por eles),
     `## Onde mexe`, `## Escopo`, `## Delegação`, `## PRs`, `## Review`,
     `## Anotações`.
4. **Não** criar `resumo/`, `task-code/` nem `task-planning/` pra delegada —
   a delegada é o único doc da task do lado de quem delega.
5. Rodar `sync-all.ps1`.
6. Entregar no chat uma **mensagem pronta pro dev**, tom formal, sem jargão
   da Biblioteca:

```markdown
**Task {id} — {título}** ({link do card})
**O que fazer:** {1-2 frases do objetivo}
**Onde olhar:** {bullets curtos do Onde mexe}
**Atenção:** {pontos}
**Estimativa:** {dificuldade} ({tempo})
```

Nunca enviar a mensagem — só entregar o texto.

---

## Modo revisar

Para cada link de PR:

1. `gh pr view <url> --json number,title,headRefName,body,author,state,url`.
2. **Achar a delegada:** id da task na branch (`/(\d{4,7})`), no título ou no
   corpo, depois `grep -l "^task: {id}" delegadas/*.md`.
   - Não achou → avisar ("PR sem task delegada na Biblioteca") e perguntar:
     revisar mesmo assim sem referência, ou analisar a task primeiro.
   - Autor do PR ≠ `github` do dev da delegada → mencionar (pode ser
     pareamento ou reatribuição não registrada).
3. **Montar a referência** (mostrar no chat, curta): Escopo (entra/fora),
   Onde mexe, Causa provável, Atenção, REQ (ler o arquivo em `reqs/`) e os
   findings `[Blocker]`/`[Convenção]` das rodadas anteriores em `## Review`.
4. **Revisar** — com a skill de review de PR do seu fluxo, se houver, ou
   direto pelo diff (`gh pr diff`). Somar sempre estas checagens:
   - PR cobre tudo de "Onde mexe"/critério do REQ? Falta camada (ex.: back
     feito, front não)? → `[Blocker]` se o REQ exige.
   - Mexe fora do Escopo? → `[Arquitetura]` (ou `[Blocker]` se arriscado).
   - Cada item de **Atenção** foi tratado?
   - Cada finding de rodada anterior: resolvido ou não — confirmar linha a
     linha contra o código atual.
   Comentar no GitHub só depois de "sim" explícito do usuário.
5. **Registrar a rodada** na delegada, em `## Review` (remover o placeholder
   `_Nenhuma rodada ainda._`):

```markdown
### Rodada N — YYYY-MM-DD — PR #123 (meu-app-frontend) — Ajustes solicitados

- **Resumo:** 3 findings — 1 Blocker, 2 Convenção, 0 Nit
- [Blocker] `volume-table.tsx:42` — agrupamento ignora registros inativos
- [Convenção] `summary.service.ts:88` — erro genérico em vez da exceção do projeto
- **Escopo vs delegada:** front ok, falta o DTO do back
- **Comentários:** postados no GitHub | não postados
```

   Veredito no título: **"Ajustes solicitados"** se houver Blocker/Convenção
   aberto, **"Aprovado"** se nenhum (o `time.html` lê essas palavras pra cor
   do card). Só Blocker/Convenção viram bullet; Nit fica no número do Resumo.
6. PR ainda não está no doc → adicionar a URL em `## PRs` e em `pr_pending`
   (o sweep do `sync-all` fecha a delegada sozinho quando todos os PRs
   mergeiam).
7. `updated:` = hoje, rodar `sync-all.ps1`.
8. **Deploy** — quando o PR já está `MERGED`: a partir do merge commit
   (`gh pr view <n> --json mergeCommit,baseRefName`), conferir os runs do
   commit (`gh run list -R <repo> --commit <sha>`) e os status
   (`gh api repos/<repo>/commits/<sha>/status`). OK = deploy do ambiente em
   `success`; `failure` → `gh run view <id> --log-failed` e citar a linha
   decisiva. Run ainda rodando → dizer isso, nunca supor o resultado.
   Resultado vai no chat e como bullet `- **Deploy:** ...` na rodada.

---

## Modo atualizar

Edição pontual, sem fluxo de criação: anotação (`## Anotações`, bullet com
data), reatribuição (trocar `dev:` + `- DD/MM: reatribuída de X para Y —
motivo`), cancelamento (`status: archived` + anotação com motivo). Conclusão
normal **não** é manual — o sweep de PR fecha. Sempre `sync-all.ps1` no fim.

**Assumida por quem delegou** ("eu peguei a X"): a task deixa de ser
delegada e vira trabalho próprio.

1. `status: superseded` (some do `time.html`; o sweep não reabre doc
   `superseded`/`archived`), `dev:` removido se houver.
2. `## Anotações`: `- DD/MM: assumida por quem delegou — segue fluxo próprio, delegada substituída.`
3. Seguir o fluxo normal do `CLAUDE.md`, reaproveitando `## Análise`/
   `## Onde mexe`. Depois de criar os docs próprios, acrescentar
   `task-code/...` e `resumo/...` em `related:` da delegada.
4. **Nunca** cadastrar o próprio usuário no `devs.json` — dev cadastrado
   vira coluna no `time.html`; o trabalho próprio aparece no dashboard
   principal.

## Regras

- Nunca editar código, trocar branch, commitar ou abrir PR em repo de projeto.
- Nunca escrever no rastreador de tarefas.
- Nunca editar `devs.json` à mão — dev novo é pelo "+ Dev" do `time.html`
  (se o usuário pedir no chat, passar o comando:
  `powershell -ExecutionPolicy Bypass -File scripts/time-dev.ps1 -NomeB64 <base64 do nome> -Github <login>`).
- Tabela no chat **antes** de gravar qualquer arquivo; gravação só depois de
  saber o dev (ou "ainda não atribuir").
- Uma delegada por task. Task que volta do QA com o mesmo dev = nova rodada
  em `## Review`/`## Anotações`, não doc novo.
