param([string]$Godot = 'godot')
$ErrorActionPreference = 'Stop'
$projectPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'prototypes\quiet-relay'
$artifactPath = Join-Path $projectPath '.artifacts'
New-Item -ItemType Directory -Path $artifactPath -Force | Out-Null
& $Godot --headless --path $projectPath --export-release 'Windows Desktop' (Join-Path $artifactPath 'QuietRelay.exe') --log-file (Join-Path $artifactPath 'export.log')
if ($LASTEXITCODE -ne 0) { throw "Windows export failed: exit $LASTEXITCODE. Check matching existing export templates." }
Write-Output (Join-Path $artifactPath 'QuietRelay.exe')
