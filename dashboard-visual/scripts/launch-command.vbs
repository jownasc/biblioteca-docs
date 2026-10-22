' Handler do protocolo custom "biblioteca-cmd-run:" registrado via
' register-protocol.ps1. Recebe a URI clicada no dashboard/resumo
' (biblioteca-cmd-run:<comando url-encoded>), abre um cmd novo, DIGITA o
' comando decodificado e aperta Enter. A confirmacao fica dentro de cada
' fluxo (a skill rele os docs antes de agir; o prompt do Nova Task pede
' confirmacao do work item antes de gravar). O antigo "biblioteca-cmd:"
' (sem Enter) nao tinha mais nenhum botao usando e foi removido - um
' protocolo registrado sem uso e' so' superficie de ataque.
Option Explicit

Dim uri, prefixRun, encoded, decoded, shell

If WScript.Arguments.Count < 1 Then WScript.Quit 1
uri = WScript.Arguments(0)

prefixRun = "biblioteca-cmd-run:"
If LCase(Left(uri, Len(prefixRun))) <> prefixRun Then WScript.Quit 1
encoded = Mid(uri, Len(prefixRun) + 1)

decoded = UrlDecode(encoded)

' Allowlist antes de digitar/executar. O registro do protocolo (ver
' register-protocol.ps1) e' global em HKCU - QUALQUER app/pagina do
' sistema pode invocar "biblioteca-cmd-run:<payload>", nao so' o
' dashboard.html local. Sem essa checagem, um payload arbitrario de
' origem nenhuma confiavel seria digitado e executado (com Enter
' automatico na variante -run) sem revisao nenhuma - achado real da
' auditoria de 2026-08-24 (2 de 3 revisores blind apontaram isso
' independentemente). Toda invocacao legitima gerada hoje
' (build-dashboard.ps1 Get-CardCommands/quick-open, nova-task.html)
' comeca exatamente com este prefixo e termina com a aspa dupla que fecha
' o "-Command "..."" do PowerShell, sem outra aspa dupla nem quebra de
' linha no meio (ver IsAllowedCommand); qualquer coisa fora disso e'
' bloqueada.
If Not IsAllowedCommand(decoded) Then
    MsgBox "Comando bloqueado - nao bate com o formato esperado do protocolo biblioteca-cmd. Se voce clicou isso a partir do dashboard.html da Biblioteca, isso e' um bug (avise o autor); se veio de outro lugar, o bloqueio e' o comportamento certo.", vbExclamation, "Biblioteca - comando bloqueado"
    WScript.Quit 1
End If

' AppActivate por "cmd.exe" batia por substring de titulo contra QUALQUER
' janela existente, nao so' a que acabamos de abrir - se o usuario ja
' tinha outro cmd.exe aberto (ou clicava 2 botoes rapido), o SendKeys podia
' ir pra janela errada: a nova ficava vazia, a antiga recebia o comando
' (ponto fragil real, apontado em 2026-09-01). Correcao: a janela nova
' recebe um titulo unico (marker aleatorio via "title") antes de qualquer
' SendKeys, e so ativamos por ESSE titulo - impossivel casar com janela
' pre-existente. AppActivate retorna False se nao achar o titulo ainda
' (janela demorando a subir) - tenta de novo por ate 2s antes de desistir.
Dim marker, activated, attempts
Randomize
marker = "BibliotecaCmd_" & CStr(Int(Timer * 1000)) & "_" & CStr(Int(Rnd * 100000))

Set shell = CreateObject("WScript.Shell")
shell.Run "cmd.exe /k title " & marker, 1, False

activated = False
attempts = 0
Do While (Not activated) And (attempts < 20)
    WScript.Sleep 100
    activated = shell.AppActivate(marker)
    attempts = attempts + 1
Loop

If Not activated Then
    MsgBox "Nao consegui focar a janela do cmd que acabou de abrir. O comando ja esta' no clipboard - cole com Ctrl+V na janela e aperte Enter.", vbExclamation, "Biblioteca - foco falhou"
    WScript.Quit 1
