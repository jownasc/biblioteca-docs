# Shared helpers - Biblioteca de Handovers (ponytail: single PS lib, no framework)

# Pessoal: raiz/_ferramenta/scripts. Export publico (biblioteca-docs) e'
# flat: raiz/scripts - '..\..' fixo la' caia na pasta ACIMA do repo.
$script:LibRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ((Split-Path $script:LibRoot -Leaf) -eq '_ferramenta') { $script:LibRoot = Split-Path $script:LibRoot -Parent }

$script:TypeLabels = @{
    'rules' = 'Regras'
    'task-code' = 'Task code'
    'task-planning' = 'Task planning'
    'testes' = 'Testes'
    'resumo' = 'Resumo'
    'handover-tecnico' = 'Handover tecnico'
    'delegada' = 'Delegada'
}

$script:StatusLabels = @{
    'draft' = 'Rascunho'
    'in_progress' = 'Em andamento'
    'completed' = 'Concluido'
    'superseded' = 'Substituido'
    'archived' = 'Arquivado'
}

# Emoji construidos por codepoint (ConvertFromUtf32) -- nunca literal no source,
# PowerShell 5.1 le .ps1 sem BOM como ANSI e corrompe qualquer char nao-ASCII literal.
$script:StatusEmoji = @{
    'draft' = [char]::ConvertFromUtf32(0x26AA)        # circulo branco
    'in_progress' = [char]::ConvertFromUtf32(0x1F535) # circulo azul
    'completed' = [char]::ConvertFromUtf32(0x2705)    # check verde
    'superseded' = [char]::ConvertFromUtf32(0x267B)   # reciclagem
    'archived' = [char]::ConvertFromUtf32(0x1F4E6)    # caixa
}

$script:EmDash = [char]0x2014
$script:GuardSkips = New-Object System.Collections.Generic.List[string]

function Get-LibRoot { return $script:LibRoot }

# Config pessoal (nao versionada - biblioteca.config.json e' gitignored).
# Campo ausente ou arquivo inexistente = $null; quem consome decide o
# fallback (ex.: desligar a feature) em vez de travar com path/URL alheio.
function Get-BibliotecaConfig {
    $configPath = Join-Path $script:LibRoot 'biblioteca.config.json'
    # delegarSkill: nome da skill de delegacao chamada pelos botoes do
    # time.html - default a do repo; quem usa uma versao propria (outro
    # nome) aponta pra ela aqui. reposAoFim/repoAliases: ver
    # Get-RepoSortKey (dashboard-lib.ps1).
    $empty = [PSCustomObject]@{ author = $null; reposBasePath = $null; azureOrgUrl = $null; defaultBranch = $null; githubOrg = $null; delegarSkill = 'delegar-task'; reposAoFim = @(); repoAliases = @{} }
    if (-not (Test-Path $configPath)) { return $empty }
    try {
        $raw = [IO.File]::ReadAllText($configPath) | ConvertFrom-Json
    } catch {
        return $empty
    }
    $aliases = @{}
    if ($raw.repoAliases) { $raw.repoAliases.PSObject.Properties | ForEach-Object { $aliases[$_.Name] = "$($_.Value)" } }
    return [PSCustomObject]@{
        author        = if ($raw.author) { $raw.author } else { $null }
        reposBasePath = if ($raw.reposBasePath) { $raw.reposBasePath } else { $null }
        azureOrgUrl   = if ($raw.azureOrgUrl) { $raw.azureOrgUrl } else { $null }
        defaultBranch = if ($raw.defaultBranch) { $raw.defaultBranch } else { $null }
        githubOrg     = if ($raw.githubOrg) { $raw.githubOrg } else { $null }
        delegarSkill  = if ($raw.delegarSkill) { $raw.delegarSkill } else { 'delegar-task' }
        reposAoFim    = @($raw.reposAoFim | Where-Object { $_ })
        repoAliases   = $aliases
    }
}

function Test-SizeSane([int]$oldLen, [int]$newLen, [string]$path) {
    $maxAbsolute = 2MB
    if ($newLen -gt $maxAbsolute) {
        $msg = "$path - resultado $([math]::Round($newLen/1KB)) KB excede limite de $([math]::Round($maxAbsolute/1KB)) KB"
        Write-Warning "sync-header: $msg. Corrupcao suspeita, arquivo NAO alterado."
        $script:GuardSkips.Add($msg)
        return $false
    }
    if ($oldLen -gt 1000 -and $newLen -gt ($oldLen * 3)) {
        $msg = "$path - cresceu de $oldLen para $newLen bytes (>3x)"
        Write-Warning "sync-header: $msg. Corrupcao suspeita, arquivo NAO alterado."
        $script:GuardSkips.Add($msg)
        return $false
    }
    return $true
}

