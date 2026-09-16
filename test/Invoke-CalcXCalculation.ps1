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

Import-Module (Join-Path $PSScriptRoot 'CalcXCli.Common.psm1') -Force

$ProtocolVersion = Get-CalcXProtocolVersion
$BundleName = Get-CalcXBundleName
$TestModuleName = 'entry_test'
$TestRunner = '/ets/testrunner/OpenHarmonyTestRunner'
$ResultPrefix = 'CALCX_TEST_RESULT:'

function New-CalculationRequest {
    param(
        [Parameter(Mandatory)][string]$InputLatex,
        [Parameter(Mandatory)][string]$InputMode,
        [Parameter(Mandatory)][string]$InputAngle,
        [Parameter(Mandatory)][string]$InputPrecision
    )
    return [ordered]@{
        protocolVersion = $ProtocolVersion
        requestId = New-CalcXRequestId
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
        $decoded = ConvertFrom-CalcXBase64Url (ConvertTo-CalcXBase64Url $json)
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
        Write-CalcXDiagnostic 'Latex must contain at least one non-whitespace character.'
        exit 2
    }
    if ($Latex.Length -gt 4096) {
        Write-CalcXDiagnostic 'Latex must not exceed 4096 characters.'
        exit 2
    }
    if ($Mode -notin @('standard', 'matrix', 'equation')) {
        Write-CalcXDiagnostic 'Mode must be standard, matrix, or equation.'
        exit 2
    }
    if ($Angle -notin @('degree', 'radian')) {
        Write-CalcXDiagnostic 'Angle must be degree or radian.'
        exit 2
    }
    if ($Precision -ne 'auto' -and $Precision -ne 'decimal-auto' -and $Precision -notmatch '^(?:[0-9]|1[0-5])$') {
        Write-CalcXDiagnostic 'Precision must be auto, decimal-auto, or an integer from 0 through 15.'
        exit 2
    }
    if ($TimeoutSeconds -lt 5 -or $TimeoutSeconds -gt 300) {
        Write-CalcXDiagnostic 'TimeoutSeconds must be from 5 through 300.'
        exit 2
    }

    try {
        $resolvedHdc = Resolve-CalcXHdcExecutable $HdcPath
    } catch {
        Write-CalcXDiagnostic $_.Exception.Message
        exit 10
    }

    try {
        $selectedDevice = Get-CalcXDevice -HdcPath $resolvedHdc -DeviceId $DeviceId
    } catch {
        Write-CalcXDiagnostic $_.Exception.Message
        if ($_.Exception.Message -like 'Multiple*') { exit 12 }
        if ($_.Exception.Message -like 'No HarmonyOS*' -or $_.Exception.Message -like 'Requested device*') { exit 11 }
        exit 10
    }

    $request = New-CalculationRequest -InputLatex $Latex -InputMode $Mode -InputAngle $Angle -InputPrecision $Precision
    $requestJson = $request | ConvertTo-Json -Compress
    $requestPayload = ConvertTo-CalcXBase64Url $requestJson
    $arguments = @(
        '-t', $selectedDevice,
        'shell', 'aa', 'test',
        '-b', $BundleName,
        '-m', $TestModuleName,
        '-s', 'unittest', $TestRunner,
        '-s', 'calcxRequest', $requestPayload
    )

    try {
        $testResult = Invoke-CalcXProcessWithTimeout -FilePath $resolvedHdc -ArgumentList $arguments -TimeoutSeconds $TimeoutSeconds
    } catch [TimeoutException] {
        Write-CalcXDiagnostic $_.Exception.Message
        exit 14
    }

    $combinedOutput = $testResult.StdOut + "`n" + $testResult.StdErr
    $matches = [regex]::Matches($combinedOutput, [regex]::Escape($ResultPrefix) + '([A-Za-z0-9_-]+)')
    $response = $null
    foreach ($match in $matches) {
        try {
            $candidate = ConvertFrom-CalcXBase64Url $match.Groups[1].Value | ConvertFrom-Json
            if ($candidate.protocolVersion -eq $ProtocolVersion -and $candidate.requestId -eq $request.requestId) {
                $response = $candidate
            }
        } catch {
            continue
        }
    }
    if ($null -eq $response) {
        Write-CalcXDiagnostic "The test run did not return a valid result marker (HDC exit $($testResult.ExitCode))."
        if ($testResult.StdErr) {
            Write-CalcXDiagnostic $testResult.StdErr.Trim()
        }
        exit 13
    }

    [Console]::Out.WriteLine(($response | ConvertTo-Json -Compress -Depth 10))
    if (-not $response.ok) {
        exit 20
    }
    if ($testResult.ExitCode -ne 0) {
        Write-CalcXDiagnostic "The calculation succeeded, but aa test exited with code $($testResult.ExitCode)."
        exit 13
    }
    exit 0
} catch {
    Write-CalcXDiagnostic $_.Exception.Message
    exit 21
}
