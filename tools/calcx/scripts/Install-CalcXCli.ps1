[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CalculatorX\CLI'),
    [switch]$Build,
    [switch]$SkipPathUpdate
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $PSScriptRoot
$distRoot = Join-Path $toolRoot 'dist'
if ($Build) {
    & (Join-Path $PSScriptRoot 'Build-CalcXLauncher.ps1')
}

$sourceLauncher = Join-Path $distRoot 'calcx.exe'
$sourceRuntime = Join-Path $distRoot 'runtime'
if (-not (Test-Path -LiteralPath $sourceLauncher -PathType Leaf) -or
    -not (Test-Path -LiteralPath $sourceRuntime -PathType Container)) {
    throw 'The CLI distribution is missing. Run Build-CalcXLauncher.ps1 first or use -Build.'
}

$resolvedInstallRoot = [IO.Path]::GetFullPath($InstallRoot)
$installDrive = [IO.Path]::GetPathRoot($resolvedInstallRoot)
if ($resolvedInstallRoot.TrimEnd('\') -eq $installDrive.TrimEnd('\')) {
    throw 'InstallRoot cannot be a drive root.'
}

$installAction = if ($SkipPathUpdate) {
    'Install CalculatorX CLI'
} else {
    'Install CalculatorX CLI and update the user PATH'
}

if ($PSCmdlet.ShouldProcess($resolvedInstallRoot, $installAction)) {
    $parent = Split-Path -Parent $resolvedInstallRoot
    New-Item -ItemType Directory -Path $parent -Force | Out-Null

    $stagingRoot = "$resolvedInstallRoot.installing-$PID"
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $stagingRoot | Out-Null
    try {
        Copy-Item -LiteralPath $sourceLauncher -Destination $stagingRoot
        Copy-Item -LiteralPath $sourceRuntime -Destination $stagingRoot -Recurse

        if (Test-Path -LiteralPath $resolvedInstallRoot) {
            Remove-Item -LiteralPath $resolvedInstallRoot -Recurse -Force
        }
        Move-Item -LiteralPath $stagingRoot -Destination $resolvedInstallRoot
    } finally {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force
        }
    }

    if (-not $SkipPathUpdate) {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User') ?? ''
        $segments = @($userPath.Split(';', [StringSplitOptions]::RemoveEmptyEntries) |
            ForEach-Object { $_.Trim() })
        $alreadyPresent = @($segments | Where-Object {
            $_.TrimEnd('\') -ieq $resolvedInstallRoot.TrimEnd('\')
        }).Count -gt 0
        if (-not $alreadyPresent) {
            $segments += $resolvedInstallRoot
            [Environment]::SetEnvironmentVariable('Path', ($segments -join ';'), 'User')
        }
    }

    [Console]::Out.WriteLine("CalculatorX CLI installed at: $resolvedInstallRoot")
    if ($SkipPathUpdate) {
        [Console]::Out.WriteLine("Run directly: $resolvedInstallRoot\calcx.exe -SelfTest")
    } else {
        [Console]::Out.WriteLine('Open a new terminal, then run: calcx -SelfTest')
    }
}