function Clean-Field([string]$s) {
    if ($null -eq $s) { return '' }
    return $s.Trim().Trim([char]13)
}

function Format-DisplayDate([string]$iso) {
    $iso = Clean-Field $iso
    if (-not $iso -or $iso -eq 'YYYY-MM-DD') { return $iso }
    if ($iso -match '^(\d{4})-(\d{2})-(\d{2})$') {
        return '{0:D2}/{1:D2}/{2}' -f [int]$Matches[3], [int]$Matches[2], $Matches[1]
    }
    return $iso
}

function Parse-Frontmatter([string]$text) {
    if ($text -notmatch '(?s)^(---\r?\n)(.*?)(\r?\n---\r?\n)') {
        return $null
    }
    # Matches[0]/[2] guardados ANTES do foreach abaixo - o loop usa -match
    # em cada linha, o que sobrescreve a variavel automatica $Matches do
    # match externo. Ler $Matches depois do loop pra calcular $end usava
    # por engano o ultimo match INTERNO (bug real, corrompia .Body sempre
    # que lido direto sem passar por Get-ContentBody - so nao aparecia
    # porque Get-ContentBody "cura" isso ao cortar tudo antes do 1o "# ").
    $frontmatterLen = $Matches[0].Length
    $metaBlock = $Matches[2]
    $meta = @{}
    foreach ($line in ($metaBlock -split '\r?\n')) {
        if ($line -match '^related:\s*$') {
            $meta['_related_last'] = $true
            $meta['related'] = @()
        }
        elseif ($line -match '^\s+-\s+(.+)$' -and $meta.ContainsKey('_related_last')) {
            if (-not $meta['related']) { $meta['related'] = @() }
            $meta['related'] += Clean-Field $Matches[1]
        }
        elseif ($line -match '^(\w+):\s*(.*)$') {
            $meta.Remove('_related_last') | Out-Null
            $meta[$Matches[1]] = Clean-Field $Matches[2].Trim('"')
        }
    }
    $meta.Remove('_related_last') | Out-Null
    $body = $text.Substring($frontmatterLen)
    return @{ Meta = $meta; Body = $body }
}

function Get-TaskCell([string]$task) {
    $t = Clean-Field $(if ($task) { $task } else { 'general' })
    if ($t -match '^\d+$') { return "Task **$t**" }
    return '**Geral**'
}

function Build-Badge($meta) {
    $status = Clean-Field $(if ($meta['status']) { $meta['status'] } else { 'draft' })
    $statusLabel = if ($script:StatusLabels.ContainsKey($status)) { $script:StatusLabels[$status] } else { $status }
    $emoji = if ($script:StatusEmoji.ContainsKey($status)) { $script:StatusEmoji[$status] } else { '' }
    $repo = Clean-Field $meta['repo']
    $updated = Format-DisplayDate $meta['updated']

    $parts = @("$emoji **$statusLabel**", "``$repo``", $updated)
    $line = ($parts -join ' | ')
    return "<!-- badge:auto -->`n$line`n<!-- /badge:auto -->"
}

function Insert-Badge([string]$body, [string]$badge) {
    if ($body -match '(?m)^# .*$') {
        $m = [regex]::Match($body, '(?m)^# .*$')
        $insertAt = $m.Index + $m.Length
        $before = $body.Substring(0, $insertAt)
        $after = $body.Substring($insertAt) -replace '^(\r?\n)+', ''
        return "$before`n`n$badge`n`n$after"
    }
    return "$badge`n`n$body"
}

