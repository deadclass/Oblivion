param([string]$Godot = 'godot')
$ErrorActionPreference = 'Stop'
$projectPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'prototypes\quiet-relay'
$artifactPath = Join-Path $projectPath '.artifacts'
New-Item -ItemType Directory -Path $artifactPath -Force | Out-Null
& $Godot --headless --path $projectPath --fixed-fps 120 --script res://tests/run_tests.gd --log-file (Join-Path $artifactPath 'automated-tests.log')
if ($LASTEXITCODE -ne 0) { throw "Automated checks failed: exit $LASTEXITCODE" }
$testOutput = Get-Content -LiteralPath (Join-Path $artifactPath 'automated-tests.log') -Raw
$testResult = [regex]::Match($testOutput, 'RESULT: (\d+) checks, 0 failures')
if (-not $testResult.Success -or [int]$testResult.Groups[1].Value -lt 450 -or $testOutput -notmatch 'failures; COMPLETE' -or $testOutput -match 'SCRIPT ERROR:|ERROR: FAIL:|Parse Error:') { throw 'Automated log is incomplete or contains a script/test error, even if the engine returned exit 0.' }
& $Godot --headless --path $projectPath --quit-after 120 --log-file (Join-Path $artifactPath 'engine-smoke.log')
if ($LASTEXITCODE -ne 0) { throw "Engine smoke failed: exit $LASTEXITCODE" }
$smokeOutput = Get-Content -LiteralPath (Join-Path $artifactPath 'engine-smoke.log') -Raw
if ($smokeOutput -match 'SCRIPT ERROR:|Parse Error:') { throw 'Source smoke contains a script error.' }
Write-Output 'Automated checks and source smoke passed.'

