[CmdletBinding()]
param(
    [ValidateSet('Observe', 'LoadCheck', 'Combat', 'CoverCheck', 'TelekinesisCheck', 'TelekinesisUI')][string]$Mode = 'Observe',
    [ValidateRange(0, 38)][int]$SaveSlot = 0,
    [string]$SaveDirectory = (Join-Path $env:APPDATA 'pfe\Local Store\#SharedObjects\pfe.swf'),
    [string]$SaveFile,
    [switch]$Fresh,
    [switch]$Hidden,
    [string]$TravelLand,
    [ValidateSet('RealisticVision','Sandevistan','RConnect','RandomRooms')][string[]]$ExtraMod = @(),
    [ValidateSet('current','classic','vanilla','disabled')][string]$TestVisionMode,
    [string]$TestVisionSwf,
    [ValidateRange(120, 7200)][int]$Ticks = 1200
)
$ErrorActionPreference = 'Stop'
$modRoot = Split-Path $PSScriptRoot -Parent
$gameRoot = Split-Path (Split-Path $modRoot -Parent) -Parent
$testRoot = Join-Path $PSScriptRoot 'test-game'
$descriptor = Join-Path $testRoot 'app-tdfc-test.xml'
$candidate = Join-Path $PSScriptRoot 'out\TDFCMod.swf'
if (!(Test-Path -LiteralPath $candidate)) { throw 'Build the candidate with build.ps1 first.' }
if (($TestVisionMode -or $TestVisionSwf) -and $ExtraMod -notcontains 'RealisticVision') { throw 'Vision test overrides require the copied RealisticVision dependency.' }
if ($TestVisionSwf) {
    $TestVisionSwf = (Get-Item -LiteralPath $TestVisionSwf).FullName
    if ([IO.Path]::GetExtension($TestVisionSwf) -ne '.swf') { throw 'TestVisionSwf must be an existing SWF candidate.' }
}

# Refuse to overwrite files used by an existing test. Never stop another game.
$running = Get-CimInstance Win32_Process -Filter "Name = 'adl64.exe'" |
    Where-Object { $_.CommandLine -and $_.CommandLine.Contains($descriptor) }
if ($running) { throw "TDFC test is still running (PID $($running.ProcessId)). Close that test window first." }

New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
foreach ($asset in Get-ChildItem -LiteralPath $gameRoot -File) {
    if ($asset.Name -match '^(pfe\.swf|(sound|sprite|texture).*\.swf|lang\.xml|text_(zh|en|ru)\.xml)$') {
        $dest = Join-Path $testRoot $asset.Name
        if (!(Test-Path -LiteralPath $dest) -or (Get-FileHash -LiteralPath $dest).Hash -ne (Get-FileHash -LiteralPath $asset.FullName).Hash) {
            Copy-Item -LiteralPath $asset.FullName -Destination $dest -Force
        }
    }
}
foreach ($dir in @('Rooms', 'Music')) {
    if (!(Test-Path -LiteralPath (Join-Path $testRoot $dir))) {
        Copy-Item -LiteralPath (Join-Path $gameRoot $dir) -Destination $testRoot -Recurse
    }
}
$modDest = Join-Path $testRoot 'mods\TDFC\release'
New-Item -ItemType Directory -Force -Path $modDest | Out-Null
Copy-Item -LiteralPath $candidate -Destination (Join-Path $modDest 'TDFCMod.swf') -Force

