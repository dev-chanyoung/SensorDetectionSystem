# SafeCar load-test re-run: one case per invocation.
# Starts the app jar, resets retest data, runs JMeter (CLI), records monitors, stops the app, then analyzes.
# Usage example:
#   .\run-case.ps1 -Name mq-t15-c2-p10 -Jar retest-mq -TomcatThreads 15 -Consumers 2 -Prefetch 10
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [ValidateSet('retest-mq', 'retest-sync', 'feb26', 'c-fae13e0', 'c-c3bfdee')][string]$Jar = 'retest-mq',
    [int]$Threads = 5000,
    [int]$Ramp = 5,
    [int]$Loops = 10,
    [int]$TomcatThreads = 0,   # 0 = keep the jar's default
    [int]$Consumers = 0,       # 0 = keep the jar's default (sets concurrency and max-concurrency)
    [int]$Prefetch = 0,        # 0 = keep the jar's default
    [int]$CooldownSec = 60,    # wait before starting, so the laptop cools down between runs
    [string[]]$ExtraAppArgs = @(),
    [string]$Plan = 'plan.jmx', # CLI only: 'plan-gui.jmx' = same listeners as the GUI run, but without the GUI
    [switch]$WaitTimeWait,     # before starting, wait until the number of TIME_WAIT sockets is below -TimeWaitMax (ephemeral ports run out otherwise)
    [int]$TimeWaitMax = 500,
    [int]$TimeWaitTimeoutSec = 420,
    [switch]$Warmup,           # run a short JMeter warm-up (CLI) after the app is up, before the data reset
    [switch]$ConsoleApp,      # run the app in a visible console window (stdout not redirected), like running it from an IDE console
    [switch]$KeepData,        # do not TRUNCATE the DB before the run (to reproduce February, when rows accumulated)
    [switch]$Gui             # run JMeter in GUI mode with the February listeners (you press Start, then close JMeter)
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Java = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\java.exe' } else { Join-Path $env:USERPROFILE '.jdks\corretto-17.0.14\bin\java.exe' }
$JMeter = Join-Path $(if ($env:JMETER_HOME) { $env:JMETER_HOME } else { throw 'Set JMETER_HOME to the Apache JMeter folder (for example C:\apache-jmeter-5.6.3)' }) 'bin\jmeter.bat'
$Psql = (Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\psql.exe' | Select-Object -First 1).FullName
$DockerBin = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin'
if (Test-Path $DockerBin) { $env:Path += ";$DockerBin" }
$DbName = 'safecar_retest'   # never the original 'safecar' DB (February evidence)
$Queue = 'vehicle.alert.queue'
$RabbitAuth = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('guest:guest')) }

function Invoke-Sql([string]$sql) {
    $env:PGCLIENTENCODING = 'UTF8'
    $out = & $Psql -h 127.0.0.1 -U postgres -d $DbName -A -t -c $sql
    if ($LASTEXITCODE -ne 0) { throw "psql failed: $sql" }
    return ($out | Out-String).Trim()
}

# ---- pre-checks ----
foreach ($p in @($Java, $JMeter, $Psql)) { if (-not (Test-Path $p)) { throw "missing: $p" } }
$jarPath = Join-Path $Root "jars\$Jar.jar"
if (-not (Test-Path $jarPath)) { throw "missing jar: $jarPath" }
if (Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue) {
    throw 'Port 8080 is already in use. Stop the app running in IntelliJ (or elsewhere) first.'
}
$running = (& docker ps --format '{{.Names}}') -join ' '
foreach ($c in @('safecar-redis', 'safecar-rabbitmq')) {
    if ($running -notmatch $c) { throw "container not running: $c  (docker compose up -d redis rabbitmq)" }
}

