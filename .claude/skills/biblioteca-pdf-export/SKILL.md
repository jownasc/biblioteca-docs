---
name: biblioteca-pdf-export
description: Exporta documentos markdown da Biblioteca pessoal de documentação técnica (task-code/, task-planning/, testes/, handover-tecnico/, reqs/, resumo/, cada .md com frontmatter YAML: number, type, status, repo, task, author, updated, titulo_busca, function, pr_merged/pr_pending) para PDF em tema escuro, na paleta real do dashboard da Biblioteca. Use sempre que o usuário pedir para "exportar pra PDF", "gerar PDF", "converter documento da Biblioteca", "mandar handover pro PO" ou mencionar um número de task/arquivo da Biblioteca junto com PDF. Também use proativamente quando o usuário disser que vai compartilhar um `handover-tecnico` ou `testes` com alguém fora do time técnico.
license: Personal use
---

# Biblioteca PDF Export

Converte um documento markdown da Biblioteca (frontmatter YAML padrão) para
PDF em tema escuro, replicando a paleta real do dashboard. Roda 100% local
via CLI — sem enviar nada pra fora.

## Motor: Edge (Chromium) headless

Desde 2026-10-07 o PDF sai do Edge em modo headless (`--print-to-pdf`), que
já vem instalado em todo Windows. O script procura `msedge`, depois Chrome.

Por que trocou do `wkhtmltopdf` (WebKit de 2012):

- **Margem só na página 1.** A margem nativa do wkhtmltopdf sai branca; para
  manter o fundo escuro até a borda era preciso margem 0 e simular o respiro
  com `padding` do `body`, que só existe na primeira página. No Chromium,
  `box-decoration-break: clone` repete o `padding` em cada página.
- **Sem regras modernas de paginação.** `break-after`, `orphans`/`widows` e
  `:has()` eram ignorados, então manter título/texto/figura juntos dependia
  de regex no HTML. No Chromium é CSS nativo.
- **Fundo até o fim da última página** exigia renderizar até 3 vezes e medir
  o PDF com poppler. No Chromium o fundo do `html` cobre a folha inteira.

`weasyprint` segue descartado: falha ao carregar `libgobject` no Windows
mesmo com o runtime GTK3 oficial (testado em 2026-09-11, 2 instaladores).

Versão anterior (wkhtmltopdf) no histórico git da Biblioteca.

## Dependências — não checar antes de converter

Python (`pyyaml`), pandoc e Edge/Chrome. **Ir direto pra "Uso"** — não rodar
`winget install`, `pip install` nem verificação de versão antes de
converter. Só diagnosticar se a conversão falhar de verdade (ver o fim).

## Uso

```powershell
python ".claude\skills\biblioteca-pdf-export\scripts\convert_to_pdf.py" <caminho\do\documento.md> [caminho\de\saida.pdf]
```

(path relativo à raiz da Biblioteca — a skill mora no próprio repo.)

Sem `caminho\de\saida.pdf`, o PDF vai pra `Biblioteca\exportacoes\`, mesmo
nome do `.md` de origem. `exportacoes/` é versionada no git da Biblioteca e
não é escaneada pelo `sync-all.ps1`.

```
(motor: Edge headless)
OK: C:\...\exportacoes\108364-metricas-reativacao.pdf
```

## Opções por documento (frontmatter)

**Padrão: A4 retrato, sem capítulos** — o mesmo formato de sempre.

**Paisagem automática:** se o `.md` tem pelo menos um print de tela largo
(imagem local com 1000px ou mais de largura e proporção de 1,3 ou mais), o
documento inteiro sai em paisagem — em retrato o print fica pequeno demais
para ler. O motor não mistura orientação por página.

| Campo | Efeito |
|---|---|
| `pdf_orientation: landscape` | Força paisagem (quando o usuário pedir, mesmo sem imagem). |
| `pdf_orientation: portrait` | Força retrato, mesmo com prints largos (desliga a regra automática). |
| `pdf_chapters: true` | Cada `##` (h2) começa em página nova, como seção primária em ABNT. O primeiro h2 não quebra, para o cabeçalho não ficar sozinho. Só quando pedido. |

Quando o usuário pedir "muda para paisagem/retrato" ou "capítulo em página
nova", gravar o campo correspondente no frontmatter do `.md` (o pedido vale
para os próximos exports do mesmo doc) e regerar.

