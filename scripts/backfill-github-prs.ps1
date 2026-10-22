# Backfill de resumo/ a partir do historico de Pull Requests do usuario
# no GitHub - pra um usuario novo da Biblioteca (que ja resolveu tasks
# antes de existir a Biblioteca) comecar com um dashboard minimamente
# populado, sem precisar reescrever task-code/planning/testes de tudo.
#
# So' gera `resumo` (status/PR links) - e' o suficiente pro dashboard
# mostrar cards de verdade com pill de PR colorido. Sem dry-run (decisao
# do usuario): aplica direto, pula grupos (task+repo ou cluster+repo) que
# ja tem resumo. Sem ferramenta de limpeza pra entrada errada/duplicada
# ainda (fora de escopo, ver plano) - usuario esta ciente.
param(
    [string]$Org,
    [int]$Limit = 500
)

# Sem isso, titulo de PR com acento/reticencia unicode (gh devolve UTF-8)
# chega corrompido no ConvertFrom-Json - console assume o codepage padrao
# do Windows (nao UTF-8) pra decodificar o stdout do `gh`. Mesmo padrao
# ja usado em build-dashboard.ps1. Bug real, 2026-09-01: "marítimo" virou
# "mar├¡timo", reticencia unicode (…) virou "ÔÇª" em 2 titulos de PR
# diferentes - so' apareceu porque alguns titulos tinham char nao-ASCII.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$libScript = Join-Path $PSScriptRoot 'lib-doc.ps1'
. $libScript

$root = Get-LibRoot
$config = Get-BibliotecaConfig

if (-not $Org) { $Org = $config.githubOrg }
if (-not $Org) {
    Write-Host "backfill-github-prs: nenhuma org informada. Passe -Org <nome> ou grave 'githubOrg' em biblioteca.config.json." -ForegroundColor Yellow
    exit 1
}

$ghAvailable = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
if (-not $ghAvailable) {
    Write-Host "backfill-github-prs: 'gh' (GitHub CLI) nao encontrado no PATH." -ForegroundColor Yellow
    exit 1
}
$authCheck = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "backfill-github-prs: 'gh' nao esta autenticado - rode 'gh auth login' primeiro." -ForegroundColor Yellow
    exit 1
}

Write-Host "backfill-github-prs: buscando PRs de @me em '$Org' (limite $Limit)..."
$fields = 'number,title,url,repository,closedAt'
$merged = @()
$open = @()
try {
    $merged = gh search prs --owner $Org --author '@me' --merged --json $fields --limit $Limit | ConvertFrom-Json
} catch { Write-Host "backfill-github-prs: erro buscando PRs mergeadas - $_" -ForegroundColor Yellow }
try {
    $open = gh search prs --owner $Org --author '@me' --state open --json $fields --limit $Limit | ConvertFrom-Json
} catch { Write-Host "backfill-github-prs: erro buscando PRs abertas - $_" -ForegroundColor Yellow }

$allPrs = @()
foreach ($pr in $merged) { $allPrs += [PSCustomObject]@{ Number = $pr.number; Title = $pr.title; Url = $pr.url; Repo = $pr.repository.name; State = 'merged' } }
foreach ($pr in $open) { $allPrs += [PSCustomObject]@{ Number = $pr.number; Title = $pr.title; Url = $pr.url; Repo = $pr.repository.name; State = 'open' } }

Write-Host "backfill-github-prs: $($allPrs.Count) PR(s) encontrada(s) no total (mergeadas + abertas)."

# Classificacao do titulo em 3 trilhas, cada PR cai na primeira que bater -
# nenhuma delas "adivinha" um numero de task, so' organiza pelo que ja esta
# escrito no titulo:
#
# 1. Convencao de commitlint com id de task no escopo - "tipo(NNNNN): assunto" (ou
#    "tipo(NNNNN-slug): assunto") - vira task numerica de verdade.
# 2. Conventional commit generico com escopo nao-numerico - "tipo(scope):
#    assunto" (ex.: "fix(wagons): ...", quando o time nao usa numero de
#    task no escopo) - vira `task: general` + `cluster: {scope}`, agrupado
#    por scope+repo.
# 3. Sem escopo nenhum (ex.: "Develop", "Revert ...") - vira `task: general`
#    + `cluster: {titulo tal como veio}`, agrupado por titulo+repo (titulo
#    identico no mesmo repo cai no mesmo card - "card avulso por titulo").
$numericPattern = '^\w+\((\d+)(?:-[\w-]+)?\):\s*(.+)$'
$scopePattern = '^\w+\(([^\)]+)\):\s*(.+)$'

