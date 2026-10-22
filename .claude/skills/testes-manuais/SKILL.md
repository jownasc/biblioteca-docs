---
name: testes-manuais
description: >-
  Monta, executa com o usuario e registra testes manuais de uma task — de API
  (Insomnia/Postman/curl) ou de tela (localhost) — na secao Testes manuais do
  doc testes/ da Biblioteca. Use apos implementar endpoint, tela ou fluxo, ou
  antes de entregar PR. Aciona controle-documentacao — um doc testes/ por task,
  nunca arquivo separado.
---

# Testes manuais (API e tela)

## Quando usar

- Endpoint novo ou alterado (status HTTP, body, headers)
- Tela/fluxo novo ou alterado (comportamento, formulario, listagem,
  permissao, traducao)
- Evidencia de teste pra PR

## Fluxo obrigatorio

1. **Gate — checklist no chat, bloqueia os passos 2-5:** listar os cenarios
   num bloco dedicado, sozinho, na mensagem atual (`✅` pro que ja foi
   confirmado, `🟡 Pendente:` pro que falta), agrupado por REQ/criterio de
   aceite. O usuario testa a partir dessa lista no chat, nunca a partir do
   doc da Biblioteca. Escrever ou atualizar o doc em `testes/` **antes**
   desse bloco aparecer na conversa e' a violacao mais comum deste fluxo —
   ter o roteiro pronto mentalmente nao conta como "exibido".
2. Usuario executa (ambiente local ou o combinado) e reporta o resultado de
   cada item.
3. Atualizar ou criar **um** doc em `testes/` da Biblioteca (tipo `testes`,
   template `_templates/testes.md`) via `controle-documentacao` — grava o
   resultado ja confirmado, nao a lista do que testar.
4. Rodar `scripts/sync-all.ps1` da Biblioteca.
5. Commit/entrega so' depois que o usuario confirmar que os testes manuais
   passaram (se o seu fluxo tiver esse gate). Testes OK + usuario fecha a
   entrega → `status: completed` (gatilho do `controle-documentacao`).

**Nao** criar `test-manual-*` separado. **Nao** editar `INDEX.md` nem a
tabela de metadados a mao.

## Secao Testes manuais — API

| # | Metodo | Path | Objetivo |
|---|--------|------|----------|

| # | Teste | Esperado | Real (status + body) | OK? |
|---|-------|----------|----------------------|-----|

Headers/ambiente usados (token, idioma, tenant etc.) num bloco `http` logo
abaixo — sem valor real de token/segredo, so' o nome do header.

## Secao Testes manuais — tela

Pre-requisito: lint e build do projeto passando antes de pedir o teste.

| # | Acao | Comportamento esperado |
|---|------|------------------------|

| # | Teste | Esperado | Observado | OK? |
|---|-------|----------|-----------|-----|

## Apos documentar

- [ ] `related` aponta pro `task-planning/` e, se houver, `handover-tecnico/` da task
- [ ] `sync-all.ps1`
- [ ] `status: completed` quando a entrega fechar