# Optional, read-only copies of deployed mods for coexistence checks. Each run clears only
# known copied binaries in this test root so a previous extra cannot contaminate a baseline.
$extraHashes = @()
foreach ($extra in @('RealisticVision','Sandevistan','RConnect','RandomRooms')) {
    $extraDest = Join-Path $testRoot "mods\$extra\release"
    $extraBinary = Join-Path $extraDest ($extra + 'Mod.swf')
    if ($ExtraMod -contains $extra) {
        $extraSource = Join-Path $gameRoot "mods\$extra\release"
        New-Item -ItemType Directory -Force -Path $extraDest | Out-Null
        foreach ($fileName in @(($extra + 'Mod.swf'), 'config.txt')) {
            $extraFile = Join-Path $extraSource $fileName
            if (Test-Path -LiteralPath $extraFile) {
                Copy-Item -LiteralPath $extraFile -Destination (Join-Path $extraDest $fileName) -Force
                $extraHashes += @{path=$extraFile; sha256=(Get-FileHash -LiteralPath $extraFile).Hash}
            }
        }
    } elseif (Test-Path -LiteralPath $extraBinary) { Remove-Item -LiteralPath $extraBinary }
}

# Override only the isolated copy for input/visibility regression checks.
if ($TestVisionSwf) { Copy-Item -LiteralPath $TestVisionSwf -Destination (Join-Path $testRoot 'mods\RealisticVision\release\RealisticVisionMod.swf') -Force }
if ($TestVisionMode) {
    $visionConfig = Join-Path $testRoot 'mods\RealisticVision\release\config.txt'
    $visionText = Get-Content -LiteralPath $visionConfig -Raw
    $visionText = $visionText -replace '(?m)^enabled=\d+', ('enabled=' + $(if ($TestVisionMode -eq 'disabled') {'0'} else {'1'}))
    $visionText = $visionText -replace '(?m)^mode=\w+', ('mode=' + $(if ($TestVisionMode -eq 'disabled') {'current'} else {$TestVisionMode}))
    [IO.File]::WriteAllText($visionConfig, $visionText, (New-Object System.Text.UTF8Encoding($false)))
}

# Existing saves may contain MSW items; the native inventory loader needs their definitions.
# Copy only the deployed dependency binary. No dependency source or configuration is edited.
$msw = Join-Path $gameRoot 'mods\MoreSkills&Weapons\release\MoreSkillsWeaponsMod.swf'
if (!(Test-Path -LiteralPath $msw)) { throw 'Existing saves require the installed MoreSkillsWeaponsMod.swf.' }
$mswDest = Join-Path $testRoot 'mods\MoreSkills&Weapons\release'
New-Item -ItemType Directory -Force -Path $mswDest | Out-Null
$testMsw = & (Join-Path $PSScriptRoot 'prepare-test-dependency.ps1')
Copy-Item -LiteralPath $testMsw -Destination (Join-Path $mswDest 'MoreSkillsWeaponsMod.swf') -Force

