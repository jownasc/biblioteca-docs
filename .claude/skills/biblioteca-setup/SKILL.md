---
name: biblioteca-setup
description: >-
  Instalacao guiada da Biblioteca num computador novo. Dispara automaticamente quando
  `biblioteca.config.json` NAO existe na raiz deste repo (primeira sessao apos clonar).
  Faz 3 perguntas curtas, grava o config e roda o sync inicial. Use tambem se o usuario
  pedir explicitamente "configurar a biblioteca" ou "instalar a biblioteca".
---

# biblioteca-setup

## Quando disparar

No inicio de QUALQUER sessao neste repo: checar se `biblioteca.config.json`
existe na raiz. Se não existir, essa é a primeira coisa a fazer — antes de
qualquer outra skill (`controle-documentacao`, `task-hub-*`), porque elas
todas dependem desse arquivo pra funcionar direito.

Se já existir, não fazer nada (não perguntar de novo, não reconfigurar
sozinho — se o usuário quiser mudar algo depois, é edição manual do JSON ou
pedido explícito de "reconfigurar").

## As 3 perguntas (nessa ordem, uma de cada vez — não despeje as 3 juntas)

**1. Nome**

> "Antes de começar: qual seu nome? Vai aparecer como autor nos documentos
> que você criar."

Guarda em `author`.

**2. Onde ficam os repositórios dos seus projetos**

> "Onde no seu computador ficam as pastas dos projetos que você vai
> documentar? (ex.: `C:\Users\voce\Documents\Repo`). É onde os comandos de
> 'retomar task' vão entrar automaticamente."

Guarda em `reposBasePath`. Aceitar o path como veio (não validar
existência agressivamente — a pasta pode ainda não existir na hora da
instalação).

**3. Azure DevOps (opcional)**

> "Você usa Azure DevOps pra rastrear tasks? Se sim, cola o link de UMA
> task/work item existente (qualquer uma) que eu pego o resto sozinho. Se
> não usar Azure DevOps, só responde 'não' ou deixa em branco."

Se o usuário colar um link (formato
`https://dev.azure.com/{org}/{projeto}/_workitems/edit/{numero}` ou
variação próxima terminando em `/edit/<numero>` ou `/<numero>`): extrair
tudo ANTES do número final via regex — ex. de
`https://dev.azure.com/Acme/MeuProjeto/_workitems/edit/48213` extrai
`https://dev.azure.com/Acme/MeuProjeto/_workitems/edit` — e guarda em
`azureOrgUrl`.

Se o usuário disser que não usa, ou não colar nada: `azureOrgUrl` fica
`null`/ausente. A pill do Azure simplesmente não aparece em nenhum card —
não é um erro, é o comportamento esperado sem essa integração.

**Testar o MCP `azure-devops` com o link colado.** Se o usuário colou um
link, além de extrair `azureOrgUrl` por regex, chamar
`mcp__azure-devops__wit_work_item` (`action: get`, `id` extraído do link,
`expand: Relations`) pra confirmar que o MCP está conectado de verdade —
é o mesmo procedimento que o botão "+ Nova Task" do dashboard usa pra
buscar REQ/parent sozinho. Mostrar o resultado objetivo: "Achei: #{id} -
{título} (parent: #{parent}, se houver). Bateu?" Só ferramentas de leitura
(`wit_work_item` action `get`) — nunca `wit_work_item_write`/
`wit_work_item_comment_write`/`wit_work_item_link_write`/`wit_backlog`.
Se o MCP não estiver instalado/conectado nessa máquina, avisar que
`azureOrgUrl` ainda funciona sozinho (link direto nos cards), só o
preenchimento automático de REQ/parent do "+ Nova Task" fica indisponível
até o MCP ser configurado (`claude mcp add --scope user`, ver
`dashboard-visual/CLAUDE.md`) — não é bloqueante pro resto da
Biblioteca.

## Gravar o config

Criar `biblioteca.config.json` na raiz do repo:

```json
{
  "author": "{resposta 1}",
  "reposBasePath": "{resposta 2}",
  "azureOrgUrl": "{URL extraida da resposta 3, ou omitir o campo se nao usar}"
}
```

Esse arquivo é pessoal — já vem no `.gitignore` do repo, não commitar nem
sugerir commitar.

## Depois de gravar

1. Rodar `powershell -ExecutionPolicy Bypass -File scripts/install-global.ps1`
   — deixa a Biblioteca funcionando com o Claude aberto em **qualquer**
   repo (o uso normal é trabalhar no repo do projeto e gravar doc aqui):
   junction de `controle-documentacao`, `biblioteca-pdf-export`,
   `testes-manuais`, `mock-completo`, `delegar-task` e `evidencia-imagem` em
   `~/.claude/skills`, hooks globais em `~/.claude/settings.json` (sync
   após gravar doc, backup de plano em `planos/`; faz backup `.bak-*` do
   settings antes) e o guard de pre-commit. Idempotente.
   Avisar o usuário: os hooks só valem a partir da **próxima** sessão do
   Claude Code.
2. Rodar `powershell -ExecutionPolicy Bypass -File scripts/sync-all.ps1`
   e confirmar que rodou sem erro (lint-clusters ok, dashboard gerado).
3. **Abrir o dashboard sozinho no navegador** — não só avisar o usuário
   pra abrir manualmente (ele não deve precisar navegar até o arquivo):
   `Start-Process "dashboard-visual/dashboard.html"` (path
   relativo à raiz do repo — o handler default do Windows pra `.html` é o
   navegador). Depois, avisar: "Configurado — já abri o dashboard no
   navegador. Comece criando sua primeira task pela skill
   `controle-documentacao`." Se `Start-Process` falhar por qualquer motivo
   (máquina sem GUI, etc.), cair pro fallback de sempre: avisar o path do
   arquivo pra abrir manualmente.
4. Se o usuário já usa GitHub (`gh` autenticado), sugerir — sem perguntar
   nem bloquear, só mencionar: "Se você já resolveu tasks antes de existir
   a Biblioteca, rode a skill `importar-historico-github` pra povoar
   automaticamente um `resumo` por task a partir do seu histórico de Pull
   Requests — dá pra começar com o dashboard já populado em vez de vazio."

## O que essa skill NÃO faz

Não cria documentos, não explica os tipos de doc (isso é
`controle-documentacao` e `01-regras-biblioteca.md`) — só resolve a
configuração inicial de máquina/pessoa, uma vez.
