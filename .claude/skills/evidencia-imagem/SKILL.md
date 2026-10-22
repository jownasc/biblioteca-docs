---
name: evidencia-imagem
description: Monta uma imagem PNG de evidência para PO/QA/operação — prints reais (tela, relatório, anexo do card) com quadrados vermelhos, títulos por etapa ("Antes", "Depois") e uma lista de regras/observações — e salva em exportacoes/ da Biblioteca. Use SOMENTE quando o usuário pedir explicitamente ("monta a imagem de evidência", "print explicando o fix", "imagem com quadrado vermelho"). Não disparar sozinha ao fechar task.
---

# Imagem de evidência

Gera um PNG único, vertical, para quem não é técnico entender um fix ou um
comportamento: etapas numeradas com print real, quadrado vermelho no ponto que
importa e regras no rodapé. Saída **sempre** em
`<Biblioteca>/exportacoes/{task}-{slug}.png` (o script resolve a pasta sozinho).

Depende de Python 3 + Pillow (`pip install pillow`). Fontes: Segoe UI do
Windows (`C:/Windows/Fonts`).

## Fluxo

1. **Juntar evidências reais** — nunca inventar dado nem simular tela:
   - Print anexado no card do rastreador (ex.: Azure DevOps via MCP, só
     leitura) — baixar o anexo pra uma pasta temporária.
   - Tela de um ambiente: screenshot salvo em disco (navegador automatizado ou
     manual). Produção só leitura; nunca salvar formulário nem disparar ação
     que notifica terceiros.
   - Planilha/relatório: ler o arquivo e passar as linhas como `table` —
     mostra o dado real em vez de print borrado.
2. **Preferir produção** como exemplo. Sem dado em produção, usar outro
   ambiente e **dizer isso numa nota** (ambiente + id do registro).
3. **Localizar os quadrados com a grade — obrigatório, nunca chutar coordenada**:
   ```bash
   python "<pasta desta skill>/scripts/compose.py" --grid print.png   # gera print-grid.png, régua a cada 50px
   ```
   Abrir o `-grid.png` e ler x0,y0,x1,y1 no tamanho ORIGINAL. O script avisa
   área fora da imagem, mas não quadrado no lugar errado.
4. **Dado pessoal** (nome/e-mail de usuário, cabeçalho logado etc.) vai em
   `"blur"` — principalmente print de produção.
5. Escrever o `spec.json` numa pasta temporária (formato completo no topo de
   `scripts/compose.py`) e rodar:
   ```bash
   python "<pasta desta skill>/scripts/compose.py" spec.json
   ```
   Recursos: `"n"` em box/highlight/nota (selo ①② ligando destaque à regra),
   `{"row": [A, B]}` lado a lado (só com prints estreitos, < ~900px — o script
   avisa quando reduz demais), `header` da tabela opcional com `"fill"`. Texto
   quebra linha sozinho. Nome já existente vira `-v2`, `-v3` (nunca sobrescreve).
6. Abrir o PNG gerado e conferir: quadrados no lugar, texto legível, nada
   cortado, nenhum AVISO no stderr. Ajustar e regerar se precisar (apagar a
   versão errada, pra não sobrar `-v2` à toa).
7. Entregar só o caminho do arquivo + 1 linha do que ele mostra.

## Texto

- Para quem não é técnico: frases curtas, sem nome de tabela/arquivo/flag.
  Título = o que mudou; cada seção diz o que o print mostra ("Antes da
  correção: a coluna mostrava X").
- Seção "Antes" com `"alert": true` (título em vermelho).
- Rodapé "Regras": casos de borda em linguagem de negócio e de onde veio o
  exemplo.
- Tom profissional, sem "nós".

## Não fazer

- Não entregar a imagem fora de `exportacoes/`.
- Não usar dado de outro cliente/registro fora da task.
- Não registrar a imagem como doc (`sync-all` não indexa `exportacoes/`); só
  citar o caminho no `resumo` da task, se existir.
