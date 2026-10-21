[CmdletBinding()]
param([string]$WorkDirectory = (Join-Path $PSScriptRoot ('..\..\work\publication-guards-' + [Guid]::NewGuid().ToString('N'))))
. (Join-Path $PSScriptRoot 'Common.ps1')

# These isolated tests replace the release evaluator and shortcut readback with fixtures. Git is denied except
# for explicitly allowed local-only URL-resolution checks under this new scratch folder. No external connection,
# engine process, credential lookup, real desktop operation or remote mutation is used.
$script:NativePublicationGit = ${function:Invoke-PublicationGit}
$script:NativeWriteReadiness = ${function:Assert-PublicationWriteReadiness}
$script:AllowOfflineGit = $false
$script:FixtureReleaseMode = 'ReleaseApproved'
$script:FullReleaseChecks = 0
function Test-ReleaseCandidate([string]$RunDirectory, [string]$ProjectRoot, [switch]$EvidenceOnly) {
    if ($EvidenceOnly) { throw 'A publication path requested EvidenceOnly.' }
    $script:FullReleaseChecks++
    $m = Read-Json (Join-Path $RunDirectory 'candidate.json')
    [pscustomobject]@{ Valid = $true; Mode = $script:FixtureReleaseMode; RunId = $m.RunId; ManifestSha256 = Get-Sha256 (Join-Path $RunDirectory 'candidate.json'); SourceSha256 = $m.SourceSha256; ArtifactSetSha256 = $m.ArtifactSetSha256 }
}
function Invoke-PublicationGit([string]$Directory, [string[]]$Arguments, [int]$TimeoutSeconds = 120, [switch]$AllowFailure) {
    if (-not $script:AllowOfflineGit -or $Directory -ine $script:OfflineGitDirectory) { throw 'Git is denied outside the offline URL fixture.' }
    $identitySet = $Arguments.Count -eq 4 -and $Arguments[0] -ceq 'config' -and $Arguments[1] -ceq '--local' -and $Arguments[2] -cmatch '^(user|author|committer)\.(name|email)$' -and $Arguments[3] -cin @('deadclass','337182703+deadclass@users.noreply.github.com')
    $identityRead = $Arguments.Count -eq 2 -and $Arguments[0] -ceq 'var' -and $Arguments[1] -cin @('GIT_AUTHOR_IDENT','GIT_COMMITTER_IDENT')
    $allowed = ($Arguments.Count -eq 2 -and $Arguments[0] -ceq 'init' -and $Arguments[1] -ceq '--quiet') -or ($Arguments.Count -eq 4 -and ($Arguments -join ' ') -ceq ('remote add origin ' + $script:OblivionRepository)) -or ($Arguments.Count -eq 5 -and ($Arguments -join ' ') -ceq 'remote get-url --push --all origin') -or (($Arguments -join ' ') -ceq 'config --get credential.interactive') -or $identitySet -or $identityRead
    if (-not $allowed) { throw 'Only local git init and remote URL configuration/inspection are allowed in the fixture; network verbs are refused.' }
    & $script:NativePublicationGit -Directory $Directory -Arguments $Arguments -TimeoutSeconds $TimeoutSeconds -AllowFailure:$AllowFailure
}
$script:ShortcutReadbacks = @{}
function Get-PublicationDesktopPath { $script:FixtureDesktop }
function Read-PublicationShortcut([string]$Path) {
    if (-not $script:ShortcutReadbacks.ContainsKey($Path)) { throw 'No fixture shortcut readback exists.' }
    $script:ShortcutReadbacks[$Path]
}

$script:Passed = 0
function Expect-Refusal([string]$Name, [scriptblock]$Action, [string]$Pattern) {
    $caught = $null
    try { $null = & $Action } catch { $caught = $_.Exception.Message }
    if ($null -eq $caught -or $caught -notmatch $Pattern) { throw "FAIL: $Name; expected refusal /$Pattern/, got [$caught]" }
    $script:Passed++
    Write-Output "PASS: $Name"
}