$taskGroups = @{}
$scopeGroups = @{}
$titleGroups = @{}

foreach ($pr in $allPrs) {
    if ($pr.Title -match $numericPattern) {
        $taskId = $Matches[1]
        $subject = $Matches[2].Trim()
        $key = "$taskId|$($pr.Repo)"
        if (-not $taskGroups.ContainsKey($key)) {
            $taskGroups[$key] = [PSCustomObject]@{ Repo = $pr.Repo; Task = $taskId; Cluster = $null; Kind = $null; Prs = New-Object System.Collections.Generic.List[object] }
        }
        $taskGroups[$key].Prs.Add([PSCustomObject]@{ Number = $pr.Number; Url = $pr.Url; State = $pr.State; Subject = $subject })
        continue
    }
    if ($pr.Title -match $scopePattern) {
        $scope = $Matches[1].Trim()
        $subject = $Matches[2].Trim()
        $key = "$scope|$($pr.Repo)"
        if (-not $scopeGroups.ContainsKey($key)) {
            $scopeGroups[$key] = [PSCustomObject]@{ Repo = $pr.Repo; Task = 'general'; Cluster = $scope; Kind = 'scope'; Prs = New-Object System.Collections.Generic.List[object] }
        }
        $scopeGroups[$key].Prs.Add([PSCustomObject]@{ Number = $pr.Number; Url = $pr.Url; State = $pr.State; Subject = $subject })
        continue
    }
    $title = $pr.Title.Trim()
    $key = "$title|$($pr.Repo)"
    if (-not $titleGroups.ContainsKey($key)) {
        $titleGroups[$key] = [PSCustomObject]@{ Repo = $pr.Repo; Task = 'general'; Cluster = $title; Kind = 'title'; Prs = New-Object System.Collections.Generic.List[object] }
    }
    $titleGroups[$key].Prs.Add([PSCustomObject]@{ Number = $pr.Number; Url = $pr.Url; State = $pr.State; Subject = $title })
}

Write-Host "backfill-github-prs: $($taskGroups.Count) grupo(s) por numero de task, $($scopeGroups.Count) grupo(s) por scope (fallback), $($titleGroups.Count) grupo(s) avulso(s) por titulo (fallback)."

# Mesma convencao de classificacao de repo usada em Get-PrKindInfo/
# Get-LayerStatusHtml (build-dashboard.ps1) - migrations/tooling cai em
# backend por padrao, mesmo lugar onde resumo de migration ja vive hoje.
function Get-RepoLayer([string]$repo) {
    if ($repo -match '-backend$') { return 'backend' }
    if ($repo -match '^([^-]+-)?(mfe|mobile)-') { return 'frontend' }
    return 'backend'
}

function Get-Slug([string]$text) {
    $slug = $text.ToLowerInvariant()
    $slug = $slug -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')
    if ($slug.Length -gt 50) { $slug = $slug.Substring(0, 50).Trim('-') }
    if (-not $slug) { $slug = 'tarefa' }
    return $slug
}

# Ja existe resumo pra essa task+repo? Mesmo grep documentado em
# controle-documentacao - nao sobrescreve resumo real nem backfill anterior.
function Test-ResumoExists([string]$taskId, [string]$repo) {
    $resumoDir = Join-Path $root 'resumo'
    if (-not (Test-Path $resumoDir)) { return $false }
    $files = Get-ChildItem -Path $resumoDir -Recurse -Filter '*.md' -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $raw = [IO.File]::ReadAllText($f.FullName)
        $p = Parse-Frontmatter $raw
        if ($p -and (Clean-Field $p.Meta['task']) -eq $taskId -and (Clean-Field $p.Meta['repo']) -eq $repo) { return $true }
    }
    return $false
}

# Equivalente pra grupos `task: general` - mesmo grep de `cluster:`+`repo:`
# ja documentado em controle-documentacao pra esse caso.
function Test-ResumoExistsCluster([string]$cluster, [string]$repo) {
    $resumoDir = Join-Path $root 'resumo'
    if (-not (Test-Path $resumoDir)) { return $false }
    $files = Get-ChildItem -Path $resumoDir -Recurse -Filter '*.md' -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $raw = [IO.File]::ReadAllText($f.FullName)
        $p = Parse-Frontmatter $raw
        if ($p -and (Clean-Field $p.Meta['cluster']) -eq $cluster -and (Clean-Field $p.Meta['repo']) -eq $repo) { return $true }
    }
    return $false
}

