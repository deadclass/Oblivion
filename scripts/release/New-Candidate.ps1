[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$JobFile,
    [Parameter(Mandatory = $true)][string]$Godot,
    [ValidateRange(1,24)][int]$ValidityHours = 24
)
. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Get-ReleaseProjectRoot
$job = Read-Json $JobFile
Assert-Fields $job @('TaskId','OriginalTask','AcceptanceCriteria','ChangedFiles','ImplementerIdentity') 'Job'
foreach ($name in @('TaskId','OriginalTask','ImplementerIdentity')) { Assert-Text $job.$name "Job $name" }
if (@($job.AcceptanceCriteria).Count -eq 0) { throw 'At least one original acceptance criterion is required.' }
foreach ($criterion in @($job.AcceptanceCriteria)) { Assert-Text $criterion 'Acceptance criterion' }
foreach ($relative in @($job.ChangedFiles)) { $null = Resolve-Child $root $relative }
$engine = [IO.Path]::GetFullPath($Godot)
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) { throw 'Existing Godot executable missing.' }
Assert-NoReparse $engine
$templateConfig = Get-Content -LiteralPath (Join-Path $root 'prototypes/quiet-relay/export_presets.cfg') -Raw
$templateMatch = [regex]::Match($templateConfig, '(?m)^custom_template/release="([^"]+)"\s*$')
if (-not $templateMatch.Success) { throw 'Existing explicit Windows release template is required.' }
$template = $templateMatch.Groups[1].Value
if (-not (Test-Path -LiteralPath $template -PathType Leaf)) { throw 'Configured existing Windows release template missing.' }
$toolPaths = @($engine,$template)
if ($engine -match '_console\.exe$') {
    $companion = $engine -replace '_console\.exe$', '.exe'
    if (-not (Test-Path -LiteralPath $companion -PathType Leaf)) { throw 'Godot console launcher companion engine is missing.' }
    $toolPaths += $companion
}
$buildTools = @($toolPaths | ForEach-Object { Assert-NoReparse $_; [pscustomobject]@{ Path = $_; Sha256 = Get-Sha256 $_ } })
$started = [DateTimeOffset]::UtcNow
$runId = $started.ToString('yyyyMMddTHHmmssfffZ') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$runs = Join-Path $root '.artifacts/releases'
New-Item -ItemType Directory -Path $runs -Force | Out-Null
Assert-NoReparse (Join-Path $root '.artifacts')
Assert-NoReparse $runs
$run = Resolve-Child $runs $runId
New-Item -ItemType Directory -Path $run | Out-Null
Write-Output "Candidate run: $run"
try {
    Copy-Item -LiteralPath $JobFile -Destination (Join-Path $run 'job.json')
    $source = Get-SourceManifest $root
    Copy-SourceSnapshot $root (Join-Path $run 'source-check') $source
    Copy-SourceSnapshot $root (Join-Path $run 'clean-source') $source
    New-Item -ItemType Directory -Path (Join-Path $run 'candidate/bin'),(Join-Path $run 'candidate/captures'),(Join-Path $run 'approvals') | Out-Null
    $shell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $stages = @()
    foreach ($pair in @(@('source-check','source-verification'),@('clean-source','clean-verification'))) {
        $snapshot = Join-Path $run $pair[0]
        $stages += Invoke-RecordedProcess $run $pair[1] $shell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $snapshot 'scripts/Verify.ps1'),'-Godot',$engine)
        foreach ($name in @('automated-tests.log','engine-smoke.log')) {
            Copy-Item -LiteralPath (Join-Path $snapshot ('prototypes/quiet-relay/.artifacts/' + $name)) -Destination (Join-Path $run ('evidence/' + $pair[1] + '/' + $name))
        }
        Assert-Log (Join-Path $run ('evidence/' + $pair[1] + '/automated-tests.log')) -Regression
        Assert-Log (Join-Path $run ('evidence/' + $pair[1] + '/engine-smoke.log'))
    }
    $clean = Join-Path $run 'clean-source'
    $stages += Invoke-RecordedProcess $run 'windows-export' $shell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $clean 'scripts/Export-Windows.ps1'),'-Godot',$engine)
    $exportFolder = Join-Path $clean 'prototypes/quiet-relay/.artifacts'
    Copy-Item -LiteralPath (Join-Path $exportFolder 'export.log') -Destination (Join-Path $run 'evidence/windows-export/export.log')
    Assert-Log (Join-Path $run 'evidence/windows-export/export.log')
    foreach ($file in @(Get-ChildItem -LiteralPath $exportFolder -File | Where-Object { $_.Extension -in @('.exe','.pck','.dll') })) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $run 'candidate/bin')
    }
    $executable = Join-Path $run 'candidate/bin/QuietRelay.exe'
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'Fresh candidate executable missing.' }
    $artifacts = @(Get-FileEntries $run @('candidate/bin'))
    $artifactHash = Get-EntriesHash $artifacts
    $stages += Invoke-RecordedProcess $run 'executable-smoke' $executable @('--headless','--quit-after','120','--log-file',(Join-Path $run 'evidence/executable-smoke/engine.log')) -ExpectedArtifactSetSha256 $artifactHash
    Assert-Log (Join-Path $run 'evidence/executable-smoke/engine.log')
    $stages += Invoke-RecordedProcess $run 'rendered-capture' $executable @('--log-file',(Join-Path $run 'evidence/rendered-capture/engine.log'),'--','--capture',('--capture-dir=' + (Join-Path $run 'candidate/captures'))) 120 $artifactHash
    Assert-Log (Join-Path $run 'evidence/rendered-capture/engine.log') -AllowShaderCacheWarning
    Assert-Captures $run
    foreach ($snapshot in @($root,(Join-Path $run 'source-check'),$clean)) {
        if ((Get-SourceManifest $snapshot).Sha256 -cne $source.Sha256) { throw 'Source changed during verification/export; evidence is stale.' }
    }
    if ((Get-EntriesHash @(Get-FileEntries $run @('candidate/bin'))) -cne $artifactHash) { throw 'Candidate executable/sidecars changed after testing.' }
    foreach ($tool in $buildTools) { if ((Get-Sha256 $tool.Path) -cne $tool.Sha256) { throw 'Engine/template changed during verification.' } }
    $evidence = @(Get-FileEntries $run @('evidence','candidate/captures'))
    $manifest = [pscustomobject][ordered]@{
        SchemaVersion = 1; Status = 'AwaitingIndependentApproval'; RunId = $runId; ProjectRoot = $root
        StartedUtc = $started.ToString('o'); CompletedUtc = [DateTimeOffset]::UtcNow.ToString('o'); ExpiresUtc = $started.AddHours($ValidityHours).ToString('o')
        SourceSha256 = $source.Sha256; SourceFiles = $source.Files; ArtifactSetSha256 = Get-EntriesHash $artifacts; ArtifactFiles = $artifacts
        TaskSha256 = Get-Sha256 (Join-Path $run 'job.json'); Job = $job; Stages = $stages; EvidenceFiles = $evidence
        Engine = $buildTools[0]; Template = $buildTools[1]; BuildTools = $buildTools
    }
    Write-Json (Join-Path $run 'candidate.json') $manifest
    Test-ReleaseCandidate $run $root -EvidenceOnly
    Write-Output 'Verification evidence complete. Independent exact-hash code/acceptance review and supported visual approval are still required. Delivery/publication remain refused.'
} catch {
    Write-Json (Join-Path $run 'failure.json') ([pscustomobject]@{ Status = 'Failed'; RunId = $runId; FailedUtc = [DateTimeOffset]::UtcNow.ToString('o'); Error = $_.Exception.Message })
    throw
}