$work = [IO.Path]::GetFullPath($WorkDirectory)
if (Test-Path -LiteralPath $work) { throw 'Guard test folder must be new; existing files are never removed.' }
New-Item -ItemType Directory -Path $work | Out-Null
$run = Join-Path $work 'run'
$sourceFolder = Join-Path $run 'source-check\prototypes\quiet-relay\scripts'
New-Item -ItemType Directory -Path $sourceFolder -Force | Out-Null
$gameFile = Join-Path $sourceFolder 'world.gd'
[IO.File]::WriteAllText($gameFile, "extends Node2D`n", (New-Object Text.UTF8Encoding($false)))
$gameSha = Get-Sha256 $gameFile
$dest = [pscustomobject]@{ RepositoryUrl = $script:OblivionRepository; Branch = $script:OblivionBranch; PullRequest = 1; Visibility = 'public' }
$now = [DateTimeOffset]::UtcNow
$manifest = [pscustomobject]@{ RunId = 'guard-fixture'; SourceSha256 = ('A' * 64); ArtifactSetSha256 = ('B' * 64); TaskSha256 = ('C' * 64); CompletedUtc = $now.AddMinutes(-5).ToString('o'); ExpiresUtc = $now.AddHours(1).ToString('o'); Job = [pscustomobject]@{ ImplementerIdentity = 'fixture-implementer'; ReleaseIntent = [pscustomobject]@{ GitHubPublication = $true; DesktopDelivery = $true } }; SourceFiles = @([pscustomobject]@{ Path = 'prototypes/quiet-relay/scripts/world.gd'; Sha256 = $gameSha; Bytes = (Get-Item -LiteralPath $gameFile).Length }) }
$script:FixtureDesktop = Join-Path $work 'fixture-desktop'
$fixtureGame = Join-Path $script:FixtureDesktop 'OBLIVION'
$fixtureBuild = Join-Path $fixtureGame ('builds/' + $manifest.RunId)
$deliveryFolder = Join-Path $run 'delivery'
$recoveryFolder = Join-Path $deliveryFolder 'previous-build'
New-Item -ItemType Directory -Path $fixtureBuild,$recoveryFolder -Force | Out-Null
$deliveredFile = Join-Path $fixtureBuild 'QuietRelay.exe'
[IO.File]::WriteAllText($deliveredFile, 'unexecuted candidate artifact fixture', (New-Object Text.UTF8Encoding($false)))
$artifact = [pscustomobject][ordered]@{ Path = 'candidate/bin/QuietRelay.exe'; Sha256 = Get-Sha256 $deliveredFile; Bytes = [long](Get-Item -LiteralPath $deliveredFile).Length }
$manifest | Add-Member -NotePropertyName ArtifactFiles -NotePropertyValue @($artifact)
$manifest.ArtifactSetSha256 = Get-EntriesHash @($artifact)
Write-Json (Join-Path $run 'candidate.json') $manifest
$fixtureLauncher = Join-Path $fixtureGame 'Play Oblivion.lnk'
$backupLauncher = Join-Path $deliveryFolder 'previous-Play Oblivion.lnk'
$recoveryLauncher = Join-Path $deliveryFolder 'Recover previous Oblivion.lnk'
$recoveryTarget = Join-Path $recoveryFolder 'Previous.exe'
foreach ($file in @($fixtureLauncher,$backupLauncher,$recoveryLauncher,$recoveryTarget)) { [IO.File]::WriteAllText($file, 'unexecuted local fixture', (New-Object Text.UTF8Encoding($false))) }
$recoveryFiles = @([pscustomobject][ordered]@{ Path = 'Previous.exe'; Sha256 = Get-Sha256 $recoveryTarget; Bytes = [long](Get-Item -LiteralPath $recoveryTarget).Length })
$priorTarget = Join-Path $work 'previous-original/Previous.exe'
$previous = [pscustomobject]@{ Launcher = $fixtureLauncher; LauncherSha256 = Get-Sha256 $backupLauncher; Target = $priorTarget; TargetSha256 = Get-Sha256 $recoveryTarget; Arguments = ''; RecoveryTarget = $recoveryTarget; RecoveryLauncher = $recoveryLauncher; RecoveryFiles = $recoveryFiles }
Write-Json (Join-Path $deliveryFolder 'previous.json') $previous
$delivery = [pscustomobject]@{ Status = 'Delivered'; RunId = $manifest.RunId; ManifestSha256 = Get-Sha256 (Join-Path $run 'candidate.json'); SourceSha256 = $manifest.SourceSha256; ArtifactSetSha256 = $manifest.ArtifactSetSha256; DeliveredUtc = $now.AddMinutes(-3).ToString('o'); Launcher = $fixtureLauncher; Target = $deliveredFile; WorkingDirectory = $fixtureBuild; PreviousLauncherBackup = $backupLauncher; PreviousTarget = $priorTarget; PreviousTargetSha256 = Get-Sha256 $recoveryTarget; RecoveryTarget = $recoveryTarget; RecoveryLauncher = $recoveryLauncher; RecoveryFiles = $recoveryFiles }
$deliveryPath = Join-Path $deliveryFolder 'receipt.json'
Write-Json $deliveryPath $delivery
$script:ShortcutReadbacks[$fixtureLauncher] = [pscustomobject]@{ Target = $deliveredFile; WorkingDirectory = $fixtureBuild; Arguments = '' }
$script:ShortcutReadbacks[$recoveryLauncher] = [pscustomobject]@{ Target = $recoveryTarget; WorkingDirectory = $recoveryFolder; Arguments = '' }
$mapping = [pscustomobject]@{ SchemaVersion = 1; Destination = $dest; OwnerPolicy = [pscustomobject]@{ ConfirmedBy = 'fixture-owner'; ConfirmedUtc = $now.AddMinutes(-10).ToString('o'); AutomaticVerifiedPush = $true; Destination = $dest }; ExpectedRemoteHead = ('a' * 40); RunId = $manifest.RunId; ManifestSha256 = Get-Sha256 (Join-Path $run 'candidate.json'); SourceSha256 = $manifest.SourceSha256; ArtifactSetSha256 = $manifest.ArtifactSetSha256; TaskSha256 = $manifest.TaskSha256; ExpiresUtc = $manifest.ExpiresUtc; Files = @([pscustomobject]@{ CandidatePath = 'prototypes/quiet-relay/scripts/world.gd'; PublicPath = 'prototypes/quiet-relay/scripts/world.gd'; Mode = 'ExactCandidate'; OriginalSha256 = $gameSha; PublicSha256 = $gameSha }) }
$mapPath = Join-Path $work 'mapping.json'
$approvalPath = Join-Path $work 'approval.json'
Write-Json $mapPath $mapping
$approval = [pscustomobject]@{ SchemaVersion = 1; Decision = 'ApprovedForPublicPush'; ReviewedBy = 'fixture-independent-reviewer'; ReviewNotes = 'Fixture only; no actual publication authorization.'; ApprovedUtc = $now.AddMinutes(-1).ToString('o'); ExpiresUtc = $now.AddMinutes(30).ToString('o'); MappingSha256 = Get-Sha256 $mapPath; Destination = $dest; ExpectedRemoteHead = $mapping.ExpectedRemoteHead; RunId = $manifest.RunId; ManifestSha256 = $mapping.ManifestSha256; SourceSha256 = $mapping.SourceSha256; ArtifactSetSha256 = $mapping.ArtifactSetSha256; TaskSha256 = $mapping.TaskSha256 }
Write-Json $approvalPath $approval
$valid = Test-PublicationContract $run $work $mapPath $approvalPath
if (-not $valid.Valid -or $valid.Files.Count -ne 1 -or $script:FullReleaseChecks -ne 1) { throw 'Valid fixture did not use the full release gate.' }
$script:Passed++
Write-Output 'PASS: valid exact fixture requires full release evaluator'

