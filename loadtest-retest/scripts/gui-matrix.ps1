# GUI measurement matrix (run at the library; you press Start in the JMeter window each time).
# Same 5000/5/10 load, JMeter GUI with the February listeners, alternating window state (front vs minimized)
# and build (sync Tomcat 7 / MQ Tomcat 12 consumer 1 prefetch 10), -Rounds rounds of 4 trials.
# Per trial: run-case.ps1 -Gui starts the app, warms up, resets data, opens the JMeter GUI; a small notice box tells you what to do.
# Run this script HIDDEN with redirected output (never minimized).
param([int]$Rounds = 3, [int]$StartIndex = 1, [int]$EndIndex = 0, [string]$Builds = 'SM', [string]$Tag = '', [switch]$CpuLog, [switch]$DryRun)
$ErrorActionPreference = 'Continue'
$Root = $PSScriptRoot
Set-Location $Root
$Log = Join-Path $Root 'gui-matrix.log'
$Csv = Join-Path $Root 'gui-matrix-results.csv'
function Log([string]$m) {
    $l = "$(Get-Date -Format 'MM-dd HH:mm:ss') [gui-matrix] $m"
    for ($i = 0; $i -lt 10; $i++) { try { [IO.File]::AppendAllText($Log, $l + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false))); break } catch { Start-Sleep -Milliseconds 400 } }
}
function Append-Line([string]$path, [string]$line) {
    for ($i = 0; $i -lt 10; $i++) { try { [IO.File]::AppendAllText($path, $line + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false))); break } catch { Start-Sleep -Milliseconds 400 } }
}

$S = @{ Key = 'S'; Label = 'SYNC Tomcat 7'; Jar = 'c-fae13e0'; T = 7; C = 0; P = 0 }
$M = @{ Key = 'M'; Label = 'MQ Tomcat 12'; Jar = 'c-c3bfdee'; T = 12; C = 1; P = 10 }
$trials = @()
for ($r = 1; $r -le $Rounds; $r++) {
    if ($r % 2 -eq 1) { $seq = @(@($S, 'front'), @($S, 'min'), @($M, 'front'), @($M, 'min')) }
    else { $seq = @(@($S, 'min'), @($S, 'front'), @($M, 'min'), @($M, 'front')) }
    foreach ($x in $seq) { $trials += [pscustomobject]@{ Round = $r; Cond = $x[0]; Win = $x[1] } }
}
$trials = @($trials | Where-Object { $Builds.Contains([string]$_.Cond.Key) })   # -Builds S = sync only, M = MQ only
$total = $trials.Count
if ($DryRun) {
    $i = 0
    foreach ($t in $trials) { $i++; '{0,2}/{1}  round {2}  {3,-14} window={4}' -f $i, $total, $t.Round, $t.Cond.Label, $t.Win }
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System.Runtime.InteropServices;
public class KeepAwake { [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f); }
"@
[void][KeepAwake]::SetThreadExecutionState([uint32]2147483649)   # keep the PC awake while running

$dockerBin = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin'
if (Test-Path $dockerBin) { $env:Path += ";$dockerBin" }
$running = (& docker ps --format '{{.Names}}') -join ' '
foreach ($n in @('safecar-redis', 'safecar-rabbitmq')) { if ($running -notmatch $n) { Log "starting container $n"; & docker start $n | Out-Null } }
for ($i = 0; $i -lt 30; $i++) { if ((& docker exec safecar-redis redis-cli PING 2>$null) -match 'PONG') { break }; Start-Sleep -Seconds 2 }

if (-not (Test-Path $Csv)) { 'name,round,build,window,error_pct,tps_all,tps_success,dir' | Set-Content -Encoding utf8 $Csv }

function Show-Notice([string]$text) {
    $env:GUI_NOTICE = $text
    $ps = 'Add-Type -AssemblyName System.Windows.Forms; $f = New-Object Windows.Forms.Form; $f.TopMost = $true; $f.StartPosition = "CenterScreen"; $f.Width = 1; $f.Height = 1; $f.ShowInTaskbar = $false; $f.Show(); [void][Windows.Forms.MessageBox]::Show($f, $env:GUI_NOTICE, "SafeCar GUI test", "OK", "Information"); $f.Close()'
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ps))
    Start-Process powershell -ArgumentList '-NoProfile', '-WindowStyle', 'Hidden', '-EncodedCommand', $enc -WindowStyle Hidden | Out-Null
}
function Get-JMeterGui {
    Get-CimInstance Win32_Process -Filter "Name='java.exe'" | Where-Object { $_.CommandLine -match 'ApacheJMeter' -and $_.CommandLine -notmatch '\s-n\s' } |
        ForEach-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue } | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
}
function Read-Summary([string]$dir) {
    $s = Get-Content (Join-Path $dir 'summary.md') -Raw -Encoding UTF8
    $e = if ($s -match '([\d.]+)%\*\*\)') { $Matches[1] } else { '' }
    $t = if ($s -match 'Throughput\(.*?\) ([\d,.]+)/s') { $Matches[1] -replace ',', '' } else { '' }
    $st = if ($s -match '([\d,.]+)/s\*\*') { $Matches[1] -replace ',', '' } else { '' }
    return @($e, $t, $st)
}

