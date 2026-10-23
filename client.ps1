# ============================================================
#  VZX Remote Client — PowerShell
#  Roda no PC do cliente, sem instalar nada
#  Busca comandos do painel web e executa no jogo
# ============================================================

# ── Limpa histórico do PowerShell ao iniciar ────────────────
try {
    $histFile = (Get-PSReadLineOption).HistorySavePath
    if (Test-Path $histFile) {
        # Remove as últimas linhas que contêm a URL do painel
        $lines = Get-Content $histFile | Where-Object { $_ -notmatch "wwwremotefivem" -and $_ -notmatch "irm " -and $_ -notmatch "iex " }
        $lines | Set-Content $histFile -Encoding UTF8
    }
} catch {}

# ── Desativa logging de script block pra essa sessão ────────
try {
    $null = [System.Diagnostics.EventLog]::SourceExists("")
    Set-PSDebug -Off
    # Limpa variável de histórico em memória
    [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
} catch {}

# ── URL do painel ────────────────────────────────────────────
$API_URL      = "https://wwwremotefivem.netlify.app/api/get-cmd"
$CONFIG_URL   = "https://wwwremotefivem.netlify.app/api/config"
$PROCESS_NAME = "GTA5"
$INTERVAL     = 3

Write-Host ""
Write-Host "  ██╗   ██╗███████╗██╗  ██╗" -ForegroundColor Yellow
Write-Host "  ██║   ██║╚══███╔╝╚██╗██╔╝" -ForegroundColor Yellow
Write-Host "  ██║   ██║  ███╔╝  ╚███╔╝ " -ForegroundColor Yellow
Write-Host "  ╚██╗ ██╔╝ ███╔╝   ██╔██╗ " -ForegroundColor Yellow
Write-Host "   ╚████╔╝ ███████╗██╔╝ ██╗" -ForegroundColor Yellow
Write-Host "    ╚═══╝  ╚══════╝╚═╝  ╚═╝" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Remote Panel Client v1.0" -ForegroundColor Cyan
Write-Host "  Processo alvo: $PROCESS_NAME" -ForegroundColor Gray
Write-Host ""
Write-Host "  Aguardando comandos do painel..." -ForegroundColor Green
Write-Host "  Pressione CTRL+C para parar." -ForegroundColor DarkGray
Write-Host ""

$wshell  = New-Object -ComObject WScript.Shell
$lastCmd = ""

# ── Ao fechar (CTRL+C) limpa os rastros ─────────────────────
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    try {
        # Limpa histórico
        $histFile = (Get-PSReadLineOption).HistorySavePath
        if (Test-Path $histFile) {
            $lines = Get-Content $histFile | Where-Object {
                $_ -notmatch "wwwremotefivem" -and
                $_ -notmatch "irm " -and
                $_ -notmatch "iex " -and
                $_ -notmatch "client\.ps1"
            }
            $lines | Set-Content $histFile -Encoding UTF8
        }
        # Limpa memória do histórico
        try { [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory() } catch {}
    } catch {}
}

while ($true) {
    try {
        $resp = Invoke-WebRequest -Uri $API_URL -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $cmd  = $resp.Content.Trim()

        if (-not [string]::IsNullOrEmpty($cmd) -and $cmd -ne $lastCmd) {
            $lastCmd = $cmd
            $proc = Get-Process -Name $PROCESS_NAME -ErrorAction SilentlyContinue
            if ($proc) {
                $ativou = $false
                foreach ($p in $proc) {
                    if (-not [string]::IsNullOrEmpty($p.MainWindowTitle)) {
                        if ($wshell.AppActivate($p.MainWindowTitle)) {
                            $ativou = $true; break
                        }
                    }
                }
                if (-not $ativou) { $ativou = $wshell.AppActivate($PROCESS_NAME) }
                if ($ativou) {
                    Start-Sleep -Milliseconds 150
                    $wshell.SendKeys($cmd)
                    Write-Host "  [$(Get-Date -Format 'HH:mm:ss')] ✓ Enviado: $cmd" -ForegroundColor Green
                } else {
                    Write-Host "  [$(Get-Date -Format 'HH:mm:ss')] ⚠ Janela nao encontrada." -ForegroundColor Yellow
                }
            } else {
                Write-Host "  [$(Get-Date -Format 'HH:mm:ss')] ⚠ Processo '$PROCESS_NAME' nao encontrado." -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "  [$(Get-Date -Format 'HH:mm:ss')] ✗ Erro de conexao." -ForegroundColor Red
    }
    Start-Sleep -Seconds $INTERVAL
}