Move-Item -LiteralPath $deliveryPath -Destination (Join-Path $deliveryFolder 'receipt-held.json')
Expect-Refusal 'missing delivery receipt stops publication' { Test-PublicationContract $run $work $mapPath $approvalPath } 'Required JSON is missing'
Move-Item -LiteralPath (Join-Path $deliveryFolder 'receipt-held.json') -Destination $deliveryPath
$delivery.SourceSha256 = ('F' * 64); Write-Json $deliveryPath $delivery
Expect-Refusal 'stale delivery receipt stops publication' { Test-PublicationContract $run $work $mapPath $approvalPath } 'Stale desktop delivery receipt'
$delivery.SourceSha256 = $manifest.SourceSha256; Write-Json $deliveryPath $delivery
$script:ShortcutReadbacks[$fixtureLauncher].Arguments = '--unapproved'
Expect-Refusal 'actual selected launcher readback is required' { Test-PublicationContract $run $work $mapPath $approvalPath } 'Actual selected launcher readback'
$script:ShortcutReadbacks[$fixtureLauncher].Arguments = ''
[IO.File]::WriteAllText($deliveredFile, 'changed candidate bytes', (New-Object Text.UTF8Encoding($false)))
Expect-Refusal 'changed actual desktop artifact stops publication' { Test-PublicationContract $run $work $mapPath $approvalPath } 'Actual delivered executable/sidecars differ'
[IO.File]::WriteAllText($deliveredFile, 'unexecuted candidate artifact fixture', (New-Object Text.UTF8Encoding($false)))
$extraDelivered = Join-Path $fixtureBuild 'unexpected.txt'
[IO.File]::WriteAllText($extraDelivered, 'extra unapproved file', (New-Object Text.UTF8Encoding($false)))
Expect-Refusal 'extra actual desktop artifact stops publication' { Test-PublicationContract $run $work $mapPath $approvalPath } 'contains extra files'
Move-Item -LiteralPath $extraDelivered -Destination (Join-Path $work 'extra-delivered-held.txt')
[IO.File]::WriteAllText($recoveryTarget, 'damaged previous build', (New-Object Text.UTF8Encoding($false)))
Expect-Refusal 'missing recoverability stops publication' { Test-PublicationContract $run $work $mapPath $approvalPath } 'no longer recoverable'
[IO.File]::WriteAllText($recoveryTarget, 'unexecuted local fixture', (New-Object Text.UTF8Encoding($false)))

