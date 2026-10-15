# Measures compute time (C) and wait time (W) of the request path at LOW load, as in February (server-side Prometheus metrics),
# so that the optimal Tomcat thread count can be calculated:  N = Ncpu x Ucpu x (1 + W/C)
# Builds: MQ (c-c3bfdee, Tomcat 7, Consumer 1, Prefetch 10) and, as a reference, sync (c-fae13e0, Tomcat 7). Same load for both: -Users/5/10.
# Per run: fresh app -> warm-up -> data reset -> scrape /actuator/prometheus -> JMeter CLI -> scrape again -> deltas -> cw-results.csv
# Optionally waits for another process (e.g. the running cli-queue) to exit first:  -WaitForPid <pid>
param([int]$Users = 1000, [int]$Reps = 2, [int]$WaitForPid = 0, [int]$RestSec = 60)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Set-Location $Root
Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public class KeepAwake { [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f); }'
[void][KeepAwake]::SetThreadExecutionState([uint32]2147483649)   # keep the PC awake while running
$Java = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\java.exe' } else { Join-Path $env:USERPROFILE '.jdks\corretto-17.0.14\bin\java.exe' }
$JMeter = Join-Path $(if ($env:JMETER_HOME) { $env:JMETER_HOME } else { throw 'Set JMETER_HOME to the Apache JMeter folder (for example C:\apache-jmeter-5.6.3)' }) 'bin\jmeter.bat'
$Psql = (Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\psql.exe' | Select-Object -First 1).FullName
$DockerBin = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin'
if (Test-Path $DockerBin) { $env:Path += ";$DockerBin" }
$DbName = 'safecar_retest'
$Queue = 'vehicle.alert.queue'
$RabbitAuth = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('guest:guest')) }
$Log = Join-Path $Root 'cw.log'
$Csv = Join-Path $Root 'cw-results.csv'
function Log([string]$m) {
    $l = "$(Get-Date -Format 'MM-dd HH:mm:ss') [cw] $m"
    for ($i = 0; $i -lt 10; $i++) { try { [IO.File]::AppendAllText($Log, $l + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false))); break } catch { Start-Sleep -Milliseconds 400 } }
}
function Invoke-Sql([string]$sql) {
    $env:PGCLIENTENCODING = 'UTF8'
    $out = & $Psql -h 127.0.0.1 -U postgres -d $DbName -A -t -c $sql
    if ($LASTEXITCODE -ne 0) { throw "psql failed: $sql" }
    return ($out | Out-String).Trim()
}
# sum of a Prometheus metric over all label sets whose labels do not match $exclude
function Sum-Metric([string]$text, [string]$name, [string]$exclude = '') {
    $s = 0.0
    foreach ($line in ($text -split "`n")) {
        if ($line -match ('^' + [regex]::Escape($name) + '(\{([^}]*)\})?\s+(\S+)\s*$')) {
            if ($exclude -and $Matches[2] -match $exclude) { continue }
            $s += [double]::Parse($Matches[3], [Globalization.CultureInfo]::InvariantCulture)
        }
    }
    return $s
}
function Get-Prom { (Invoke-WebRequest 'http://localhost:8080/actuator/prometheus' -UseBasicParsing -TimeoutSec 15).Content }

if ($WaitForPid -gt 0) { Log "waiting for pid $WaitForPid to exit"; Wait-Process -Id $WaitForPid -ErrorAction SilentlyContinue; Log 'wait done'; Start-Sleep -Seconds 60 }

$running = (& docker ps --format '{{.Names}}') -join ' '
foreach ($n in @('safecar-redis', 'safecar-rabbitmq')) { if ($running -notmatch $n) { Log "starting container $n"; & docker start $n | Out-Null } }
for ($i = 0; $i -lt 30; $i++) { if ((& docker exec safecar-redis redis-cli PING 2>$null) -match 'PONG') { break }; Start-Sleep -Seconds 2 }
if (-not (Test-Path $Csv)) { 'build,rep,users,error_pct,tps,req_count,req_avg_ms,acq_count,acq_avg_ms,acq_per_req,usage_avg_ms,cpu_cores,dir' | Set-Content -Encoding utf8 $Csv }

