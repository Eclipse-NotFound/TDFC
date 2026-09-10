$ErrorActionPreference = 'Stop'
$modRoot = Split-Path $PSScriptRoot -Parent
$gameRoot = Split-Path (Split-Path $modRoot -Parent) -Parent
$oldJava = $env:JAVA_HOME
$oldPath = $env:PATH
Push-Location $modRoot
try {
    $env:JAVA_HOME='D:\Program Files\Adobe Animate 2024\jre'
    $env:PATH=(Join-Path $env:JAVA_HOME 'bin')+';'+$oldPath
    & 'D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk\bin\mxmlc.bat' -load-config build/tdfc-config.xml -source-path+=tests -output build/out/LogicTests.swf tests/LogicTests.as
    if ($LASTEXITCODE -ne 0) { throw 'Logic test compile failed.' }
    $arguments = '-runtime "{0}" "{1}"' -f (Join-Path $gameRoot 'runtimes\air\win64'), (Join-Path $PSScriptRoot 'logic-test.xml')
    $p=Start-Process -FilePath (Join-Path $gameRoot 'adl64.exe') -ArgumentList $arguments -WorkingDirectory $gameRoot -WindowStyle Hidden -PassThru -Wait
    Get-Content -LiteralPath 'build\out\logic-result.txt'
    if ($p.ExitCode -ne 0) { throw "Logic tests failed: $($p.ExitCode)" }
} finally {Pop-Location; $env:JAVA_HOME=$oldJava; $env:PATH=$oldPath}
