# ============================================================
#  VZX Remote Client — PowerShell
#  Roda no PC do cliente, sem instalar nada
#  Busca comandos do painel web e executa no jogo
# ============================================================

# ── URL do painel — troque pela URL do seu Netlify ──────────
$API_URL      = "https://SEU-PAINEL.netlify.app/api/get-cmd"
$CONFIG_URL   = "https://SEU-PAINEL.netlify.app/api/config"
$PROCESS_NAME = "GTA5"   # nome do processo do FiveM sem .exe (pode ser GTA5 ou FiveM)
$INTERVAL     = 3        # segundos entre verificações

# ─────────────────────────────────────────────────────────────

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
Write-Host "  API: $API_URL" -ForegroundColor Gray
Write-Host ""
Write-Host "  Aguardando comandos do painel..." -ForegroundColor Green
Write-Host "  Pressione CTRL+C para parar." -ForegroundColor DarkGray
Write-Host ""

$wshell    = New-Object -ComObject WScript.Shell
$lastCmd   = ""
$lastCfgTs = 0

while ($true) {
    try {
        # ── 1. Busca comando one-shot ────────────────────────
        $resp = Invoke-WebRequest -Uri $API_URL -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $cmd  = $resp.Content.Trim()

        if (-not [string]::IsNullOrEmpty($cmd) -and $cmd -ne $lastCmd) {
            $lastCmd = $cmd

            # Verifica se o processo está rodando
            $proc = Get-Process -Name $PROCESS_NAME -ErrorAction SilentlyContinue
            if ($proc) {
                $ativou = $false

                # Tenta focar a janela pelo título
                foreach ($p in $proc) {
                    if (-not [string]::IsNullOrEmpty($p.MainWindowTitle)) {
                        if ($wshell.AppActivate($p.MainWindowTitle)) {
                            $ativou = $true
                            break
                        }
                    }
                }
                # Fallback pelo nome
                if (-not $ativou) {
                    $ativou = $wshell.AppActivate($PROCESS_NAME)
                }

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
        Write-Host "  [$(Get-Date -Format 'HH:mm:ss')] ✗ Erro: $_" -ForegroundColor Red
    }

    Start-Sleep -Seconds $INTERVAL
}
