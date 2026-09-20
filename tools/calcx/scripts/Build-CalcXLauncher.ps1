[CmdletBinding()]
param(
    [switch]$Clean
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $PSScriptRoot
$launcherRoot = Join-Path $toolRoot 'launcher'
$runtimeRoot = Join-Path $toolRoot 'runtime'
$buildRoot = Join-Path $toolRoot '.build'
$distRoot = Join-Path $toolRoot 'dist'

function Remove-GeneratedDirectory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedLeaf
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    if ((Split-Path -Leaf $resolved) -ne $ExpectedLeaf -or
        -not $resolved.StartsWith($toolRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove an unexpected generated directory: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

$cmake = Get-Command cmake -CommandType Application -ErrorAction SilentlyContinue
$ninja = Get-Command ninja -CommandType Application -ErrorAction SilentlyContinue
$compiler = Get-Command g++ -CommandType Application -ErrorAction SilentlyContinue
if (-not $cmake -or -not $ninja -or -not $compiler) {
    throw 'Building calcx.exe requires cmake, ninja, and a MinGW g++ compiler in PATH.'
}

if ($Clean) {
    Remove-GeneratedDirectory -Path $buildRoot -ExpectedLeaf '.build'
}

New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
& $cmake.Source `
    -S $launcherRoot `
    -B $buildRoot `
    -G Ninja `
    '-DCMAKE_BUILD_TYPE=Release' `
    "-DCMAKE_CXX_COMPILER=$($compiler.Source)"
if ($LASTEXITCODE -ne 0) {
    throw "CMake configuration failed with exit code $LASTEXITCODE."
}

& $cmake.Source --build $buildRoot --config Release
if ($LASTEXITCODE -ne 0) {
    throw "Launcher build failed with exit code $LASTEXITCODE."
}

$launcher = Join-Path $buildRoot 'calcx.exe'
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
    throw "Launcher output was not found: $launcher"
}

Remove-GeneratedDirectory -Path $distRoot -ExpectedLeaf 'dist'
$distRuntime = Join-Path $distRoot 'runtime'
$distCommands = Join-Path $distRuntime 'commands'
New-Item -ItemType Directory -Path $distCommands -Force | Out-Null

Copy-Item -LiteralPath $launcher -Destination (Join-Path $distRoot 'calcx.exe')
Copy-Item -LiteralPath (Join-Path $runtimeRoot 'calcx.ps1') -Destination $distRuntime
Copy-Item -LiteralPath (Join-Path $runtimeRoot 'CalcXCli.Common.psm1') -Destination $distRuntime
Get-ChildItem -LiteralPath (Join-Path $runtimeRoot 'commands') -Filter '*.ps1' -File |
    Copy-Item -Destination $distCommands

[Console]::Out.WriteLine((Join-Path $distRoot 'calcx.exe'))