if ($CooldownSec -gt 0) { Write-Host "cooldown $CooldownSec s ..."; Start-Sleep -Seconds $CooldownSec }
$twBefore = (Get-NetTCPConnection -State TimeWait -ErrorAction SilentlyContinue | Measure-Object).Count
if ($WaitTimeWait) {
    $twDeadline = (Get-Date).AddSeconds($TimeWaitTimeoutSec)
    while ($twBefore -ge $TimeWaitMax -and (Get-Date) -lt $twDeadline) {
        Start-Sleep -Seconds 10
        $twBefore = (Get-NetTCPConnection -State TimeWait -ErrorAction SilentlyContinue | Measure-Object).Count
    }
    Write-Host "[$Name] TIME_WAIT sockets before start: $twBefore"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Out = Join-Path $Root "results\${stamp}_$Name"
New-Item -ItemType Directory -Force $Out | Out-Null

# ---- start app ----
$appArgs = @('-jar', "`"$jarPath`"",
    "--spring.datasource.url=jdbc:postgresql://localhost:5432/$DbName",
    '--loadtest.monitor.enabled=true')
if ($TomcatThreads -gt 0) { $appArgs += "--server.tomcat.threads.max=$TomcatThreads", "--server.tomcat.threads.min=$TomcatThreads" }
if ($Consumers -gt 0) { $appArgs += "--spring.rabbitmq.listener.simple.concurrency=$Consumers", "--spring.rabbitmq.listener.simple.max-concurrency=$Consumers" }
if ($Prefetch -gt 0) { $appArgs += "--spring.rabbitmq.listener.simple.prefetch=$Prefetch" }
$appArgs += $ExtraAppArgs

Write-Host "[$Name] starting app: $Jar"
if ($ConsoleApp) {
    New-Item -ItemType File (Join-Path $Out 'app.log'), (Join-Path $Out 'app.err.log') | Out-Null
    $app = Start-Process -FilePath $Java -ArgumentList $appArgs -PassThru -WindowStyle Normal
} else {
    $app = Start-Process -FilePath $Java -ArgumentList $appArgs -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $Out 'app.log') -RedirectStandardError (Join-Path $Out 'app.err.log')
}

try {
    $up = $false
    for ($i = 0; $i -lt 120 -and -not $up; $i++) {
        Start-Sleep -Seconds 1
        if ($app.HasExited) { throw 'app exited during startup (see app.log / app.err.log)' }
        try { $up = ((Invoke-RestMethod http://localhost:8080/actuator/health -TimeoutSec 2).status -eq 'UP') } catch { }
    }
    if (-not $up) { throw 'app did not become healthy within 120 s' }
    Write-Host "[$Name] app is up (pid $($app.Id))"
    if ($Warmup) {
        Write-Host "[$Name] warm-up (500 users x 4 loops) ..."
        & $JMeter -n -t (Join-Path $Root 'plan.jmx') '-Jthreads=500' '-Jramp=3' '-Jloops=4' -l (Join-Path $Out 'warmup.jtl') -j (Join-Path $Out 'warmup-jmeter.log') | Out-Null
    }

    # ---- reset retest data ----
    if (-not $KeepData) { Invoke-Sql 'TRUNCATE vehicle_log, alert, hourly_vehicle_stats, daily_vehicle_stats RESTART IDENTITY;' | Out-Null }
    try { Invoke-RestMethod -Method Delete -Headers $RabbitAuth "http://localhost:15672/api/queues/%2F/$Queue/contents" | Out-Null } catch { }
    & docker exec safecar-redis redis-cli FLUSHALL | Out-Null
    Start-Sleep -Seconds 10

    # ---- background monitor: queue depth + CPU every second ----
    $stopFile = Join-Path $Out '.stop-monitor'
    $monitorCsv = Join-Path $Out 'monitor-host.csv'
    $job = Start-Job -ArgumentList $stopFile, $monitorCsv, $Queue -ScriptBlock {
        param($stopFile, $csv, $queue)
        $auth = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('guest:guest')) }
        'time,cpu_percent,queue_messages,queue_ready,queue_unacked,perf_pct,temp_c' | Set-Content -Encoding ascii $csv
        while (-not (Test-Path $stopFile)) {
            $t = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
            $cpu = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime
            $perf = ''; $temp = ''
            try { $perf = (Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'" -ErrorAction Stop).PercentProcessorPerformance } catch { }
            try { $tz = Get-CimInstance Win32_PerfFormattedData_Counters_ThermalZoneInformation -ErrorAction Stop | Select-Object -First 1; $temp = [math]::Round($tz.HighPrecisionTemperature / 10 - 273.15, 1) } catch { }
            $m = ''; $r = ''; $u = ''
            try {
                $q = Invoke-RestMethod -Headers $auth "http://localhost:15672/api/queues/%2F/$queue" -TimeoutSec 2
                $m = $q.messages; $r = $q.messages_ready; $u = $q.messages_unacknowledged
            } catch { }
            "$t,$cpu,$m,$r,$u,$perf,$temp" | Add-Content -Encoding ascii $csv
            Start-Sleep -Milliseconds 1000
        }
    }

    # ---- JMeter (CLI) ----
    $jtl = Join-Path $Out 'results.jtl'
    Write-Host "[$Name] JMeter $Threads/$Ramp/$Loops ..."
    $jStart = Get-Date
    if ($Gui) {
        Write-Host ''
        Write-Host '=================================================================='
        Write-Host ' JMeter GUI is opening. In the JMeter window:'
        Write-Host '   1) press the green Start button (Ctrl+R)'
        Write-Host '   2) wait until the run finishes (top-right counter shows 0/5000)'
        Write-Host '   3) close the JMeter window (do not save changes)'
        Write-Host '=================================================================='
        Start-Process -FilePath $JMeter -Wait -ArgumentList @('-t', "`"$(Join-Path $Root 'plan-gui.jmx')`"",
            "-Jthreads=$Threads", "-Jramp=$Ramp", "-Jloops=$Loops", "-Jjtl=`"$jtl`"",
            '-j', "`"$(Join-Path $Out 'jmeter.log')`"")
        if (-not (Test-Path $jtl)) { throw 'no results file - was the test started in the JMeter window?' }
    } else {
        & $JMeter -n -t (Join-Path $Root $Plan) "-Jthreads=$Threads" "-Jramp=$Ramp" "-Jloops=$Loops" `
            "-Jjtl=$(Join-Path $Out 'listener.jtl')" -l $jtl -j (Join-Path $Out 'jmeter.log') | Tee-Object -FilePath (Join-Path $Out 'jmeter.out.txt')
    }
    $jEnd = Get-Date
    $twAfter = (Get-NetTCPConnection -State TimeWait -ErrorAction SilentlyContinue | Measure-Object).Count

    # ---- let the consumer drain the queue (MQ build), then count rows ----
    if ($Jar -eq 'retest-mq') {
        for ($i = 0; $i -lt 180; $i++) {
            try {
                $q = Invoke-RestMethod -Headers $RabbitAuth "http://localhost:15672/api/queues/%2F/$Queue" -TimeoutSec 2
                if ($q.messages -eq 0) { break }
            } catch { }
            Start-Sleep -Seconds 1
        }
    } else {
        # @Async backlog: wait until the alert count stops growing (max 180 s)
        $prev = -1; $stable = 0
        for ($i = 0; $i -lt 90 -and $stable -lt 3; $i++) {
            Start-Sleep -Seconds 2
            $cur = [int](Invoke-Sql "SELECT count(*) FROM alert WHERE vehicle_id='LOAD-TEST-01';")
            if ($cur -eq $prev) { $stable++ } else { $stable = 0 }
            $prev = $cur
        }
    }
    $rows = Invoke-Sql "SELECT count(*) FROM vehicle_log WHERE vehicle_id='LOAD-TEST-01';"
    $alerts = Invoke-Sql "SELECT count(*) FROM alert WHERE vehicle_id='LOAD-TEST-01';"

    New-Item -ItemType File $stopFile | Out-Null
    Wait-Job $job -Timeout 10 | Out-Null
    Remove-Job $job -Force
}
finally {
    if (-not $app.HasExited) { Stop-Process -Id $app.Id -Force }
}

$rabbitVersion = ''
try { $rabbitVersion = (Invoke-RestMethod -Headers $RabbitAuth http://localhost:15672/api/overview).rabbitmq_version } catch { }
$meta = [ordered]@{
    name = $Name; tcpTimeWaitBefore = $twBefore; tcpTimeWaitAfter = $twAfter; jar = $Jar; jmeterMode = $(if ($Gui) { 'GUI' } else { 'CLI' }); threads = $Threads; ramp = $Ramp; loops = $Loops
    tomcatThreads = $TomcatThreads; consumers = $Consumers; prefetch = $Prefetch
    extraAppArgs = $ExtraAppArgs; appArgs = $appArgs
    jmeterStart = $jStart.ToString('o'); jmeterEnd = $jEnd.ToString('o')
    dbRowsLoadTest = [int]$rows; dbAlertsLoadTest = [int]$alerts
    rabbitmqVersion = $rabbitVersion
    redisVersion = ((& docker exec safecar-redis redis-server --version) -join ' ')
    javaVersion = (& cmd /c "`"$Java`" -version 2>&1") -join ' '
}
$meta | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (Join-Path $Out 'meta.json')

Write-Host "[$Name] analyzing ..."
& python (Join-Path $Root 'analyze.py') $Out
Write-Host "[$Name] done -> $Out"
