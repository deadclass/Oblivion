$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
. (Join-Path $PSScriptRoot '..\release\Common.ps1')

$script:OblivionRepository = 'https://github.com/deadclass/Oblivion.git'
$script:OblivionBranch = 'prototype/quiet-relay-collaboration'
$script:OblivionPullRequest = 1

function Assert-PublicationDestination($Destination) {
    Assert-Fields $Destination @('RepositoryUrl','Branch','PullRequest','Visibility') 'Publication destination'
    if ($Destination.RepositoryUrl -cne $script:OblivionRepository -or $Destination.Branch -cne $script:OblivionBranch -or $Destination.PullRequest -ne 1 -or $Destination.Visibility -cne 'public') {
        throw 'Publication destination must be the owner-approved public deadclass/Oblivion branch prototype/quiet-relay-collaboration, PR 1.'
    }
}

function Assert-PublicRelativePath([string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or $Relative -match '[\\:\x00-\x1f\x7f]' -or $Relative -match '^/|/$|//' -or $Relative -match '(^|/)\.{1,2}(/|$)' -or $Relative -match '(^|/)-' -or $Relative -match '[<>"|?*]') { throw 'Unsafe publication path.' }
    if ($Relative -match '(?i)(^|/)(AGENTS\.md|\.git|\.godot|\.artifacts|[^/]*\.artifacts|node_modules|build|evidence|history|local-profile|editor_data|outputs|work|tools|\.codex|\.agents|\.aws)(/|$)' -or $Relative -match '(?i)(^|/)\.env($|\.)' -or $Relative -match '(?i)\.(exe|dll|pck|zip|7z|tar|gz|log|tmp|import|pem|key|pfx|p12|lnk)$') { throw "Private/generated/binary publication path refused: $Relative" }
}

function Test-ProtectedGamePath([string]$Relative) { $Relative.StartsWith('prototypes/quiet-relay/', [StringComparison]::OrdinalIgnoreCase) }
function Test-ReviewedPublicVersionPath([string]$Relative) {
    $Relative -cmatch '^docs/.*\.(md|txt|json)$' -or $Relative -cmatch '(^|/)(README|CONTRIBUTING)\.md$' -or $Relative -ceq '.gitignore' -or $Relative -ceq 'prototypes/quiet-relay/export_presets.cfg'
}

function Assert-PublicFile([string]$Path, [string]$PublicPath) {
    Assert-PublicRelativePath $PublicPath
    Assert-NoReparse $Path
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 77 -and $bytes[1] -eq 90) { throw 'Executable bytes refused in public source.' }
    if ($bytes.Length -ge 4 -and (($bytes[0] -eq 127 -and $bytes[1] -eq 69 -and $bytes[2] -eq 76 -and $bytes[3] -eq 70) -or ($bytes[0] -eq 80 -and $bytes[1] -eq 75))) { throw 'Executable/archive bytes refused in public source.' }
    $asset = $PublicPath -match '(?i)\.(png|jpg|jpeg|webp|wav|ogg|mp3|ttf|otf)$'
    if (-not $asset -and $PublicPath -notmatch '(?i)\.(gd|uid|godot|tscn|tres|cfg|md|txt|json|ps1|cs|svg|glsl|gdshader)$' -and $PublicPath -cnotin @('.gitignore','.gitattributes')) { throw "Unreviewed public source file type: $PublicPath" }
    if ($asset) { $text = [Text.Encoding]::ASCII.GetString($bytes) }
    else {
        try { $text = (New-Object Text.UTF8Encoding($false, $true)).GetString($bytes) } catch { throw "Public text is not valid UTF-8: $PublicPath" }
        if ($text.IndexOf([char]0) -ge 0) { throw "Binary bytes in public text: $PublicPath" }
    }
    if ($text -match '(?i)(?<![A-Z0-9])[A-Z]:[\\/]|/(Users|home)/|(?<!\\)\\\\(?!\\)[_$A-Z0-9-][_$A-Z0-9.-]*\\(?!\\)[_$A-Z0-9-]|file:[/]{2}') { throw "Private absolute machine path in public content: $PublicPath" }
    if ($text -match '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16})\b') { throw "Secret-shaped content refused: $PublicPath" }
    if ($text -match '(?i)(api[_-]?key|access[_-]?token|client[_-]?secret|password)\s*[:=]\s*["''][A-Za-z0-9+/_=.-]{12,}["'']') { throw "Credential assignment refused: $PublicPath" }
    if ($PublicPath -ceq 'prototypes/quiet-relay/export_presets.cfg' -and $text -match '(?m)^custom_template/(debug|release)\s*=\s*"[^"\r\n]+"') { throw 'Machine-specific export-template configuration refused.' }
}

function Assert-PublicationIntent($Manifest) {
    Assert-Fields $Manifest.Job @('ReleaseIntent') 'Original job'
    Assert-Fields $Manifest.Job.ReleaseIntent @('GitHubPublication') 'Original job release intent'
    if ($Manifest.Job.ReleaseIntent.GitHubPublication -isnot [bool] -or -not $Manifest.Job.ReleaseIntent.GitHubPublication) { throw 'Original job does not authorize GitHub publication; a local harness trial can never publish.' }
}

