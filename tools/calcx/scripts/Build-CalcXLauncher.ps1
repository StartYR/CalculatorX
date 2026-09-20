[CmdletBinding()]
param(
    [switch]$Clean
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $toolRoot)
$launcherRoot = Join-Path $toolRoot 'launcher'
$buildRoot = Join-Path $toolRoot '.build'

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

$destination = Join-Path $repositoryRoot 'calcx.exe'
Copy-Item -LiteralPath $launcher -Destination $destination -Force

[Console]::Out.WriteLine($destination)