Expect-Refusal 'missing publication approval' { Test-PublicationContract $run $work $mapPath (Join-Path $work 'missing.json') } 'Required JSON is missing'
$approval.Decision = 'Rejected'; Write-Json $approvalPath $approval
Expect-Refusal 'rejected publication approval' { Test-PublicationContract $run $work $mapPath $approvalPath } 'missing or rejected'
$approval.Decision = 'ApprovedForPublicPush'; Write-Json $approvalPath $approval
$script:FixtureReleaseMode = 'EvidenceOnly-NOT-RELEASE-APPROVAL'
Expect-Refusal 'evidence-only is not release approval' { Test-PublicationContract $run $work $mapPath $approvalPath } 'Complete independent release approval'
$script:FixtureReleaseMode = 'ReleaseApproved'
$wrongDest = [pscustomobject]@{ RepositoryUrl = $script:OblivionRepository; Branch = 'main'; PullRequest = 1; Visibility = 'public' }
Expect-Refusal 'wrong destination branch' { Assert-PublicationDestination $wrongDest } 'owner-approved public'
$wrongDest.Branch = $script:OblivionBranch; $wrongDest.PullRequest = 2
Expect-Refusal 'wrong pull request' { Assert-PublicationDestination $wrongDest } 'owner-approved public'
$mapping.SourceSha256 = ('D' * 64); Write-Json $mapPath $mapping
$approval.MappingSha256 = Get-Sha256 $mapPath; Write-Json $approvalPath $approval
Expect-Refusal 'stale mapping source hash' { Test-PublicationContract $run $work $mapPath $approvalPath } 'Stale publication mapping'
$mapping.SourceSha256 = $manifest.SourceSha256; Write-Json $mapPath $mapping
$approval.MappingSha256 = ('E' * 64); Write-Json $approvalPath $approval
Expect-Refusal 'mapping changed after review' { Test-PublicationContract $run $work $mapPath $approvalPath } 'mapping changed after review'
$approval.MappingSha256 = Get-Sha256 $mapPath; Write-Json $approvalPath $approval
$approval.ExpiresUtc = $now.AddMinutes(-1).ToString('o'); Write-Json $approvalPath $approval
Expect-Refusal 'expired approval' { Test-PublicationContract $run $work $mapPath $approvalPath } 'stale, expired or future'
$approval.ExpiresUtc = $now.AddMinutes(30).ToString('o'); Write-Json $approvalPath $approval
Expect-Refusal 'moved remote head' { Assert-ExpectedRemoteHead ('a' * 40) ('b' * 40) } 'Remote head moved'
Expect-Refusal 'local instruction file' { Assert-PublicRelativePath 'AGENTS.md' } 'Private/generated/binary'
Expect-Refusal 'exported binary path' { Assert-PublicRelativePath 'release/game.exe' } 'Private/generated/binary'
Expect-Refusal 'cache path' { Assert-PublicRelativePath 'prototypes/quiet-relay/.godot/cache.bin' } 'Private/generated/binary'
$scan = Join-Path $work 'scan.txt'
[IO.File]::WriteAllText($scan, 'Documentation: https://github.com/deadclass/Oblivion', (New-Object Text.UTF8Encoding($false)))
Assert-PublicFile $scan 'docs/SETUP.md'
$script:Passed++
Write-Output 'PASS: public HTTPS documentation is accepted'
[IO.File]::WriteAllText($scan, ('local ' + 'C:' + [char]92 + 'Users' + [char]92 + 'fixture'), (New-Object Text.UTF8Encoding($false)))
Expect-Refusal 'private machine path in public bytes' { Assert-PublicFile $scan 'docs/SETUP.md' } 'Private absolute machine path'
foreach ($server in @('studio-server','192.0.2.10','_studio-server')) {
    $unc = (([string][char]92) * 2) + $server + [char]92 + '_private-share' + [char]92 + 'game'
    [IO.File]::WriteAllText($scan, $unc, (New-Object Text.UTF8Encoding($false)))
    Expect-Refusal ('real UNC server/share path: ' + $server) { Assert-PublicFile $scan 'docs/SETUP.md' } 'Private absolute machine path'
}
Assert-PublicFile (Join-Path $PSScriptRoot 'Common.ps1') 'scripts/publication/Common.ps1'
Assert-PublicFile (Join-Path $PSScriptRoot '../release/Common.ps1') 'scripts/release/Common.ps1'
$script:Passed++
Write-Output 'PASS: actual complete guard code with escaped regex expressions is publishable text'
[IO.File]::WriteAllText($scan, ('ghp_' + ('q' * 28)), (New-Object Text.UTF8Encoding($false)))
Expect-Refusal 'credential-shaped public bytes' { Assert-PublicFile $scan 'docs/SETUP.md' } 'Secret-shaped content'
[IO.File]::WriteAllText($scan, 'custom_template/release="private-template"', (New-Object Text.UTF8Encoding($false)))
Expect-Refusal 'machine export template setting' { Assert-PublicFile $scan 'prototypes/quiet-relay/export_presets.cfg' } 'Machine-specific export-template'
$mapping.Files[0].Mode = 'ReviewedPublicVersion'; Write-Json $mapPath $mapping
$approval.MappingSha256 = Get-Sha256 $mapPath; Write-Json $approvalPath $approval
Expect-Refusal 'gameplay public rewrite' { Test-PublicationContract $run $work $mapPath $approvalPath } 'cannot be sanitized'
$mapping.Files[0].Mode = 'ExactCandidate'
$mapping.Files[0].CandidatePath = 'Prototypes/quiet-relay/scripts/world.gd'
$mapping.Files[0].PublicPath = 'docs/world.gd'
Write-Json $mapPath $mapping
$approval.MappingSha256 = Get-Sha256 $mapPath; Write-Json $approvalPath $approval
Expect-Refusal 'case-variant candidate cannot bypass exact game mapping' { Test-PublicationContract $run $work $mapPath $approvalPath } 'canonical candidate manifest path'
if (-not (Test-ProtectedGamePath 'Prototypes/Quiet-Relay/scripts/world.gd')) { throw 'Case-variant game paths must remain protected.' }
$script:Passed++
Write-Output 'PASS: game path protection covers case variants'
$mapping.Files[0].CandidatePath = 'prototypes/quiet-relay/scripts/world.gd'
$mapping.Files[0].PublicPath = $mapping.Files[0].CandidatePath
$mapping.Files = @(); Write-Json $mapPath $mapping
$approval.MappingSha256 = Get-Sha256 $mapPath; Write-Json $approvalPath $approval
Expect-Refusal 'empty source mapping' { Test-PublicationContract $run $work $mapPath $approvalPath } 'no reviewed files'
$manifest.Job.ReleaseIntent.GitHubPublication = $false
Expect-Refusal 'local harness trial can never publish' { Assert-PublicationIntent $manifest } 'does not authorize GitHub publication'
$base = @{ 'preserved.txt' = [pscustomobject]@{ Mode = '100644'; Sha = ('a' * 40) } }
$noFiles = [pscustomobject]@{ Files = @() }
Expect-Refusal 'remote-only file deletion' { Assert-PublicationTrees $base @{} $noFiles $work } 'deletion is forbidden'
$different = @{ 'preserved.txt' = [pscustomobject]@{ Mode = '100644'; Sha = ('b' * 40) } }
Expect-Refusal 'remote-only file change' { Assert-PublicationTrees $base $different $noFiles $work } 'remote-only content was modified'
$remoteGame = @{ 'prototypes/quiet-relay/scripts/remote.gd' = [pscustomobject]@{ Mode = '100644'; Sha = ('a' * 40) } }
Expect-Refusal 'untested remote-only game source' { Assert-PublicationTrees $remoteGame $remoteGame $noFiles $work } 'explicit reconciliation'