function Assert-ExpectedRemoteHead([string]$Expected, [string]$Actual) {
    if ($Expected -cnotmatch '^[0-9a-f]{40}$' -or $Actual -cne $Expected) { throw 'Remote head moved or is invalid; reconcile and obtain a new reviewed mapping and approval.' }
}

function Get-PublicationDesktopPath { [Environment]::GetFolderPath('Desktop') }
function Read-PublicationShortcut([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Required delivered or recovery shortcut is missing.' }
    Assert-NoReparse $Path
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($Path)
    [pscustomobject]@{ Target = $link.TargetPath; WorkingDirectory = $link.WorkingDirectory; Arguments = $link.Arguments }
}

function Assert-VerifiedDesktopDelivery([string]$Run, $Manifest, $Release) {
    Assert-Fields $Manifest.Job.ReleaseIntent @('DesktopDelivery') 'Original job release intent'
    if ($Manifest.Job.ReleaseIntent.DesktopDelivery -isnot [bool] -or -not $Manifest.Job.ReleaseIntent.DesktopDelivery) { throw 'Publication requires authorized verified desktop delivery first.' }
    $receiptFolder = Resolve-Child $Run 'delivery'
    $receipt = Read-Json (Resolve-Child $Run 'delivery/receipt.json')
    Assert-Fields $receipt @('Status','RunId','ManifestSha256','SourceSha256','ArtifactSetSha256','DeliveredUtc','Launcher','Target','WorkingDirectory','PreviousLauncherBackup','PreviousTarget','PreviousTargetSha256','RecoveryTarget','RecoveryLauncher','RecoveryFiles') 'Desktop delivery receipt'
    if ($receipt.Status -cne 'Delivered') { throw 'Desktop delivery is failed or incomplete.' }
    foreach ($key in @('RunId','ManifestSha256','SourceSha256','ArtifactSetSha256')) { if ($receipt.$key -cne $Release.$key) { throw "Stale desktop delivery receipt: $key differs." } }
    $delivered = Get-Utc $receipt.DeliveredUtc
    if ($delivered -lt (Get-Utc $Manifest.CompletedUtc) -or $delivered -gt [DateTimeOffset]::UtcNow.AddMinutes(2) -or $delivered -gt (Get-Utc $Manifest.ExpiresUtc)) { throw 'Desktop delivery evidence is stale or future dated.' }
    $desktop = Get-PublicationDesktopPath
    Assert-NoReparse $desktop
    $gameFolder = Resolve-Child $desktop 'OBLIVION'
    $launcher = Resolve-Child $gameFolder 'Play Oblivion.lnk'
    $destination = Resolve-Child $gameFolder ('builds/' + $Manifest.RunId)
    $target = Resolve-Child $destination 'QuietRelay.exe'
    foreach ($pair in @(@($receipt.Launcher,$launcher),@($receipt.WorkingDirectory,$destination),@($receipt.Target,$target))) {
        if ([IO.Path]::GetFullPath([string]$pair[0]) -ine [IO.Path]::GetFullPath([string]$pair[1])) { throw 'Desktop receipt names a different launcher, target or working folder.' }
    }
    Assert-NoReparse $destination
    $actualFiles = @(Get-ChildItem -LiteralPath $destination -Recurse -Force)
    foreach ($item in $actualFiles) { Assert-NoReparse $item.FullName }
    $actualFiles = @($actualFiles | Where-Object { -not $_.PSIsContainer })
    if ($actualFiles.Count -ne @($Manifest.ArtifactFiles).Count) { throw 'Delivered artifact set is incomplete or contains extra files.' }
    $deliveredEntries = @()
    foreach ($entry in @($Manifest.ArtifactFiles)) {
        if ($entry.Path -cnotmatch '^candidate/bin/([^/]+)$') { throw 'Unexpected approved desktop artifact path.' }
        $file = Resolve-Child $destination $Matches[1]
        if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Get-Sha256 $file) -cne $entry.Sha256 -or (Get-Item -LiteralPath $file).Length -ne $entry.Bytes) { throw 'Actual delivered executable/sidecars differ from the approved candidate.' }
        $deliveredEntries += [pscustomobject][ordered]@{ Path = $entry.Path; Sha256 = Get-Sha256 $file; Bytes = [long](Get-Item -LiteralPath $file).Length }
    }
    if ((Get-EntriesHash @($deliveredEntries | Sort-Object Path)) -cne $Release.ArtifactSetSha256) { throw 'Actual desktop artifact set hash differs.' }
    $readback = Read-PublicationShortcut $launcher
    if ($readback.Target -ine $target -or $readback.WorkingDirectory -ine $destination -or $readback.Arguments -cne '') { throw 'Actual selected launcher readback differs from verified desktop delivery.' }
    $previous = Read-Json (Resolve-Child $Run 'delivery/previous.json')
    Assert-Fields $previous @('Launcher','LauncherSha256','Target','TargetSha256','Arguments','RecoveryTarget','RecoveryLauncher','RecoveryFiles') 'Previous build recovery receipt'
    $backup = Resolve-Child $Run 'delivery/previous-Play Oblivion.lnk'
    if ($receipt.PreviousLauncherBackup -ine $backup -or (Get-Sha256 $backup) -cne $previous.LauncherSha256 -or $previous.Launcher -ine $launcher -or $receipt.PreviousTarget -ine $previous.Target -or $receipt.PreviousTargetSha256 -cne $previous.TargetSha256) { throw 'Previous launcher/build recovery evidence differs.' }
    $recovery = Resolve-Child $Run 'delivery/previous-build'
    $recoveryTarget = Resolve-Child $recovery ([IO.Path]::GetFileName([string]$previous.Target))
    $recoveryLauncher = Resolve-Child $Run 'delivery/Recover previous Oblivion.lnk'
    if ($receipt.RecoveryTarget -ine $recoveryTarget -or $previous.RecoveryTarget -ine $recoveryTarget -or $receipt.RecoveryLauncher -ine $recoveryLauncher -or $previous.RecoveryLauncher -ine $recoveryLauncher -or (Get-Sha256 $recoveryTarget) -cne $receipt.PreviousTargetSha256) { throw 'Previous executable is no longer recoverable.' }
    if ((Get-EntriesHash @($receipt.RecoveryFiles)) -cne (Get-EntriesHash @($previous.RecoveryFiles)) -or @($receipt.RecoveryFiles).Count -eq 0) { throw 'Previous build file manifest differs.' }
    $recovered = @(Get-ChildItem -LiteralPath $recovery -Recurse -Force)
    foreach ($item in $recovered) { Assert-NoReparse $item.FullName }
    if (@($recovered | Where-Object { -not $_.PSIsContainer }).Count -ne @($receipt.RecoveryFiles).Count) { throw 'Previous recovery artifact set differs.' }
    foreach ($entry in @($receipt.RecoveryFiles)) {
        Assert-Fields $entry @('Path','Sha256','Bytes') 'Previous recovery artifact'
        $file = Resolve-Child $recovery $entry.Path
        if ((Get-Sha256 $file) -cne $entry.Sha256 -or (Get-Item -LiteralPath $file).Length -ne $entry.Bytes) { throw 'Previous recovery artifact changed.' }
    }
    $recoverReadback = Read-PublicationShortcut $recoveryLauncher
    if ($recoverReadback.Target -ine $recoveryTarget -or $recoverReadback.WorkingDirectory -ine $recovery -or $recoverReadback.Arguments -cne $previous.Arguments) { throw 'Recovery launcher readback failed.' }
}

