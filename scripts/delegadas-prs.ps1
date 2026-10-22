# Descobre PRs dos devs do time pra cada task delegada ativa - busca no
# GitHub PR do login do dev que cite o id da task (titulo/corpo; o template
# de PR costuma citar o work item, ex.: secao "Referencia Azure DevOps"):
#   gh search prs <taskId> --author <login> --owner <githubOrg>
# URL nova vai pra secao "## PRs" do doc + `pr_pending`. Nao classifica
# estado aqui: o sweep normal do build-dashboard.ps1 (dentro do sync-all
# rodado no fim) ja resolve merged/closed na mesma rodada e fecha a
# delegada (status: completed) quando todos os PRs dela mergeiam.
#
# Botao "Buscar PRs" do time.html, ou a skill delegar-task.
# ponytail: 1 chamada de rede por delegada ativa - ok pra dezenas; se o time
# crescer muito, trocar por 1 `gh search prs --author` por dev e casar o id local.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'lib-doc.ps1')
$root = Get-LibRoot
$cfg = Get-BibliotecaConfig
$devsPath = Join-Path $root 'delegadas\devs.json'

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "delegadas-prs: 'gh' nao encontrado no PATH." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $devsPath)) {
    Write-Host 'delegadas-prs: delegadas/devs.json nao existe - nenhum dev cadastrado.' -ForegroundColor Yellow
    exit 0
}
$loginById = @{}
foreach ($d in @(([IO.File]::ReadAllText($devsPath) | ConvertFrom-Json).devs | Where-Object { $_ })) {
    if ($d.github) { $loginById[$d.id] = $d.github }
}

$prLinkPattern = 'https?://github\.com/\S*?/pull/\d+'
$found = 0
$checked = 0
foreach ($doc in (Get-ParsedDocs $root)) {
    $p = $doc.Parsed
    if (-not $p -or $p.Meta['type'] -ne 'delegada') { continue }
    if ($p.Meta['status'] -notin @('draft', 'in_progress')) { continue }
    $task = Clean-Field $p.Meta['task']
    $dev = Clean-Field $p.Meta['dev']
    if (-not $dev -or $task -notmatch '^\d+$') { continue }
    if (-not $loginById.ContainsKey($dev)) {
        Write-Host "delegadas-prs: task $task - dev '$dev' sem login no devs.json, pulando." -ForegroundColor Yellow
        continue
    }
    $checked++
    $ghArgs = @('search', 'prs', $task, '--author', $loginById[$dev], '--json', 'url', '--limit', '20')
    if ($cfg.githubOrg) { $ghArgs += @('--owner', $cfg.githubOrg) }
    try { $results = @(& gh @ghArgs 2>$null | ConvertFrom-Json) } catch { $results = @() }
    $urls = @($results | ForEach-Object { $_.url } | Where-Object { $_ -match $prLinkPattern })
    if ($urls.Count -eq 0) { continue }

    $known = "$($p.Body) $($p.Meta['pr_pending']) $($p.Meta['pr_merged']) $($p.Meta['pr_rejected'])"
    $new = @($urls | Where-Object { -not $known.Contains($_) } | Select-Object -Unique)
    if ($new.Count -eq 0) { continue }

    $meta = $p.Meta
    $meta['pr_pending'] = ((Clean-Field $meta['pr_pending']) + ' ' + ($new -join ' ')).Trim()
    $meta['updated'] = (Get-Date -Format 'yyyy-MM-dd')
    $body = Get-ContentBody $p.Body
    # So' a URL na linha (sem titulo do PR): titulo com "task NNNN" antes da
    # URL seguinte faria o Get-Signals descartar o link como citacao.
    $bullets = ($new | ForEach-Object { "- $_" }) -join "`n"
    $body = $body -replace '(?m)^_Nenhum PR ainda\._[ \t]*\r?\n?', ''
    if ($body -match '(?m)^## PRs[ \t]*$') {
        $m = [regex]::Match($body, '(?m)^## PRs[ \t]*$')
        $at = $m.Index + $m.Length
        $body = $body.Substring(0, $at) + "`n`n$bullets" + $body.Substring($at)
    } else {
        $body = $body.TrimEnd() + "`n`n## PRs`n`n$bullets`n"
    }
    [IO.File]::WriteAllText($doc.File.FullName, (Serialize-Frontmatter $meta) + $body)
    Sync-DocumentFile $doc.File.FullName | Out-Null
    $found += $new.Count
    Write-Host "delegadas-prs: task $task (@$($loginById[$dev])) - $($new.Count) PR(s) novo(s): $($new -join ' ')"
}

Write-Host "delegadas-prs: $checked delegada(s) ativa(s) verificada(s), $found PR(s) novo(s)."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'sync-all.ps1') | Select-Object -Last 2
