# Gera INDEX.md a partir do frontmatter de todos os documentos
param([array]$ParsedDocs)
. (Join-Path $PSScriptRoot 'lib-doc.ps1')
$root = Get-LibRoot
# -ParsedDocs vem de sync-all.ps1 (parse compartilhado); sem ele, parseia
# por conta propria (rodando este script solo) - ver lint-clusters.ps1.
$parsedDocs = if ($ParsedDocs) { $ParsedDocs } else { Get-ParsedDocs $root }
$rows = @()
$maxNum = 1
$maxPseudoTask = 900

foreach ($d in $parsedDocs) {
    $f = $d.File
    $p = $d.Parsed
    if (-not $p -or -not $p.Meta['number']) { continue }
    if ($p.Meta['number'] -match '^\d+$') {
        $n = [int]$p.Meta['number']
        if ($n -gt $maxNum) { $maxNum = $n }
    }
    if ($p.Meta['pseudo_task'] -match '^\d+$') {
        $n = [int]$p.Meta['pseudo_task']
        if ($n -gt $maxPseudoTask) { $maxPseudoTask = $n }
    }
    $rel = $f.FullName.Substring($root.Length + 1) -replace '\\', '/'
    $num = $p.Meta['number'].PadLeft(2, '0')
    $status = Clean-Field $(if ($p.Meta['status']) { $p.Meta['status'] } else { 'draft' })
    $statusLabel = if ($script:StatusLabels.ContainsKey($status)) { $script:StatusLabels[$status] } else { $status }
    $rows += [PSCustomObject]@{
        Num = [int]$p.Meta['number']
        Type = $p.Meta['type']
        Status = $status
        Line = "| $num | [``$rel``]($rel) | $statusLabel | $($p.Meta['repo']) | $($p.Meta['task']) | $($p.Meta['function']) |"
    }
}
$next = $maxNum + 1
$nextPseudoTask = $maxPseudoTask + 1
$today = Get-Date -Format 'dd/MM/yyyy'

$tableHeader = @(
    '| # | Arquivo | Status | Repo | Task | Funcao |'
    '|:--|:--|:--|:--|:--|:--|'
)

# INDEX.md fica pequeno de proposito (ativas + cabecalho) - e' o unico arquivo
# que se espera ler por completo; historico cresce pra sempre em CATALOGO.md,
# consultado so por grep/busca pontual (ver controle-documentacao).
$index = @(
    '# Indice - Biblioteca'
    ''
    '> **Gerado automaticamente.** Nao editar. Rode ``scripts/sync-all.ps1`` apos alterar documentos.'
    ''
    "**Pasta:** ``$root``  "
    "**Proximo numero:** ``$next``  "
    ('**Proximo pseudo_task (doc ``task: general`` sem numero de task real):** ``' + $nextPseudoTask + '``  ')
    "**Atualizado:** $today"
    ''
    '---'
    ''
    '## Como usar'
    ''
    '| Acao | Onde |'
    '|:--|:--|'
    '| Regras e templates | [`01-regras-biblioteca.md`](01-regras-biblioteca.md) |'
    '| Skill do agente | ``~/.cursor/skills/controle-documentacao/SKILL.md`` |'
    '| Templates | [`_templates/`](_templates/) |'
    '| Sincronizar tabelas + indice | ``scripts/sync-all.ps1`` |'
    '| Historico completo (busca pontual, nao ler por completo) | [`CATALOGO.md`](CATALOGO.md) |'
    ''
    '---'
    ''
)

$active = $rows | Where-Object { $_.Status -in @('draft', 'in_progress') } | Sort-Object Num -Descending
if ($active.Count -gt 0) {
    $index += '## Em andamento agora'
    $index += ''
    $index += $tableHeader
    foreach ($r in $active) { $index += $r.Line }
    $index += ''
}

$out = Join-Path $root 'INDEX.md'
[System.IO.File]::WriteAllText($out, ($index -join "`r`n"))

$catalogo = @(
    '# Catalogo completo - Biblioteca'
    ''
    '> **Gerado automaticamente.** Nao editar. Historico de tudo, agrupado por'
    '> tipo, mais recente primeiro. So consultar via grep/busca pontual — nao'
    '> ler por completo (cresce pra sempre). Ativas ficam em [`INDEX.md`](INDEX.md).'
    ''
    '---'
    ''
)

$groupOrder = @('task-code', 'task-planning', 'testes', 'resumo', 'handover-tecnico', 'delegada', 'rules')
foreach ($type in $groupOrder) {
    $group = $rows | Where-Object { $_.Type -eq $type } | Sort-Object Num -Descending
    if ($group.Count -eq 0) { continue }
    $typeLabel = if ($script:TypeLabels.ContainsKey($type)) { $script:TypeLabels[$type] } else { $type }
    $catalogo += "## $typeLabel"
    $catalogo += ''
    $catalogo += $tableHeader
    foreach ($r in $group) { $catalogo += $r.Line }
    $catalogo += ''
}

$catOut = Join-Path $root 'CATALOGO.md'
[System.IO.File]::WriteAllText($catOut, ($catalogo -join "`r`n"))
Write-Host "build-index: $($rows.Count) entradas, proximo #$next, proximo pseudo_task $nextPseudoTask"
