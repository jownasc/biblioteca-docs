---
number: NN
type: delegada
status: in_progress
repo: meu-app-backend meu-app-frontend
task: 000000
function: Resumo de uma linha do problema/demanda
titulo_busca: Titulo curto com palavras-chave
dev: id-do-dev
dificuldade: Baixa a média
estimativa: 2-4h
delegada_em: YYYY-MM-DD
related:
  - reqs/000000-slug.md
updated: YYYY-MM-DD
author: —
---
# 000000: Titulo curto

## Análise

| Campo | Valor |
|---|---|
| Tela | Módulo > Página > Aba |
| Repo | `meu-app-backend` (back) + `meu-app-frontend` (front) |
| Causa provável | O que o código faz hoje e por que gera o problema — com nomes reais de arquivo/função/campo |
| Atenção | Riscos, decisões pendentes com o PO, spec obrigatória, efeito colateral |
| Dificuldade | Baixa a média (2-4h) |

## Onde mexe

- **Back:** `arquivo.service.ts` (o que mudar) e o DTO `NomeDoDto`.
- **Front:** `arquivo.tsx` (o que mudar).

## Escopo

- **Entra:** o que a entrega precisa cobrir (critério de aceite do REQ).
- **Fora:** o que não deve ser mexido nesta task.

## Delegação

- **Dev:** Nome (@login)
- **Delegada em:** DD/MM/YYYY
- **REQ:** `reqs/000000-slug.md`

## PRs

_Nenhum PR ainda._

## Review

_Nenhuma rodada ainda._

## Anotações
