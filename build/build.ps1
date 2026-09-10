[CmdletBinding()]
param(
    [string]$JavaHome = 'D:\Program Files\Adobe Animate 2024\jre',
    [string]$FlexBin = 'D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk\bin'
)
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $FlexBin 'mxmlc.bat'
if (!(Test-Path -LiteralPath $compiler) -or !(Test-Path -LiteralPath (Join-Path $JavaHome 'bin\java.exe'))) { throw 'Java/Flex toolchain unavailable; provide JavaHome and FlexBin.' }
$modRoot = Split-Path $PSScriptRoot -Parent
$oldJava = $env:JAVA_HOME
$oldPath = $env:PATH
Push-Location $modRoot
try {
    $env:JAVA_HOME = $JavaHome
    $env:PATH = (Join-Path $JavaHome 'bin') + ';' + $oldPath
    New-Item -ItemType Directory -Force -Path 'build\out' | Out-Null
    & $compiler -load-config build/tdfc-config.xml -output build/out/TDFCMod.swf src/TDFCMod.as
    if ($LASTEXITCODE -ne 0) { throw "Compiler failed: $LASTEXITCODE. Do not launch an older candidate." }
    Get-FileHash -LiteralPath 'build\out\TDFCMod.swf'
} finally { Pop-Location; $env:JAVA_HOME=$oldJava; $env:PATH=$oldPath }