function Test-PublicationApproval([string]$RunDirectory, [string]$ProjectRoot, [string]$MappingPath, [string]$ApprovalPath) {
    # This is deliberately a full release check. EvidenceOnly is never an authority to publish.
    $release = Test-ReleaseCandidate -RunDirectory $RunDirectory -ProjectRoot $ProjectRoot
    if ($release.Valid -isnot [bool] -or -not $release.Valid -or $release.Mode -cne 'ReleaseApproved') { throw 'Complete independent release approval is required.' }
    $run = [IO.Path]::GetFullPath($RunDirectory)
    $manifest = Read-Json (Join-Path $run 'candidate.json')
    Assert-PublicationIntent $manifest
    Assert-Fields $manifest.Job.ReleaseIntent @('DesktopDelivery') 'Original job release intent'
    if ($manifest.Job.ReleaseIntent.DesktopDelivery -isnot [bool] -or -not $manifest.Job.ReleaseIntent.DesktopDelivery) { throw 'GitHub publication requires authorized desktop delivery intent first.' }
    $mapping = Read-Json $MappingPath
    $approval = Read-Json $ApprovalPath
    Assert-Fields $mapping @('SchemaVersion','Destination','OwnerPolicy','ExpectedRemoteHead','RunId','ManifestSha256','SourceSha256','ArtifactSetSha256','TaskSha256','ExpiresUtc','Files') 'Publication mapping'
    Assert-Fields $approval @('SchemaVersion','Decision','ReviewedBy','ReviewNotes','ApprovedUtc','ExpiresUtc','MappingSha256','Destination','ExpectedRemoteHead','RunId','ManifestSha256','SourceSha256','ArtifactSetSha256','TaskSha256') 'Publication approval'
    if ($mapping.SchemaVersion -ne 1 -or $approval.SchemaVersion -ne 1 -or $approval.Decision -cne 'ApprovedForPublicPush') { throw 'Explicit reviewed publication approval is missing or rejected.' }
    Assert-PublicationDestination $mapping.Destination
    Assert-PublicationDestination $approval.Destination
    Assert-Fields $mapping.OwnerPolicy @('ConfirmedBy','ConfirmedUtc','AutomaticVerifiedPush','Destination') 'Owner publication policy'
    Assert-PublicationDestination $mapping.OwnerPolicy.Destination
    Assert-Text $mapping.OwnerPolicy.ConfirmedBy 'Owner confirmation identity'
    if ($mapping.OwnerPolicy.AutomaticVerifiedPush -isnot [bool] -or -not $mapping.OwnerPolicy.AutomaticVerifiedPush -or (Get-Utc $mapping.OwnerPolicy.ConfirmedUtc) -gt [DateTimeOffset]::UtcNow.AddMinutes(2)) { throw 'Specific owner authorization for automatic verified pushes is required.' }
    Assert-Text $approval.ReviewedBy 'Publication reviewer identity'
    Assert-Text $approval.ReviewNotes 'Public content review notes'
    if ($approval.ReviewedBy.Trim() -ieq $manifest.Job.ImplementerIdentity.Trim()) { throw 'Publication content needs an independent reviewer.' }
    foreach ($key in @('RunId','ManifestSha256','SourceSha256','ArtifactSetSha256')) {
        if ($mapping.$key -cne $release.$key -or $approval.$key -cne $release.$key) { throw "Stale publication mapping or approval: $key differs from the exact release." }
    }
    if ($mapping.TaskSha256 -cne $manifest.TaskSha256 -or $approval.TaskSha256 -cne $manifest.TaskSha256) { throw 'Publication task evidence differs.' }
    if ($approval.MappingSha256 -cne (Get-Sha256 $MappingPath)) { throw 'Publication mapping changed after review.' }
    Assert-ExpectedRemoteHead $mapping.ExpectedRemoteHead $approval.ExpectedRemoteHead
    $approved = Get-Utc $approval.ApprovedUtc
    $expires = Get-Utc $approval.ExpiresUtc
    if ($approved -lt (Get-Utc $manifest.CompletedUtc) -or $approved -gt [DateTimeOffset]::UtcNow.AddMinutes(2) -or $expires -le $approved -or $expires -gt (Get-Utc $manifest.ExpiresUtc) -or $expires -gt (Get-Utc $mapping.ExpiresUtc) -or [DateTimeOffset]::UtcNow -gt $expires -or (Get-Utc $mapping.ExpiresUtc) -gt (Get-Utc $manifest.ExpiresUtc)) { throw 'Publication review is stale, expired or future dated.' }
    $files = @($mapping.Files)
    if ($files.Count -eq 0) { throw 'Publication mapping has no reviewed files.' }
    $sources = @{}
    foreach ($entry in @($manifest.SourceFiles)) {
        if ($sources.ContainsKey([string]$entry.Path)) { throw 'Candidate source manifest has duplicate or case-colliding paths.' }
        $sources[[string]$entry.Path] = $entry
    }
    $mappedSources = @{}
    $publicPaths = @{}
    $resolvedFiles = @()
    $reviewRoot = Split-Path ([IO.Path]::GetFullPath($MappingPath)) -Parent
    foreach ($file in $files) {
        Assert-Fields $file @('CandidatePath','PublicPath','Mode','OriginalSha256','PublicSha256') 'Publication file mapping'
        Assert-PublicRelativePath $file.CandidatePath
        Assert-PublicRelativePath $file.PublicPath
        if (-not $sources.ContainsKey([string]$file.CandidatePath) -or $mappedSources.ContainsKey([string]$file.CandidatePath) -or $publicPaths.ContainsKey([string]$file.PublicPath)) { throw 'Mapping refers to absent or duplicate source/public paths.' }
        $source = $sources[[string]$file.CandidatePath]
        if ($file.CandidatePath -cne $source.Path) { throw 'CandidatePath must exactly match the canonical candidate manifest path, including case.' }
        if ($file.OriginalSha256 -cne $source.Sha256) { throw 'Stale mapping original source hash.' }
        $candidateFile = Resolve-Child (Join-Path $run 'source-check') $file.CandidatePath
        if ((Get-Sha256 $candidateFile) -cne $source.Sha256) { throw 'Candidate source changed.' }
        $publicFile = $candidateFile
        if ($file.Mode -ceq 'ExactCandidate') {
            if ($file.PublicSha256 -cne $source.Sha256) { throw 'Exact candidate content hash differs.' }
        } elseif ($file.Mode -ceq 'ReviewedPublicVersion') {
            if ($file.CandidatePath -cne $file.PublicPath -or -not (Test-ReviewedPublicVersionPath $file.CandidatePath)) { throw 'Gameplay/assets/tests/project content cannot be sanitized or relocated.' }
            Assert-Fields $file @('PublicVersionPath','ReviewNotes') 'Reviewed public content'
            Assert-Text $file.ReviewNotes 'Public-version review notes'
            $publicFile = Resolve-Child $reviewRoot $file.PublicVersionPath
        } else { throw 'Unknown publication mapping mode.' }
        if ((Test-ProtectedGamePath $file.CandidatePath) -and $file.PublicPath -cne $file.CandidatePath) { throw 'Game content must preserve its approved path.' }
        if ((Test-ProtectedGamePath $file.PublicPath) -and $file.PublicPath -cne $file.CandidatePath) { throw 'Non-game source cannot overwrite game content.' }
        if ((Get-Sha256 $publicFile) -cne $file.PublicSha256) { throw 'Reviewed public version is missing or changed.' }
        Assert-PublicFile $publicFile $file.PublicPath
        $mappedSources[[string]$file.CandidatePath] = $true
        $publicPaths[[string]$file.PublicPath] = $true
        $resolvedFiles += [pscustomobject]@{ CandidatePath = $file.CandidatePath; PublicPath = $file.PublicPath; File = $publicFile; Sha256 = $file.PublicSha256 }
    }
    foreach ($source in @($manifest.SourceFiles)) {
        if ((Test-ProtectedGamePath $source.Path) -and -not $mappedSources.ContainsKey([string]$source.Path)) { throw "Incomplete gameplay/assets/tests/project mapping: $($source.Path)" }
    }
    [pscustomobject]@{ Valid = $true; Release = $release; Manifest = $manifest; Mapping = $mapping; MappingSha256 = Get-Sha256 $MappingPath; ApprovalSha256 = Get-Sha256 $ApprovalPath; Files = $resolvedFiles }
}

