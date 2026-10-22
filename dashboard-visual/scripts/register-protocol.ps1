# Setup unico (por maquina) do protocolo customizado "biblioteca-cmd-run:" -
# permite que um link do dashboard/resumo abra direto um cmd novo com o
# comando ja digitado e executado (ver launch-command.vbs), sem copiar/colar
# manual. So HKCU (usuario atual), nao precisa admin. Idempotente - rodar de
# novo so sobrescreve as mesmas chaves.
#
# Desfazer: reg delete "HKCU\Software\Classes\biblioteca-cmd-run" /f

$vbsPath = Join-Path $PSScriptRoot 'launch-command.vbs'
if (-not (Test-Path $vbsPath)) {
    Write-Error "launch-command.vbs nao encontrado em $vbsPath"
    exit 1
}

$keyPath = 'HKCU:\Software\Classes\biblioteca-cmd-run'
New-Item -Path $keyPath -Force | Out-Null
Set-ItemProperty -Path $keyPath -Name '(Default)' -Value 'URL:Biblioteca Cmd Run Protocol'
Set-ItemProperty -Path $keyPath -Name 'URL Protocol' -Value ''

$commandKeyPath = Join-Path $keyPath 'shell\open\command'
New-Item -Path $commandKeyPath -Force | Out-Null
Set-ItemProperty -Path $commandKeyPath -Name '(Default)' -Value "wscript.exe `"$vbsPath`" `"%1`""

# Versoes antigas registravam tambem "biblioteca-cmd:" (sem Enter), que
# ficou sem nenhum botao usando - remove pra nao deixar protocolo orfao.
Remove-Item -Path 'HKCU:\Software\Classes\biblioteca-cmd' -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Protocolo 'biblioteca-cmd-run:' registrado (HKCU) -> $vbsPath" -ForegroundColor Green
Write-Host 'Pra desfazer:  reg delete "HKCU\Software\Classes\biblioteca-cmd-run" /f'
