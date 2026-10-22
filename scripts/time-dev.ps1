# Adiciona/remove dev da pagina Time (delegadas/devs.json). Chamado pelo
# dialogo "+ Dev" de time.html via protocolo biblioteca-cmd-run: - sem
# Claude, sem skill. Regenera o dashboard no fim (a pagina recarrega
# sozinha em ate 20s).
#
# Nome chega em base64 UTF-8 (-NomeB64): o launch-command.vbs decodifica a
# URL byte a byte e corromperia qualquer acento ("Joao" com til).
#
#   .\time-dev.ps1 -NomeB64 <base64> -Github <login>
#   .\time-dev.ps1 -Remover <id>
param([string]$NomeB64, [string]$Github, [string]$Remover)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'lib-doc.ps1')
$root = Get-LibRoot
$dir = Join-Path $root 'delegadas'
$path = Join-Path $dir 'devs.json'
New-Item -ItemType Directory -Force -Path $dir | Out-Null

$devs = @()
if (Test-Path $path) {
    $devs = @(([IO.File]::ReadAllText($path) | ConvertFrom-Json).devs | Where-Object { $_ })
}

function Save-Devs($list) {
    $json = [PSCustomObject]@{ devs = @($list) } | ConvertTo-Json -Depth 4
    [IO.File]::WriteAllText($path, $json + "`n", (New-Object System.Text.UTF8Encoding $false))
}

# Id estavel = nome sem acento, minusculo, hifenizado. E' o valor que vai no
# `dev:` do frontmatter das delegadas - nunca muda depois de criado.
function Get-DevSlug([string]$nome) {
    $plain = -join ($nome.Normalize([Text.NormalizationForm]::FormD).ToCharArray() |
        Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
    return (($plain.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-'))
}

if ($Remover) {
    if ($Remover -notmatch '^[a-z0-9-]+$') { Write-Host "id invalido: $Remover" -ForegroundColor Red; exit 1 }
    $ativos = @(Get-ParsedDocs $root | Where-Object {
        $_.Parsed -and $_.Parsed.Meta['type'] -eq 'delegada' -and $_.Parsed.Meta['dev'] -eq $Remover -and
        $_.Parsed.Meta['status'] -in @('draft', 'in_progress')
    })
    if ($ativos.Count -gt 0) {
        Write-Host "time-dev: '$Remover' ainda tem $($ativos.Count) task(s) ativa(s) - reatribua ou conclua antes de remover:" -ForegroundColor Yellow
        $ativos | ForEach-Object { Write-Host "  $($_.File.FullName)" }
        exit 1
    }
    $before = $devs.Count
    $devs = @($devs | Where-Object { $_.id -ne $Remover })
    if ($devs.Count -eq $before) { Write-Host "time-dev: '$Remover' nao estava cadastrado." -ForegroundColor Yellow; exit 0 }
    Save-Devs $devs
    Write-Host "time-dev: '$Remover' removido."
} else {
    if (-not $NomeB64 -or -not $Github) { Write-Host 'uso: time-dev.ps1 -NomeB64 <base64> -Github <login> | -Remover <id>' -ForegroundColor Red; exit 1 }
    try {
        $nome = ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($NomeB64)) -replace '\s+', ' ').Trim()
    } catch {
        Write-Host 'time-dev: nome em base64 invalido.' -ForegroundColor Red; exit 1
    }
    if (-not $nome -or $nome.Length -gt 60 -or $nome -match '[\p{C}<>"]') { Write-Host "time-dev: nome invalido: '$nome'" -ForegroundColor Red; exit 1 }
    $Github = $Github.TrimStart('@')
    if ($Github -notmatch '^[A-Za-z0-9-]{1,39}$') { Write-Host "time-dev: login do GitHub invalido: '$Github'" -ForegroundColor Red; exit 1 }
    $id = Get-DevSlug $nome
    if (-not $id) { Write-Host 'time-dev: nao deu pra gerar id a partir do nome.' -ForegroundColor Red; exit 1 }
    if ($devs | Where-Object { $_.id -eq $id -or "$($_.github)" -ieq $Github }) {
        Write-Host "time-dev: '$nome' (@$Github) ja esta cadastrado - nada a fazer." -ForegroundColor Yellow
        exit 0
    }
    # So' aviso: login errado nao quebra nada, so' o "Buscar PRs" nao acha PR.
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        # try: com ErrorActionPreference=Stop, stderr de exe nativo vira excecao no PS 5.1
        $ghOk = $true
        try { gh api "users/$Github" --silent 2>$null | Out-Null; $ghOk = ($LASTEXITCODE -eq 0) } catch { $ghOk = $false }
        if (-not $ghOk) { Write-Host "time-dev: aviso - login '$Github' nao encontrado no GitHub (cadastrado mesmo assim)." -ForegroundColor Yellow }
    }
    $devs += [PSCustomObject]@{ id = $id; nome = $nome; github = $Github }
    Save-Devs $devs
    Write-Host "time-dev: '$nome' (@$Github) adicionado com id '$id'."
}

& (Join-Path $PSScriptRoot '..\dashboard-visual\scripts\build-dashboard.ps1') | Select-Object -Last 1
