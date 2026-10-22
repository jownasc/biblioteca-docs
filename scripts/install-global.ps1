# Instala o que a Biblioteca precisa FORA do proprio repo - sem isso o fluxo
# so' funciona com o Claude aberto dentro da Biblioteca, e o uso real e'
# dentro do repo do projeto gravando doc aqui. Chamado pelo biblioteca-setup.
# Idempotente: rodar de novo so' reaplica (ex.: depois de mover a pasta).
#   1. Junction de skills em ~/.claude/skills (ficam sempre iguais as do repo)
#   2. Hooks globais em ~/.claude/settings.json (sync apos gravar doc,
#      backup de plano em planos/)
#   3. Guard de pre-commit (.git/hooks nao e' versionado)
param(
    [string]$SettingsPath = (Join-Path $env:USERPROFILE '.claude\settings.json'),
    [string]$SkillsDir = (Join-Path $env:USERPROFILE '.claude\skills')
)

. (Join-Path $PSScriptRoot 'lib-doc.ps1')
$root = Get-LibRoot
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# 1. Skills usadas de dentro de outros repos. biblioteca-setup,
# importar-historico-github e task-hub-* ficam so' no repo (so' fazem
# sentido com a sessao aberta aqui). Skill que nao existe nesta copia e'
# pulada (quem usa versao propria com outro nome nao recebe duplicata).
New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
foreach ($name in 'controle-documentacao', 'biblioteca-pdf-export', 'delegar-task', 'testes-manuais', 'mock-completo', 'evidencia-imagem') {
    $src = Join-Path $root ".claude\skills\$name"
    if (-not (Test-Path $src)) { continue }
    $dst = Join-Path $SkillsDir $name
    $item = Get-Item $dst -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -eq 'Junction') {
        # Directory.Delete nao-recursivo remove so' o link, nunca o alvo
        [IO.Directory]::Delete($dst)
    } elseif ($item) {
        # Copia solta antiga - backup fora de skills/ (senao carrega duplicada)
        $bak = Join-Path (Split-Path $SkillsDir -Parent) "skills-backup\$name-$stamp"
        New-Item -ItemType Directory -Force -Path (Split-Path $bak -Parent) | Out-Null
        Move-Item $dst $bak
        Write-Host "install-global: copia antiga de $name movida pra $bak"
    }
    New-Item -ItemType Junction -Path $dst -Target $src | Out-Null
    Write-Host "install-global: skill $name -> $src"
}

# 2. Hooks - identificados pelo statusMessage: troca o hook antigo (path
# velho/quebrado) sem tocar em nenhum outro hook do usuario.
$settings = if (Test-Path $SettingsPath) { Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { [PSCustomObject]@{} }
if (-not $settings.hooks) { $settings | Add-Member -Force hooks ([PSCustomObject]@{}) }

function Set-BibliotecaHook($event, $matcher, $status, $timeout, $command) {
    $entries = @()
    foreach ($e in @($settings.hooks.$event | Where-Object { $_ })) {
        $e.hooks = @($e.hooks | Where-Object { $_.statusMessage -ne $status })
        if ($e.hooks.Count -gt 0) { $entries += $e }
    }
    $entries += [PSCustomObject]@{
        matcher = $matcher
        hooks = @([PSCustomObject]@{ type = 'command'; command = $command; shell = 'powershell'; timeout = $timeout; statusMessage = $status })
    }
    $settings.hooks | Add-Member -Force $event $entries
}

$rootQ = $root.Replace("'", "''")
$syncQ = (Join-Path $PSScriptRoot 'sync-all.ps1').Replace("'", "''")
Set-BibliotecaHook 'PostToolUse' 'Write|Edit' 'Sincronizando Biblioteca...' 30 (
    "`$j = [Console]::In.ReadToEnd() | ConvertFrom-Json; `$p = `$j.tool_input.file_path; if (-not `$p) { `$p = `$j.tool_response.filePath }; " +
    "if (`$p -and (`$p -replace '/', '\') -like '$rootQ\*' -and `$p -like '*.md') { powershell -ExecutionPolicy Bypass -File '$syncQ' }")
Set-BibliotecaHook 'PermissionRequest' 'ExitPlanMode' 'Arquivando plano em Biblioteca/planos...' 15 (
    "`$plans = Join-Path `$env:USERPROFILE '.claude\plans'; `$latest = Get-ChildItem `$plans -Filter *.md -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1; " +
    "if (`$latest) { `$dest = Join-Path '$rootQ\planos' ((Get-Date -Format 'yyyy-MM-dd_HHmmss') + '-' + `$latest.Name); Copy-Item `$latest.FullName `$dest -Force }")
New-Item -ItemType Directory -Force -Path (Join-Path $root 'planos') | Out-Null

if (Test-Path $SettingsPath) { Copy-Item $SettingsPath "$SettingsPath.bak-$stamp" }
New-Item -ItemType Directory -Force -Path (Split-Path $SettingsPath -Parent) | Out-Null
[IO.File]::WriteAllText($SettingsPath, ($settings | ConvertTo-Json -Depth 32), (New-Object System.Text.UTF8Encoding $false))
Write-Host "install-global: hooks gravados em $SettingsPath (backup .bak-$stamp)"

# 3. Pre-commit - path relativo ao toplevel, funciona no layout pessoal
# (_ferramenta/scripts) e no flat (scripts).
$hook = Join-Path $root '.git\hooks\pre-commit'
if ((Test-Path (Join-Path $root '.git')) -and -not (Test-Path $hook)) {
    $rel = $PSScriptRoot.Substring($root.Length + 1).Replace('\', '/')
    $body = "#!/bin/sh`npowershell -ExecutionPolicy Bypass -File `"`$(git rev-parse --show-toplevel)/$rel/pre-commit-check.ps1`"`nexit `$?`n"
    [IO.File]::WriteAllText($hook, $body, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "install-global: pre-commit instalado"
}
