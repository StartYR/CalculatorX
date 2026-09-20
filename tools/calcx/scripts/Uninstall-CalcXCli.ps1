[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CalculatorX\CLI'),
    [switch]$SkipPathUpdate
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$resolvedInstallRoot = [IO.Path]::GetFullPath($InstallRoot)
$installDrive = [IO.Path]::GetPathRoot($resolvedInstallRoot)
if ($resolvedInstallRoot.TrimEnd('\') -eq $installDrive.TrimEnd('\')) {
    throw 'InstallRoot cannot be a drive root.'
}

$uninstallAction = if ($SkipPathUpdate) {
    'Uninstall CalculatorX CLI'
} else {
    'Uninstall CalculatorX CLI and remove the user PATH entry'
}

if ($PSCmdlet.ShouldProcess($resolvedInstallRoot, $uninstallAction)) {
    if (-not $SkipPathUpdate) {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User') ?? ''
        $segments = @($userPath.Split(';', [StringSplitOptions]::RemoveEmptyEntries) |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_.TrimEnd('\') -ine $resolvedInstallRoot.TrimEnd('\') })
        [Environment]::SetEnvironmentVariable('Path', ($segments -join ';'), 'User')
    }

    if (Test-Path -LiteralPath $resolvedInstallRoot) {
        Remove-Item -LiteralPath $resolvedInstallRoot -Recurse -Force
    }
    [Console]::Out.WriteLine("CalculatorX CLI uninstalled from: $resolvedInstallRoot")
}
