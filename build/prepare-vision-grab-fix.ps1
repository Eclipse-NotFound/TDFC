[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$modRoot = Split-Path $PSScriptRoot -Parent
$gameRoot = Split-Path (Split-Path $modRoot -Parent) -Parent
$original = Join-Path $gameRoot 'mods\RealisticVision\release\RealisticVisionMod.swf'
$expected = '57FA90F813C267C1BB0BC4B4AAB536257CF10EDCD20E7E38BDA93E9B3AA9B6E0'
if ((Get-FileHash -LiteralPath $original).Hash -ne $expected) {
    throw 'The deployed RealisticVision version changed. Inspect it before preparing a new hotfix.'
}
# This tool only builds a candidate under TDFC. It never deploys to another mod.
$work = Join-Path $PSScriptRoot 'out\vision-grab-fix'
$output = Join-Path $work 'RealisticVisionMod.swf'
$java = 'D:\Program Files\Adobe Animate 2024\jre\bin\java.exe'
$ffdec = 'D:\RemainsMod\mods\Sandevistan\build\tools\ffdec\ffdec-cli.jar'
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $PSScriptRoot 'out\tool-profile'
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    & $java -jar $ffdec -selectclass RealisticVisionMod -export script (Join-Path $work 'original') $original | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Cannot export the deployed visual mod.' }
    $source = [IO.File]::ReadAllText((Join-Path $work 'original\scripts\RealisticVisionMod.as'))
    $start = $source.IndexOf('private function blockInvisibleGrab()')
    $end = $source.IndexOf('private function onFrame(', $start)
    if ($start -lt 0 -or $end -lt 0) { throw 'Grab function boundaries changed.' }
    $body = $source.Substring($start, $end - $start)
    $anchor = 'if(_loc2_ !== this.curLoc)'
    if (($body.Split(@($anchor), [StringSplitOptions]::None).Length - 1) -ne 1) { throw 'Grab guard changed.' }
    $guard = 'if(_loc2_ !== this.curLoc || this.cfgMode == "vanilla" || Boolean(_loc2_.base) || this.cfgBaseRooms[_loc2_.id] == true)'
    $body = $body.Replace($anchor, $guard)
    $source = $source.Substring(0, $start) + $body + $source.Substring($end)
    $version = 'private static const VERSION:String = "v0.28.0";'
    if (!$source.Contains($version)) { throw 'Deployed visual mod version marker changed.' }
    $source = $source.Replace($version, 'private static const VERSION:String = "v0.28.0-grabfix.1";')
    $scripts = Join-Path $work 'patch\scripts'
    New-Item -ItemType Directory -Force -Path $scripts | Out-Null
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path $scripts 'RealisticVisionMod.as'), $source, $encoding)
    & $java -jar $ffdec -importScript $original $output $scripts | Out-Host
    if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $output)) { throw 'Visual mod hotfix compilation failed.' }
    & $java -jar $ffdec -selectclass RealisticVisionMod -export script (Join-Path $work 'verify') $output | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read back the candidate.' }
    $verified = [IO.File]::ReadAllText((Join-Path $work 'verify\scripts\RealisticVisionMod.as'))
    if (!$verified.Contains($guard) -or !$verified.Contains('v0.28.0-grabfix.1')) { throw 'The intended hotfix did not survive compilation.' }
    $manifest = @{source=$original; sourceSha256=$expected; candidate=$output; candidateSha256=(Get-FileHash -LiteralPath $output).Hash; version='v0.28.0-grabfix.1'; deployed=$false}
    [IO.File]::WriteAllText((Join-Path $work 'candidate.json'), ($manifest | ConvertTo-Json), $encoding)
} finally { $env:APPDATA = $previousAppData }
return $output