function Test-PublicationContract([string]$RunDirectory, [string]$ProjectRoot, [string]$MappingPath, [string]$ApprovalPath) {
    $contract = Test-PublicationApproval $RunDirectory $ProjectRoot $MappingPath $ApprovalPath
    Assert-VerifiedDesktopDelivery ([IO.Path]::GetFullPath($RunDirectory)) $contract.Manifest $contract.Release
    $contract
}

function Assert-PublicationGitEnvironment {
    # Refuse process-scoped Git routing/config injection rather than changing the user's environment or config.
    # WorkingDirectory alone does not isolate git when these variables point at another repository or index.
    $blocked = @('GIT_DIR','GIT_WORK_TREE','GIT_COMMON_DIR','GIT_INDEX_FILE','GIT_OBJECT_DIRECTORY','GIT_ALTERNATE_OBJECT_DIRECTORIES','GIT_NAMESPACE','GIT_SHALLOW_FILE','GIT_GRAFT_FILE','GIT_REPLACE_REF_BASE','GIT_PREFIX','GIT_CONFIG','GIT_CONFIG_COUNT','GIT_CONFIG_PARAMETERS','GIT_AUTHOR_NAME','GIT_AUTHOR_EMAIL','GIT_COMMITTER_NAME','GIT_COMMITTER_EMAIL')
    foreach ($name in $blocked) {
        if (-not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($name,'Process'))) { throw "Git repository-routing/config environment variable $name is set; publication requires a clean process and does not modify that environment." }
    }
    foreach ($name in @([Environment]::GetEnvironmentVariables('Process').Keys)) {
        if ([string]$name -imatch '^GIT_CONFIG_(KEY|VALUE)_[0-9]+$') { throw 'Injected Git config environment entries are refused; publication requires a clean process.' }
    }
}

