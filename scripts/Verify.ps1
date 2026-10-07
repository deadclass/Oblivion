param([string]$Godot = 'godot')
$ErrorActionPreference = 'Stop'
$projectPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'prototypes\quiet-relay'
$artifactPath = Join-Path $projectPath '.artifacts'
New-Item -ItemType Directory -Path $artifactPath -Force | Out-Null
& $Godot --headless --path $projectPath --fixed-fps 120 --script res://tests/run_tests.gd --log-file (Join-Path $artifactPath 'automated-tests.log')
if ($LASTEXITCODE -ne 0) { throw "Automated checks failed: exit $LASTEXITCODE" }
& $Godot --headless --path $projectPath --quit-after 120 --log-file (Join-Path $artifactPath 'engine-smoke.log')
if ($LASTEXITCODE -ne 0) { throw "Engine smoke failed: exit $LASTEXITCODE" }
Write-Output 'Automated checks and source smoke passed.'
