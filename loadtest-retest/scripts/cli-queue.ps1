# Unattended CLI load-test queue (no JMeter GUI, no listeners unless the condition says so). Keeps the PC awake while it runs.
# Each condition is run -Reps times, round-robin (rep 1 of every condition, then rep 2, ...), the start condition rotates every rep.
# Before every run it rests until the PC is calm (CPU low and temperature low) - at least -MinRestSec, at most -MaxRestSec - and logs how long it rested.
# Each run = fresh app + warm-up + data reset (see run-case.ps1 -Warmup). The host monitor also records CPU performance % and temperature.
# Results: results\<stamp>_<name>\summary.md and one line per run in cli-queue-results.csv. Resumable: finished tag+name+rep are skipped.
#
# Usage (PowerShell, in this folder):
#   .\cli-queue.ps1 -Phase 0 -Reps 1             # smoke test
#   .\cli-queue.ps1 -Phase 1 -Reps 2 -Tag w2     # sync vs MQ and Tomcat-thread effect at 5000/5/10
#   .\cli-queue.ps1 -Phase 2 -Reps 2 -Tag w2     # consumer / prefetch / accept-count / pool / show-sql
#   .\cli-queue.ps1 -Phase 3 -Reps 2 -Tag w2     # load levels 1000 / 2000 / 3000 / 8000
#   .\cli-queue.ps1 -Phase 4 -Reps 2 -Tag w2     # CLI + listeners (plan-gui.jmx)
#   .\cli-queue.ps1 -Phase 5 -Reps 2 -Tag v      # stabilisation check: the same condition twice
#   add -DryRun to only print what would run
param(
    [int]$Phase = 1,
    [int]$Reps = 2,
    [int]$RepStart = 1,          # first repetition number to run (e.g. 3 = run only the third repetition)
    [string[]]$Only = @(),       # run only these condition names of the phase
    [string]$Tag = '',
    [int]$MinRestSec = 30,
    [int]$MaxRestSec = 600,
    [double]$CalmCpuPct = 25,
    [double]$CalmTempC = 54,
    [switch]$WaitTimeWait,
    [switch]$CpuLog,             # also record per-process CPU (app / JMeter / postgres / docker) every 2 s -> results\<run>\cpu-process.csv (always on for phase 6)
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Csv = Join-Path $Root 'cli-queue-results.csv'
$Log = Join-Path $Root 'cli-queue.log'
function Append-Line([string]$path, [string]$line) {
    for ($i = 0; $i -lt 10; $i++) {
        try { [IO.File]::AppendAllText($path, $line + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false))); return } catch { Start-Sleep -Milliseconds 400 }
    }
}
function Log([string]$m) { $l = "$(Get-Date -Format 'MM-dd HH:mm:ss') $m"; Append-Line $Log $l; Write-Host $l }