function Get-PublicationGitStartInfo([string]$Executable, [string]$Directory, [string]$ArgumentLine) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Executable
    $start.WorkingDirectory = $Directory
    $start.Arguments = $ArgumentLine
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    # Child-only flags: never launch login UI or alter the caller's environment/credential configuration.
    $start.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
    $start.EnvironmentVariables['GCM_INTERACTIVE'] = 'never'
    $start
}

function Get-PublicationGitCandidatePaths {
    # Native StarNet children can omit the existing Codex dependency runtime from PATH.
    # This is the same pre-existing bundled Git used by the owner-authorized GCM sign-in.
    $profileRoot = [Environment]::GetFolderPath('UserProfile')
    if (-not [string]::IsNullOrWhiteSpace($profileRoot)) { Join-Path $profileRoot '.cache/codex-runtimes/codex-primary-runtime/dependencies/native/git/cmd/git.exe' }
    foreach ($root in @([Environment]::GetFolderPath('ProgramFiles'), [Environment]::GetFolderPath('ProgramFilesX86'))) {
        if (-not [string]::IsNullOrWhiteSpace($root)) {
            Join-Path $root 'Git/cmd/git.exe'
            Join-Path $root 'Git/bin/git.exe'
        }
    }
    $localRoot = [Environment]::GetFolderPath('LocalApplicationData')
    if (-not [string]::IsNullOrWhiteSpace($localRoot)) {
        Join-Path $localRoot 'Programs/Git/cmd/git.exe'
        Join-Path $localRoot 'Programs/Git/bin/git.exe'
    }
}

function Resolve-PublicationGit {
    # Resolve an installed application, never an alias/function or a command downloaded at runtime.
    $applications = @(Get-Command -Name git.exe -CommandType Application -ErrorAction SilentlyContinue)
    $candidates = @($applications | ForEach-Object { $_.Source }) + @(Get-PublicationGitCandidatePaths)
    $seen = @{}
    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate) -or -not [IO.Path]::IsPathRooted($candidate)) { continue }
        $full = [IO.Path]::GetFullPath($candidate)
        if ($seen.ContainsKey($full)) { continue }
        $seen[$full] = $true
        if ([IO.Path]::GetFileName($full) -ine 'git.exe' -or -not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        Assert-NoReparse $full
        return $full
    }
    throw 'Existing Git application is unavailable on PATH or in the supported existing Windows/Codex runtime locations; publication stops without installation or PATH changes.'
}

