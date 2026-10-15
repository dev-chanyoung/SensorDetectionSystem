# Unattended evening queue: saturation search -> 2x2x2 factorial -> show-sql repeat. Run it HIDDEN with redirected output.
# Waits until the laptop is on AC power (does not start on battery), then runs the cli-queue phases one after another.
param([int]$WaitAcMin = 180, [switch]$DryRun)
$ErrorActionPreference = 'Continue'
$Root = $PSScriptRoot
Set-Location $Root
$Log = Join-Path $Root 'run-home.log'
function Log([string]$m) {
    $l = "$(Get-Date -Format 'MM-dd HH:mm:ss') [run-home] $m"
    for ($i = 0; $i -lt 10; $i++) { try { [IO.File]::AppendAllText($Log, $l + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false))); break } catch { Start-Sleep -Milliseconds 400 } }
}
function OnAc { $b = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue; return (($null -eq $b) -or ($b.BatteryStatus -ne 1)) }

$phases = @(
    @{ Phase = 7; Reps = 2; Tag = 'sat' },
    @{ Phase = 8; Reps = 3; Tag = 'fac' },
    @{ Phase = 9; Reps = 5; Tag = 'sql' }
)
if ($DryRun) { $phases | ForEach-Object { "phase $($_.Phase) reps $($_.Reps) tag $($_.Tag)" }; return }

Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public class KeepAwake { [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f); }'
[void][KeepAwake]::SetThreadExecutionState([uint32]2147483649)   # keep the PC awake while running

$waited = 0
while (-not (OnAc)) {
    if ($waited -eq 0) { Log 'on battery - waiting for AC power before starting' }
    if ($waited -ge $WaitAcMin * 60) { Log 'AC power never connected - giving up'; return }
    Start-Sleep -Seconds 30; $waited += 30
}
Log "start (AC ok, waited $waited s)"
foreach ($ph in $phases) {
    Log "phase $($ph.Phase) (tag $($ph.Tag), reps $($ph.Reps)) start"
    $p = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Root\cli-queue.ps1`"", '-Phase', $ph.Phase, '-Reps', $ph.Reps, '-Tag', $ph.Tag) `
        -WorkingDirectory $Root -WindowStyle Hidden -PassThru -Wait `
        -RedirectStandardOutput "$Root\logs\home-p$($ph.Phase).out.txt" -RedirectStandardError "$Root\logs\home-p$($ph.Phase).err.txt"
    Log "phase $($ph.Phase) end (exit $($p.ExitCode))"
}
Log 'run-home FINISHED'
[void][KeepAwake]::SetThreadExecutionState([uint32]2147483648)