# Trava real contra duplicata - Test-ResumoExists(Cluster) so' casa por
# task/cluster+repo, mas a MAIORIA das PRs desta Biblioteca ja tem task
# numerica de verdade documentada manualmente (task-code/planning/testes/
# resumo/handover) sob um titulo/numero DIFERENTE do scope literal do
# commit (ex.: PR com commit "fix(proj-107064): ..." ja documentada sob a
# task 107064 "de verdade", nao sob o cluster "proj-107064" cru) - o
# classificador por scope/titulo nunca reconhece isso como "ja existe"
# porque a chave de agrupamento e' outra. Bug real, 2026-09-01: rodada
# sem essa trava criou 47 "resumo" novos, 44 dos quais eram PRs que ja
# estavam documentadas em algum lugar da Biblioteca - so 3 eram gap de
# verdade. Fonte de verdade real e' a URL do PR, nao o texto do titulo/
# scope - varre TODO arquivo .md da Biblioteca (nao so' resumo/, PR
# tambem aparece em handover-tecnico/task-planning) 1x no início, monta
# um set de URLs ja conhecidas, e qualquer grupo com pelo menos 1 PR
# nesse set e' tratado como ja coberto (pula o grupo inteiro, nao cria
# entrada parcial).
function Get-ExistingPrUrls([string]$root) {
    $urls = New-Object System.Collections.Generic.HashSet[string]
    $files = Get-ChildItem -Path $root -Recurse -Filter '*.md' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\_ferramenta\\' }
    foreach ($f in $files) {
        $raw = [IO.File]::ReadAllText($f.FullName)
        foreach ($m in [regex]::Matches($raw, 'https?://github\.com/\S*?/pull/\d+')) {
            [void]$urls.Add($m.Value)
        }
    }
    return $urls
}

$allDocs = Get-DocumentFiles $root
$existingPrUrls = Get-ExistingPrUrls $root
Write-Host "backfill-github-prs: $($existingPrUrls.Count) URL(s) de PR ja referenciadas na Biblioteca (qualquer doc)."
$script:nextNumber = Get-NextNumber $allDocs
$created = 0
$skipped = 0
$today = Get-Date -Format 'yyyy-MM-dd'

