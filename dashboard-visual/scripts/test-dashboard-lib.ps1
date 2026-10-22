# Auto-check das funcoes puras de dashboard-lib.ps1 (ponytail: assert
# executavel, sem framework). Cobre a logica de dado/comando do gerador
# do dashboard - a parte onde um bug de fato corrompe ou quebra algo, nao
# o HTML/CSS/JS de UI (isso exigiria DOM/browser, fora de escopo aqui).
$hubRoot = 'C:\teste-fake-hub'
. (Join-Path $PSScriptRoot 'dashboard-lib.ps1')

$failures = @()
function Assert($cond, [string]$label) {
    if (-not $cond) { $script:failures += $label }
}

# Esc
Assert ((Esc '<a href="x">&</a>') -eq '&lt;a href=&quot;x&quot;&gt;&amp;&lt;/a&gt;') 'Esc: escapa & < > "'
Assert ((Esc $null) -eq '') 'Esc: null vira string vazia'
Assert ((Esc 'texto simples') -eq 'texto simples') 'Esc: texto sem caractere especial fica igual'

# Get-Signals
$docsComPr = @(
    [PSCustomObject]@{ Body = 'ver https://github.com/org/repo/pull/12 e mais texto' }
    [PSCustomObject]@{ Body = 'mesmo link de novo: https://github.com/org/repo/pull/12' }
    [PSCustomObject]@{ Body = 'outro PR https://github.com/org/repo2/pull/34, sem link nenhum aqui' }
)
$signals = Get-Signals $docsComPr
Assert (@($signals.PRs).Count -eq 2) 'Get-Signals: deduplica o mesmo link de PR'
Assert (@($signals.PRs) -contains 'https://github.com/org/repo/pull/12') 'Get-Signals: acha o link do 1o PR'
Assert (@($signals.PRs) -contains 'https://github.com/org/repo2/pull/34') 'Get-Signals: acha o link do 2o PR'

$signalsVazio = Get-Signals @([PSCustomObject]@{ Body = 'nada de PR aqui' })
Assert (@($signalsVazio.PRs).Count -eq 0) 'Get-Signals: corpo sem link de PR retorna lista vazia'

# Get-LaunchUri
Assert ((Get-LaunchUri 'echo oi') -eq ('biblioteca-cmd-run:' + [Uri]::EscapeDataString('echo oi'))) 'Get-LaunchUri: esquema biblioteca-cmd-run'

# Get-CardCommands - regressao do fix do apostrofo em Task/Repo (item #2
# da auditoria de 2026-08-24: sem escape, um apostrofo fechava a string
# PowerShell cedo e quebrava o comando gerado).
$cardComApostrofo = [PSCustomObject]@{ Active = $true; Task = "104691"; Repo = "o'brien-app" }
$cmds = Get-CardCommands $cardComApostrofo
$resumeCmd = ($cmds | Where-Object { $_.Label -eq 'Retomar task' }).Cmd
Assert ($resumeCmd -match "no repo o''brien-app") 'Get-CardCommands: apostrofo em Repo vem escapado (dobrado) no comando'
Assert ($resumeCmd -notmatch "no repo o'brien-app'`"") 'Get-CardCommands: apostrofo cru NAO aparece sem escape (nao fecha a string cedo)'

$cardSemAtivo = [PSCustomObject]@{ Active = $false; Task = '999'; Repo = 'repo-normal' }
$cmdsSemAtivo = Get-CardCommands $cardSemAtivo
Assert (@($cmdsSemAtivo | Where-Object { $_.Label -eq 'Retomar task' }).Count -eq 0) 'Get-CardCommands: card inativo nao gera "Retomar task"'
Assert (@($cmdsSemAtivo | Where-Object { $_.Label -eq 'Reabrir p/ QA' }).Count -eq 1) 'Get-CardCommands: "Reabrir p/ QA" sempre presente'

# Get-RepoSortKey
$backend = Get-RepoSortKey 'acme-app-settings-backend'
$frontend = Get-RepoSortKey 'acme-mfe-settings'
Assert ($backend.Bucket -eq 0 -and $frontend.Bucket -eq 0) 'Get-RepoSortKey: backend/mfe com padrao de dominio ficam no Bucket 0'
Assert ($backend.Domain -eq 'settings' -and $frontend.Domain -eq 'settings') 'Get-RepoSortKey: backend/mfe do mesmo dominio (settings) ficam com o mesmo Domain (adjacentes na ordenacao)'
Assert ($backend.SubOrder -lt $frontend.SubOrder) 'Get-RepoSortKey: backend vem antes do mfe dentro do mesmo dominio'
Assert ((Get-RepoSortKey 'app-settings-backend').Domain -eq 'settings') 'Get-RepoSortKey: prefixo de org e opcional'

$alias = Get-RepoSortKey 'acme-mfe-schedule' @() @{ 'schedule' = 'scheduling' }
Assert ($alias.Domain -eq 'scheduling') 'Get-RepoSortKey: repoAliases junta dominio do front com o do back'

$pessoal = Get-RepoSortKey 'Minhas-Skills' @('minhas-skills')
Assert ($pessoal.Bucket -eq 2) 'Get-RepoSortKey: repo em reposAoFim cai no Bucket 2 (sempre por ultimo, sem diferenciar caixa)'

$desconhecido = Get-RepoSortKey 'algum-repo-sem-padrao'
Assert ($desconhecido.Bucket -eq 1) 'Get-RepoSortKey: repo sem padrao conhecido cai no fallback Bucket 1'

# Get-DelegadaField / Get-DelegadaReview (time.html) - corpo no formato do
# _templates/delegada.md; acento via codepoint (este .ps1 nao tem BOM).
$ccedil = [char]0x00E7; $atilde = [char]0x00E3; $aacute = [char]0x00E1; $otilde = [char]0x00F5
$bodyDeleg = @"
## An${aacute}lise

| Campo | Valor |
|---|---|
| Tela | Mar > Relatorio |
| **Causa prov${aacute}vel** | ``volume-table.tsx`` exibe ``item.basement`` |
| Aten${ccedil}${atilde}o | Spec obrigatoria |

## Review

### Rodada 1 - 2026-10-01 - PR #1 - Ajustes solicitados

- **Resumo:** 2 findings - 1 Blocker

### Rodada 2 - 2026-10-02 - PR #1 - Aprovado

- **Resumo:** 0 findings

## Anota${ccedil}${otilde}es
"@
Assert ((Get-DelegadaField $bodyDeleg 'Causa') -eq '`volume-table.tsx` exibe `item.basement`') 'Get-DelegadaField: le valor de linha com rotulo em negrito e acento'
Assert ((Get-DelegadaField $bodyDeleg 'Aten') -eq 'Spec obrigatoria') 'Get-DelegadaField: casa por prefixo ASCII do rotulo'
Assert ((Get-DelegadaField $bodyDeleg 'Dificuldade') -eq '') 'Get-DelegadaField: rotulo ausente retorna vazio'
$rev = Get-DelegadaReview $bodyDeleg
Assert ($rev.Count -eq 2 -and $rev.Verdict -eq 'aprovado' -and $rev.Resumo -eq '0 findings') 'Get-DelegadaReview: usa a ULTIMA rodada (veredito + resumo dela, nao da 1a)'
Assert ($null -eq (Get-DelegadaReview '## Review')) 'Get-DelegadaReview: sem rodada retorna null'

if ($failures.Count -gt 0) {
    Write-Host "test-dashboard-lib: $($failures.Count) falha(s):" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
Write-Host 'test-dashboard-lib: ok (23 casos).'
