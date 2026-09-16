[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Setting,

    [Parameter(Mandatory, Position = 1)]
    [string]$Value,

    [string]$DeviceId,

    [int]$TimeoutSeconds = 30,

    [string]$HdcPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'CalcXCli.Common.psm1') -Force

$resultPrefix = 'CALCX_TEST_RESULT:'
$allowedSettings = @{
    'angle' = @('degree', 'radian')
    'answer-output' = @('auto', 'decimal')
    'decimal-precision' = @('auto') + @(0..15 | ForEach-Object { "$_" })
    'haptic-feedback' = @('true', 'false')
    'vibration-curve' = @('0', '1', '2', '3')
    'startup-page' = @(0..9 | ForEach-Object { "$_" })
    'color-mode' = @('light', 'dark', 'system')
    'combination-style' = @(0..4 | ForEach-Object { "$_" })
    'permutation-style' = @(0..4 | ForEach-Object { "$_" })
}

try {
    if (-not $allowedSettings.ContainsKey($Setting)) {
        Write-CalcXDiagnostic "Unsupported setting: $Setting"
        exit 2
    }
    if ($allowedSettings[$Setting] -notcontains $Value) {
        Write-CalcXDiagnostic "Unsupported value '$Value' for setting '$Setting'."
        exit 2
    }
    if ($TimeoutSeconds -lt 5 -or $TimeoutSeconds -gt 300) {
        Write-CalcXDiagnostic 'TimeoutSeconds must be from 5 through 300.'
        exit 2
    }
    try {
        $resolvedHdc = Resolve-CalcXHdcExecutable $HdcPath
        $selectedDevice = Get-CalcXDevice -HdcPath $resolvedHdc -DeviceId $DeviceId
    } catch {
        Write-CalcXDiagnostic $_.Exception.Message
        if ($_.Exception.Message -like 'Multiple*') { exit 12 }
        if ($_.Exception.Message -like 'No HarmonyOS*' -or $_.Exception.Message -like 'Requested device*') { exit 11 }
        exit 10
    }

    $request = [ordered]@{
        protocolVersion = Get-CalcXProtocolVersion
        requestId = New-CalcXRequestId
        command = 'settings.set'
        setting = $Setting
        value = $Value
    }
    $payload = ConvertTo-CalcXBase64Url ($request | ConvertTo-Json -Compress)
    $arguments = @(
        '-t', $selectedDevice,
        'shell', 'aa', 'test',
        '-b', (Get-CalcXBundleName),
        '-m', 'entry_test',
        '-s', 'unittest', '/ets/testrunner/OpenHarmonyTestRunner',
        '-s', 'calcxRequest', $payload
    )
    try {
        $testResult = Invoke-CalcXProcessWithTimeout -FilePath $resolvedHdc -ArgumentList $arguments -TimeoutSeconds $TimeoutSeconds
    } catch [TimeoutException] {
        Write-CalcXDiagnostic $_.Exception.Message
        exit 14
    }

    $combinedOutput = $testResult.StdOut + "`n" + $testResult.StdErr
    $response = $null
    foreach ($match in [regex]::Matches($combinedOutput, [regex]::Escape($resultPrefix) + '([A-Za-z0-9_-]+)')) {
        try {
            $candidate = ConvertFrom-CalcXBase64Url $match.Groups[1].Value | ConvertFrom-Json
            if ($candidate.protocolVersion -eq (Get-CalcXProtocolVersion) -and $candidate.requestId -eq $request.requestId) {
                $response = $candidate
            }
        } catch { }
    }
    if ($null -eq $response) {
        Write-CalcXDiagnostic "The test run did not return a valid settings result (HDC exit $($testResult.ExitCode))."
        exit 13
    }
    [Console]::Out.WriteLine(($response | ConvertTo-Json -Compress -Depth 10))
    if (-not $response.ok) { exit 20 }

    $startResult = Invoke-CalcXProcessWithTimeout -FilePath $resolvedHdc `
        -ArgumentList @('-t', $selectedDevice, 'shell', 'aa', 'start', '-a', 'EntryAbility', '-b', (Get-CalcXBundleName)) `
        -TimeoutSeconds $TimeoutSeconds
    if ($startResult.ExitCode -ne 0) {
        Write-CalcXDiagnostic 'The setting was stored, but CalculatorX could not be brought back to the foreground.'
        exit 13
    }
    exit 0
} catch {
    Write-CalcXDiagnostic $_.Exception.Message
    exit 21
}
