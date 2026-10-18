[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [Parameter(Mandatory=$true)][string]$MappingPath,
    [Parameter(Mandatory=$true)][string]$ApprovalPath,
    [Parameter(Mandatory=$true)][string]$CheckoutParent,
    [string]$ProjectRoot = '',
    [switch]$Preflight,
    [switch]$ExecutePush
)
. (Join-Path $PSScriptRoot 'Common.ps1')
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = Get-ReleaseProjectRoot }
if ($Preflight -and $ExecutePush) { throw 'Preflight never publishes; choose one operation.' }
$project = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\','/')
if ($Preflight) {
    $ready = Test-PublicationPreflight $RunDirectory $project $MappingPath $ApprovalPath $CheckoutParent
    [pscustomobject]@{ Status = 'ReadyForDesktopDelivery-NoPush'; RunId = $ready.Release.RunId; ManifestSha256 = $ready.Release.ManifestSha256; MappingSha256 = $ready.MappingSha256; ApprovalSha256 = $ready.ApprovalSha256; ExpectedRemoteHead = $ready.Mapping.ExpectedRemoteHead; PreparedCheckout = $ready.Prepared.Checkout; PreparedTree = $ready.Prepared.TreeSha }
    return
}
$contract = Test-PublicationContract $RunDirectory $project $MappingPath $ApprovalPath
if (-not $ExecutePush) {
    [pscustomobject]@{ Status = 'ValidatedOnly-NoPush'; RunId = $contract.Release.RunId; Destination = $script:OblivionRepository; Branch = $script:OblivionBranch; ExpectedRemoteHead = $contract.Mapping.ExpectedRemoteHead }
    return
}
$ready = Test-PublicationPreflight $RunDirectory $project $MappingPath $ApprovalPath $CheckoutParent
if ($ready.MappingSha256 -cne $contract.MappingSha256 -or $ready.ApprovalSha256 -cne $contract.ApprovalSha256) { throw 'Publication review changed during preparation.' }
$checkout = $ready.Prepared.Checkout
$baseTree = $ready.Prepared.BaseTree
$treeSha = $ready.Prepared.TreeSha
$expected = $ready.Prepared.ExpectedRemoteHead
$changed = Invoke-PublicationGit $checkout @('diff','--cached','--quiet') -AllowFailure
if ($changed.ExitCode -eq 0) { throw 'Reviewed publication candidate has no changes; no push was made.' }
if ($changed.ExitCode -ne 1) { throw 'Unable to verify staged source changes.' }
$null = Invoke-PublicationGit $checkout @('-c','commit.gpgSign=false','commit','-m','Publish independently verified Oblivion source')
$commit = (Invoke-PublicationGit $checkout @('rev-parse','HEAD')).Stdout.Trim()
$parentCommit = (Invoke-PublicationGit $checkout @('rev-parse','HEAD^')).Stdout.Trim()
Assert-ExpectedRemoteHead $expected $parentCommit
Assert-PublicationTrees $baseTree (Get-PublicationTree $checkout $commit) $contract $checkout

# Re-prove release, actual delivery, reviewed bytes, destination and fresh head before the sole remote write.
$fresh = Test-PublicationContract $RunDirectory $project $MappingPath $ApprovalPath
if ($fresh.MappingSha256 -cne $contract.MappingSha256 -or $fresh.ApprovalSha256 -cne $contract.ApprovalSha256) { throw 'Publication review changed during preparation.' }
Assert-PublicationTrees $baseTree (Get-PublicationTree $checkout $commit) $fresh $checkout
Assert-ExpectedRemoteHead $expected (Get-PublicationRemoteHead $checkout)
Assert-PublicationPushDestination $checkout
$null = Invoke-PublicationGit $checkout @('push','--porcelain','origin',($commit + ':refs/heads/' + $script:OblivionBranch))

# Exit zero is insufficient: verify remote ref, freshly fetched head, entire tree and all mapped blobs.
$remote = Get-PublicationRemoteHead $checkout
if ($remote -cne $commit) { throw 'Push outcome is unconfirmed: remote head differs. Do not report publication complete.' }
$null = Invoke-PublicationGit $checkout @('fetch','--no-tags','origin',('refs/heads/' + $script:OblivionBranch))
if ((Invoke-PublicationGit $checkout @('rev-parse','FETCH_HEAD')).Stdout.Trim() -cne $commit) { throw 'Post-push fetched head differs; publication is unconfirmed.' }
$remoteTreeSha = (Invoke-PublicationGit $checkout @('rev-parse','FETCH_HEAD^{tree}')).Stdout.Trim()
if ($remoteTreeSha -cne $treeSha) { throw 'Post-push remote content tree differs; publication is unconfirmed.' }
Assert-PublicationTrees $baseTree (Get-PublicationTree $checkout 'FETCH_HEAD') $fresh $checkout
$receipt = [pscustomobject][ordered]@{ SchemaVersion = 1; Status = 'RemoteCommitAndContentVerified'; VerifiedUtc = [DateTimeOffset]::UtcNow.ToString('o'); RunId = $contract.Release.RunId; ManifestSha256 = $contract.Release.ManifestSha256; SourceSha256 = $contract.Release.SourceSha256; ArtifactSetSha256 = $contract.Release.ArtifactSetSha256; MappingSha256 = $contract.MappingSha256; ApprovalSha256 = $contract.ApprovalSha256; PreviousRemoteHead = $expected; Commit = $commit; Tree = $treeSha; Destination = $contract.Mapping.Destination; Checkout = $checkout }
Write-Json (Join-Path $checkout '.publication-local\verified-push.json') $receipt
$receipt