# condition: Name, Jar, Users, Loops, Tomcat threads (0 = jar default), Consumers, Prefetch (0 = default), extra app args, plan
function C([string]$n, [string]$jar, [int]$users, [int]$loops, [int]$t, [int]$c, [int]$p, [string[]]$extra = @(), [string]$plan = 'plan.jmx') {
    @{ Name = $n; Jar = $jar; Users = $users; Loops = $loops; T = $t; C = $c; P = $p; Extra = $extra; Plan = $plan }
}
$DEFAULTS = @('--server.tomcat.threads.max=200', '--spring.datasource.hikari.maximum-pool-size=30', '--server.tomcat.accept-count=100')
# 2x2x2 factorial (phase 8): Tomcat threads 7/200 x Hikari pool 17/30 x accept-count 100/1000, all other settings equal (build fae13e0)
$FACT = @()
foreach ($th in 7, 200) { foreach ($pl in 17, 30) { foreach ($ac in 100, 1000) {
    $FACT += ,(C "f-t$th-p$pl-a$ac" 'c-fae13e0' 8000 10 0 0 0 @("--server.tomcat.threads.max=$th", "--spring.datasource.hikari.maximum-pool-size=$pl", "--server.tomcat.accept-count=$ac"))
} } }
$SQLON = @('--spring.jpa.show-sql=true', '--spring.jpa.properties.hibernate.format_sql=true')
$phases = @{
    0 = @( (C 'smoke-mq' 'c-c3bfdee' 500 2 12 1 10) )
    1 = @(
        (C 's-t7'   'c-fae13e0' 5000 10 7  0 0),
        (C 's-t12'  'c-fae13e0' 5000 10 12 0 0),
        (C 'mq-t7'  'c-c3bfdee' 5000 10 7  1 10),
        (C 'mq-t12' 'c-c3bfdee' 5000 10 12 1 10),
        (C 'mq-t15' 'c-c3bfdee' 5000 10 15 1 10),
        (C 'mq-t20' 'c-c3bfdee' 5000 10 20 1 10)
    )
    2 = @(
        (C 'mq-t12-c2'      'c-c3bfdee' 5000 10 12 2 10),
        (C 'mq-t12-c3'      'c-c3bfdee' 5000 10 12 3 10),
        (C 'mq-t12-p20'     'c-c3bfdee' 5000 10 12 1 20),
        (C 'mq-t12-p50'     'c-c3bfdee' 5000 10 12 1 50),
        (C 'mq-t12-acc100'  'c-c3bfdee' 5000 10 12 1 10 @('--server.tomcat.accept-count=100')),
        (C 'mq-t12-pool30'  'c-c3bfdee' 5000 10 12 1 10 @('--spring.datasource.hikari.maximum-pool-size=30')),
        (C 's-t7-sqlon'     'c-fae13e0' 5000 10 7  0 0  $SQLON)
    )
    3 = @(
        (C 's-t7-1000'   'c-fae13e0' 1000 10 7  0 0),
        (C 's-t7-2000'   'c-fae13e0' 2000 10 7  0 0),
        (C 's-t7-3000'   'c-fae13e0' 3000 10 7  0 0),
        (C 's-t7-8000'   'c-fae13e0' 8000 10 7  0 0),
        (C 'mq-t12-1000' 'c-c3bfdee' 1000 10 12 1 10),
        (C 'mq-t12-2000' 'c-c3bfdee' 2000 10 12 1 10),
        (C 'mq-t12-3000' 'c-c3bfdee' 3000 10 12 1 10),
        (C 'mq-t12-8000' 'c-c3bfdee' 8000 10 12 1 10)
    )
    4 = @(
        (C 's-t7-lsn'   'c-fae13e0' 5000 10 7  0 0  @() 'plan-gui.jmx'),
        (C 'mq-t12-lsn' 'c-c3bfdee' 5000 10 12 1 10 @() 'plan-gui.jmx')
    )
    5 = @( (C 'verify-s-t7' 'c-fae13e0' 5000 10 7 0 0) )
    # default vs tuned, same build (fae13e0: show-sql off): default = Tomcat 200 / pool 30 / accept 100, tuned = the jar's own 7 / 17 / 1000
    7 = @(   # saturation search: tuned build (7 / 17 / 1000), rising load
        (C 'sat-6000'  'c-fae13e0' 6000  10 0 0 0),
        (C 'sat-8000'  'c-fae13e0' 8000  10 0 0 0),
        (C 'sat-10000' 'c-fae13e0' 10000 10 0 0 0),
        (C 'sat-12000' 'c-fae13e0' 12000 10 0 0 0)
    )
    8 = $FACT
    9 = @(   # show-sql off vs on, sync Tomcat 7, 5000
        (C 'sql-off' 'c-fae13e0' 5000 10 7 0 0),
        (C 'sql-on'  'c-fae13e0' 5000 10 7 0 0 $SQLON)
    )
    6 = @(
        (C 'def-5000' 'c-fae13e0' 5000 10 0 0 0 $DEFAULTS),
        (C 'tun-5000' 'c-fae13e0' 5000 10 0 0 0),
        (C 'def-8000' 'c-fae13e0' 8000 10 0 0 0 $DEFAULTS),
        (C 'tun-8000' 'c-fae13e0' 8000 10 0 0 0)
    )
}
if (-not $phases.ContainsKey($Phase)) { throw "unknown phase $Phase" }
$conds = $phases[$Phase]
if ($Only.Count -gt 0) { $conds = @($conds | Where-Object { $Only -contains $_.Name }) }
$total = $conds.Count * $Reps
Log "phase $Phase tag '$Tag': $($conds.Count) conditions x $Reps reps = $total runs, rest $MinRestSec-$MaxRestSec s (calm: cpu<$CalmCpuPct% temp<=$CalmTempC C)"
if ($DryRun) {
    for ($r = $RepStart; $r -lt $RepStart + $Reps; $r++) { foreach ($c in $conds) { "{0,-14} rep {1}  jar={2} {3}x5s x{4}  tomcat={5} consumers={6} prefetch={7} plan={8} extra={9}" -f $c.Name, $r, $c.Jar, $c.Users, $c.Loops, $c.T, $c.C, $c.P, $c.Plan, ($c.Extra -join ' ') } }
    return
}

# keep the PC awake while this process runs (does not change any system setting)
Add-Type @"
using System.Runtime.InteropServices;
public class KeepAwake { [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f); }
"@
[void][KeepAwake]::SetThreadExecutionState([uint32]2147483649)   # ES_CONTINUOUS | ES_SYSTEM_REQUIRED