function Build-MetadataFooter($meta) {
    $num = Clean-Field $meta['number']
    $typ = Clean-Field $meta['type']
    $label = if ($script:TypeLabels.ContainsKey($typ)) { $script:TypeLabels[$typ] } else { $typ }
    $stub = Clean-Field $(if ($meta['stub']) { $meta['stub'] } else { $script:EmDash })
    $stubCell = if ($stub -eq $script:EmDash -or $stub -eq '-' -or -not $stub) { "$script:EmDash" } else { "``$stub``" }
    $author = Clean-Field $meta['author']
    $planActive = Clean-Field $meta['plan_active']

    $rows = @(
        "| Numero | $num |"
        "| Tipo | $label |"
        "| Task | $(Get-TaskCell $meta['task']) |"
        "| Stub | $stubCell |"
    )
    if ($typ -eq 'task-planning' -and $planActive) {
        $rows += "| Plano ativo | ``$planActive`` |"
    }
    $rows += "| Autor | $author |"

    $table = "| Campo | Valor |`n|---|---|`n" + ($rows -join "`n")
    return "<!-- meta:auto -->`n<details>`n<summary>Metadados</summary>`n`n$table`n`n</details>`n<!-- /meta:auto -->`n"
}

function Strip-GeneratedParts([string]$body) {
    # legado: tabela 3-colunas antiga, sempre no topo do body
    $body = $body -replace '(?s)^\| \| \| \|\r?\n\|:--\|:--\|:--\|\r?\n.*?(?=\r?\n# |\r?\n## |\z)', ''
    # blocos marcados, podem aparecer em qualquer posicao do body
    $body = $body -replace '(?s)<!-- badge:auto -->.*?<!-- /badge:auto -->\r?\n*', ''
    $body = $body -replace '(?s)<!-- related:auto -->.*?<!-- /related:auto -->\r?\n*', ''
    $body = $body -replace '(?s)<!-- meta:auto -->.*?<!-- /meta:auto -->\r?\n*', ''
    $body = $body -replace '(?s)^---\r?\n.*?\r?\n---\r?\n+', ''
    # limpeza de sequela: badges sem marcador gravados por uma versao anterior
    # do script (bug ja corrigido) ficam soltos como texto comum. Remove qualquer
    # linha orfa igual ao padrao de badge, em qualquer posicao.
    $emojiAlt = ($script:StatusEmoji.Values | Where-Object { $_ } | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $labelAlt = ($script:StatusLabels.Values | ForEach-Object { [regex]::Escape($_) }) -join '|'
    if ($emojiAlt -and $labelAlt) {
        $orphanBadge = "(?m)^(?:$emojiAlt) \*\*(?:$labelAlt)\*\* \|.*`$\r?\n*"
        $body = [regex]::Replace($body, $orphanBadge, '')
    }
    return $body.Trim("`r", "`n")
}

function Get-ContentBody([string]$body) {
    $body = Strip-GeneratedParts $body
    if ($body -match '(?m)^# ') {
        $idx = [regex]::Match($body, '(?m)^# ').Index
        return $body.Substring($idx)
    }
    return $body.TrimStart()
}

function Build-RelatedSection($meta) {
    if (-not $meta['related'] -or @($meta['related']).Count -eq 0) { return '' }
    $items = @()
    foreach ($r in @($meta['related'])) {
        $r = Clean-Field $r
        if ($r) { $items += "- ``$r``" }
    }
    if ($items.Count -eq 0) { return '' }
    return "<!-- related:auto -->`n## Documentos relacionados`n$($items -join "`n")`n<!-- /related:auto -->`n"
}

function Serialize-Frontmatter($meta) {
    $lines = @('---')
    $order = @('number', 'type', 'status', 'repo', 'task', 'branch', 'function', 'titulo_busca', 'dev', 'dificuldade', 'estimativa', 'delegada_em', 'stub', 'cluster', 'pseudo_task', 'pr_pending', 'pr_merged', 'pr_rejected', 'plan_active', 'related', 'updated', 'author')
    foreach ($key in $order) {
        if (-not $meta.Contains($key)) { continue }
        if ($key -eq 'related') {
            $relatedItems = @($meta['related'] | Where-Object { $_ })
            if ($relatedItems.Count -eq 0) { continue }
            $lines += 'related:'
            foreach ($r in $relatedItems) {
                $lines += "  - $r"
            }
            continue
        }
        if ([string]::IsNullOrWhiteSpace([string]$meta[$key])) { continue }
        $lines += "${key}: $($meta[$key])"
    }
    foreach ($key in ($meta.Keys | Sort-Object)) {
        if ($key -in $order) { continue }
        $lines += "${key}: $($meta[$key])"
    }
    $lines += '---'
    $lines += ''
    return ($lines -join "`n")
}

function Sync-DocumentFile([string]$path) {
    $raw = [System.IO.File]::ReadAllText($path)
    $text = $raw -replace "`r`n", "`n" -replace "`r", "`n"
    # arquivos antigos podem ter `r` solto residual (bug historico de normalizacao);
    # colapsa 3+ newlines seguidas em 1 linha em branco, nunca perde conteudo real.
    $text = $text -replace "(`n){3,}", "`n`n"
    # mesma corrupcao deixava exatamente 1 linha em branco entre itens de lista
    # que originalmente eram "tight" (sem espaco). Junta item-lista + item-lista.
    $listItem = '[ \t]*(?:[-*]|\d+\.)[ \t]+'
    $text = [regex]::Replace($text, "(?m)^($listItem.*)`n`n(?=$listItem)", ('$1' + "`n"))
    $parsed = Parse-Frontmatter $text
    if (-not $parsed) { return $false }

    $meta = $parsed.Meta
    if (-not $meta['type']) { return $false }
    if (-not $meta['status']) { $meta['status'] = 'draft' }

    $body = Get-ContentBody $parsed.Body
    $badge = Build-Badge $meta
    $body = Insert-Badge $body $badge

    $related = Build-RelatedSection $meta
    $footer = Build-MetadataFooter $meta
    $fm = Serialize-Frontmatter $meta

    $newText = $fm + $body
    if (-not $newText.EndsWith("`n")) { $newText += "`n" }
    if ($related) { $newText += "`n" + $related }
    $newText += "`n" + $footer

    $newText = $newText -replace "`n", "`r`n"

    if (-not (Test-SizeSane $raw.Length $newText.Length $path)) {
        return $false
    }

    $oldNorm = $text -replace "`n", "`r`n"
    if ($newText -ne $oldNorm) {
        [System.IO.File]::WriteAllText($path, $newText)
        return $true
    }
    return $false
}

function Get-DocumentFiles([string]$root) {
    Get-ChildItem -Path $root -Recurse -Filter '*.md' |
        Where-Object {
            $_.FullName -notmatch '[\\/]_templates[\\/]' -and
            $_.FullName -notmatch '[\\/]_archive[\\/]' -and
            $_.FullName -notmatch '[\\/]progresso[\\/]' -and
            $_.Name -notin @('INDEX.md', 'README.md', 'CATALOGO.md') -and
            $_.DirectoryName -notmatch '[\\/]scripts[\\/]'
        }
}

# Parse uma unica vez, compartilhado entre lint-clusters/build-index/
# build-dashboard via sync-all.ps1 (cada um antes fazia seu proprio
# Get-DocumentFiles + Parse-Frontmatter por arquivo - 4 varreduras
# completas da Biblioteca por sync-all, agora 1). So chamar isso DEPOIS
# de sync-header.ps1 rodar (ele e' quem re-grava os arquivos - cache
# calculado antes ficaria desatualizado).
function Get-ParsedDocs([string]$root) {
    $files = Get-DocumentFiles $root
    $docs = @()
    foreach ($f in $files) {
        $parsed = Parse-Frontmatter ([IO.File]::ReadAllText($f.FullName))
        $docs += [PSCustomObject]@{ File = $f; Parsed = $parsed }
    }
    return $docs
}

function Get-NextNumber($docs) {
    $max = 1
    foreach ($d in $docs) {
        $p = Parse-Frontmatter ([IO.File]::ReadAllText($d.FullName))
        if ($p -and $p.Meta['number'] -match '^\d+$') {
            $n = [int]$p.Meta['number']
            if ($n -gt $max) { $max = $n }
        }
    }
    return $max + 1
}

# pseudo_task e' um contador separado do `number:` global - so pra doc
# `task: general` que quer um numero curto e buscavel (ver
# 01-regras-biblioteca.md, campo `pseudo_task`). Faixa 900+ desde
# 2026-08-24 (decisao do usuario) - nunca colide visualmente com task id
# real (ids de work item costumam ter 5-6 digitos, ex. 104691) e filtra so digitando "9" na
# busca do dashboard. Historico pre-900: comecou em 13/14, renumerado
# retroativamente pra 901/902 na mesma decisao.
function Get-NextPseudoTask($docs) {
    $max = 900
    foreach ($d in $docs) {
        $p = Parse-Frontmatter ([IO.File]::ReadAllText($d.FullName))
        if ($p -and $p.Meta['pseudo_task'] -match '^\d+$') {
            $n = [int]$p.Meta['pseudo_task']
            if ($n -gt $max) { $max = $n }
        }
    }
    return $max + 1
}