$builds = @(
    @{ Key = 'mq';   Jar = 'c-c3bfdee'; Args = @('--server.tomcat.threads.max=7', '--spring.rabbitmq.listener.simple.concurrency=1', '--spring.rabbitmq.listener.simple.max-concurrency=1', '--spring.rabbitmq.listener.simple.prefetch=10') },
    @{ Key = 'sync'; Jar = 'c-fae13e0'; Args = @('--server.tomcat.threads.max=7') }
)
$k = 0
for ($rep = 1; $rep -le $Reps; $rep++) {
    $order = if ($rep % 2 -eq 1) { $builds } else { @($builds[1], $builds[0]) }
    foreach ($b in $order) {
        $k++
        $name = "cw-$($b.Key)-u$Users-r$rep"
        if ($k -gt 1) { Start-Sleep -Seconds $RestSec }
        Log "$name start"
        $Out = Join-Path $Root "results\$(Get-Date -Format 'yyyyMMdd-HHmmss')_$name"
        New-Item -ItemType Directory -Force $Out | Out-Null
        $appArgs = @('-jar', "`"$(Join-Path $Root "jars\$($b.Jar).jar")`"", "--spring.datasource.url=jdbc:postgresql://localhost:5432/$DbName", '--loadtest.monitor.enabled=true') + $b.Args
        $app = Start-Process -FilePath $Java -ArgumentList $appArgs -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $Out 'app.log') -RedirectStandardError (Join-Path $Out 'app.err.log')
        try {
            $up = $false
            for ($i = 0; $i -lt 120 -and -not $up; $i++) {
                Start-Sleep -Seconds 1
                if ($app.HasExited) { throw 'app exited during startup' }
                try { $up = ((Invoke-RestMethod http://localhost:8080/actuator/health -TimeoutSec 2).status -eq 'UP') } catch { }
            }
            if (-not $up) { throw 'app did not become healthy' }
            & $JMeter -n -t (Join-Path $Root 'plan.jmx') '-Jthreads=500' '-Jramp=3' '-Jloops=4' -l (Join-Path $Out 'warmup.jtl') -j (Join-Path $Out 'warmup-jmeter.log') | Out-Null
            Invoke-Sql 'TRUNCATE vehicle_log, alert, hourly_vehicle_stats, daily_vehicle_stats RESTART IDENTITY;' | Out-Null
            try { Invoke-RestMethod -Method Delete -Headers $RabbitAuth "http://localhost:15672/api/queues/%2F/$Queue/contents" | Out-Null } catch { }
            & docker exec safecar-redis redis-cli FLUSHALL | Out-Null
            Start-Sleep -Seconds 10
            $before = Get-Prom
            $jtl = Join-Path $Out 'results.jtl'
            & $JMeter -n -t (Join-Path $Root 'plan.jmx') "-Jthreads=$Users" '-Jramp=5' '-Jloops=10' "-Jjtl=$(Join-Path $Out 'listener.jtl')" -l $jtl -j (Join-Path $Out 'jmeter.log') | Out-Null
            $after = Get-Prom
            $rows = Import-Csv $jtl
            $err = ($rows | Where-Object { $_.success -ne 'true' } | Measure-Object).Count
            $ts = $rows | ForEach-Object { [long]$_.timeStamp }
            $span = (($ts | Measure-Object -Maximum).Maximum - ($ts | Measure-Object -Minimum).Minimum) / 1000.0
            $ex = 'uri="/actuator|uri="/favicon|uri="/error|uri="UNKNOWN'
            $rc = (Sum-Metric $after 'http_server_requests_seconds_count' $ex) - (Sum-Metric $before 'http_server_requests_seconds_count' $ex)
            $rs = (Sum-Metric $after 'http_server_requests_seconds_sum' $ex) - (Sum-Metric $before 'http_server_requests_seconds_sum' $ex)
            $ac = (Sum-Metric $after 'hikaricp_connections_acquire_seconds_count') - (Sum-Metric $before 'hikaricp_connections_acquire_seconds_count')
            $as = (Sum-Metric $after 'hikaricp_connections_acquire_seconds_sum') - (Sum-Metric $before 'hikaricp_connections_acquire_seconds_sum')
            $uc = (Sum-Metric $after 'hikaricp_connections_usage_seconds_count') - (Sum-Metric $before 'hikaricp_connections_usage_seconds_count')
            $us = (Sum-Metric $after 'hikaricp_connections_usage_seconds_sum') - (Sum-Metric $before 'hikaricp_connections_usage_seconds_sum')
            $reqAvg = if ($rc -gt 0) { $rs / $rc * 1000 } else { 0 }
            $acqAvg = if ($ac -gt 0) { $as / $ac * 1000 } else { 0 }
            $usgAvg = if ($uc -gt 0) { $us / $uc * 1000 } else { 0 }
            $perReq = if ($rc -gt 0) { $ac / $rc } else { 0 }
            Set-Content -Encoding utf8 (Join-Path $Out 'prom-before.txt') $before
            Set-Content -Encoding utf8 (Join-Path $Out 'prom-after.txt') $after
            $line = '{0},{1},{2},{3:0.00},{4:0.0},{5},{6:0.00},{7},{8:0.00},{9:0.00},{10:0.00},{11},{12}' -f $b.Key, $rep, $Users, ($err / $rows.Count * 100), ($rows.Count / $span), $rc, $reqAvg, $ac, $acqAvg, $perReq, $usgAvg, [Environment]::ProcessorCount, (Split-Path $Out -Leaf)
            for ($i = 0; $i -lt 10; $i++) { try { [IO.File]::AppendAllText($Csv, $line + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false))); break } catch { Start-Sleep -Milliseconds 400 } }
            Log "$name done: $line"
        } catch {
            Log "$name FAILED: $_"
        } finally {
            if (-not $app.HasExited) { Stop-Process -Id $app.Id -Force }
        }
    }
}
Log 'measure-cw FINISHED'
