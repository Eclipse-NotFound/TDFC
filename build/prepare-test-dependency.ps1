[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$modRoot = Split-Path $PSScriptRoot -Parent
$gameRoot = Split-Path (Split-Path $modRoot -Parent) -Parent
$original = Join-Path $gameRoot 'mods\MoreSkills&Weapons\release\MoreSkillsWeaponsMod.swf'
$cache = Join-Path $PSScriptRoot 'out\msw-test-fix'
$output = Join-Path $cache 'MoreSkillsWeaponsMod.swf'
$stamp = Join-Path $cache 'source-sha256.txt'
$hash = (Get-FileHash -LiteralPath $original).Hash
if ((Test-Path -LiteralPath $output) -and (Test-Path -LiteralPath $stamp) -and (Get-Content -LiteralPath $stamp -Raw).Trim() -eq $hash) { return $output }
$java = 'D:\Program Files\Adobe Animate 2024\jre\bin\java.exe'
$ffdec = 'D:\RemainsMod\mods\Sandevistan\build\tools\ffdec\ffdec-cli.jar'
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $PSScriptRoot 'out\tool-profile'
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    & $java -jar $ffdec -selectclass MSWAutoTest -export script $cache $original | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Failed to inspect the test dependency.' }
    $script = Join-Path $cache 'scripts\MSWAutoTest.as'
    $text = [IO.File]::ReadAllText($script)
    # Exact source anchor: reject unexpected dependency versions rather than guessing.
    $pattern = 'enabled = id != "pfe";'
    if (($text.Split(@($pattern), [StringSplitOptions]::None).Length - 1) -ne 1) { throw 'MSW test guard changed; inspect the new dependency before testing.' }
    $text = $text.Replace($pattern, 'enabled = id == "pfe-msw-test";')
    [IO.File]::WriteAllText($script, $text, (New-Object System.Text.UTF8Encoding($false)))
    & $java -jar $ffdec -importScript $original $output (Join-Path $cache 'scripts') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Failed to disable competing auto-test in the isolated dependency copy.' }
    & $java -jar $ffdec -selectclass MSWAutoTest -export script (Join-Path $cache 'verify') $output | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Dependency verification export failed.' }
    $verified = [IO.File]::ReadAllText((Join-Path $cache 'verify\scripts\MSWAutoTest.as'))
    if (!$verified.Contains('id == "pfe-msw-test"')) { throw 'Dependency test guard did not survive compilation.' }
    $hash | Set-Content -LiteralPath $stamp
} finally { $env:APPDATA = $previousAppData }
return $output
