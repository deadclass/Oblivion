[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$RunDirectory,[Parameter(Mandatory = $true)][string]$ApprovalFile)
. (Join-Path $PSScriptRoot 'Common.ps1')
$null = Test-ReleaseCandidate $RunDirectory (Get-ReleaseProjectRoot) -EvidenceOnly
$manifestPath = Join-Path $RunDirectory 'candidate.json'
$manifest = Read-Json $manifestPath
$approval = Read-Json $ApprovalFile
Assert-Fields $approval @('Kind') 'Approval'
if ($approval.Kind -notin @('Review','Visual')) { throw 'Approval kind must be Review or Visual.' }
Assert-Approval $approval $approval.Kind $manifest (Get-Sha256 $manifestPath) $manifest.Job.ImplementerIdentity
$target = Join-Path $RunDirectory ('approvals/' + $approval.Kind.ToLowerInvariant() + '.json')
if (Test-Path -LiteralPath $target) { throw 'Approval already exists. Create a new candidate rather than replacing a review decision.' }
Copy-Item -LiteralPath $ApprovalFile -Destination $target
Write-Output ('Saved exact-hash ' + $approval.Kind + ' approval. Run Test-Candidate.ps1 to check the complete gate.')
