[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [string]$MappingPath,
    [string]$PublicationApprovalPath,
    [string]$CheckoutParent,
    [switch]$Deliver
)

. (Join-Path $PSScriptRoot '../release/Common.ps1')
$project = Get-ReleaseProjectRoot
$run = [IO.Path]::GetFullPath($RunDirectory)
$approved = Test-ReleaseCandidate $run $project
if ($approved.Mode -cne 'ReleaseApproved') { throw 'Desktop delivery requires the complete release gate.' }
$manifest = Read-Json (Join-Path $run 'candidate.json')
Assert-Fields $manifest.Job @('ReleaseIntent') 'Release job'
Assert-Fields $manifest.Job.ReleaseIntent @('DesktopDelivery','GitHubPublication') 'Release intent'
if ($manifest.Job.ReleaseIntent.DesktopDelivery -isnot [bool] -or -not $manifest.Job.ReleaseIntent.DesktopDelivery) { throw 'This task is not authorized for desktop delivery (a harness trial cannot deliver).' }
if ($manifest.Job.ReleaseIntent.GitHubPublication -isnot [bool]) { throw 'GitHub publication intent must explicitly be Boolean true or false before desktop delivery.' }
$publicationReady = $null
if ($manifest.Job.ReleaseIntent.GitHubPublication) {
    foreach ($pair in @(@('MappingPath',$MappingPath),@('PublicationApprovalPath',$PublicationApprovalPath),@('CheckoutParent',$CheckoutParent))) {
        Assert-Text $pair[1] ('Combined release requires ' + $pair[0] + ' before desktop delivery')
    }
    . (Join-Path $PSScriptRoot '../publication/Common.ps1')
    $publicationReady = Test-PublicationPreflight -RunDirectory $run -ProjectRoot $project -MappingPath $MappingPath -ApprovalPath $PublicationApprovalPath -CheckoutParent $CheckoutParent
    if ($publicationReady.Valid -isnot [bool] -or -not $publicationReady.Valid -or $publicationReady.Release.ManifestSha256 -cne $approved.ManifestSha256) { throw 'Publication preflight does not prove readiness for this exact approved candidate.' }
}

# The owner selected this one launcher. There is intentionally no arbitrary shortcut/path override.
$desktop = [Environment]::GetFolderPath('Desktop')
Assert-NoReparse $desktop
$gameFolder = Resolve-Child $desktop 'OBLIVION'
if (-not (Test-Path -LiteralPath $gameFolder -PathType Container)) { throw 'Existing desktop OBLIVION folder is missing.' }
$launcher = Resolve-Child $gameFolder 'Play Oblivion.lnk'
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) { throw 'The owner-selected existing Play Oblivion.lnk is missing.' }
$oldLinkHash = Get-Sha256 $launcher
$shell = New-Object -ComObject WScript.Shell
$prior = $shell.CreateShortcut($launcher)
$oldTarget = $prior.TargetPath
$oldWorking = $prior.WorkingDirectory
$oldArguments = $prior.Arguments
if (-not (Test-Path -LiteralPath $oldTarget -PathType Leaf)) { throw 'Previous playable target is missing; cannot prove recoverability.' }
Assert-NoReparse $oldTarget
$oldTargetHash = Get-Sha256 $oldTarget
$destination = Resolve-Child $gameFolder ('builds/' + $manifest.RunId)
if (Test-Path -LiteralPath $destination) { throw 'This version already has a desktop folder; inspect its receipt instead of overwriting it.' }
$plan = [pscustomobject]@{ Mode='Plan'; Launcher=$launcher; PreviousTarget=$oldTarget; PreviousTargetSha256=$oldTargetHash; Destination=$destination; RunId=$manifest.RunId; SourceSha256=$approved.SourceSha256; ArtifactSetSha256=$approved.ArtifactSetSha256 }
if (-not $Deliver) { $plan; return }

