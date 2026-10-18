[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$RunDirectory)
. (Join-Path $PSScriptRoot 'Common.ps1')
try { Test-ReleaseCandidate $RunDirectory (Get-ReleaseProjectRoot) }
catch { Write-Error ('RELEASE REFUSED: ' + $_.Exception.Message); exit 1 }
