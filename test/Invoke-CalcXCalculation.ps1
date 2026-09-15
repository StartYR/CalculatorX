[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Latex,

    [string]$Mode = 'standard',

    [string]$Angle = 'radian',

    [string]$Precision = 'auto',

    [string]$DeviceId,

    [int]$TimeoutSeconds = 30,

    [string]$HdcPath,

    [switch]$SelfTest
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$ProtocolVersion = 1
$BundleName = 'com.startyi.calcx'
$TestModuleName = 'entry_test'
$TestRunner = '/ets/testrunner/OpenHarmonyTestRunner'
$ResultPrefix = 'CALCX_TEST_RESULT:'

function Write-Diagnostic {
    param([Parameter(Mandatory)][string]$Message)
    [Console]::Error.WriteLine($Message)
}

function ConvertTo-Base64Url {
    param([Parameter(Mandatory)][string]$Text)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function ConvertFrom-Base64Url {
    param([Parameter(Mandatory)][string]$Text)
    if ($Text -notmatch '^[A-Za-z0-9_-]+$') {
        throw 'Value is not URL-safe Base64.'
    }
    $padded = $Text.Replace('-', '+').Replace('_', '/')
    switch ($padded.Length % 4) {
        0 { }
        2 { $padded += '==' }
        3 { $padded += '=' }
        default { throw 'URL-safe Base64 has an invalid length.' }
    }
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($padded))
}

function Resolve-HdcExecutable {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
            throw "HDC was not found at the supplied path: $RequestedPath"
        }
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $command = Get-Command hdc -CommandType Application -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = [Collections.Generic.List[string]]::new()
    if ($env:DEVECO_SDK_HOME) {
        $candidates.Add((Join-Path $env:DEVECO_SDK_HOME 'default\openharmony\toolchains\hdc.exe'))
    }
    $candidates.Add('E:\Program Files\HUAWEI\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe')

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'HDC was not found in PATH or the known DevEco Studio SDK locations. Use -HdcPath.'
}

function Invoke-ProcessWithTimeout {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][int]$TimeoutSeconds
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    foreach ($argument in $ArgumentList) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "Failed to start process: $FilePath"
    }
    $standardOutputTask = $process.StandardOutput.ReadToEndAsync()
    $standardErrorTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill($true)
        $process.WaitForExit()
        throw [TimeoutException]::new("Process timed out after $TimeoutSeconds seconds.")
    }

    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut = $standardOutputTask.GetAwaiter().GetResult()
        StdErr = $standardErrorTask.GetAwaiter().GetResult()
    }
}

function New-CalculationRequest {
    param(
        [Parameter(Mandatory)][string]$InputLatex,
        [Parameter(Mandatory)][string]$InputMode,
        [Parameter(Mandatory)][string]$InputAngle,
        [Parameter(Mandatory)][string]$InputPrecision
    )
    return [ordered]@{
        protocolVersion = $ProtocolVersion
        requestId = [Guid]::NewGuid().ToString('D')
        latex = $InputLatex
        mode = $InputMode
        angle = $InputAngle
        precision = $InputPrecision
    }
}

function Test-ProtocolRoundTrip {
    $samples = @(
        '\frac{1}{2}+\frac{1}{3}',
        '"quoted" + 空格 + π',
        "line 1`nline 2"
    )
    foreach ($sample in $samples) {
        $request = New-CalculationRequest -InputLatex $sample -InputMode 'standard' -InputAngle 'radian' -InputPrecision 'auto'
        $json = $request | ConvertTo-Json -Compress
        $decoded = ConvertFrom-Base64Url (ConvertTo-Base64Url $json)
        if ($decoded -cne $json) {
            throw 'UTF-8 JSON URL-safe Base64 round-trip failed.'
        }
    }
    [Console]::Out.WriteLine('{"ok":true,"selfTest":"protocol-round-trip"}')
}