$receiptFolder = Resolve-Child $run 'delivery'
if (Test-Path -LiteralPath $receiptFolder) { throw 'A delivery attempt already exists for this candidate; inspect it before retrying.' }
New-Item -ItemType Directory -Path $receiptFolder | Out-Null
$backup = Join-Path $receiptFolder 'previous-Play Oblivion.lnk'
Copy-Item -LiteralPath $launcher -Destination $backup
if ((Get-Sha256 $backup) -cne $oldLinkHash) { throw 'Previous shortcut backup failed hash verification.' }
$recovery = Join-Path $receiptFolder 'previous-build'
New-Item -ItemType Directory -Path $recovery | Out-Null
$oldFolder = Split-Path $oldTarget -Parent
$oldFiles = @(Get-ChildItem -LiteralPath $oldFolder -File -Force | Where-Object { $_.Extension -in @('.exe','.pck','.dll') })
$recoveryFiles = @()
foreach ($file in $oldFiles) {
    Assert-NoReparse $file.FullName
    $before = Get-Sha256 $file.FullName
    $saved = Resolve-Child $recovery $file.Name
    Copy-Item -LiteralPath $file.FullName -Destination $saved
    if ((Get-Sha256 $saved) -cne $before -or (Get-Sha256 $file.FullName) -cne $before) { throw 'Previous build changed while preserving recovery files.' }
    $recoveryFiles += [pscustomobject]@{ Path=$file.Name; Sha256=$before; Bytes=$file.Length }
}
$recoveryTarget = Resolve-Child $recovery ([IO.Path]::GetFileName($oldTarget))
if (-not (Test-Path -LiteralPath $recoveryTarget -PathType Leaf) -or (Get-Sha256 $recoveryTarget) -cne $oldTargetHash) { throw 'Previous executable was not preserved.' }
$recoveryLauncher = Join-Path $receiptFolder 'Recover previous Oblivion.lnk'
$recoverLink = $shell.CreateShortcut($recoveryLauncher)
$recoverLink.TargetPath = $recoveryTarget
$recoverLink.WorkingDirectory = $recovery
$recoverLink.Arguments = $oldArguments
$recoverLink.Save()
$recoverReadback = $shell.CreateShortcut($recoveryLauncher)
if ($recoverReadback.TargetPath -ine $recoveryTarget -or $recoverReadback.WorkingDirectory -ine $recovery -or $recoverReadback.Arguments -cne $oldArguments) { throw 'Recovery shortcut readback failed.' }
Write-Json (Join-Path $receiptFolder 'previous.json') ([pscustomobject]@{ Launcher=$launcher; LauncherSha256=$oldLinkHash; Target=$oldTarget; TargetSha256=$oldTargetHash; WorkingDirectory=$oldWorking; Arguments=$oldArguments; RecoveryTarget=$recoveryTarget; RecoveryLauncher=$recoveryLauncher; RecoveryFiles=$recoveryFiles })
$pendingLink = Resolve-Child $gameFolder ('.pending-' + [guid]::NewGuid().ToString('N') + '.lnk')
$switched = $false
try {
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($entry in @($manifest.ArtifactFiles)) {
        if ($entry.Path -notmatch '^candidate/bin/([^/]+)$') { throw 'Unexpected artifact location.' }
        Copy-Item -LiteralPath (Resolve-Child $run $entry.Path) -Destination (Resolve-Child $destination $Matches[1])
    }
    $copied = @(Get-ChildItem -LiteralPath $destination -File -Force)
    if ($copied.Count -ne @($manifest.ArtifactFiles).Count) { throw 'Desktop artifact set is incomplete.' }
    foreach ($entry in @($manifest.ArtifactFiles)) {
        $target = Resolve-Child $destination ([IO.Path]::GetFileName($entry.Path))
        if ((Get-Sha256 $target) -cne $entry.Sha256 -or (Get-Item -LiteralPath $target).Length -ne $entry.Bytes) { throw 'Desktop build differs from the approved candidate.' }
    }
    $newTarget = Resolve-Child $destination 'QuietRelay.exe'
    $next = $shell.CreateShortcut($pendingLink)
    $next.TargetPath = $newTarget
    $next.WorkingDirectory = $destination
    $next.Arguments = ''
    $next.Description = 'Oblivion verified build ' + $manifest.RunId
    $next.IconLocation = $newTarget + ',0'
    $next.Save()
    # Revalidate immediately before the only launcher mutation, including source/build/evidence/approval hashes.
    $rechecked = Test-ReleaseCandidate $run $project
    if ($rechecked.ManifestSha256 -cne $approved.ManifestSha256 -or (Get-Sha256 $launcher) -cne $oldLinkHash -or (Get-Sha256 $oldTarget) -cne $oldTargetHash) { throw 'Candidate or previous launcher/build changed before delivery.' }
    if ($manifest.Job.ReleaseIntent.GitHubPublication) {
        $freshPublication = Test-PublicationPreflight -RunDirectory $run -ProjectRoot $project -MappingPath $MappingPath -ApprovalPath $PublicationApprovalPath -CheckoutParent $CheckoutParent
        if ($freshPublication.Valid -isnot [bool] -or -not $freshPublication.Valid -or $freshPublication.Release.ManifestSha256 -cne $approved.ManifestSha256 -or $freshPublication.MappingSha256 -cne $publicationReady.MappingSha256 -or $freshPublication.ApprovalSha256 -cne $publicationReady.ApprovalSha256 -or $freshPublication.Mapping.ExpectedRemoteHead -cne $publicationReady.Mapping.ExpectedRemoteHead) { throw 'Publication readiness or its approved mapping changed before desktop delivery.' }
    }
    $replacementBackup = Join-Path $receiptFolder 'replacement-previous.lnk'
    [IO.File]::Replace($pendingLink,$launcher,$replacementBackup)
    $switched = $true
    if ((Get-Sha256 $replacementBackup) -cne $oldLinkHash) { throw 'Atomic replacement backup does not match the previous launcher.' }
    $readback = $shell.CreateShortcut($launcher)
    if ($readback.TargetPath -ine $newTarget -or $readback.WorkingDirectory -ine $destination -or $readback.Arguments -ne '') { throw 'Shortcut target/working directory readback failed.' }
    foreach ($entry in @($manifest.ArtifactFiles)) {
        if ((Get-Sha256 (Resolve-Child $destination ([IO.Path]::GetFileName($entry.Path)))) -cne $entry.Sha256) { throw 'Delivered artifact changed during shortcut update.' }
    }
    $null = Test-ReleaseCandidate $run $project
    $publicationEvidence = $null
    if ($null -ne $publicationReady) { $publicationEvidence = [pscustomobject]@{ MappingSha256=$publicationReady.MappingSha256; ApprovalSha256=$publicationReady.ApprovalSha256; ExpectedRemoteHead=$publicationReady.Mapping.ExpectedRemoteHead; PreflightUtc=[DateTimeOffset]::UtcNow.ToString('o') } }
    $receipt = [pscustomobject]@{ Status='Delivered'; RunId=$manifest.RunId; ManifestSha256=$approved.ManifestSha256; SourceSha256=$approved.SourceSha256; ArtifactSetSha256=$approved.ArtifactSetSha256; DeliveredUtc=[DateTimeOffset]::UtcNow.ToString('o'); Launcher=$launcher; Target=$newTarget; WorkingDirectory=$destination; PreviousLauncherBackup=$backup; PreviousTarget=$oldTarget; PreviousTargetSha256=$oldTargetHash; RecoveryTarget=$recoveryTarget; RecoveryLauncher=$recoveryLauncher; RecoveryFiles=$recoveryFiles; PublicationPreflight=$publicationEvidence }
    Write-Json (Join-Path $receiptFolder 'receipt.json') $receipt
    $receipt
} catch {
    $reason = $_.Exception.Message
    if ($switched) {
        [IO.File]::Copy($backup,$launcher,$true)
        if ((Get-Sha256 $launcher) -cne $oldLinkHash) { throw ('DELIVERY FAILED; launcher rollback also failed. Backup: ' + $backup + '; original error: ' + $reason) }
    }
    Write-Json (Join-Path $receiptFolder 'failure.json') ([pscustomobject]@{ Status='Failed'; Reason=$reason; PreviousLauncherRestored=$switched; CandidatePreserved=$destination; AtUtc=[DateTimeOffset]::UtcNow.ToString('o') })
    throw ('DELIVERY REFUSED: ' + $reason)
}