# Real Git regression for the reviewer's reproduced inherited-pushurl bug. Configuration is confined to a
# new scratch file and process environment; both previous environment values are restored in finally.
$script:OfflineGitDirectory = Join-Path $work 'offline-git-url-fixture'
New-Item -ItemType Directory -Path $script:OfflineGitDirectory | Out-Null
$globalFixture = Join-Path $work 'offline-git-global-config'
$oldGlobal = [Environment]::GetEnvironmentVariable('GIT_CONFIG_GLOBAL','Process')
$oldNoSystem = [Environment]::GetEnvironmentVariable('GIT_CONFIG_NOSYSTEM','Process')
try {
    [IO.File]::WriteAllText($globalFixture, ("[remote ""origin""]`n pushurl = " + $script:OblivionRepository + "`n pushurl = https://example.invalid/unapproved.git`n"), (New-Object Text.UTF8Encoding($false)))
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_GLOBAL',$globalFixture,'Process')
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_NOSYSTEM','1','Process')
    $script:AllowOfflineGit = $true
    $null = Invoke-PublicationGit $script:OfflineGitDirectory @('init','--quiet')
    $null = Invoke-PublicationGit $script:OfflineGitDirectory @('remote','add','origin',$script:OblivionRepository)
    Expect-Refusal 'real offline git refuses inherited second push URL' { Assert-PublicationPushDestination $script:OfflineGitDirectory } 'exactly one approved repository URL'
    [IO.File]::WriteAllText($globalFixture, ("[remote ""origin""]`n pushurl = " + $script:OblivionRepository + "`n"), (New-Object Text.UTF8Encoding($false)))
    Assert-PublicationPushDestination $script:OfflineGitDirectory
    $script:Passed++
    Write-Output 'PASS: real offline git accepts exactly one effective approved push URL'
    foreach ($routingName in @('GIT_DIR','GIT_WORK_TREE','GIT_COMMON_DIR','GIT_INDEX_FILE','GIT_OBJECT_DIRECTORY','GIT_ALTERNATE_OBJECT_DIRECTORIES','GIT_NAMESPACE','GIT_AUTHOR_EMAIL','GIT_COMMITTER_EMAIL')) {
        $oldRouting = [Environment]::GetEnvironmentVariable($routingName,'Process')
        $unintended = Join-Path $work ('unintended-' + $routingName)
        try {
            [Environment]::SetEnvironmentVariable($routingName,$unintended,'Process')
            Expect-Refusal ("inherited $routingName cannot redirect a git operation") { Invoke-PublicationGit $script:OfflineGitDirectory @('init','--quiet') } ('environment variable ' + $routingName + ' is set')
            if (Test-Path -LiteralPath $unintended) { throw 'Git routing guard allowed unintended filesystem mutation.' }
        } finally { [Environment]::SetEnvironmentVariable($routingName,$oldRouting,'Process') }
    }
    Assert-PublicationPushDestination $script:OfflineGitDirectory
    $script:Passed++
    Write-Output 'PASS: clean local git environment works after routing-variable tests'
    $interactiveValue = (Invoke-PublicationGit $script:OfflineGitDirectory @('config','--get','credential.interactive')).Stdout.Trim()
    if ($interactiveValue -cne 'never') { throw 'Actual Git child did not receive request-scoped no-login configuration.' }
    $script:Passed++
    Write-Output 'PASS: actual local Git child receives credential.interactive=never'
    $privateOverrides = "[author]`n name = Fixture Hidden Author`n email = fixture-hidden-author@example.invalid`n[committer]`n name = Fixture Hidden Committer`n email = fixture-hidden-committer@example.invalid`n"
    [IO.File]::AppendAllText($globalFixture,$privateOverrides,(New-Object Text.UTF8Encoding($false)))
    $null = Invoke-PublicationGit $script:OfflineGitDirectory @('config','--local','user.name','deadclass')
    $null = Invoke-PublicationGit $script:OfflineGitDirectory @('config','--local','user.email','337182703+deadclass@users.noreply.github.com')
    $authorBefore = (Invoke-PublicationGit $script:OfflineGitDirectory @('var','GIT_AUTHOR_IDENT')).Stdout
    $committerBefore = (Invoke-PublicationGit $script:OfflineGitDirectory @('var','GIT_COMMITTER_IDENT')).Stdout
    if ($authorBefore -notlike '*fixture-hidden-author@example.invalid*' -or $committerBefore -notlike '*fixture-hidden-committer@example.invalid*') { throw 'Offline positive control did not exercise global author/committer override precedence.' }
    $script:Passed++
    Write-Output 'PASS: offline control reproduces global author/committer overriding local user identity'
    $effectiveIdentity = Set-PublicationCheckoutIdentity $script:OfflineGitDirectory
    if ($effectiveIdentity.Status -cne 'EffectivePublicIdentityVerified-LocalOnly') { throw 'Actual effective public identity was not verified.' }
    $script:Passed++
    Write-Output 'PASS: production local identity helper overrides global author/committer and verifies effective identities'
} finally {
    $script:AllowOfflineGit = $false
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_GLOBAL',$oldGlobal,'Process')
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_NOSYSTEM',$oldNoSystem,'Process')
}
$publishText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Publish-Verified.ps1') -Raw
if ($publishText -match 'commit.*TaskId' -or $publishText -notmatch "'commit','-m','Publish independently verified Oblivion source'") { throw 'Public commit messages must not interpolate private task metadata.' }
$script:Passed++
Write-Output 'PASS: public commit metadata uses a fixed non-sensitive message'