function Start-CpuSampler([string]$csv, [string]$stopFile) {
    Start-Job -ArgumentList $csv, $stopFile -ScriptBlock {
        param($csv, $stop)
        $cores = [Environment]::ProcessorCount
        'time,app_pct,jmeter_pct,postgres_pct,docker_pct,other_pct,total_pct' | Set-Content -Encoding ascii $csv
        while (-not (Test-Path $stop)) {
            Start-Sleep -Milliseconds 700
            $kind = @{}
            foreach ($w in @(Get-CimInstance Win32_Process -Filter "Name='java.exe'" -ErrorAction SilentlyContinue)) {
                $kind[[int]$w.ProcessId] = $(if ($w.CommandLine -match 'ApacheJMeter') { 'jmeter' } else { 'app' })
            }
            $sum = @{ app = 0.0; jmeter = 0.0; postgres = 0.0; docker = 0.0; other = 0.0 }
            foreach ($p in @(Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction SilentlyContinue)) {
                if ($p.Name -eq '_Total' -or $p.Name -eq 'Idle') { continue }
                $g = if ($kind.ContainsKey([int]$p.IDProcess)) { $kind[[int]$p.IDProcess] } elseif ($p.Name -match '^postgres') { 'postgres' } elseif ($p.Name -match '^(com\.docker|vmmem|Docker Desktop|wslhost|wslservice)') { 'docker' } else { 'other' }
                $sum[$g] += [double]$p.PercentProcessorTime / $cores
            }
            $tot = $sum.app + $sum.jmeter + $sum.postgres + $sum.docker + $sum.other
            $line = '{0},{1},{2},{3},{4},{5},{6}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), [math]::Round($sum.app, 1), [math]::Round($sum.jmeter, 1), [math]::Round($sum.postgres, 1), [math]::Round($sum.docker, 1), [math]::Round($sum.other, 1), [math]::Round($tot, 1)
            for ($i = 0; $i -lt 5; $i++) { try { [IO.File]::AppendAllText($csv, $line + [Environment]::NewLine); break } catch { Start-Sleep -Milliseconds 200 } }
        }
    }
}
function Stop-CpuSampler($job, [string]$stopFile) {
    if ($null -eq $job) { return }
    New-Item -ItemType File $stopFile -Force | Out-Null
    Wait-Job $job -Timeout 15 | Out-Null
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Item $stopFile -ErrorAction SilentlyContinue
}
Log "start: $total trials ($Rounds rounds), start index $StartIndex"
$k = 0
foreach ($t in $trials) {
    $k++
    if ($k -lt $StartIndex) { continue }
    if ($EndIndex -gt 0 -and $k -gt $EndIndex) { break }
    $c = $t.Cond
    $name = "gui$($c.Key)-$($t.Win)-r$($t.Round)$Tag"
    $runArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Root\run-case.ps1`"", '-Name', $name, '-Jar', $c.Jar,
        '-Threads', '5000', '-Ramp', '5', '-Loops', '10', '-TomcatThreads', $c.T, '-CooldownSec', '90', '-Warmup', '-WaitTimeWait', '-Gui')
    if ($c.C -gt 0) { $runArgs += @('-Consumers', $c.C) }
    if ($c.P -gt 0) { $runArgs += @('-Prefetch', $c.P) }
    Log "[$k/$total] $name start"
    $p = Start-Process powershell -ArgumentList $runArgs -WorkingDirectory $Root -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput "$Root\logs\$name.out.txt" -RedirectStandardError "$Root\logs\$name.err.txt"
    $noticed = $false
    $cpuJob = $null; $cpuStop = Join-Path $Root "logs\.stop-cpu-$name"; $cpuCsv = Join-Path $Root "logs\cpu-$name.csv"
    if ($CpuLog) { Remove-Item $cpuStop -ErrorAction SilentlyContinue; $cpuJob = Start-CpuSampler $cpuCsv $cpuStop }
    while (-not $p.HasExited) {
        Start-Sleep -Seconds 3
        if (-not $noticed -and (Get-JMeterGui)) {
            $noticed = $true
            $head = "[$k/$total]  $($c.Label)`n`n"
            if ($t.Win -eq 'front') {
                $body = "[앞에 두고]`n1) 이 창에서 OK`n2) JMeter 창을 클릭해 맨 앞으로`n3) 초록 Start(Ctrl+R)`n4) 창을 그대로 두고 아무것도 만지지 마세요`n5) 약 60초 뒤 JMeter를 닫으세요(저장 안 함)"
            } else {
                $body = "[최소화]`n1) 이 창에서 OK`n2) JMeter 창을 클릭 -> 초록 Start(Ctrl+R)`n3) Start 직후 바로 JMeter 창을 최소화(-)`n4) 아무것도 만지지 마세요`n5) 약 60초 뒤 창을 복원해서 JMeter를 닫으세요(저장 안 함)"
            }
            Show-Notice ($head + $body)
            Log "[$k/$total] $name notice shown ($($t.Win))"
        }
    }
    Stop-CpuSampler $cpuJob $cpuStop
    try {
        $dir = (Get-ChildItem (Join-Path $Root 'results') -Directory -Filter "*_$name" | Sort-Object Name | Select-Object -Last 1).FullName
        $v = Read-Summary $dir
        if ($cpuJob -and (Test-Path $cpuCsv)) { Move-Item $cpuCsv (Join-Path $dir 'cpu-process.csv') -Force }
        Append-Line $Csv "$name,$($t.Round),$($c.Key),$($t.Win),$($v[0]),$($v[1]),$($v[2]),$(Split-Path $dir -Leaf)"
        Log "[$k/$total] $name done: error=$($v[0])% tps=$($v[1])"
    } catch {
        Log "[$k/$total] $name FAILED: $_"
        Get-CimInstance Win32_Process -Filter "Name='java.exe'" | Where-Object { $_.CommandLine -match 'jars\\c-|jars\\feb26|jars\\retest|ApacheJMeter' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    }
}
Log 'gui-matrix FINISHED'
[void][KeepAwake]::SetThreadExecutionState([uint32]2147483648)
