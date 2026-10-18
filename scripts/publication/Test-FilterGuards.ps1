[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$WorkDirectory)
. (Join-Path $PSScriptRoot 'Common.ps1')

# Real Git and the production checkout/audit helpers. Only remote transport is substituted
# with a new local seed; there are no network calls or real approval/delivery fixtures.
$nativeGit = ${function:Invoke-PublicationGit}
$work = [IO.Path]::GetFullPath($WorkDirectory)
if (Test-Path -LiteralPath $work) { throw 'Filter fixture directory must be new.' }
New-Item -ItemType Directory -Path $work | Out-Null
$script:seed = Join-Path $work 'seed'
$parent = Join-Path $work 'checkouts'
New-Item -ItemType Directory -Path $script:seed,$parent | Out-Null
$marker = Join-Path $work 'FILTER-EXECUTED'
$globalFixture = Join-Path $work 'global-config'
$oldGlobal = [Environment]::GetEnvironmentVariable('GIT_CONFIG_GLOBAL','Process')
$oldSystem = [Environment]::GetEnvironmentVariable('GIT_CONFIG_NOSYSTEM','Process')
$environmentBefore = [Environment]::GetEnvironmentVariables('Process')
# Snapshot real user config files read-only, including any configured global file.
$configPaths = @((Join-Path ([Environment]::GetFolderPath('UserProfile')) '.gitconfig'), (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.config/git/config'))
if ($env:XDG_CONFIG_HOME) { $configPaths += Join-Path $env:XDG_CONFIG_HOME 'git/config' }
if ($oldGlobal) { $configPaths += $oldGlobal }
$actualConfig = @{}
foreach ($path in $configPaths) { if (Test-Path -LiteralPath $path -PathType Leaf) { $actualConfig[$path] = Get-Sha256 $path } else { $actualConfig[$path] = 'ABSENT' } }
$script:operations = New-Object Collections.Generic.List[string]
function Invoke-PublicationGit([string]$Directory, [string[]]$Arguments, [int]$TimeoutSeconds = 120, [switch]$AllowFailure) {
    if (-not ([IO.Path]::GetFullPath($Directory)).StartsWith($work + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture Git escaped scratch directory.' }
    $script:operations.Add(($Arguments -join ' '))
    if ($Arguments[0] -ceq 'fetch') {
        # Request-only file transport exception for this isolated fixture, never production.
        return & $nativeGit $Directory @('-c','protocol.file.allow=always','fetch','--no-tags','--no-recurse-submodules',$script:seed,$script:head) $TimeoutSeconds -AllowFailure:$AllowFailure
    }
    if ($Arguments[0] -cin @('push','ls-remote','clone')) { throw 'Network/ref mutation is forbidden in fixtures.' }
    & $nativeGit $Directory $Arguments $TimeoutSeconds -AllowFailure:$AllowFailure
}
function Get-PublicationRemoteHead([string]$Directory) { $script:head }
function Write-FixtureText([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false))) }
function Set-Seed([string]$Attributes) {
    $null = Invoke-PublicationGit $script:seed @('read-tree','--empty')
    $entries = @{'remote-only.txt' = "preserved remote bytes`n"; 'mapped.txt' = "old mapped bytes`n"}
    if ($Attributes -ne '') { $entries['.gitattributes'] = $Attributes }
    foreach ($path in @($entries.Keys)) {
        $inputFile = Join-Path $work 'blob-input'
        Write-FixtureText $inputFile $entries[$path]
        $blob = (Invoke-PublicationGit $script:seed @('hash-object','-w','--no-filters','--',$inputFile)).Stdout.Trim()
        $null = Invoke-PublicationGit $script:seed @('update-index','--add','--cacheinfo',('100644,' + $blob + ',' + $path))
    }
    $tree = (Invoke-PublicationGit $script:seed @('write-tree')).Stdout.Trim()
    $script:head = (Invoke-PublicationGit $script:seed @('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit-tree',$tree,'-m','isolated filter fixture')).Stdout.Trim()
}
$script:passed = 0
function Run-Case([string]$Name, [string]$Attributes, [string]$Config, [string]$Overlay, [string]$Refusal = '', [string]$Before = '') {
    Write-FixtureText $globalFixture $Config
    Set-Seed $Attributes
    $file = Join-Path $work 'mapped-source'
    Write-FixtureText $file "reviewed mapped bytes`n"
    $files = @([pscustomobject]@{ PublicPath = 'mapped.txt'; File = $file; Sha256 = Get-Sha256 $file })
    if ($Overlay -ne '') {
        $attrFile = Join-Path $work 'overlay-attributes'
        Write-FixtureText $attrFile $Overlay
        $files += [pscustomobject]@{ PublicPath = '.gitattributes'; File = $attrFile; Sha256 = Get-Sha256 $attrFile }
    }
    $contract = [pscustomobject]@{ Mapping = [pscustomobject]@{ ExpectedRemoteHead = $script:head }; Files = $files }
    $script:operations.Clear()
    $configHash = Get-Sha256 $globalFixture
    $caught = $null
    try { $prepared = Initialize-PublicationCheckout $contract (Get-ReleaseProjectRoot) $parent } catch { $caught = $_.Exception.Message }
    if ($Refusal -eq '') {
        if ($null -ne $caught) { throw "FAIL $Name : $caught" }
        if ($prepared.TreeSha -cnotmatch '^[0-9a-f]{40}$') { throw 'Missing real staged tree.' }
        $remoteFile = Join-Path $prepared.Checkout 'remote-only.txt'
        if (-not (Test-Path -LiteralPath $remoteFile -PathType Leaf) -or [IO.File]::ReadAllText($remoteFile) -cne "preserved remote bytes`n") { throw 'Remote-only worktree bytes were not materialized unchanged.' }
        if ((Get-Sha256 (Join-Path $prepared.Checkout 'mapped.txt')) -cne (Get-Sha256 $file)) { throw 'Final mapped worktree bytes differ.' }
    } else {
        if ($null -eq $caught -or $caught -notmatch $Refusal) { throw "FAIL $Name : expected /$Refusal/, got [$caught]" }
        if ($Before -eq 'checkout' -and @($script:operations | Where-Object { $_ -match '^checkout(-index)? ' }).Count -ne 0) { throw 'Refusal occurred after checkout.' }
        if ($Before -eq 'add' -and @($script:operations | Where-Object { $_ -match '^add ' }).Count -ne 0) { throw 'Refusal occurred after staging.' }
    }
    if (Test-Path -LiteralPath $marker) { throw 'A content filter executed.' }
    if ((Get-Sha256 $globalFixture) -cne $configHash) { throw 'Fixture inherited config was modified.' }
    $script:passed++
    Write-Json (Join-Path $work ('case-' + $script:passed + '.json')) ([pscustomobject]@{ Name = $Name; ExpectedRefusal = $Refusal; ActualRefusal = $caught; Before = $Before; Operations = @($script:operations.ToArray()); ConfigSha256 = $configHash; MarkerAbsent = $true })
    Write-Output "PASS: $Name"
}
try {
    Write-FixtureText $globalFixture ''
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_GLOBAL',$globalFixture,'Process')
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_NOSYSTEM','1','Process')
    $null = Invoke-PublicationGit $script:seed @('init','--quiet')
    $standard = "[filter `"lfs`"]`n clean = git-lfs clean -- %f`n smudge = git-lfs smudge -- %f`n process = git-lfs filter-process`n required = true`n"
    Run-Case 'unused exact inherited LFS defaults succeed' '' $standard ''
    Run-Case 'explicitly unspecified attributes succeed' "remote-only.txt !filter`nmapped.txt !filter`n" $standard ''
    Run-Case 'explicitly unset attribute refuses ambiguous Git state label' "remote-only.txt -filter`n" $standard '' 'Active Git filter' 'checkout'
    Run-Case 'remote-only active LFS refuses before checkout' "remote-only.txt filter=lfs`n" $standard '' 'Active Git filter' 'checkout'
    Run-Case 'mapped active LFS refuses before checkout' "mapped.txt filter=lfs`n" $standard '' 'Active Git filter' 'checkout'
    Run-Case 'set attribute refuses without a configured driver' "remote-only.txt filter`n" '' '' 'Active Git filter' 'checkout'
    Run-Case 'unknown named attribute refuses without a configured driver' "remote-only.txt filter=missing`n" '' '' 'Active Git filter' 'checkout'
    Run-Case 'literal unspecified driver is not an inactive attribute' "remote-only.txt filter=unspecified`n" '' '' 'Active Git filter' 'checkout'
    Run-Case 'literal unset driver is not an inactive attribute' "remote-only.txt filter=unset`n" '' '' 'Active Git filter' 'checkout'
    Run-Case 'late overlay attributes refuse before first add' '' $standard "mapped.txt filter=lfs`n" 'Active Git filter' 'add'
    Run-Case 'overlay attributes covering remote-only file refuse before add' '' $standard "remote-only.txt filter=lfs`n" 'Active Git filter' 'add'
    $dangerous = "[filter `"evil`"]`n clean = cmd /c echo EXECUTED > " + $marker.Replace('\','/') + "`n"
    Run-Case 'unknown executable command refuses without execution' '' $dangerous '' 'Configured Git content filter' 'checkout'
    Run-Case 'near-match LFS command refuses' '' ($standard.Replace('git-lfs clean -- %f','git-lfs clean -- %f extra')) '' 'Configured Git content filter' 'checkout'
    Run-Case 'duplicate unknown command cannot hide behind allowed default' '' ($standard + "[filter `"lfs`"]`n clean = cmd /c echo EXECUTED`n") '' 'Configured Git content filter' 'checkout'
    Run-Case 'earlier unknown duplicate cannot hide behind later default' '' ("[filter `"lfs`"]`n clean = cmd /c echo EXECUTED`n" + $standard) '' 'Configured Git content filter' 'checkout'
    Run-Case 'multiline configured command refuses' '' "[filter `"lfs`"]`n clean = `"git-lfs clean -- %f\nextra`"`n" '' 'Configured Git content filter' 'checkout'
    foreach ($kind in @('clean','smudge','process')) {
        $commandConfig = "[filter `"evil`"]`n " + $kind + ' = cmd /c echo EXECUTED > ' + $marker.Replace('\','/') + "`n"
        Run-Case ('active executable ' + $kind + ' refuses before execution') "* filter=evil`n" $commandConfig '' 'Configured Git content filter' 'checkout'
    }
    Run-Case 'overlay attribute applies to attribute file itself' '' $standard "* filter=lfs`n" 'Active Git filter' 'add'
    Run-Case 'alternate driver with standard command refuses' '' "[filter `"other`"]`n process = git-lfs filter-process`n" '' 'Configured Git content filter' 'checkout'
    Run-Case 'global attributes participate in fetched-index audit' '' ($standard + "[core]`n attributesFile = " + (Join-Path $work 'global-attributes').Replace('\','/') + "`n") ''
    Write-FixtureText (Join-Path $work 'global-attributes') "remote-only.txt filter=lfs`n"
    Run-Case 'active global attributes refuse before checkout' '' ($standard + "[core]`n attributesFile = " + (Join-Path $work 'global-attributes').Replace('\','/') + "`n") '' 'Active Git filter' 'checkout'
} finally {
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_GLOBAL',$oldGlobal,'Process')
    [Environment]::SetEnvironmentVariable('GIT_CONFIG_NOSYSTEM',$oldSystem,'Process')
}
foreach ($path in @($actualConfig.Keys)) {
    $current = 'ABSENT'
    if (Test-Path -LiteralPath $path -PathType Leaf) { $current = Get-Sha256 $path }
    if ($current -cne $actualConfig[$path]) { throw 'Actual user/global config changed.' }
}
$environmentAfter = [Environment]::GetEnvironmentVariables('Process')
if ($environmentBefore.Count -ne $environmentAfter.Count) { throw 'Caller environment count changed.' }
foreach ($key in $environmentBefore.Keys) { if ($environmentBefore[$key] -cne $environmentAfter[$key]) { throw ('Caller environment changed: ' + $key) } }
if (Test-Path -LiteralPath $marker) { throw 'Content filter execution marker exists.' }
$result = [pscustomobject]@{ Status = 'Passed'; Checks = $script:passed; PowerShellVersion = $PSVersionTable.PSVersion.ToString(); FilterExecutionMarkerAbsent = $true; CallerEnvironmentUnchanged = $true; ActualGlobalConfigUnchanged = $true; NetworkOperations = 0; Scope = 'Real local Git and production checkout/audits; transport redirected to isolated local seed only.' }
Write-Json (Join-Path $work 'result.json') $result
$result
