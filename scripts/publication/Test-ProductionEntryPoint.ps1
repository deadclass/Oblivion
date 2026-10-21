[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RunDirectory,
    [Parameter(Mandatory=$true)][string]$WorkDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
. (Join-Path $PSScriptRoot 'Common.ps1')
$run = [IO.Path]::GetFullPath($RunDirectory)
$work = [IO.Path]::GetFullPath($WorkDirectory)
if (Test-Path -LiteralPath (Join-Path $run 'approvals/review.json')) { throw 'This negative regression requires a fresh real candidate before independent review approval is imported.' }
if (Test-Path -LiteralPath $work) { throw 'Entry-point test work directory must be new.' }
$project = Get-ReleaseProjectRoot
$before = (Get-SourceManifest $project).Sha256
# Confirm genuine candidate evidence first, without approving it or filling review receipts.
$evidence = Test-ReleaseCandidate $run $project -EvidenceOnly
New-Item -ItemType Directory -Path $work | Out-Null
$entry = Join-Path $PSScriptRoot 'Publish-Verified.ps1'
$shell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$stdout = Join-Path $work 'production-stdout.log'
$stderr = Join-Path $work 'production-stderr.log'
$arguments = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$entry,'-RunDirectory',$run,'-MappingPath',(Join-Path $work 'absent-mapping.json'),'-ApprovalPath',(Join-Path $work 'absent-public-review.json'),'-CheckoutParent',$work)
# ProjectRoot is intentionally omitted: this exercises the actual production script's PS5 default path.
$line = (@($arguments | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join ' ')
$process = Start-Process -FilePath $shell -ArgumentList $line -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null = $process.Handle
if (-not $process.WaitForExit(60000)) {
    & (Join-Path $env:SystemRoot 'System32/taskkill.exe') /PID $process.Id /T /F | Out-Null
    throw 'Production entry-point regression timed out.'
}
$process.WaitForExit()
$errorText = [IO.File]::ReadAllText($stderr)
if ($process.ExitCode -eq 0 -or $errorText -notmatch 'Required JSON is missing:' -or $errorText -notmatch '(?i)approvals[\\/]review\.json' -or $errorText -match 'Path.*empty string|ParameterBindingValidationException') { throw ('Actual PS5 production entry point did not reach the expected missing-review gate. Inspect ' + $stderr) }
if ((Get-SourceManifest $project).Sha256 -cne $before -or (Test-Path -LiteralPath (Join-Path $run 'approvals/review.json'))) { throw 'Negative entry-point test changed source or fabricated review.' }
$receipt = [pscustomobject][ordered]@{ Status = 'Passed'; Case = 'ActualPS5ProductionEntryPoint-OmittedProjectRoot-MissingIndependentReview'; RunId = $evidence.RunId; SourceSha256 = $before; EntryPointSha256 = Get-Sha256 $entry; ExitCode = $process.ExitCode; ProjectRootWasOmitted = $true; ExpectedRefusal = 'Required JSON is missing: approvals/review.json'; ApprovalsCreated = 0; DesktopMutations = 0; RemoteMutations = 0; Scope = 'Actual production entry point in a new Windows PowerShell 5.1 process, using genuine fresh candidate evidence; release refused before mapping preparation, desktop operation or Git.' }
Write-Json (Join-Path $work 'result.json') $receipt
$receipt
