$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function Get-ReleaseProjectRoot {
    [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-TextSha256([string]$Value) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace('-', '') }
    finally { $algorithm.Dispose() }
}

function Read-Json([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required JSON is missing: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Json([string]$Path, $Value) {
    $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Assert-Fields($Value, [string[]]$Names, [string]$Label) {
    if ($null -eq $Value) { throw "$Label is missing." }
    foreach ($name in $Names) {
        if ($Value.PSObject.Properties.Name -notcontains $name) { throw "$Label lacks $name." }
    }
}

function Assert-Text($Value, [string]$Label) {
    if ([string]::IsNullOrWhiteSpace([string]$Value)) { throw "$Label must not be empty." }
}

function Get-Utc([string]$Value) {
    [DateTimeOffset]::Parse($Value, [Globalization.CultureInfo]::InvariantCulture).ToUniversalTime()
}

function Assert-NoReparse([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse points are not accepted: $Path" }
}

function Resolve-Child([string]$Root, [string]$Relative) {
    if ([IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)' -or $Relative -match ':') { throw "Unsafe relative path: $Relative" }
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $full = [IO.Path]::GetFullPath((Join-Path $rootFull $Relative))
    if (-not $full.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes run directory: $Relative" }
    $cursor = $rootFull
    foreach ($part in ($Relative -split '[\\/]' | Where-Object { $_ -ne '' -and $_ -ne '.' })) {
        $cursor = Join-Path $cursor $part
        if (Test-Path -LiteralPath $cursor) { Assert-NoReparse $cursor }
    }
    $full
}

function Get-Relative([string]$Root, [string]$Path) {
    $prefix = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'File is outside expected root.' }
    $full.Substring($prefix.Length).Replace('\', '/')
}

function Test-SourcePath([string]$Relative) {
    $normal = $Relative.Replace('\', '/')
    if ($normal -match '(^|/)(\.git|\.godot|\.artifacts|node_modules|history|build|evidence|local-profile|editor_data)(/|$)' -or $normal -match '^(tools|outputs|work)(/|$)') { return $false }
    if ($normal -match '\.(log|tmp|pck|exe|dll|zip|import|pem|key)$' -or $normal -match '(^|/)\.env($|\.)') { return $false }
    # Every root file and all source, documentation and scripts are included. Only generated/private artifact locations are excluded.
    if ($normal -notmatch '/') { return $true }
    return ($normal -match '^(docs|scripts)/' -or $normal -match '^prototypes/quiet-relay/')
}

function Get-SourceManifest([string]$Root) {
    Assert-NoReparse $Root
    $entries = New-Object Collections.Generic.List[object]
    $pending = New-Object Collections.Generic.Stack[string]
    $pending.Push([IO.Path]::GetFullPath($Root))
    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force)) {
            $relative = Get-Relative $Root $item.FullName
            if ($item.PSIsContainer) {
                if ((Test-SourcePath ($relative + '/placeholder')) -or $relative -eq 'prototypes') {
                    Assert-NoReparse $item.FullName
                    $pending.Push($item.FullName)
                }
            } elseif (Test-SourcePath $relative) {
                Assert-NoReparse $item.FullName
                $entries.Add([pscustomobject][ordered]@{ Path = $relative; Sha256 = Get-Sha256 $item.FullName; Bytes = [long]$item.Length })
            }
        }
    }
    $ordered = @($entries | Sort-Object -Property Path)
    if ($ordered.Count -lt 20) { throw 'Source snapshot is unexpectedly incomplete.' }
    [pscustomobject][ordered]@{ Sha256 = Get-TextSha256 ($ordered | ConvertTo-Json -Depth 5 -Compress); Files = $ordered }
}

function Copy-SourceSnapshot([string]$Root, [string]$Destination, $Manifest) {
    New-Item -ItemType Directory -Path $Destination | Out-Null
    foreach ($entry in @($Manifest.Files)) {
        $source = Resolve-Child $Root $entry.Path
        $target = Resolve-Child $Destination $entry.Path
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target
    }
    if ((Get-SourceManifest $Destination).Sha256 -ne $Manifest.Sha256) { throw 'Source changed while snapshotting.' }
}

function ConvertTo-WindowsArgument([string]$Argument) {
    '"' + ([regex]::Replace([regex]::Replace($Argument, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1')) + '"'
}

function Invoke-RecordedProcess([string]$Run, [string]$Name, [string]$Executable, [string[]]$Arguments, [int]$TimeoutSeconds = 300, [string]$ExpectedArtifactSetSha256 = '') {
    if ($ExpectedArtifactSetSha256 -ne '' -and (Get-EntriesHash @(Get-FileEntries $Run @('candidate/bin'))) -cne $ExpectedArtifactSetSha256) { throw "Executable/sidecars changed before $Name." }
    $folder = Resolve-Child $Run ('evidence/' + $Name)
    New-Item -ItemType Directory -Path $folder | Out-Null
    $stdout = Join-Path $folder 'stdout.log'
    $stderr = Join-Path $folder 'stderr.log'
    $started = [DateTimeOffset]::UtcNow
    $argumentLine = (@($Arguments | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join ' ')
    $process = Start-Process -FilePath $Executable -ArgumentList $argumentLine -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    # Windows PowerShell 5.1 otherwise sometimes loses the native exit code after a fast process exits.
    $null = $process.Handle
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        # Kill this bounded verification process tree only. No source or previous build is deleted.
        & (Join-Path $env:SystemRoot 'System32\taskkill.exe') /PID $process.Id /T /F | Out-Null
        throw "$Name exceeded its $TimeoutSeconds second limit."
    }
    $process.WaitForExit()
    $record = [pscustomobject][ordered]@{ Name = $Name; Executable = $Executable; Arguments = $Arguments; StartedUtc = $started.ToString('o'); EndedUtc = [DateTimeOffset]::UtcNow.ToString('o'); ExitCode = $process.ExitCode; Completed = $true; Stdout = Get-Relative $Run $stdout; Stderr = Get-Relative $Run $stderr }
    if ($ExpectedArtifactSetSha256 -ne '') {
        if ((Get-EntriesHash @(Get-FileEntries $Run @('candidate/bin'))) -cne $ExpectedArtifactSetSha256) { throw "Executable/sidecars changed during $Name." }
        $record | Add-Member -NotePropertyName ArtifactSetSha256 -NotePropertyValue $ExpectedArtifactSetSha256
    }
    Write-Json (Join-Path $folder 'process.json') $record
    if ($record.ExitCode -ne 0) { throw "$Name failed with exit $($record.ExitCode). See $folder" }
    $record
}

function Assert-Log([string]$Path, [switch]$Regression, [switch]$AllowShaderCacheWarning) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing log: $Path" }
    $content = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($content) -or $content -notmatch 'Godot Engine v4\.7\.2') { throw "Missing matching Godot startup in $Path" }
    $checked = $content
    if ($AllowShaderCacheWarning) {
        $checked = $checked -replace "(?m)^ERROR: Can't create shader cache folder, no shader caching will happen: user://\r?\n\s+at: RasterizerGLES3 \(drivers/gles3/rasterizer_gles3\.cpp:\d+\)\r?\n", ''
    }
    if ($checked -match '(?im)SCRIPT ERROR:|Parse Error:|(^|\s)ERROR:|\bFAIL:|\bINCOMPLETE\b|Capture failed:') { throw "Error or incomplete result in $Path" }
    if ($Regression) {
        $matches = [regex]::Matches($content, '(?m)^RESULT: (\d+) checks, 0 failures; COMPLETE\s*$')
        if ($matches.Count -ne 1 -or [int]$matches[0].Groups[1].Value -lt 450) { throw "Regression log lacks one complete >=450-check passing result: $Path" }
    }
}

function Get-ExpectedImages {
    @('01-four-targets-keyboard.png','02-controls-xbox.png','03-controls-playstation.png','04-tap-target-a.png','05-tap-target-b.png','06-aim-overrides-selection.png','07-move-while-aiming.png','08-bow-selected-target.png','09-manual-arrow-heading.png','10-faster-plain-boomerang.png','11-three-second-steered-form.png','12-returning-to-origin.png','13-targeted-bomb-platform-a.png','14-targeted-bomb-upper-platform.png','15-manual-bomb-override.png','16-targeted-bomb-out-of-range.png','17-targeted-bomb-landing.png','18-targeted-bomb-burst.png','19-ground-dash.png','20-sword-dash.png','21-circle-dodge.png','22-l1-block.png','23-controls-pause.png')
}

function Assert-Captures([string]$Run) {
    Add-Type -AssemblyName System.Drawing
    $folder = Resolve-Child $Run 'candidate/captures'
    $expected = @(Get-ExpectedImages)
    $found = @(Get-ChildItem -LiteralPath $folder -File)
    if ($found.Count -ne $expected.Count) { throw 'Capture image set is incomplete or contains unexpected files.' }
    foreach ($name in $expected) {
        $path = Resolve-Child $Run ('candidate/captures/' + $name)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing rendered frame: $name" }
        $bitmap = [Drawing.Image]::FromFile($path)
        try { if ($bitmap.Width -lt 1000 -or $bitmap.Height -lt 600) { throw "Unexpected rendered frame dimensions: $name" } }
        finally { $bitmap.Dispose() }
    }
}

function Get-FileEntries([string]$Run, [string[]]$Folders) {
    $entries = @()
    foreach ($folder in $Folders) {
        foreach ($file in @(Get-ChildItem -LiteralPath (Resolve-Child $Run $folder) -Recurse -File -Force)) {
            Assert-NoReparse $file.FullName
            $entries += [pscustomobject][ordered]@{ Path = Get-Relative $Run $file.FullName; Sha256 = Get-Sha256 $file.FullName; Bytes = [long]$file.Length }
        }
    }
    @($entries | Sort-Object -Property Path)
}

function Get-EntriesHash($Entries) { Get-TextSha256 (@($Entries) | ConvertTo-Json -Depth 5 -Compress) }

function Assert-EntryFiles([string]$Run, $Entries) {
    foreach ($entry in @($Entries)) {
        Assert-Fields $entry @('Path','Sha256','Bytes') 'Evidence file entry'
        $path = Resolve-Child $Run $entry.Path
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Evidence file is missing: $($entry.Path)" }
        if ((Get-Item -LiteralPath $path).Length -ne $entry.Bytes -or (Get-Sha256 $path) -ne $entry.Sha256) { throw "Evidence file changed: $($entry.Path)" }
    }
}

function Assert-Approval($Approval, [string]$Kind, $Manifest, [string]$ManifestSha256, [string]$Implementer) {
    Assert-Fields $Approval @('SchemaVersion','Kind','Decision','Identity','Notes','RunId','ManifestSha256','SourceSha256','ArtifactSetSha256','TaskSha256','ApprovedUtc') "$Kind approval"
    if ($Approval.SchemaVersion -ne 1 -or $Approval.Kind -ne $Kind -or $Approval.Decision -cne 'Approved') { throw "$Kind approval is absent or rejected." }
    Assert-Text $Approval.Identity "$Kind reviewer identity"
    Assert-Text $Approval.Notes "$Kind review notes"
    if ($Approval.Identity.Trim() -ieq $Implementer.Trim()) { throw 'Implementer cannot independently approve their own candidate.' }
    foreach ($name in @('RunId','SourceSha256','ArtifactSetSha256','TaskSha256')) {
        if ($Approval.$name -cne $Manifest.$name) { throw "$Kind approval refers to different $name." }
    }
    if ($Approval.ManifestSha256 -cne $ManifestSha256) { throw "$Kind approval refers to different evidence." }
    $approved = Get-Utc $Approval.ApprovedUtc
    if ($approved -lt (Get-Utc $Manifest.CompletedUtc) -or $approved -gt [DateTimeOffset]::UtcNow.AddMinutes(2) -or $approved -gt (Get-Utc $Manifest.ExpiresUtc)) { throw "$Kind approval is stale or future dated." }
    if ($Kind -eq 'Review') {
        Assert-Fields $Approval @('AcceptanceResults') 'Review approval'
        $results = @($Approval.AcceptanceResults)
        $criteria = @($Manifest.Job.AcceptanceCriteria)
        if ($results.Count -ne $criteria.Count) { throw 'Review did not evaluate every original acceptance criterion.' }
        for ($i = 0; $i -lt $criteria.Count; $i++) {
            Assert-Fields $results[$i] @('Criterion','Passed','Evidence') 'Acceptance result'
            if ($results[$i].Criterion -cne $criteria[$i] -or $results[$i].Passed -isnot [bool] -or -not $results[$i].Passed) { throw 'Acceptance review is incomplete or failed.' }
            Assert-Text $results[$i].Evidence 'Acceptance evidence explanation'
        }
    } elseif ($Kind -eq 'Visual') {
        Assert-Fields $Approval @('Method','InspectedImages') 'Visual approval'
        if ($Approval.Method -notin @('supported-image-inspection','human-rendered-inspection')) { throw 'Unsupported visual inspection method.' }
        $images = @($Manifest.EvidenceFiles | Where-Object { $_.Path -like 'candidate/captures/*.png' } | Sort-Object Path)
        $inspected = @($Approval.InspectedImages | Sort-Object Path)
        if ($images.Count -ne 23 -or $inspected.Count -ne $images.Count) { throw 'All 23 exact rendered images need independent inspection.' }
        for ($i = 0; $i -lt $images.Count; $i++) {
            Assert-Fields $inspected[$i] @('Path','Sha256','Passed','Observation') 'Inspected image'
            if ($inspected[$i].Path -cne $images[$i].Path -or $inspected[$i].Sha256 -cne $images[$i].Sha256 -or $inspected[$i].Passed -isnot [bool] -or -not $inspected[$i].Passed) { throw 'Visual inspection does not approve the exact complete rendered image set.' }
            Assert-Text $inspected[$i].Observation 'Per-image inspection observation'
        }
    }
}

function Test-ReleaseCandidate([string]$RunDirectory, [string]$ProjectRoot, [switch]$EvidenceOnly) {
    $run = [IO.Path]::GetFullPath($RunDirectory)
    Assert-NoReparse $run
    $manifestPath = Join-Path $run 'candidate.json'
    $manifest = Read-Json $manifestPath
    Assert-Fields $manifest @('SchemaVersion','Status','RunId','ProjectRoot','StartedUtc','CompletedUtc','ExpiresUtc','SourceSha256','SourceFiles','ArtifactSetSha256','ArtifactFiles','TaskSha256','Job','Stages','EvidenceFiles','Engine','Template','BuildTools') 'Candidate manifest'
    if ($manifest.SchemaVersion -ne 1 -or $manifest.Status -cne 'AwaitingIndependentApproval') { throw 'Candidate is failed or incomplete.' }
    if ([IO.Path]::GetFullPath($manifest.ProjectRoot).TrimEnd('\') -ine [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')) { throw 'Candidate belongs to a different project root.' }
    if ([string]::IsNullOrWhiteSpace($manifest.RunId)) { throw 'Run ID missing.' }
    $started = Get-Utc $manifest.StartedUtc
    $completed = Get-Utc $manifest.CompletedUtc
    $expires = Get-Utc $manifest.ExpiresUtc
    if ($completed -lt $started -or $expires -le $completed -or ($expires - $started).TotalHours -gt 24.01 -or $started -gt [DateTimeOffset]::UtcNow.AddMinutes(2) -or [DateTimeOffset]::UtcNow -gt $expires) { throw 'Candidate evidence is expired, future dated or chronologically invalid.' }
    Assert-Fields $manifest.Job @('TaskId','OriginalTask','AcceptanceCriteria','ChangedFiles','ImplementerIdentity') 'Job'
    Assert-Text $manifest.Job.OriginalTask 'Original task'
    if (@($manifest.Job.AcceptanceCriteria).Count -eq 0) { throw 'Acceptance criteria missing.' }
    if ($manifest.TaskSha256 -cne (Get-Sha256 (Join-Path $run 'job.json'))) { throw 'Original job changed.' }
    $savedJob = Read-Json (Join-Path $run 'job.json')
    if (($savedJob | ConvertTo-Json -Depth 20 -Compress) -cne ($manifest.Job | ConvertTo-Json -Depth 20 -Compress)) { throw 'Manifest does not preserve the original job.' }
    if ((Get-EntriesHash $manifest.SourceFiles) -cne $manifest.SourceSha256) { throw 'Source manifest hash is inconsistent.' }
    foreach ($root in @($ProjectRoot, (Join-Path $run 'source-check'), (Join-Path $run 'clean-source'))) {
        if ((Get-SourceManifest $root).Sha256 -cne $manifest.SourceSha256) { throw "Source is missing, changed or stale: $root" }
    }
    Assert-EntryFiles $run $manifest.ArtifactFiles
    $actualArtifacts = @(Get-FileEntries $run @('candidate/bin'))
    if ((Get-EntriesHash $actualArtifacts) -cne $manifest.ArtifactSetSha256 -or (Get-EntriesHash $manifest.ArtifactFiles) -cne $manifest.ArtifactSetSha256) { throw 'Executable or its sidecars changed.' }
    if (@($actualArtifacts | Where-Object { $_.Path -ceq 'candidate/bin/QuietRelay.exe' }).Count -ne 1) { throw 'Candidate executable missing.' }
    Assert-EntryFiles $run $manifest.EvidenceFiles
    if ((Get-EntriesHash @(Get-FileEntries $run @('evidence','candidate/captures'))) -cne (Get-EntriesHash $manifest.EvidenceFiles)) { throw 'Evidence set has missing, changed or additional files.' }
    if (@($manifest.BuildTools).Count -lt 2) { throw 'Build tool provenance is incomplete.' }
    foreach ($requiredTool in @($manifest.Engine,$manifest.Template)) {
        Assert-Fields $requiredTool @('Path','Sha256') 'Required build tool'
        if (@($manifest.BuildTools | Where-Object { $_.Path -ceq $requiredTool.Path -and $_.Sha256 -ceq $requiredTool.Sha256 }).Count -ne 1) { throw 'Required engine/template provenance is absent or inconsistent.' }
    }
    if ($manifest.Engine.Path -match '_console\.exe$') {
        $companion = $manifest.Engine.Path -replace '_console\.exe$', '.exe'
        if (@($manifest.BuildTools | Where-Object { $_.Path -ceq $companion }).Count -ne 1) { throw 'Actual Godot engine companion provenance is missing.' }
    }
    foreach ($tool in @($manifest.BuildTools)) {
        Assert-Fields $tool @('Path','Sha256') 'Build tool'
        if (-not (Test-Path -LiteralPath $tool.Path -PathType Leaf) -or (Get-Sha256 $tool.Path) -cne $tool.Sha256) { throw 'Engine/template provenance changed or is missing.' }
    }
    $required = @('source-verification','clean-verification','windows-export','executable-smoke','rendered-capture')
    if (@($manifest.Stages).Count -ne $required.Count) { throw 'Required verification stage missing.' }
    $priorEnd = $started
    foreach ($name in $required) {
        $stage = @($manifest.Stages | Where-Object { $_.Name -ceq $name })
        if ($stage.Count -ne 1) { throw "Missing or duplicate stage: $name" }
        Assert-Fields $stage[0] @('StartedUtc','EndedUtc','ExitCode','Completed') "$name stage"
        if ($stage[0].Completed -isnot [bool] -or -not $stage[0].Completed -or $stage[0].ExitCode -ne 0 -or (Get-Utc $stage[0].StartedUtc) -lt $priorEnd -or (Get-Utc $stage[0].EndedUtc) -lt (Get-Utc $stage[0].StartedUtc) -or (Get-Utc $stage[0].EndedUtc) -gt $completed) { throw "Failed, stale or incomplete stage: $name" }
        $priorEnd = Get-Utc $stage[0].EndedUtc
        if ($name -in @('executable-smoke','rendered-capture')) {
            Assert-Fields $stage[0] @('ArtifactSetSha256') "$name artifact provenance"
            if ($stage[0].ArtifactSetSha256 -cne $manifest.ArtifactSetSha256) { throw 'Tested executable/sidecars do not match approved artifacts.' }
        }
        $savedStage = Read-Json (Resolve-Child $run ('evidence/' + $name + '/process.json'))
        if (($savedStage | ConvertTo-Json -Depth 10 -Compress) -cne ($stage[0] | ConvertTo-Json -Depth 10 -Compress)) { throw 'Stage metadata changed.' }
    }
    foreach ($folder in @('source-verification','clean-verification')) {
        Assert-Log (Resolve-Child $run ('evidence/' + $folder + '/automated-tests.log')) -Regression
        Assert-Log (Resolve-Child $run ('evidence/' + $folder + '/engine-smoke.log'))
    }
    Assert-Log (Resolve-Child $run 'evidence/windows-export/export.log')
    Assert-Log (Resolve-Child $run 'evidence/executable-smoke/engine.log')
    Assert-Log (Resolve-Child $run 'evidence/rendered-capture/engine.log') -AllowShaderCacheWarning
    Assert-Captures $run
    if (-not $EvidenceOnly) {
        $manifestHash = Get-Sha256 $manifestPath
        Assert-Approval (Read-Json (Join-Path $run 'approvals/review.json')) 'Review' $manifest $manifestHash $manifest.Job.ImplementerIdentity
        Assert-Approval (Read-Json (Join-Path $run 'approvals/visual.json')) 'Visual' $manifest $manifestHash $manifest.Job.ImplementerIdentity
    }
    [pscustomobject]@{ Valid = $true; Mode = $(if ($EvidenceOnly) { 'EvidenceOnly-NOT-RELEASE-APPROVAL' } else { 'ReleaseApproved' }); RunId = $manifest.RunId; SourceSha256 = $manifest.SourceSha256; ArtifactSetSha256 = $manifest.ArtifactSetSha256; ManifestSha256 = Get-Sha256 $manifestPath; ExpiresUtc = $manifest.ExpiresUtc }
}
