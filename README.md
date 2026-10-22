# 📚 Biblioteca

**An original, zero-dependency, local-first task lifecycle and technical documentation platform driven by Git and AI agents.**

![Windows](https://img.shields.io/badge/platform-windows-0078D6?logo=windows&logoColor=white)
![Local-first](https://img.shields.io/badge/local--first-100%25-2ea44f)
![Zero deps](https://img.shields.io/badge/dependencies-zero-6b5628)
![License MIT](https://img.shields.io/badge/license-MIT-blue)

A memória e governança de todo o seu trabalho de engenharia, a um clique — sem abrir repo por repo, sem procurar arquivos.

Spec, plano, teste e handover de cada task, num dashboard visual gerado a partir de Markdown puro versionado em Git. Sem banco de dados pesado, sem servidor em background, sem etapa de build complexa. O agente de IA escreve e audita os documentos; o engenheiro governa e navega.

> *Telas com dados fictícios ilustrativos.*

---

## 🖥️ O Dashboard Visual

Uma página HTML estática, salva diretamente nos favoritos do navegador:

![Tasks ativas — card expandido com pendências, PRs por estado e comandos](docs/screenshots/dashboard-ativas.png)

- **Estado Real do PR e do Git:** Verde para aberto, roxo para mergeado, vermelho para fechado (reconciliado via GitHub CLI `gh`).
- **Pendências no Card:** Status de bloqueio e dependências mapeados direto no documento.
- **Botões de Ação com Comandos Prontos:** Retomar branch, reabrir para QA e comandos de terminal gerados automaticamente.

![Tasks completas — grade compacta com busca](docs/screenshots/dashboard-completas.png)

- **Busca Instantânea:** Filtro em tempo real por task, repo ou descrição com favoritos fixados no topo.

![Página de resumo — status, implementação, REQs, testes e tasks relacionadas](docs/screenshots/resumo-completo.png)

---

## 🛡️ O Quality Gate (Verificação Pré-PR & Evidências)

Diferente de fluxos onde testes são apenas mocks teóricos, a Biblioteca estabelece um **Quality Gate determinístico antes de abrir qualquer Pull Request**:

```
[task-code] ──> [task-planning] ──> [Implementação] ──> [Quality Gate] ──> [PR & Handover]
(Requisito)       (Plano Ativo)        (Código/Testes)    (HTTP/UI Live)    (Merge & Docs)
```

1. **Testes Unitários & Contratos:** Mapeados e consolidados em `testes/`.
2. **Validação Ativa de Endpoints HTTP:** Execução de requisições reais nos endpoints criados/alterados para validação de payloads JSON, headers e status codes (garantindo que o contrato backend não quebre o frontend).
3. **Inspeção de UI & Captura de Evidências:** Navegação e verificação de fluxo de ponta a ponta, capturando screenshots determinísticos e logs de rede anexados ao artefato da task.
4. **Auditoria Humana:** Nenhuma branch é promovida sem a revisão e aprovação explícita das evidências pelo engenheiro responsável.

---

## 📂 Estrutura do Ciclo de Vida da Task

Cada entrega gera arquivos `.md` com frontmatter YAML estrito em pastas dedicadas:

| Tipo | Papel no Ciclo de Vida |
|------|------------------------|
| `task-code/` | Card da tarefa, escopo da entrega e especificação da branch |
| `task-planning/` | Plano de execução em fases (`plan_active` rastreia o passo atual) |
| `progresso/` | Estado de trabalho volátil — desenhado para **sobreviver a quedas de sessão de IA** |
| `testes/` | Critérios de aceitação, testes unitários, validações HTTP e evidências |
| `handover-tecnico/` | Documentação definitiva de longo prazo: playbooks, contratos e troubleshooting |
| `resumo/` | Visão atômica factual que alimenta os cards e filtros do dashboard |
| `reqs/` | Requisitos originais do rastreador de tarefas (referência bruta) |

A sincronização e regeneração do índice são feitas por scripts PowerShell nativos:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/sync-all.ps1
```

---

## 🛠️ Skills & Automação de Agentes

Inclui ferramentas prontas para integração com agentes de IA (Claude Code / DevTools):

| Skill | Papel |
|-------|-------|
| `controle-documentacao` | Gate pra criar/editar qualquer doc (template, status, sync) |
| `biblioteca-setup` | Cadastro guiado na primeira sessão |
| `importar-historico-github` | Gera `resumo/` a partir dos seus PRs no GitHub |
| `biblioteca-pdf-export` | Converte um doc em PDF no tema do dashboard (pra mandar pra PO/QA) |
| `testes-manuais` | Monta e registra o roteiro de teste manual (API ou tela) no doc `testes/` da task |
| `mock-completo` | Garante que dado mockado pra teste local cubra o fluxo inteiro da task |
| `delegar-task` | Analisa uma task, passa pra outro dev, acompanha PRs e registra o review (página **Time**) |
| `evidencia-imagem` | Monta um PNG de evidência (prints + destaques + regras) em `exportacoes/` |
| `task-hub-resume` / `task-hub-qa` | Acionadas pelos botões do dashboard |

Ficam em `.claude/skills/` e `dashboard-visual/.claude/skills/`. As que
fazem sentido fora da Biblioteca (todas menos `biblioteca-setup`,
`importar-historico-github` e `task-hub-*`) também viram globais
(junction em `~/.claude/skills`, feito no setup).

### E o fluxo de desenvolvimento?

A Biblioteca não traz skills de triagem, plano, TDD, review ou git — ela
se pluga em qualquer fluxo. O contrato é a tabela **Gatilhos automáticos**
do `controle-documentacao`: evento do fluxo (plano aprovado, testes
rodados, PR aberto, task fechada) → o que atualizar na Biblioteca. Funciona
com o fluxo do seu `CLAUDE.md`, com um público como o
[superpowers](https://github.com/obra/superpowers), ou sem fluxo nenhum.

A página **Time** é opcional: crie a pasta `delegadas/` (ou deixe a skill
`delegar-task` criar na primeira delegação) pra ela aparecer no header.

---

## ⚠️ Limitações

- **Só Windows** (scripts `.ps1`).
- **Um usuário, local** — favoritos ficam no `localStorage` do navegador.
- **Cores de PR exigem `gh` autenticado**; sem ele os pills ficam cinza.
- **Opcionais:** Azure DevOps (`azureOrgUrl` no config), protocolo
  `biblioteca-cmd-run:` (`register-protocol.ps1`, sem ele os botões só
  copiam pro clipboard) e MCP `azure-devops` (somente leitura).

---

## ⚙️ Filosofia de Design (First Principles)

- **Local-first & Zero-dependency:** Funciona offline, rápido, sem depender de banco de dados, containers ou serviços externos de terceiros.
- **Token & Context Optimization:** A divisão em templates atômicos reduz drasticamente o consumo de tokens e elimina o risco de alucinação por poluição de contexto.
- **Engenharia sob Controle:** A IA automatiza a digitação e a estrutura; o engenheiro define a arquitetura, valida os testes e aprova as entregas.

---

## 📄 Licença

Distribuído sob a licença [MIT](LICENSE). Desenvolvido por **[Jonathan Nascimento](https://github.com/jownasc)**.