# Pre-delivery readiness uses the full real approval/mapping validator; only the remote preparation/read
# seams are fixtures here. It may prepare without a delivery receipt, but normal publication may not.
$mapping = $valid.Mapping
Write-Json $mapPath $mapping
$approval.MappingSha256 = Get-Sha256 $mapPath
Write-Json $approvalPath $approval
$script:PreflightPreparations = 0
$script:PreflightPreparationFailure = ''
$script:PreflightHead = [string]$mapping.ExpectedRemoteHead
function Initialize-PublicationCheckout($Contract, [string]$ProjectRoot, [string]$CheckoutParent) {
    $script:PreflightPreparations++
    if ($script:PreflightPreparationFailure -ne '') { throw $script:PreflightPreparationFailure }
    [pscustomobject]@{ Checkout = $work; ExpectedRemoteHead = $Contract.Mapping.ExpectedRemoteHead; BaseTree = @{}; TreeSha = ('d' * 40) }
}
function Get-PublicationRemoteHead([string]$Directory) { $script:PreflightHead }
function Assert-PublicationPushDestination([string]$Directory) { }
function Assert-PublicationWriteReadiness([string]$Directory, [string]$ExpectedRemoteHead) { [pscustomobject]@{ Status = 'FixtureExistingReceivePackReady-NoRefUpdate'; ExpectedRemoteHead = $ExpectedRemoteHead } }
Expect-Refusal 'publication preflight refuses missing independent public review' { Test-PublicationPreflight $run $work $mapPath (Join-Path $work 'missing-review.json') $work } 'Required JSON is missing'
if ($script:PreflightPreparations -ne 0) { throw 'Missing public review must fail before remote preparation.' }
Move-Item -LiteralPath $deliveryPath -Destination (Join-Path $deliveryFolder 'receipt-preflight-held.json')
try {
    $ready = Test-PublicationPreflight $run $work $mapPath $approvalPath $work
    if (-not $ready.Valid -or $ready.MappingSha256 -cne (Get-Sha256 $mapPath) -or $ready.Prepared.TreeSha -cne ('d' * 40)) { throw 'Preflight did not preserve complete candidate/mapping readiness.' }
    $script:Passed++
    Write-Output 'PASS: preflight can prove readiness before actual delivery without fabricating a receipt'
    Expect-Refusal 'normal publication still requires actual delivery after preflight' { Test-PublicationContract $run $work $mapPath $approvalPath } 'Required JSON is missing'
} finally { Move-Item -LiteralPath (Join-Path $deliveryFolder 'receipt-preflight-held.json') -Destination $deliveryPath }
$script:PreflightHead = ('b' * 40)
Expect-Refusal 'pre-delivery readiness refuses moved remote head' { Test-PublicationPreflight $run $work $mapPath $approvalPath $work } 'Remote head moved'
$script:PreflightHead = [string]$mapping.ExpectedRemoteHead
$script:PreflightPreparationFailure = 'Remote-only game source requires explicit reconciliation.'
Expect-Refusal 'pre-delivery readiness refuses untested mixed remote game tree' { Test-PublicationPreflight $run $work $mapPath $approvalPath $work } 'explicit reconciliation'