$run = [guid]::NewGuid().ToString('N')
$options = [ordered]@{run=$run; scenario=@{Observe='observe'; LoadCheck='load-check'; Combat='combat'; CoverCheck='cover-check'; TelekinesisCheck='telekinesis-check'; TelekinesisUI='telekinesis-ui'}[$Mode]; ticks=$Ticks; exit=($Mode -notin @('Observe','TelekinesisUI')); fresh=[bool]$Fresh}
if ($TravelLand) { $options.travelLand = $TravelLand }
$manifest = [ordered]@{run=$run; created=(Get-Date).ToString('o'); candidateSha256=(Get-FileHash -LiteralPath $candidate).Hash; mswSha256=(Get-FileHash -LiteralPath $msw).Hash; sources=@()}
$manifest.testMswSha256=(Get-FileHash -LiteralPath $testMsw).Hash
$manifest.extraMods=$extraHashes
$manifest.testVisionMode=$TestVisionMode
if ($TestVisionSwf) { $manifest.testVisionSwf=@{path=$TestVisionSwf; sha256=(Get-FileHash -LiteralPath $TestVisionSwf).Hash} }
if ($TestVisionMode) { $manifest.testVisionConfigSha256=(Get-FileHash -LiteralPath $visionConfig).Hash }
if (!$Fresh) {
    # The only external write destination is this exact test application's storage.
    $store = Join-Path $env:APPDATA 'pfe-tdfc-test\Local Store\#SharedObjects\pfe.swf'
    New-Item -ItemType Directory -Force -Path $store | Out-Null
    if ($SaveFile) {
        $source = (Get-Item -LiteralPath $SaveFile).FullName
        if ([IO.Path]::GetExtension($source) -ne '.sav') { throw 'SaveFile must be a game-exported .sav file.' }
        $copy = Join-Path $testRoot 'seed.sav'
        $hash = (Get-FileHash -LiteralPath $source).Hash
        Copy-Item -LiteralPath $source -Destination $copy -Force
        if ((Get-FileHash -LiteralPath $copy).Hash -ne $hash) { throw 'Save copy hash mismatch.' }
        $manifest.sources += @{path=$source; sha256=$hash}
        $options.saveFile = $copy
    } else {
        $source = Join-Path $SaveDirectory "PFEgame$SaveSlot.sol"
        if (!(Test-Path -LiteralPath $source)) { throw "Save slot missing: $source. No new-game fallback." }
        foreach ($slot in Get-ChildItem -LiteralPath $SaveDirectory -File -Filter 'PFEgame*.sol') {
            if ($slot.Name -notmatch '^PFEgame\d+\.sol$') { continue }
            $hash = (Get-FileHash -LiteralPath $slot.FullName).Hash
            $copy = Join-Path $store $slot.Name
            Copy-Item -LiteralPath $slot.FullName -Destination $copy -Force
            if ((Get-FileHash -LiteralPath $copy).Hash -ne $hash) { throw "Save copy hash mismatch: $($slot.Name)" }
            $manifest.sources += @{path=$slot.FullName; sha256=$hash}
        }
        # Language/control preferences are copied; original config is never written.
        $config = Join-Path $SaveDirectory 'config.sol'
        if (Test-Path -LiteralPath $config) { Copy-Item -LiteralPath $config -Destination (Join-Path $store 'config.sol') -Force }
        $options.saveSlot = $SaveSlot
    }
    $options.saveSource = $source
    $options.saveSha256 = (Get-FileHash -LiteralPath $source).Hash
}
$encoding = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $testRoot 'tdfc-test.json'), ($options | ConvertTo-Json -Depth 5), $encoding)
[IO.File]::WriteAllText((Join-Path $testRoot 'tdfc-test-manifest.json'), ($manifest | ConvertTo-Json -Depth 5), $encoding)
[IO.File]::WriteAllText((Join-Path $testRoot 'tdfc-test-result.json'), (@{run=$run; pass=$null; reason='pending'} | ConvertTo-Json), $encoding)
[IO.File]::WriteAllText((Join-Path $testRoot 'tdfc-test-status.json'), (@{run=$run; frame=0; status='starting'} | ConvertTo-Json), $encoding)
$xml = @'
<?xml version="1.0" encoding="UTF-8"?>
<application xmlns="http://ns.adobe.com/air/application/30.0">
 <id>pfe-tdfc-test</id><versionNumber>0.6.0</versionNumber><filename>TDFC isolated test</filename>
 <initialWindow><content>pfe.swf</content><visible>true</visible><width>1000</width><height>720</height><renderMode>direct</renderMode></initialWindow>
 <supportedProfiles>extendedDesktop</supportedProfiles>
</application>
'@
[IO.File]::WriteAllText($descriptor, $xml, $encoding)
$style = if ($Hidden) {'Hidden'} else {'Normal'}
$runtime = Join-Path $gameRoot 'runtimes\air\win64'
$arguments = '-runtime "{0}" "{1}"' -f $runtime, $descriptor
$process = Start-Process -FilePath (Join-Path $gameRoot 'adl64.exe') -ArgumentList $arguments -WorkingDirectory $gameRoot -WindowStyle $style -PassThru
$process.Id | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'out\game-test.pid')
[pscustomobject]@{PID=$process.Id; Mode=$Mode; Run=$run; Save=$options.saveSource; Manifest=(Join-Path $testRoot 'tdfc-test-manifest.json')}