# make sure Redis and RabbitMQ containers are up
$dockerBin = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin'
if (Test-Path $dockerBin) { $env:Path += ";$dockerBin" }
$running = (& docker ps --format '{{.Names}}') -join ' '
foreach ($n in @('safecar-redis', 'safecar-rabbitmq')) { if ($running -notmatch $n) { Log "starting container $n"; & docker start $n | Out-Null } }
for ($i = 0; $i -lt 30; $i++) { if ((& docker exec safecar-redis redis-cli PING 2>$null) -match 'PONG') { break }; Start-Sleep -Seconds 2 }

if (-not (Test-Path $Csv)) { 'tag,name,rep,error_pct,tps_all,tps_success,avg_success_ms,rest_sec,calm,temp_start,temp_max,perf_min,perf_avg,timewait_before,timewait_after,dir' | Set-Content -Encoding utf8 $Csv }
$done = @{}; Import-Csv $Csv | ForEach-Object { $done["$($_.tag)|$($_.name)|$($_.rep)"] = $true }

function Get-TempC {
    try { $tz = Get-CimInstance Win32_PerfFormattedData_Counters_ThermalZoneInformation -ErrorAction Stop | Select-Object -First 1; return [math]::Round($tz.HighPrecisionTemperature / 10 - 273.15, 1) } catch { return $null }
}
function Start-CpuSampler([string]$csv, [string]$stopFile) {
    Start-Job -ArgumentList $csv, $stopFile -ScriptBlock {
        param($csv, $stop)
        $cores = [Environment]::ProcessorCount
        'time,app_pct,jmeter_pct,postgres_pct,docker_pct,other_pct,total_pct' | Set-Content -Encoding ascii $csv
        while (-not (Test-Path $stop)) {
            Start-Sleep -Seconds 2
            $kind = @{}
            foreach ($w in @(Get-CimInstance Win32_Process -Filter "Name='java.exe'" -ErrorAction SilentlyContinue)) {
                $kind[[int]$w.ProcessId] = $(if ($w.CommandLine -match 'ApacheJMeter') { 'jmeter' } else { 'app' })
            }
            $sum = @{ app = 0.0; jmeter = 0.0; postgres = 0.0; docker = 0.0; other = 0.0 }
            # per-process CPU from the performance counters (works for services too); % of one core, so divide by the core count
            foreach ($p in @(Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction SilentlyContinue)) {
                if ($p.Name -eq '_Total' -or $p.Name -eq 'Idle') { continue }
                $g = if ($kind.ContainsKey([int]$p.IDProcess)) { $kind[[int]$p.IDProcess] } elseif ($p.Name -match '^postgres') { 'postgres' } elseif ($p.Name -match '^(com\.docker|vmmem|Docker Desktop|wslhost|wslservice)') { 'docker' } else { 'other' }
                $sum[$g] += [double]$p.PercentProcessorTime / $cores
            }
            $tot = $sum.app + $sum.jmeter + $sum.postgres + $sum.docker + $sum.other
            $line = '{0},{1},{2},{3},{4},{5},{6}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), [math]::Round($sum.app, 1), [math]::Round($sum.jmeter, 1), [math]::Round($sum.postgres, 1), [math]::Round($sum.docker, 1), [math]::Round($sum.other, 1), [math]::Round($tot, 1)
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
function Wait-Calm {
    $start = Get-Date
    $minRest = $MinRestSec
    if ($null -eq (Get-TempC)) { $minRest = [Math]::Max($MinRestSec, 120) }   # no temperature counter: rest longer
    Start-Sleep -Seconds $minRest
    $samples = @()
    while ($true) {
        $samples += [double](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime
        if ($samples.Count -gt 6) { $samples = $samples[-6..-1] }
        $t = Get-TempC
        $elapsed = [int]((Get-Date) - $start).TotalSeconds
        $cpuOk = ($samples.Count -ge 3) -and ((($samples | Measure-Object -Average).Average) -lt $CalmCpuPct)
        $tempOk = ($null -eq $t) -or ($t -le $CalmTempC)
        if ($cpuOk -and $tempOk) { return @{ Sec = $elapsed; Temp = $t; Calm = $true } }
        if ($elapsed -ge $MaxRestSec) { return @{ Sec = $elapsed; Temp = $t; Calm = $false } }
        Start-Sleep -Seconds 10
    }
}
function Read-Summary([string]$dir) {
    $s = Get-Content (Join-Path $dir 'summary.md') -Raw -Encoding UTF8
    $e = if ($s -match '([\d.]+)%\*\*\)') { $Matches[1] } else { '' }
    $t = if ($s -match 'Throughput\(.*?\) ([\d,.]+)/s') { $Matches[1] -replace ',', '' } else { '' }
    $st = if ($s -match '([\d,.]+)/s\*\*') { $Matches[1] -replace ',', '' } else { '' }
    $a = if ($s -match '\| 200 \|[^|]*\| true \|[^|]*\|[^|]*\| ([\d,]+) \|') { $Matches[1] -replace ',', '' } else { '' }
    return @($e, $t, $st, $a)
}

$k = 0
for ($r = $RepStart; $r -lt $RepStart + $Reps; $r++) {
    # rotate the start condition each rep so that no condition is always first (heat / drift)
    $order = @(); for ($i = 0; $i -lt $conds.Count; $i++) { $order += $conds[($i + $r - 1) % $conds.Count] }
    foreach ($c in $order) {
        $k++
        if ($done["$Tag|$($c.Name)|$r"]) { Log "skip $($c.Name) rep $r (done)"; continue }
        $runName = "p$Phase$Tag-$($c.Name)-r$r"
        $rest = Wait-Calm
        Log "[$k/$total] $runName start (rested $($rest.Sec) s, calm=$($rest.Calm), temp=$($rest.Temp) C)"
        $p = @{ Name = $runName; Jar = $c.Jar; Threads = $c.Users; Ramp = 5; Loops = $c.Loops; CooldownSec = 0; Plan = $c.Plan; Warmup = $true }
        if ($WaitTimeWait) { $p.WaitTimeWait = $true }
        if ($c.T -gt 0) { $p.TomcatThreads = $c.T }
        if ($c.C -gt 0) { $p.Consumers = $c.C }
        if ($c.P -gt 0) { $p.Prefetch = $c.P }
        if ($c.Extra.Count -gt 0) { $p.ExtraAppArgs = $c.Extra }
        $cpuJob = $null; $cpuStop = Join-Path $Root "logs\.stop-cpu-$runName"; $cpuCsv = Join-Path $Root "logs\cpu-$runName.csv"
        if ($CpuLog -or $Phase -ge 6) { Remove-Item $cpuStop -ErrorAction SilentlyContinue; $cpuJob = Start-CpuSampler $cpuCsv $cpuStop }
        try {
            & (Join-Path $Root 'run-case.ps1') @p | Out-Null
            Stop-CpuSampler $cpuJob $cpuStop
            $dir = (Get-ChildItem (Join-Path $Root 'results') -Directory -Filter "*_$runName" | Sort-Object Name | Select-Object -Last 1).FullName
            if ($cpuJob -and (Test-Path $cpuCsv)) { Move-Item $cpuCsv (Join-Path $dir 'cpu-process.csv') -Force }
            $v = Read-Summary $dir
            $meta = Get-Content (Join-Path $dir 'meta.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $mon = Import-Csv (Join-Path $dir 'monitor-host.csv')
            $temps = @($mon | ForEach-Object { $_.temp_c } | Where-Object { $_ -ne '' -and $null -ne $_ } | ForEach-Object { [double]$_ })
            $perfs = @($mon | ForEach-Object { $_.perf_pct } | Where-Object { $_ -ne '' -and $null -ne $_ } | ForEach-Object { [double]$_ })
            $tmax = if ($temps.Count) { ($temps | Measure-Object -Maximum).Maximum } else { '' }
            $pmin = if ($perfs.Count) { ($perfs | Measure-Object -Minimum).Minimum } else { '' }
            $pavg = if ($perfs.Count) { [math]::Round(($perfs | Measure-Object -Average).Average, 1) } else { '' }
            "$Tag,$($c.Name),$r,$($v[0]),$($v[1]),$($v[2]),$($v[3]),$($rest.Sec),$($rest.Calm),$($rest.Temp),$tmax,$pmin,$pavg,$($meta.tcpTimeWaitBefore),$($meta.tcpTimeWaitAfter),$(Split-Path $dir -Leaf)" | ForEach-Object { Append-Line $Csv $_ }
            Log "[$k/$total] $runName done: error=$($v[0])% tps=$($v[1]) success_tps=$($v[2]) temp_max=$tmax perf_min=$pmin"
        } catch {
            Log "[$k/$total] $runName FAILED: $_"
            Stop-CpuSampler $cpuJob $cpuStop
            # clean up anything left behind so the next run can start
            Get-CimInstance Win32_Process -Filter "Name='java.exe'" | Where-Object { $_.CommandLine -match 'jars\\c-|jars\\feb26|jars\\retest|ApacheJMeter' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        }
    }
}
Log "queue finished (phase $Phase tag '$Tag')"
[void][KeepAwake]::SetThreadExecutionState([uint32]2147483648)   # ES_CONTINUOUS only: release

