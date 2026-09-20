[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('set', 'clear')]
    [string]$Command,

    [Parameter(Position = 1)]
    [AllowEmptyString()]
    [string]$Latex = '',

    [string]$DeviceId,

    [int]$TimeoutSeconds = 30,

    [string]$HdcPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'CalcXCli.Common.psm1') -Force

$resultPrefix = 'CALCX_TEST_RESULT:'

try {
    if ($Command -eq 'set' -and [string]::IsNullOrEmpty($Latex)) {
        Write-CalcXDiagnostic 'formula set requires a non-empty LaTeX string.'
        exit 2
    }
    if ($Latex.Length -gt 4096) {
        Write-CalcXDiagnostic 'LaTeX must contain at most 4096 characters.'
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

    $stopResult = Invoke-CalcXProcessWithTimeout -FilePath $resolvedHdc `
        -ArgumentList @('-t', $selectedDevice, 'shell', 'aa', 'force-stop', (Get-CalcXBundleName)) `
        -TimeoutSeconds $TimeoutSeconds
    if ($stopResult.ExitCode -ne 0) {
        Write-CalcXDiagnostic 'CalculatorX could not be stopped before preparing the formula.'
        exit 13
    }

    $requestedLatex = if ($Command -eq 'clear') { '' } else { $Latex }
    $request = [ordered]@{
        protocolVersion = Get-CalcXProtocolVersion
        requestId = New-CalcXRequestId
        command = 'formula.set'
        latex = $requestedLatex
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
        $testResult = Invoke-CalcXProcessWithTimeout -FilePath $resolvedHdc -ArgumentList $arguments `
            -TimeoutSeconds $TimeoutSeconds
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
        Write-CalcXDiagnostic "The test run did not return a valid formula result (HDC exit $($testResult.ExitCode))."
        exit 13
    }
    if (-not $response.ok) {
        [Console]::Out.WriteLine(($response | ConvertTo-Json -Compress -Depth 10))
        exit 20
    }

    $restartStopResult = Invoke-CalcXProcessWithTimeout -FilePath $resolvedHdc `
        -ArgumentList @('-t', $selectedDevice, 'shell', 'aa', 'force-stop', (Get-CalcXBundleName)) `
        -TimeoutSeconds $TimeoutSeconds
    if ($restartStopResult.ExitCode -ne 0) {
        Write-CalcXDiagnostic 'The formula was prepared, but CalculatorX could not be stopped for synchronization.'
        exit 13
    }
    $startResult = Invoke-CalcXProcessWithTimeout -FilePath $resolvedHdc `
        -ArgumentList @('-t', $selectedDevice, 'shell', 'aa', 'start', '-a', 'EntryAbility', '-b', (Get-CalcXBundleName)) `
        -TimeoutSeconds $TimeoutSeconds
    if ($startResult.ExitCode -ne 0) {
        Write-CalcXDiagnostic 'The formula was prepared, but CalculatorX could not be restarted.'
        exit 13
    }

    $formulaState = $null
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $document = Get-CalcXLayoutDocument -HdcPath $resolvedHdc -DeviceId $selectedDevice `
            -TimeoutSeconds $TimeoutSeconds
        $appLayout = Get-CalcXAppLayout -Document $document
        if ($null -ne $appLayout) {
            $formulaControl = @($appLayout.Controls | Where-Object { $_.id -eq 'calc.formula' } | Select-Object -First 1)
            if ($formulaControl.Count -gt 0 -and $formulaControl[0].description) {
                try {
                    $formulaState = $formulaControl[0].description | ConvertFrom-Json
                    if ($formulaState.webReady -and $formulaState.inputLatex -ceq $requestedLatex) { break }
                } catch { }
            }
        }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)

    $matchesRequested = $null -ne $formulaState -and $formulaState.webReady -and `
        $formulaState.inputLatex -ceq $requestedLatex
    [Console]::Out.WriteLine(([ordered]@{
        protocolVersion = Get-CalcXProtocolVersion
        requestId = $request.requestId
        ok = $matchesRequested
        executionPath = 'setup'
        command = if ($Command -eq 'clear') { 'formula.clear' } else { 'formula.set' }
        requestedLatex = $requestedLatex
        value = $formulaState
    } | ConvertTo-Json -Compress -Depth 10))
    if (-not $matchesRequested) { exit 20 }
    exit 0
} catch {
    Write-CalcXDiagnostic $_.Exception.Message
    exit 21
}