$beforeTerminal = [Environment]::GetEnvironmentVariable('GIT_TERMINAL_PROMPT','Process')
$beforeGcm = [Environment]::GetEnvironmentVariable('GCM_INTERACTIVE','Process')
$startInfo = Get-PublicationGitStartInfo 'git.exe' $work '--version'
if ($startInfo.EnvironmentVariables['GIT_TERMINAL_PROMPT'] -cne '0' -or $startInfo.EnvironmentVariables['GCM_INTERACTIVE'] -cne 'never' -or [Environment]::GetEnvironmentVariable('GIT_TERMINAL_PROMPT','Process') -cne $beforeTerminal -or [Environment]::GetEnvironmentVariable('GCM_INTERACTIVE','Process') -cne $beforeGcm) { throw 'No-login child environment leaked into caller settings.' }
$script:Passed++
Write-Output 'PASS: terminal/GCM no-login flags affect only the Git child'
$script:DryRunExit = 128
$script:DryRunCommands = @()
function Invoke-PublicationGit([string]$Directory, [string[]]$Arguments, [int]$TimeoutSeconds = 120, [switch]$AllowFailure) {
    $command = $Arguments -join ' '
    $script:DryRunCommands += $command
    if ($Arguments[0] -ceq 'push') {
        $expectedCommand = 'push --dry-run --porcelain origin ' + $mapping.ExpectedRemoteHead + ':refs/heads/prototype/quiet-relay-collaboration'
        if ($command -cne $expectedCommand) { throw 'Readiness probe must use only dry-run and the existing head on the fixed approved branch.' }
        return [pscustomobject]@{ ExitCode = $script:DryRunExit; Stdout = ''; Stderr = 'Fixture no-login receive-pack response, no secrets.' }
    }
    if ($command -cmatch '^config --local (user|author|committer)\.(name|email) (deadclass|337182703\+deadclass@users\.noreply\.github\.com)$') { return [pscustomobject]@{ ExitCode = 0; Stdout = ''; Stderr = '' } }
    if ($command -cin @('var GIT_AUTHOR_IDENT','var GIT_COMMITTER_IDENT')) { return [pscustomobject]@{ ExitCode = 0; Stdout = 'deadclass <337182703+deadclass@users.noreply.github.com> 1760760000 +0000'; Stderr = '' } }
    throw 'Unexpected Git command in no-network write-readiness fixture.'
}
Expect-Refusal 'missing existing receive-pack auth refuses readiness without login' { & $script:NativeWriteReadiness $work $mapping.ExpectedRemoteHead } 'authentication/readiness failed in no-login dry-run'
if ($script:DryRunCommands.Count -ne 1) { throw 'Failed auth must stop before local identity configuration.' }
$script:DryRunExit = 0
$script:DryRunCommands = @()
$writeReady = & $script:NativeWriteReadiness $work $mapping.ExpectedRemoteHead
if ($writeReady.Status -cne 'ReceivePackDryRunPassed-NoRefUpdate' -or $script:DryRunCommands.Count -ne 9 -or @($script:DryRunCommands | Where-Object { $_ -like '*--global*' -or ($_ -like 'push *' -and $_ -notlike '*--dry-run*') }).Count -ne 0) { throw 'Successful readiness must use only fixed dry-run and checkout-local public identity.' }
$script:Passed++
Write-Output 'PASS: receive-pack readiness uses no ref write and checkout-local public identity only'