try {
    if ($SelfTest) {
        Test-ProtocolRoundTrip
        exit 0
    }
    if ([string]::IsNullOrWhiteSpace($Latex)) {
        Write-Diagnostic 'Latex must contain at least one non-whitespace character.'
        exit 2
    }
    if ($Latex.Length -gt 4096) {
        Write-Diagnostic 'Latex must not exceed 4096 characters.'
        exit 2
    }
    if ($Mode -notin @('standard', 'matrix', 'equation')) {
        Write-Diagnostic 'Mode must be standard, matrix, or equation.'
        exit 2
    }
    if ($Angle -notin @('degree', 'radian')) {
        Write-Diagnostic 'Angle must be degree or radian.'
        exit 2
    }
    if ($Precision -ne 'auto' -and $Precision -ne 'decimal-auto' -and $Precision -notmatch '^(?:[0-9]|1[0-5])$') {
        Write-Diagnostic 'Precision must be auto, decimal-auto, or an integer from 0 through 15.'
        exit 2
    }
    if ($TimeoutSeconds -lt 5 -or $TimeoutSeconds -gt 300) {
        Write-Diagnostic 'TimeoutSeconds must be from 5 through 300.'
        exit 2
    }

    try {
        $resolvedHdc = Resolve-HdcExecutable $HdcPath
    } catch {
        Write-Diagnostic $_.Exception.Message
        exit 10
    }

    $listResult = Invoke-ProcessWithTimeout -FilePath $resolvedHdc -ArgumentList @('list', 'targets') -TimeoutSeconds 10
    if ($listResult.ExitCode -ne 0) {
        Write-Diagnostic "HDC could not list devices (exit $($listResult.ExitCode)): $($listResult.StdErr.Trim())"
        exit 10
    }
    $targets = @($listResult.StdOut -split "`r?`n" | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and $_ -ne '[Empty]' -and -not $_.StartsWith('[') })

    if ($DeviceId) {
        if ($targets -notcontains $DeviceId) {
            Write-Diagnostic "Requested device '$DeviceId' is not connected."
            exit 11
        }
        $selectedDevice = $DeviceId
    } elseif ($targets.Count -eq 0) {
        Write-Diagnostic 'No HarmonyOS device is connected. Device execution was not attempted.'
        exit 11
    } elseif ($targets.Count -gt 1) {
        Write-Diagnostic 'Multiple HarmonyOS devices are connected. Use -DeviceId to select one.'
        exit 12
    } else {
        $selectedDevice = $targets[0]
    }

    $request = New-CalculationRequest -InputLatex $Latex -InputMode $Mode -InputAngle $Angle -InputPrecision $Precision
    $requestJson = $request | ConvertTo-Json -Compress
    $requestPayload = ConvertTo-Base64Url $requestJson
    $arguments = @(
        '-t', $selectedDevice,
        'shell', 'aa', 'test',
        '-b', $BundleName,
        '-m', $TestModuleName,
        '-s', 'unittest', $TestRunner,
        '-s', 'calcxRequest', $requestPayload
    )

    try {
        $testResult = Invoke-ProcessWithTimeout -FilePath $resolvedHdc -ArgumentList $arguments -TimeoutSeconds $TimeoutSeconds
    } catch [TimeoutException] {
        Write-Diagnostic $_.Exception.Message
        exit 14
    }

    $combinedOutput = $testResult.StdOut + "`n" + $testResult.StdErr
    $matches = [regex]::Matches($combinedOutput, [regex]::Escape($ResultPrefix) + '([A-Za-z0-9_-]+)')
    $response = $null
    foreach ($match in $matches) {
        try {
            $candidate = ConvertFrom-Base64Url $match.Groups[1].Value | ConvertFrom-Json
            if ($candidate.protocolVersion -eq $ProtocolVersion -and $candidate.requestId -eq $request.requestId) {
                $response = $candidate
            }
        } catch {
            continue
        }
    }
    if ($null -eq $response) {
        Write-Diagnostic "The test run did not return a valid result marker (HDC exit $($testResult.ExitCode))."
        if ($testResult.StdErr) {
            Write-Diagnostic $testResult.StdErr.Trim()
        }
        exit 13
    }

    [Console]::Out.WriteLine(($response | ConvertTo-Json -Compress -Depth 10))
    if (-not $response.ok) {
        exit 20
    }
    if ($testResult.ExitCode -ne 0) {
        Write-Diagnostic "The calculation succeeded, but aa test exited with code $($testResult.ExitCode)."
        exit 13
    }
    exit 0
} catch {
    Write-Diagnostic $_.Exception.Message
    exit 21
}