function Invoke-PublicationGit([string]$Directory, [string[]]$Arguments, [int]$TimeoutSeconds = 120, [switch]$AllowFailure) {
    Assert-PublicationGitEnvironment
    $git = Resolve-PublicationGit
    $logRoot = Join-Path $Directory '.publication-local'
    if (-not (Test-Path -LiteralPath $logRoot)) { New-Item -ItemType Directory -Path $logRoot | Out-Null }
    $hooks = Join-Path $logRoot 'empty-hooks'
    if (-not (Test-Path -LiteralPath $hooks)) { New-Item -ItemType Directory -Path $hooks | Out-Null }
    $tag = [Guid]::NewGuid().ToString('N')
    $out = Join-Path $logRoot ($tag + '.out')
    $err = Join-Path $logRoot ($tag + '.err')
    $allArgs = @('-c',('core.hooksPath=' + $hooks),'-c','core.autocrlf=false','-c','credential.interactive=never','-c','http.followRedirects=false','-c','protocol.file.allow=never','-c','protocol.ext.allow=never') + $Arguments
    $line = (@($allArgs | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join ' ')
    $process = New-Object Diagnostics.Process
    $process.StartInfo = Get-PublicationGitStartInfo $git $Directory $line
    $null = $process.Start()
    $null = $process.Handle
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        & (Join-Path $env:SystemRoot 'System32\taskkill.exe') /PID $process.Id /T /F | Out-Null
        throw 'Bounded git operation timed out; publication is not complete.'
    }
    $process.WaitForExit()
    [IO.File]::WriteAllText($out, $stdoutTask.Result, (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText($err, $stderrTask.Result, (New-Object Text.UTF8Encoding($false)))
    $exitCode = $process.ExitCode
    $process.Dispose()
    if ($exitCode -ne 0 -and -not $AllowFailure) { throw "Git operation failed (exit $exitCode); inspect local publication logs. No publication success is claimed." }
    [pscustomobject]@{ ExitCode = $exitCode; Stdout = [IO.File]::ReadAllText($out); Stderr = [IO.File]::ReadAllText($err) }
}

function Get-PublicationRemoteHead([string]$Directory) {
    $answer = Invoke-PublicationGit $Directory @('ls-remote','--exit-code',$script:OblivionRepository,('refs/heads/' + $script:OblivionBranch))
    $lines = @($answer.Stdout -split '\r?\n' | Where-Object { $_ -ne '' })
    if ($lines.Count -ne 1 -or $lines[0] -cnotmatch '^([0-9a-f]{40})\trefs/heads/prototype/quiet-relay-collaboration$') { throw 'Unable to verify the exact approved remote branch head.' }
    $Matches[1]
}

function Assert-PublicationPushDestination([string]$Directory) {
    # Git can inherit several remote.origin.pushurl values from global/system configuration.
    # Inspect every effective push URL: checking only the first can send one push to other repositories too.
    $answer = Invoke-PublicationGit $Directory @('remote','get-url','--push','--all','origin')
    $urls = @($answer.Stdout -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($urls.Count -ne 1 -or $urls[0] -cne $script:OblivionRepository) { throw 'Git effective push destinations must contain exactly one approved repository URL; inherited multiple push URLs or URL rewrites are refused.' }
}

function Get-PublicationTree([string]$Directory, [string]$Revision) {
    $answer = Invoke-PublicationGit $Directory @('ls-tree','-r','-z',$Revision)
    $tree = @{}
    foreach ($row in @($answer.Stdout -split [char]0 | Where-Object { $_ -ne '' })) {
        if ($row -cnotmatch '^(100644|100755) blob ([0-9a-f]{40})\t(.+)$') { throw 'Remote tree has unsupported symlinks/submodules or unsafe file modes.' }
        $path = $Matches[3]
        if ($path -match '[\\\x00-\x1f\x7f]' -or $tree.ContainsKey($path)) { throw 'Remote tree has unsafe/duplicate paths.' }
        $tree[$path] = [pscustomobject]@{ Mode = $Matches[1]; Sha = $Matches[2] }
    }
    $tree
}

function Assert-PublicationTrees($BaseTree, $FinalTree, $Contract, [string]$Directory) {
    $mapped = @{}
    foreach ($file in @($Contract.Files)) {
        $mapped[$file.PublicPath] = $true
        if (-not $FinalTree.ContainsKey($file.PublicPath)) { throw 'Published candidate file is missing from commit tree.' }
        $blob = (Invoke-PublicationGit $Directory @('hash-object','--no-filters','--',$file.File)).Stdout.Trim()
        if ($FinalTree[$file.PublicPath].Sha -cne $blob) { throw 'Git filters or staging changed approved public bytes.' }
    }
    foreach ($path in @($BaseTree.Keys)) {
        if (-not $FinalTree.ContainsKey($path)) { throw 'Remote source deletion is forbidden.' }
        if (-not $mapped.ContainsKey($path) -and ($BaseTree[$path].Sha -cne $FinalTree[$path].Sha -or $BaseTree[$path].Mode -cne $FinalTree[$path].Mode)) { throw 'Unreviewed remote-only content was modified.' }
        if ((Test-ProtectedGamePath $path) -and -not $mapped.ContainsKey($path)) { throw "Remote-only game source needs explicit reconciliation into a newly verified candidate: $path" }
    }
    foreach ($path in @($FinalTree.Keys)) { if (-not $BaseTree.ContainsKey($path) -and -not $mapped.ContainsKey($path)) { throw 'Unreviewed new file in publication tree.' } }
}

function Assert-PublicationFilterConfiguration([string]$Directory) {
    # NUL records preserve duplicate values and embedded newlines; never run a filter to test it.
    $answer = Invoke-PublicationGit $Directory @('config','--null','--get-regexp','^filter\..*\.(clean|smudge|process)$') -AllowFailure
    if ($answer.ExitCode -eq 1 -and $answer.Stdout -ceq '') { return }
    if ($answer.ExitCode -ne 0 -or -not $answer.Stdout.EndsWith([string][char]0)) { throw 'Configured Git content filter query failed or returned malformed records.' }
    $allowed = @{
        'filter.lfs.clean' = 'git-lfs clean -- %f'
        'filter.lfs.smudge' = 'git-lfs smudge -- %f'
        'filter.lfs.process' = 'git-lfs filter-process'
    }
    $records = $answer.Stdout.Substring(0, $answer.Stdout.Length - 1).Split([char]0)
    foreach ($record in $records) {
        if ($record -cnotmatch '\A(filter\.lfs\.(clean|smudge|process))\n([^\r\n]+)\z' -or $Matches[3] -cne $allowed[$Matches[1]]) {
            throw 'Configured Git content filter is not an exact standard unused LFS default; no filter code is run.'
        }
    }
}

function Assert-PublicationFilterAttributes([string]$Directory, [string[]]$Paths, [switch]$Cached) {
    # Audit the full remote + mapped union, not just files about to be added. Git itself resolves
    # nested/global/info attributes; --cached uses the fetched index before any materialization.
    $seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $unique = @($Paths | Where-Object { $seen.Add($_) } | Sort-Object)
    for ($offset = 0; $offset -lt $unique.Count; $offset += 32) {
        $batch = @($unique | Select-Object -Skip $offset -First 32)
        $arguments = @('check-attr','-z')
        if ($Cached) { $arguments += '--cached' }
        $arguments += @('filter','--') + $batch
        $answer = Invoke-PublicationGit $Directory $arguments
        $fields = $answer.Stdout.Split([char]0)
        if ($fields.Count -ne (3 * $batch.Count + 1) -or $fields[$fields.Count - 1] -cne '') { throw 'Git filter attribute audit returned incomplete or malformed records.' }
        for ($index = 0; $index -lt $batch.Count; $index++) {
            if ($fields[3 * $index] -cne $batch[$index] -or $fields[3 * $index + 1] -cne 'filter') { throw 'Git filter attribute audit returned ambiguous paths or attributes.' }
            if ($fields[3 * $index + 2] -cne 'unspecified') { throw 'Active Git filter or ambiguous unset attribute refused before checkout/staging; no filter code is run.' }
        }
        # Named drivers "unspecified" and "unset" collide with check-attr's state labels.
        # --all omits genuinely unspecified attributes but includes a driver named unspecified.
        # Explicit -filter is conservatively refused above: Git renders it like filter=unset.
        $allArguments = @('check-attr','-z','--all')
        if ($Cached) { $allArguments += '--cached' }
        $all = (Invoke-PublicationGit $Directory ($allArguments + @('--') + $batch)).Stdout.Split([char]0)
        if (($all.Count - 1) % 3 -ne 0 -or $all[$all.Count - 1] -cne '') { throw 'Git filter attribute audit returned malformed all-attribute records.' }
        for ($index = 0; $index -lt $all.Count - 1; $index += 3) {
            if ($all[$index] -cnotin $batch) { throw 'Git filter attribute audit returned an unrequested path.' }
            if ($all[$index + 1] -ceq 'filter') { throw 'Active Git filter attribute named unspecified refused before checkout/staging; no filter code is run.' }
        }
    }
}

function Initialize-PublicationCheckout($Contract, [string]$ProjectRoot, [string]$CheckoutParent) {
    $project = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\','/')
    $parent = [IO.Path]::GetFullPath($CheckoutParent).TrimEnd('\','/')
    if ($parent -ieq $project -or $parent.StartsWith($project + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Publication checkout must be outside the original project.' }
    $desktop = [IO.Path]::GetFullPath((Get-PublicationDesktopPath)).TrimEnd('\','/')
    if ($parent -ieq $desktop -or $parent.StartsWith($desktop + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Publication preflight staging must be outside the desktop.' }
    Assert-NoReparse $parent
    Assert-PublicationGitEnvironment
    $checkout = Join-Path $parent ('Oblivion-publication-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $checkout | Out-Null
    $expected = [string]$Contract.Mapping.ExpectedRemoteHead
    Assert-ExpectedRemoteHead $expected (Get-PublicationRemoteHead $checkout)
    $null = Invoke-PublicationGit $checkout @('init','--quiet')
    $null = Invoke-PublicationGit $checkout @('remote','add','origin',$script:OblivionRepository)
    Assert-PublicationPushDestination $checkout
    Assert-PublicationFilterConfiguration $checkout
    $null = Invoke-PublicationGit $checkout @('fetch','--no-tags','--no-recurse-submodules','origin',('refs/heads/' + $script:OblivionBranch))
    $fetched = (Invoke-PublicationGit $checkout @('rev-parse','FETCH_HEAD')).Stdout.Trim()
    Assert-ExpectedRemoteHead $expected $fetched
    $baseTree = Get-PublicationTree $checkout $expected
    $paths = @($baseTree.Keys) + @($Contract.Files | ForEach-Object { $_.PublicPath })
    $null = Invoke-PublicationGit $checkout @('read-tree',$expected)
    Assert-PublicationFilterAttributes $checkout $paths -Cached
    # read-tree already matches the target index, so ordinary checkout may skip missing files.
    # Materialize every audited index entry explicitly before setting detached HEAD.
    $null = Invoke-PublicationGit $checkout @('checkout-index','--all','--force')
    $null = Invoke-PublicationGit $checkout @('checkout','--no-recurse-submodules','--detach','--quiet',$expected)
    foreach ($file in @($Contract.Files)) {
        $target = Resolve-Child $checkout $file.PublicPath
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $file.File -Destination $target -Force
        if ((Get-Sha256 $target) -cne $file.Sha256) { throw 'Public source changed during staging.' }
    }
    Assert-PublicationFilterConfiguration $checkout
    Assert-PublicationFilterAttributes $checkout $paths
    foreach ($file in @($Contract.Files)) {
        $null = Invoke-PublicationGit $checkout @('add','--',$file.PublicPath)
    }
    $treeSha = (Invoke-PublicationGit $checkout @('write-tree')).Stdout.Trim()
    Assert-PublicationTrees $baseTree (Get-PublicationTree $checkout $treeSha) $Contract $checkout
    [pscustomobject]@{ Checkout = $checkout; ExpectedRemoteHead = $expected; BaseTree = $baseTree; TreeSha = $treeSha }
}

function Test-PublicationPreflight([string]$RunDirectory, [string]$ProjectRoot, [string]$MappingPath, [string]$ApprovalPath, [string]$CheckoutParent) {
    # Readiness precedes desktop delivery; normal publication still requires real delivered artifact evidence.
    $contract = Test-PublicationApproval $RunDirectory $ProjectRoot $MappingPath $ApprovalPath
    $prepared = Initialize-PublicationCheckout $contract $ProjectRoot $CheckoutParent
    $fresh = Test-PublicationApproval $RunDirectory $ProjectRoot $MappingPath $ApprovalPath
    if ($fresh.MappingSha256 -cne $contract.MappingSha256 -or $fresh.ApprovalSha256 -cne $contract.ApprovalSha256 -or $fresh.Release.ManifestSha256 -cne $contract.Release.ManifestSha256) { throw 'Publication readiness evidence changed during preflight.' }
    Assert-ExpectedRemoteHead $fresh.Mapping.ExpectedRemoteHead (Get-PublicationRemoteHead $prepared.Checkout)
    Assert-PublicationPushDestination $prepared.Checkout
    $writeReadiness = Assert-PublicationWriteReadiness $prepared.Checkout $fresh.Mapping.ExpectedRemoteHead
    $fresh | Add-Member -NotePropertyName Prepared -NotePropertyValue $prepared
    $fresh | Add-Member -NotePropertyName WriteReadiness -NotePropertyValue $writeReadiness
    $fresh
}

function Assert-PublicationWriteReadiness([string]$Directory, [string]$ExpectedRemoteHead) {
    Assert-PublicationGitEnvironment
    Assert-ExpectedRemoteHead $ExpectedRemoteHead (Get-PublicationRemoteHead $Directory)
    Assert-PublicationPushDestination $Directory
    # Exercise receive-pack authentication without creating a commit or changing a ref. The source SHA is
    # the already verified current branch head, never a candidate commit; --dry-run is mandatory.
    $probe = Invoke-PublicationGit $Directory @('push','--dry-run','--porcelain','origin',($ExpectedRemoteHead + ':refs/heads/' + $script:OblivionBranch)) -AllowFailure
    if ($probe.ExitCode -ne 0) { throw "Existing Git receive-pack authentication/readiness failed in no-login dry-run (exit $($probe.ExitCode)); resolve existing credentials/access before desktop delivery. No login or ref update was attempted." }
    $identity = Set-PublicationCheckoutIdentity $Directory
    [pscustomobject]@{ Status = 'ReceivePackDryRunPassed-NoRefUpdate'; ExpectedRemoteHead = $ExpectedRemoteHead; AuthorName = $identity.AuthorName; AuthorEmail = $identity.AuthorEmail; InteractiveLoginAllowed = $false; GlobalConfigChanged = $false }
}

function Set-PublicationCheckoutIdentity([string]$Directory) {
    # Existing connected GitHub owner identity was independently read through the existing connection.
    # Configure only this new checkout, using its public login and GitHub privacy-preserving noreply form.
    $name = 'deadclass'
    $email = '337182703+deadclass@users.noreply.github.com'
    foreach ($kind in @('user','author','committer')) {
        $null = Invoke-PublicationGit $Directory @('config','--local',($kind + '.name'),$name)
        $null = Invoke-PublicationGit $Directory @('config','--local',($kind + '.email'),$email)
    }
    foreach ($variable in @('GIT_AUTHOR_IDENT','GIT_COMMITTER_IDENT')) {
        $effective = (Invoke-PublicationGit $Directory @('var',$variable)).Stdout.Trim()
        $expected = '^' + [regex]::Escape($name + ' <' + $email + '> ') + '[0-9]+ [+-][0-9]{4}$'
        if ($effective -cnotmatch $expected) { throw 'Effective public author/committer identity differs; private/global identity will not be committed.' }
    }
    [pscustomobject]@{ Status = 'EffectivePublicIdentityVerified-LocalOnly'; AuthorName = $name; AuthorEmail = $email }
}