# Real Windows PowerShell child: reproduce StarNet's PATH without Git, retain an inert function
# shadow, and require the identical pre-existing Git binary. No login/config/remote command runs.
$expectedGit = Resolve-PublicationGit
$commonPath = Join-Path $PSScriptRoot 'Common.ps1'
$encode = { param([string]$Value) [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value)) }
$childCode = @'
$ErrorActionPreference = 'Stop'
$common = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__COMMON__'))
$directory = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__DIRECTORY__'))
$expected = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__EXPECTED__'))
. $common
function git.exe { throw 'Function shadow must never run.' }
if (@(Get-Command -Name git.exe -CommandType Application -ErrorAction SilentlyContinue).Count -ne 0) { throw 'Fixture PATH still exposes Git; it does not reproduce the native failure.' }
$resolved = Resolve-PublicationGit
if ($resolved -ine $expected -or (Get-Sha256 $resolved) -cne (Get-Sha256 $expected)) { throw 'PATH fallback did not find the same installed Git binary.' }
$version = Invoke-PublicationGit $directory @('--version')
if ($version.ExitCode -ne 0 -or $version.Stdout -notmatch '^git version ') { throw 'Absolute existing Git invocation failed.' }
function Get-PublicationGitCandidatePaths { @() }
$reason = $null
try { $null = Resolve-PublicationGit } catch { $reason = $_.Exception.Message }
if ($null -eq $reason -or $reason -notmatch 'Existing Git application is unavailable') { throw 'Absent installed Git must refuse; alias/function shadow cannot satisfy discovery.' }
[pscustomobject]@{ SameExistingBinary = $true; FunctionShadowIgnored = $true; MissingInstallationRefused = $true; NetworkOperations = 0; RefUpdates = 0 } | ConvertTo-Json -Compress
'@
$childCode = $childCode.Replace('__COMMON__',(& $encode $commonPath)).Replace('__DIRECTORY__',(& $encode $work)).Replace('__EXPECTED__',(& $encode $expectedGit))
$childInfo = New-Object Diagnostics.ProcessStartInfo
$childInfo.FileName = Join-Path ([Environment]::GetFolderPath('System')) 'WindowsPowerShell/v1.0/powershell.exe'
$childInfo.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand ' + [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childCode))
$childInfo.UseShellExecute = $false
$childInfo.CreateNoWindow = $true
$childInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$childInfo.RedirectStandardOutput = $true
$childInfo.RedirectStandardError = $true
$parentPath = [Environment]::GetEnvironmentVariable('PATH','Process')
$childInfo.EnvironmentVariables['PATH'] = [Environment]::GetFolderPath('System')
$child = New-Object Diagnostics.Process
$child.StartInfo = $childInfo
$null = $child.Start()
$null = $child.Handle
$childOut = $child.StandardOutput.ReadToEndAsync()
$childErr = $child.StandardError.ReadToEndAsync()
if (-not $child.WaitForExit(120000)) {
    & (Join-Path ([Environment]::GetFolderPath('System')) 'taskkill.exe') /PID $child.Id /T /F | Out-Null
    throw 'Bounded PATH-isolated Git fixture timed out.'
}
$child.WaitForExit()
$childExit = $child.ExitCode
$child.Dispose()
if ($childExit -ne 0) { throw ('PATH-isolated real PowerShell fixture failed: ' + $childErr.Result) }
$pathProof = $childOut.Result | ConvertFrom-Json
if (-not $pathProof.SameExistingBinary -or -not $pathProof.FunctionShadowIgnored -or [Environment]::GetEnvironmentVariable('PATH','Process') -cne $parentPath) { throw 'Same-binary discovery or child-only PATH isolation failed.' }
$script:Passed++
Write-Output 'PASS: real PS5 child without Git on PATH invokes the same existing Git and ignores function shadow'
if (-not $pathProof.MissingInstallationRefused) { throw 'Missing installed Git did not refuse.' }
$script:Passed++
Write-Output 'PASS: missing PATH Git plus absent installed candidates refuses without alias/function fallback'
[pscustomobject]@{ Status = 'Passed'; Checks = $script:Passed; NetworkOperations = 0; RemoteMutations = 0; FixtureDirectory = $work; Scope = 'Contract guards use a fixture release evaluator; Git URL resolution uses an isolated local-only fixture. Not a real release or push test.' }
