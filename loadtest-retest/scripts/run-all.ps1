# Runs the whole supplementary measurement unattended:
#   0) stabilisation check (Phase 5, tag v): the same condition twice. If the second run is much worse than the first, STOP (the environment still drifts).
#   1) Phase 1, 2, 3, 4 with -Reps repetitions (tag w2). Before every run the queue rests until the PC is calm (max 10 min).
# Usage: powershell -ExecutionPolicy Bypass -File .\run-all.ps1            (resumable: finished runs are skipped)
param(
    [int]$Reps = 2,
    [string]$Tag = 'w2',
    [switch]$SkipVerify
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Log = Join-Path $Root 'cli-queue.log'
$Csv = Join-Path $Root 'cli-queue-results.csv'
function Log([string]$m) {
    $l = "$(Get-Date -Format 'MM-dd HH:mm:ss') [run-all] $m"
    for ($i = 0; $i -lt 10; $i++) { try { [IO.File]::AppendAllText($Log, $l + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false))); break } catch { Start-Sleep -Milliseconds 400 } }
    Write-Host $l
}
Set-Location $Root

if (-not $SkipVerify) {
    Log 'stabilisation check start'
    & (Join-Path $Root 'cli-queue.ps1') -Phase 5 -Reps 2 -Tag v
    $rows = @(Import-Csv $Csv | Where-Object { $_.tag -eq 'v' } | Sort-Object { [int]$_.rep })
    if ($rows.Count -lt 2) { Log 'STOP: stabilisation check did not produce 2 rows'; exit 3 }
    $e1 = [double]$rows[0].error_pct; $e2 = [double]$rows[1].error_pct
    Log "stabilisation check: rep1 error=$e1% rep2 error=$e2%"
    if ($e2 -gt 20 -or ($e2 - $e1) -gt 15) { Log 'STOP: the second run is much worse than the first -> the environment still drifts. Not continuing.'; exit 4 }
    Log 'stabilisation check passed'
}
foreach ($p in 1, 2, 3, 4) {
    Log "phase $p start"
    & (Join-Path $Root 'cli-queue.ps1') -Phase $p -Reps $Reps -Tag $Tag
    Log "phase $p finished"
}
Log 'ALL PHASES FINISHED'
