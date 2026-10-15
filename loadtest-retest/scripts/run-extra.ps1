# Extra repetitions + console-window experiment (unattended).
#  A) third repetition of the key comparisons (hidden window, like the stable runs)
#  B) does the way the script is launched (minimized console window vs hidden + redirected output) change the error rate?
#     blocks of 2 runs of the same condition, alternating: minimized, hidden, minimized, hidden
param([switch]$SkipA, [switch]$SkipB)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Set-Location $Root
$Log = Join-Path $Root 'cli-queue.log'
function Log([string]$m) {
    $l = "$(Get-Date -Format 'MM-dd HH:mm:ss') [run-extra] $m"
    for ($i = 0; $i -lt 10; $i++) { try { [IO.File]::AppendAllText($Log, $l + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false))); break } catch { Start-Sleep -Milliseconds 400 } }
    Write-Host $l
}
if (-not $SkipA) {
    Log 'A start: third repetition of Phase 1 re-measure (w3), Phase 3 8000-user conditions (w2), Phase 4 (w2)'
    & (Join-Path $Root 'cli-queue.ps1') -Phase 1 -RepStart 3 -Reps 1 -Tag w3
    & (Join-Path $Root 'cli-queue.ps1') -Phase 3 -Only @('s-t7-8000', 'mq-t12-8000') -RepStart 3 -Reps 1 -Tag w2
    & (Join-Path $Root 'cli-queue.ps1') -Phase 4 -RepStart 3 -Reps 1 -Tag w2
    Log 'A finished'
}
if (-not $SkipB) {
    Log 'B start: console-window experiment (minimized vs hidden), condition verify-s-t7 (5000/5/10)'
    foreach ($blk in @(@('m1', 'Minimized'), @('h1', 'Hidden'), @('m2', 'Minimized'), @('h2', 'Hidden'))) {
        $tag = $blk[0]; $style = $blk[1]
        Log "B block $tag ($style)"
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Root\cli-queue.ps1`"", '-Phase', '5', '-Reps', '2', '-Tag', $tag)
        if ($style -eq 'Hidden') {
            Start-Process powershell -ArgumentList $argList -WorkingDirectory $Root -WindowStyle Hidden -RedirectStandardOutput "$Root\logs\b-$tag.out.txt" -RedirectStandardError "$Root\logs\b-$tag.err.txt" -Wait
        } else {
            Start-Process powershell -ArgumentList $argList -WorkingDirectory $Root -WindowStyle Minimized -Wait
        }
    }
    Log 'B finished'
}
Log 'run-extra FINISHED'