End If

WScript.Sleep 100
shell.SendKeys EscapeSendKeys(decoded)
shell.SendKeys "{ENTER}"

' Formato exato que todo gerador legitimo usa (Get-CardCommands/
' Get-LaunchUri em build-dashboard.ps1, o builder em nova-task.html):
' powershell -NoProfile -Command "cd '<path>'; claude [...]
Const EXPECTED_PREFIX = "powershell -NoProfile -Command ""cd '"

' cmd.exe trata &|<> como literal (nao como operador de encadeamento)
' enquanto estiver dentro de uma regiao entre aspas duplas balanceadas -
' e' assim que "-Command "..."" ja protege o payload inteiro (cd + claude
' '<frase>') hoje. O bloqueio antigo (qualquer &|<> em QUALQUER lugar da
' string) travava demanda legitima toda vez que a frase/link do Azure
' colado tinha um "&" (bug real, 2026-09-01: link de work item com
' querystring "?...&_a=edit" bloqueava o botao "Abrir Claude" do Nova
' Task). O que continua perigoso de verdade e': (1) uma aspa dupla a mais
' no meio, que fecharia a string do PowerShell cedo e devolveria o resto
' pro cmd.exe como comando de verdade - por isso o payload nunca pode
' ter uma 3a aspa dupla alem das 2 que delimitam ele (a que fecha
' EXPECTED_PREFIX e a ultima do comando); (2) quebra de linha via
' SendKeys, que equivale a apertar Enter no meio e nao tem protecao de
' aspas nenhuma - continua bloqueada sempre, mesmo dentro do miolo.
Function IsAllowedCommand(cmd)
    Dim prefixOk, endsWithQuote, inner, hasStrayQuote, hasLineBreak
    prefixOk = (Left(cmd, Len(EXPECTED_PREFIX)) = EXPECTED_PREFIX)
    endsWithQuote = (Len(cmd) > Len(EXPECTED_PREFIX)) And (Right(cmd, 1) = Chr(34))
    If Not prefixOk Or Not endsWithQuote Then
        IsAllowedCommand = False
        Exit Function
    End If
    inner = Mid(cmd, Len(EXPECTED_PREFIX) + 1, Len(cmd) - Len(EXPECTED_PREFIX) - 1)
    hasStrayQuote = InStr(inner, Chr(34)) > 0
    hasLineBreak = (InStr(inner, Chr(13)) > 0) Or (InStr(inner, Chr(10)) > 0)
    IsAllowedCommand = (Not hasStrayQuote) And (Not hasLineBreak)
End Function

Function UrlDecode(s)
    Dim result, i, ch, hex
    result = ""
    i = 1
    Do While i <= Len(s)
        ch = Mid(s, i, 1)
        If ch = "%" And i + 2 <= Len(s) Then
            hex = Mid(s, i + 1, 2)
            result = result & Chr(CLng("&H" & hex))
            i = i + 3
        ElseIf ch = "+" Then
            result = result & " "
            i = i + 1
        Else
            result = result & ch
            i = i + 1
        End If
    Loop
    UrlDecode = result
End Function

' SendKeys trata + ^ % ~ ( ) { } [ ] como especiais - envolver cada um em
' chaves faz literal (regra padrao do SendKeys, ver docs do VBScript).
Function EscapeSendKeys(s)
    Dim i, ch, result
    result = ""
    For i = 1 To Len(s)
        ch = Mid(s, i, 1)
        Select Case ch
            Case "{": result = result & "{{}"
            Case "}": result = result & "{}}"
            Case "+": result = result & "{+}"
            Case "^": result = result & "{^}"
            Case "%": result = result & "{%}"
            Case "~": result = result & "{~}"
            Case "(": result = result & "{(}"
            Case ")": result = result & "{)}"
            Case "[": result = result & "{[}"
            Case "]": result = result & "{]}"
            Case Else: result = result & ch
        End Select
    Next
    EscapeSendKeys = result
End Function
