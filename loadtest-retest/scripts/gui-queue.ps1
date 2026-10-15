# Drives JMeter GUI runs unattended: brings the JMeter window to front, presses Ctrl+R (Start),
# waits until results.jtl has the expected rows, then closes JMeter. Completion is judged by the jtl, not the screen.
# Part 1: finish the already-open 'feb26-gui-noclear-2runs' window (2 runs, no Clear All, gap between runs).
# Part 2: run photo cases 2~6 (feb26 jar, 1000/5/10) one after another.
param(
    [int]$Expected = 10000,
    [int]$GapSec = 10,
    [switch]$SkipNoClear,
    [string[]]$SkipNames = @()
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Log = Join-Path $Root 'gui-queue.log'
function Log([string]$m) { $l = "$(Get-Date -Format 'HH:mm:ss') $m"; Add-Content -Encoding utf8 $Log $l; Write-Host $l }

Add-Type @"
using System; using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, int flags, int extra);
}
"@
Add-Type -AssemblyName System.Windows.Forms

function Get-JMeterProc {
    Get-CimInstance Win32_Process -Filter "Name='java.exe'" | Where-Object { $_.CommandLine -match 'ApacheJMeter' } |
        ForEach-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue } | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
}
function Wait-JMeterWindow([int]$timeoutSec = 600) {
    $end = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $end) { $p = Get-JMeterProc; if ($p) { return $p }; Start-Sleep -Seconds 2 }
    throw 'JMeter window did not appear'
}
function Focus-Window($p) {
    [W]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
    [W]::keybd_event(0x12, 0, 0, 0); [W]::keybd_event(0x12, 0, 2, 0)   # Alt tap: allows SetForegroundWindow
    [W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 800
}
function Count-Rows([string]$jtl) {
    if (-not (Test-Path $jtl)) { return 0 }
    $fs = [IO.File]::Open($jtl, 'Open', 'Read', 'ReadWrite'); $sr = New-Object IO.StreamReader($fs)
    $n = 0; while ($null -ne $sr.ReadLine()) { $n++ }; $sr.Close(); $fs.Close()
    return [Math]::Max(0, $n - 1)
}
function Find-ResultDir([string]$name, [int]$timeoutSec = 300) {
    $end = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $end) {
        $d = Get-ChildItem (Join-Path $Root 'results') -Directory -Filter "*_$name" -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
        if ($d) { return $d.FullName }
        Start-Sleep -Seconds 2
    }
    throw "result dir not found: $name"
}
function Press-Start([string]$jtl, [int]$targetRows) {
    for ($try = 1; $try -le 4; $try++) {
        $p = Wait-JMeterWindow 60
        Focus-Window $p
        [Windows.Forms.SendKeys]::Send('^r')
        Log "Ctrl+R sent (try $try)"
        Start-Sleep -Seconds 6
        if ((Count-Rows $jtl) -gt 0 -and (Count-Rows $jtl) -gt ($targetRows - $Expected)) { return }
    }
    throw 'Start did not take effect (no new rows in jtl)'
}
function Wait-Rows([string]$jtl, [int]$targetRows, [int]$timeoutSec = 900) {
    $end = (Get-Date).AddSeconds($timeoutSec); $stable = 0; $prev = -1
    while ((Get-Date) -lt $end) {
        $n = Count-Rows $jtl
        if ($n -ge $targetRows -and $n -eq $prev) { $stable++ } else { $stable = 0 }
        if ($stable -ge 3) { Log "rows=$n reached"; return }
        $prev = $n; Start-Sleep -Seconds 2
    }
    throw "timeout waiting for $targetRows rows (have $prev)"
}
function Close-JMeter {
    $p = Get-JMeterProc
    if (-not $p) { return }
    $p.CloseMainWindow() | Out-Null
    if (-not $p.WaitForExit(8000)) {
        Focus-Window $p; [Windows.Forms.SendKeys]::Send('n'); Start-Sleep -Seconds 3
    }
    if (-not $p.HasExited) { Log 'JMeter did not close gracefully; killing it'; Stop-Process -Id $p.Id -Force }
}
function Wait-Summary([string]$dir, [int]$timeoutSec = 600) {
    $end = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $end) { if (Test-Path (Join-Path $dir 'summary.md')) { return }; Start-Sleep -Seconds 3 }
    throw "summary.md not produced in $dir"
}

# ---- Part 1: window already open for feb26-gui-noclear-2runs ----
if (-not $SkipNoClear) {
    $name = 'feb26-gui-noclear-2runs'
    $dir = Find-ResultDir $name; $jtl = Join-Path $dir 'results.jtl'
    Wait-JMeterWindow | Out-Null
    Log "[$name] run 1"
    Press-Start $jtl $Expected; Wait-Rows $jtl $Expected
    Log "[$name] waiting $GapSec s without Clear All"; Start-Sleep -Seconds $GapSec
    Log "[$name] run 2"
    Press-Start $jtl (2 * $Expected); Wait-Rows $jtl (2 * $Expected)
    Close-JMeter; Wait-Summary $dir; Log "[$name] done"
}

# ---- Part 2: photo cases 2~6 ----
$cases = @(
    @{ Name = 'feb26-gui-c1-console'; Console = $true },   # case 1 settings (jar defaults), app stdout in a visible console window
    @{ Name = 'feb26-gui-c2'; Pool = 50; Max = 400; Min = 50; Accept = 500 },
    @{ Name = 'feb26-gui-c3'; Pool = 40; Max = 200; Min = 50; Accept = 1000 },
    @{ Name = 'feb26-gui-c4'; Pool = 20; Max = 100; Min = 50; Accept = 200 },
    @{ Name = 'feb26-gui-c5'; Pool = 32; Max = 200; Min = 50; Accept = 500 },
    @{ Name = 'feb26-gui-c6'; Pool = 30; Max = 200; Min = 50; Accept = 100 }
)
foreach ($c in $cases) {
    if ($SkipNames -contains $c.Name) { continue }
    $cmd = "& '$Root\run-case.ps1' -Name $($c.Name) -Jar feb26 -Gui -Threads 1000 -Ramp 5 -Loops 10 -CooldownSec 30"
    if ($c.Pool) {
        $cmd += " -ExtraAppArgs '--spring.datasource.hikari.maximum-pool-size=$($c.Pool)','--server.tomcat.threads.max=$($c.Max)','--server.tomcat.threads.min=$($c.Min)','--server.tomcat.accept-count=$($c.Accept)'"
    }
    if ($c.Console) { $cmd += ' -ConsoleApp' }
    Log "[$($c.Name)] start: pool=$($c.Pool) max=$($c.Max) min=$($c.Min) accept=$($c.Accept) console=$($c.Console)"
    $proc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmd -PassThru -WindowStyle Minimized
    try {
        $dir = Find-ResultDir $c.Name; $jtl = Join-Path $dir 'results.jtl'
        Wait-JMeterWindow | Out-Null
        Press-Start $jtl $Expected; Wait-Rows $jtl $Expected
        Close-JMeter; Wait-Summary $dir; Log "[$($c.Name)] done"
    } catch {
        Log "[$($c.Name)] FAILED: $_"
        Close-JMeter
        if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
        Get-CimInstance Win32_Process -Filter "Name='java.exe'" | Where-Object { $_.CommandLine -match 'feb26\.jar' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    }
    if (-not $proc.HasExited) { $proc.WaitForExit(60000) | Out-Null }
}
Log 'queue finished'