# Escreve um resumo pra um grupo (task numerica OU cluster general) -
# compartilhada pelas 3 trilhas, pra nao triplicar frontmatter/corpo/escrita.
function Write-BackfillResumo([PSCustomObject]$group) {
    $anyPrKnown = @($group.Prs | Where-Object { $existingPrUrls.Contains($_.Url) }).Count -gt 0
    if ($anyPrKnown) { return $false }

    $alreadyExists = if ($group.Cluster) { Test-ResumoExistsCluster $group.Cluster $group.Repo } else { Test-ResumoExists $group.Task $group.Repo }
    if ($alreadyExists) { return $false }

    $layer = Get-RepoLayer $group.Repo
    $prsSorted = @($group.Prs | Sort-Object Number -Descending)
    $latestSubject = $prsSorted[0].Subject
    $slugSource = if ($group.Cluster) { $group.Cluster } else { $latestSubject }
    $slug = Get-Slug $slugSource
    # Cluster (scope/titulo fallback) e' frequentemente o MESMO texto em
    # repos diferentes (ex.: scope de commit "proj-107064" copiado igual
    # numa mudanca espelhada em varios repos) - sem o repo no slug, 2 grupos
    # cluster+repo diferentes colidiam no mesmo arquivo `general-{slug}.md`
    # e um sobrescrevia o outro silenciosamente (bug real, 2026-09-01: 47
    # "criado" logados, so 35 arquivos sobreviveram no disco). Slug de task
    # numerica nao sofre disso na pratica (vem do titulo da ultima PR, que
    # varia por repo mesmo pra tasks cross-repo) - fica como estava.
    if ($group.Cluster) { $slug = "$slug-$(Get-Slug $group.Repo)" }
    $allMerged = @($group.Prs | Where-Object { $_.State -ne 'merged' }).Count -eq 0
    $status = if ($allMerged) { 'completed' } else { 'in_progress' }

    $mergedUrls = @($group.Prs | Where-Object { $_.State -eq 'merged' } | ForEach-Object { $_.Url })
    $openUrls = @($group.Prs | Where-Object { $_.State -eq 'open' } | ForEach-Object { $_.Url })

    $prLines = ($prsSorted | ForEach-Object {
        $stateLabel = if ($_.State -eq 'merged') { 'mergeado' } else { 'aberto' }
        "- [$($group.Repo)#$($_.Number)]($($_.Url)) $($script:EmDash) $stateLabel $($script:EmDash) $($_.Subject)"
    }) -join "`n"

    $meta = [ordered]@{
        number   = "$script:nextNumber"
        type     = 'resumo'
        status   = $status
        repo     = $group.Repo
        task     = $group.Task
        function = $latestSubject
        stub     = [char]0x2014
    }
    if ($group.Cluster) { $meta['cluster'] = $group.Cluster }
    if ($mergedUrls.Count -gt 0) { $meta['pr_merged'] = ($mergedUrls -join ' ') }
    if ($openUrls.Count -gt 0) { $meta['pr_pending'] = ($openUrls -join ' ') }
    $meta['updated'] = $today
    $meta['author'] = if ($config.author) { $config.author } else { [char]0x2014 }

    $titleSuffix = if ($group.Cluster) { $group.Cluster } else { "$latestSubject ($($group.Task))" }
    $groupedByLabel = switch ($group.Kind) { 'scope' { 'scope do commit' }; 'title' { 'titulo' }; default { $null } }
    $clusterNote = if ($groupedByLabel) { "sem numero de task formal no titulo da PR - agrupado por $groupedByLabel, " } else { '' }

    $body = @"
# Resumo $($script:EmDash) $titleSuffix

## Status atual

Gerado automaticamente a partir do historico de Pull Requests no GitHub
(backfill inicial, $($clusterNote)sem task-code/planning detalhado) - $($group.Prs.Count) PR(s):

$prLines

## O que foi implementado

- Nao documentado - backfill automatico, sem acesso ao contexto da
  mudanca alem do titulo da PR. Complementar manualmente se for revisar
  essa task.

## REQs seguidas

- Nao rastreado (backfill automatico)

## O que falta

- Nada registrado - ver PR(s) acima pro diff real
"@

    $fileName = "$($group.Task)-$slug.md"
    $destDir = Join-Path $root "resumo\$layer"
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $destPath = Join-Path $destDir $fileName

    # Get-Slug trunca em 50 chars - 2 clusters/titulos DIFERENTES podem
    # compartilhar o mesmo prefixo de 50 chars e colidir no mesmo arquivo
    # mesmo depois do slug incluir o repo (bug real, 2026-09-01: mesma
    # classe do bug de colisao entre repos, so que dentro do MESMO repo).
    # Ultima trava antes de escrever: se o path ja existe (de uma rodada
    # anterior OU de outro grupo processado nesta mesma execucao), sufixo
    # numerico ate achar um nome livre - nunca sobrescreve silenciosamente.
    if (Test-Path $destPath) {
        $suffix = 2
        do {
            $fileName = "$($group.Task)-$slug-$suffix.md"
            $destPath = Join-Path $destDir $fileName
            $suffix++
        } while (Test-Path $destPath)
    }

    [IO.File]::WriteAllText($destPath, (Serialize-Frontmatter $meta) + $body)
    Sync-DocumentFile $destPath | Out-Null

    Write-Host "  criado: resumo/$layer/$fileName ($($group.Repo), $status)"
    $script:nextNumber++
    return $true
}

foreach ($key in $taskGroups.Keys) {
    if (Write-BackfillResumo $taskGroups[$key]) { $created++ } else { $skipped++ }
}
foreach ($key in $scopeGroups.Keys) {
    if (Write-BackfillResumo $scopeGroups[$key]) { $created++ } else { $skipped++ }
}
foreach ($key in $titleGroups.Keys) {
    if (Write-BackfillResumo $titleGroups[$key]) { $created++ } else { $skipped++ }
}

Write-Host "backfill-github-prs: $created resumo(s) criado(s), $skipped pulado(s) (ja existia)."

if ($created -gt 0) {
    Write-Host "backfill-github-prs: rodando sync-all.ps1..."
    & (Join-Path $PSScriptRoot 'sync-all.ps1')
}
