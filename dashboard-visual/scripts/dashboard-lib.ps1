# Funcoes puras de build-dashboard.ps1, extraidas pra dar pra testar sem
# rodar o script inteiro (que gera arquivo e escreve disco de ponta a
# ponta). Nenhuma delas tem side-effect - so' recebem dado e devolvem
# valor/string. Ver test-dashboard-lib.ps1.

function Esc([string]$s) {
    if ($null -eq $s) { return '' }
    return $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

# $task (opcional, task numerica do card) filtra links de PR que sao
# CITACAO a outra task, nao PR proprio dela - convencao comum nos docs
# da Biblioteca e' citar trabalho relacionado tipo "...achado ao
# investigar o equivalente X (task 104691, PR [...](...))". Sem esse
# filtro, o PR citado vazava pro card da task ERRADA (bug real,
# 2026-08-25: PR #288 da task 104691 aparecendo no card da task 104689
# so' por ter sido citado la como referencia). So' exclui quando a
# citacao "task NNNNN" aparece pouco antes do link E o numero diverge
# do card - citacao de PR da MESMA task (ex.: migration espelho, PR de
# outro repo mas mesma task) nunca tem esse prefixo "task NNNNN" antes
# (a convencao so' cita "task N" pra apontar OUTRA task), entao continua
# passando normalmente.
function Get-Signals($docs, $task) {
    $prLinks = New-Object System.Collections.Generic.List[string]
    foreach ($d in $docs) {
        foreach ($m in [regex]::Matches($d.Body, 'https?://github\.com/\S*?/pull/\d+')) {
            if ($task -and $task -match '^\d+$') {
                $precedingStart = [Math]::Max(0, $m.Index - 80)
                $preceding = $d.Body.Substring($precedingStart, $m.Index - $precedingStart)
                if ($preceding -match 'task\s+(\d+)' -and $Matches[1] -ne $task) { continue }
            }
            if (-not $prLinks.Contains($m.Value)) { $prLinks.Add($m.Value) }
        }
    }
    return [PSCustomObject]@{
        PRs = @($prLinks | Select-Object -First 10)
    }
}

# Comandos copiaveis de um card - usado tanto pelos botoes inline do card
# quanto pela caixa de acoes da pagina de resumo, pra nao duplicar as
# strings de comando em dois lugares.
# Protocolo customizado registrado por register-protocol.ps1 - um link
# biblioteca-cmd-run:<comando url-encoded> abre um cmd novo, digita o
# comando e aperta Enter (launch-command.vbs). Some sem erro em navegador/
# maquina sem o protocolo registrado - so o clipboard (fallback de sempre)
# continua funcionando.
function Get-LaunchUri([string]$cmdText) {
    return 'biblioteca-cmd-run:' + [Uri]::EscapeDataString($cmdText)
}

function Get-CardCommands([PSCustomObject]$card) {
    # Envolvido em "powershell -NoProfile -Command" pra funcionar colado tanto
    # no cmd.exe (onde ; nao separa comandos, quebrava o cd) quanto no
    # PowerShell - independe do shell padrao do usuario.
    # $hubRoot vem do escopo de quem dot-source este arquivo (build-dashboard.ps1
    # ja define antes de chamar; test-dashboard-lib.ps1 define um valor de teste).
    $base = "cd '$hubRoot'"
    # Task/Repo vem do frontmatter (so' Trim() em Clean-Field, sem validar
    # caractere) e vai dentro de uma string PowerShell de aspas simples -
    # um apostrofo sem escapar fecharia a string cedo e quebraria o comando
    # gerado. Escapa dobrando a aspas simples, mesmo padrao ja usado em
    # nova-task.html pro mesmo problema.
    $safeTask = "$($card.Task)".Replace("'", "''")
    $safeRepo = "$($card.Repo)".Replace("'", "''")
    $cmds = New-Object System.Collections.Generic.List[PSCustomObject]
    if ($card.Active) {
        $cmd = "powershell -NoProfile -Command `"$base; claude 'retomar task $safeTask no repo $safeRepo'`""
        $cmds.Add([PSCustomObject]@{ Label = 'Retomar task'; Class = 'copy-btn'; Cmd = $cmd; Uri = (Get-LaunchUri $cmd) })
    }
    $qaCmd = "powershell -NoProfile -Command `"$base; claude 'ajustar qa task $safeTask no repo $safeRepo'`""
    $cmds.Add([PSCustomObject]@{ Label = 'Reabrir p/ QA'; Class = 'copy-btn qa-btn'; Cmd = $qaCmd; Uri = (Get-LaunchUri $qaCmd) })
    return $cmds
}

# Ordenacao logica (nao alfabetica pura): backend + frontend/mfe/mobile do
# mesmo dominio ficam juntos ([org-]app-settings-backend do lado de
# [org-]mfe-settings), dominios em ordem alfabetica, repos sem esse padrao
# (migrations, geral) depois dos pares, e os listados em $lastRepos
# (config `reposAoFim` - ex.: repos de skills, nao-projeto) sempre por
# ultimo. $aliases (config `repoAliases`) junta dominios com nome diferente
# entre back e front (ex.: mfe-schedule + app-scheduling-backend). Descarta
# entradas malformadas (valor com virgula/espaco vindo de frontmatter com
# 2 repos no mesmo campo por engano - nao e' pasta de verdade).
function Get-RepoSortKey([string]$repo, [string[]]$lastRepos = @(), $aliases = @{}) {
    if (@($lastRepos | ForEach-Object { $_.ToLowerInvariant() }) -contains $repo.ToLowerInvariant()) {
        return [PSCustomObject]@{ Bucket = 2; Domain = ''; SubOrder = 0; Name = $repo }
    }
    $domain = $null
    $subOrder = 3
    if ($repo -match '^(?:[^-]+-)?app-(.+)-backend$') { $domain = $Matches[1]; $subOrder = 0 }
    elseif ($repo -match '^(?:[^-]+-)?mfe-(.+)$') { $domain = $Matches[1]; $subOrder = 1 }
    elseif ($repo -match '^(?:[^-]+-)?mobile-(.+)$') { $domain = $Matches[1]; $subOrder = 2 }

    if ($domain) {
        if ($aliases.ContainsKey($domain)) { $domain = $aliases[$domain] }
        return [PSCustomObject]@{ Bucket = 0; Domain = $domain; SubOrder = $subOrder; Name = $repo }
    }
    return [PSCustomObject]@{ Bucket = 1; Domain = ''; SubOrder = 0; Name = $repo }
}

# Pedacos de HTML compartilhados pelas 3 funcoes que montam um card
# (Build-Card, Build-QaRoundCard, Build-UnifiedQaRoundCard, em
# build-dashboard.ps1) - cabecalho/subtitulos/rodape sao IDENTICOS nos 3
# tipos de card, so' o conteudo do meio muda (chips normais vs campos de
# QA). Antes cada funcao escrevia esse HTML na mao, em 3 copias
# independentes - foi assim que o titulo_busca ficou faltando no card de
# QA (2026-09-10) ate o usuario notar, e o botao de expandir precisou de
# find-and-replace em 3 lugares pra mudar de posicao. Qualquer ajuste
# visual de cabecalho/subtitulos/rodape entra AQUI, nunca direto dentro
# de Build-Card/Build-QaRoundCard/Build-UnifiedQaRoundCard - se um dia
# precisar de mais um tipo de card, ele tambem chama essas 3 funcoes, nao
# escreve o HTML de novo.

# --- Delegadas (pagina time.html) ---------------------------------------
# Valor de uma linha `| Campo | valor |` da tabela "Analise" de um doc
# `delegada` - casa pelo prefixo ASCII do rotulo (Tela/Causa/Aten), nunca
# pelo rotulo inteiro com acento (.ps1 sem BOM corrompe acento literal).
function Get-DelegadaField([string]$body, [string]$labelPrefix) {
    $m = [regex]::Match($body, "(?m)^\|\s*\**$labelPrefix[^|]*\|\s*(.+?)\s*\|\s*$")
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return ''
}

# Ultima rodada de review registrada pela skill delegar-task
# (`### Rodada N - data - PR #X - <veredito>` dentro de `## Review`) + a
# linha `**Resumo:**` dela. Veredito pelo texto do titulo: "Ajustes
# solicitados" / "Aprovado" (convencao fixa da skill).
function Get-DelegadaReview([string]$body) {
    $rounds = [regex]::Matches($body, '(?m)^### Rodada.*$')
    if ($rounds.Count -eq 0) { return $null }
    $last = $rounds[$rounds.Count - 1]
    $heading = $last.Value.Substring(4).Trim()
    $tail = $body.Substring($last.Index + $last.Length)
    $next = [regex]::Match($tail, '(?m)^#{2,3} ')
    if ($next.Success) { $tail = $tail.Substring(0, $next.Index) }
    $resumo = [regex]::Match($tail, '\*\*Resumo:\*\*\s*(.+)')
    $verdict = if ($heading -match '(?i)ajuste|mudan') { 'ajustes' } elseif ($heading -match '(?i)aprovad') { 'aprovado' } else { 'comentado' }
    return [PSCustomObject]@{
        Count   = $rounds.Count
        Heading = $heading
        Resumo  = if ($resumo.Success) { $resumo.Groups[1].Value.Trim() } else { '' }
        Verdict = $verdict
    }
}

function Get-CardHeadHtml([string]$title, [string]$rightIconsHtml) {
    return @"
  <div class="card-head">
    <div class="card-head-left">
      <span class="card-title" title="$(Esc $title)">$(Esc $title)</span>
    </div>
    <div class="card-head-right">
      $rightIconsHtml
    </div>
  </div>
"@
}

# $label = o "titulo antigo" (Task NNN - Layer, ou o label de QA#N) -
# $showLabel controla se ele aparece como subtitulo (so' quando o card
# tem titulo_busca preenchido, senao seria a mesma linha repetida 2x).
function Get-CardSubtitlesHtml([string]$label, [bool]$showLabel, [string]$repo) {
    $labelHtml = if ($showLabel) { "<div class=`"subtitle-line`"><span class=`"task-id`" title=`"$(Esc $label)`">$(Esc $label)</span></div>" } else { '' }
    return @"
  <div class="subtitles">
    $labelHtml
    <div class="repo-line"><span class="repo" title="$(Esc $repo)">$(Esc $repo)</span></div>
  </div>
"@
}

function Get-CardFootHtml([string]$updatedHtml, [string]$btnsHtml, [string]$chevronIcon) {
    return @"
  <div class="card-foot">
    $updatedHtml
    $btnsHtml
    <button class="expand-btn" type="button" title="Expandir" aria-label="Expandir">$chevronIcon</button>
  </div>
"@
}