## Formatação (inspirada na ABNT, sem rigidez)

- **Margens em todas as páginas**: 20mm em cima, 18mm nas laterais e embaixo.
- **Hierarquia de espaço**: mais respiro antes de um título do que depois;
  título nunca fica sozinho no pé da página (`break-after: avoid`).
- **Parágrafos**: sem linha órfã ou viúva (`orphans`/`widows: 3`).
- **Figuras**: `![Legenda](img/...)` com caminho relativo ao `.md` (o script
  converte para `file:///`). Saem numeradas, com "Figura N — Legenda" acima
  da imagem, legenda e imagem centralizadas, com respiro em volta e nunca
  partidas. O parágrafo imediatamente anterior fica na mesma página da
  figura. Em paisagem toda figura tem a **mesma altura (112mm)**, inclusive
  capturas de resolução menor; em retrato ocupa a largura total (teto de
  150mm). Título + parágrafo + figura precisam caber numa página (~172mm
  úteis em paisagem): se não couberem, o bloco inteiro vai para a próxima e
  sobra espaço na anterior — nesse caso encurte o texto antes da figura.
- **Tabelas**: quebram entre linhas (nunca no meio de uma linha) e repetem o
  cabeçalho na página seguinte.
- **Página nova manual**: `<div class="page-break"></div>` numa linha própria
  do `.md`. Invisível no markdown renderizado.

## Como funciona

1. Lê o frontmatter YAML (`number`, `type`, `status`, `repo`, `task`,
   `author`, `updated`, `titulo_busca`, `function`, `pr_merged`,
   `pr_pending`, `pdf_orientation`, `pdf_chapters`).
2. Remove `<!-- badge:auto -->`, `<!-- meta:auto -->` e
   `<!-- related:auto -->` do corpo (gerados pelo `sync-header.ps1`).
3. Cor de destaque por `type` — as mesmas cores dos chips do dashboard
   (`TYPE_ACCENT`).
4. Título do PDF: `titulo_busca` em destaque com `function` como subtítulo;
   sem `titulo_busca`, `function` vira o título.
5. `<title>` do PDF = nome do `.md` sem extensão.
6. Corpo convertido via `pandoc --from=markdown+pipe_tables+fenced_code_blocks --to=html5`.
7. HTML gravado numa pasta temporária e impresso pelo Edge headless com
   perfil próprio (`--user-data-dir`), para não se anexar ao navegador aberto.

### Cores por tipo (`TYPE_ACCENT` no script — mesmas do dashboard)

| type | cor |
|---|---|
| `task-code` | dourado `#d9b568` |
| `task-planning` | teal `#7cbfc4` |
| `testes` | verde `#86b894` |
| `handover-tecnico` | rosa `#c184a0` |
| `rules` | marrom `#a89484` |
| `reqs` | azul `#6f9bd1` (sem chip no dashboard — cor própria) |
| `resumo` | roxo `#9a83c9` (sem chip no dashboard — cor própria) |

Tipo sem entrada em `TYPE_ACCENT` cai no dourado padrão (`DEFAULT_ACCENT`).

## Ajustar depois

- **Espaçamento**: `margin` de `p`, `h2`, `h3`, `figure` em `css()`.
- **Margens da página**: `padding` do `body` em `css()` (não usar margem do
  `@page`, que sai branca).
- **Novo tipo de documento**: somar entrada em `TYPE_ACCENT`.

## Problemas conhecidos

- Emoji: só `✅`/`❌`/`⚠️` têm tratamento (viram `✔`/`✘`/`⚠` coloridos).
- `pr_pending` aparece como "(pendente)" na linha de PRs, sem badge próprio.
- Bloco maior que uma página (figura muito alta, `pre` enorme) não tem como
  ficar inteiro; o motor quebra onde der.
- Sem número de página (o Edge headless roda com `--no-pdf-header-footer`).

## Diagnosticar (só se a conversão falhar de verdade)

```powershell
python --version
pandoc --version
python -c "import yaml; print('pyyaml OK')"
Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
```

Instalar o que faltar:

```powershell
winget install --id Python.Python.3.12 -e
winget install --id JohnMacFarlane.Pandoc -e
python -m pip install pyyaml
```
