# Start-mode matrix: does the window state or the output target of the measurement script change the error rate?
#   A = minimized console window, output to the console   (the old "bad" way)
#   B = hidden window, stdout/stderr redirected to files   (the "good" way)
#   C = minimized console window, output redirected to files
#   D = hidden window, output to its (invisible) console
# Each block runs the same condition (verify-s-t7: sync Tomcat 7, 5000/5/10) twice; blocks alternate A B C D, repeated -Rounds times.
# A background sampler records the power-throttling (EcoQoS) state and priority of java/powershell processes every 15 s (logs/throttle.csv).
param([int]$Rounds = 2)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Set-Location $Root
$Log = Join-Path $Root 'cli-queue.log'
function Log([string]$m) {
    $l = "$(Get-Date -Format 'MM-dd HH:mm:ss') [run-matrix] $m"
    for ($i = 0; $i -lt 10; $i++) { try { [IO.File]::AppendAllText($Log, $l + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false))); break } catch { Start-Sleep -Milliseconds 400 } }
    Write-Host $l
}

$throttleCsv = Join-Path $Root 'logs\throttle.csv'
$sampler = Start-Job -ArgumentList $throttleCsv -ScriptBlock {
    param($csv)
    try {
        Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class Eco { [StructLayout(LayoutKind.Sequential)] public struct PPT { public uint Version; public uint ControlMask; public uint StateMask; } [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetProcessInformation(IntPtr h, int cls, ref Eco.PPT info, int size); }'
    } catch { }
    'time,pid,name,priority,control_mask,state_mask,cpu_sec' | Set-Content -Encoding ascii $csv
    while ($true) {
        foreach ($p in @(Get-Process -Name java, powershell -ErrorAction SilentlyContinue)) {
            try {
                $s = New-Object 'Eco+PPT'; $s.Version = 1
                $ok = [Eco]::GetProcessInformation($p.Handle, 4, [ref]$s, 12)
                $line = "{0},{1},{2},{3},{4},{5},{6}" -f (Get-Date -Format 'HH:mm:ss'), $p.Id, $p.ProcessName, $p.PriorityClass, $(if ($ok) { $s.ControlMask } else { 'na' }), $(if ($ok) { $s.StateMask } else { 'na' }), [math]::Round($p.TotalProcessorTime.TotalSeconds, 0)
                [IO.File]::AppendAllText($csv, $line + [Environment]::NewLine)
            } catch { }
        }
        Start-Sleep -Seconds 15
    }
}

$cells = @(
    @{ Key = 'A'; Style = 'Minimized'; Redirect = $false },
    @{ Key = 'B'; Style = 'Hidden';    Redirect = $true },
    @{ Key = 'C'; Style = 'Minimized'; Redirect = $true },
    @{ Key = 'D'; Style = 'Hidden';    Redirect = $false }
)
Log "matrix start: $($cells.Count) cells x $Rounds rounds, 2 runs per block"
try {
    for ($round = 1; $round -le $Rounds; $round++) {
        foreach ($c in $cells) {
            $tag = "x$($c.Key)$round"
            Log "block $tag (window=$($c.Style), redirect=$($c.Redirect))"
            $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Root\cli-queue.ps1`"", '-Phase', '5', '-Reps', '2', '-Tag', $tag)
            if ($c.Redirect) {
                Start-Process powershell -ArgumentList $argList -WorkingDirectory $Root -WindowStyle $c.Style -RedirectStandardOutput "$Root\logs\x-$tag.out.txt" -RedirectStandardError "$Root\logs\x-$tag.err.txt" -Wait
            } else {
                Start-Process powershell -ArgumentList $argList -WorkingDirectory $Root -WindowStyle $c.Style -Wait
            }
        }
    }
} finally {
    Stop-Job $sampler -ErrorAction SilentlyContinue
    Remove-Job $sampler -Force -ErrorAction SilentlyContinue
}
Log 'run-matrix FINISHED'
