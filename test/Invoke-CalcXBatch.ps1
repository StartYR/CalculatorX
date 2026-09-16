[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path,

    [string]$DeviceId,

    [int]$TimeoutSeconds = 120,

    [string]$HdcPath,

    [switch]$SelfTest
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'CalcXCli.Common.psm1') -Force

$resultPrefix = 'CALCX_TEST_RESULT:'
$summaryPrefix = 'CALCX_TEST_BATCH_SUMMARY:'
$maxItems = 50
$maxPayloadCharacters = 60000

function Get-ItemValue {
    param(
        [Parameter(Mandatory)][psobject]$Item,
        [Parameter(Mandatory)][string]$Name,
        [object]$DefaultValue
    )
    $property = $Item.PSObject.Properties[$Name]
    if ($property -and $null -ne $property.Value) {
        return $property.Value
    }
    return $DefaultValue
}

function Test-BatchItem {
    param([Parameter(Mandatory)][psobject]$Item)

    $latex = [string](Get-ItemValue -Item $Item -Name 'latex' -DefaultValue '')
    $mode = [string](Get-ItemValue -Item $Item -Name 'mode' -DefaultValue 'standard')
    $angle = [string](Get-ItemValue -Item $Item -Name 'angle' -DefaultValue 'radian')
    $precision = [string](Get-ItemValue -Item $Item -Name 'precision' -DefaultValue 'auto')
    if ([string]::IsNullOrWhiteSpace($latex) -or $latex.Length -gt 4096) {
        throw 'Every batch item must contain 1 to 4096 LaTeX characters.'
    }
    if ($mode -notin @('standard', 'matrix', 'equation')) {
        throw "Invalid batch mode: $mode"
    }
    if ($angle -notin @('degree', 'radian')) {
        throw "Invalid batch angle: $angle"
    }
    if ($precision -ne 'auto' -and $precision -ne 'decimal-auto' -and $precision -notmatch '^(?:[0-9]|1[0-5])$') {
        throw "Invalid batch precision: $precision"
    }
    return [ordered]@{
        protocolVersion = Get-CalcXProtocolVersion
        requestId = New-CalcXRequestId
        latex = $latex
        mode = $mode
        angle = $angle
        precision = $precision
    }
}

try {
    if ($SelfTest) {
        $sample = [pscustomobject]@{ latex = '\frac{1}{2}+空格'; mode = 'standard'; angle = 'radian'; precision = 'auto' }
        $item = Test-BatchItem -Item $sample
        $json = $item | ConvertTo-Json -Compress
        $decoded = ConvertFrom-CalcXBase64Url (ConvertTo-CalcXBase64Url $json)
        if ($decoded -cne $json) {
            throw 'Batch UTF-8 JSON URL-safe Base64 round-trip failed.'
        }
        [Console]::Out.WriteLine('{"ok":true,"selfTest":"batch-protocol-round-trip"}')
        exit 0
    }
    if ($TimeoutSeconds -lt 5 -or $TimeoutSeconds -gt 600) {
        Write-CalcXDiagnostic 'TimeoutSeconds must be from 5 through 600.'
        exit 2
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-CalcXDiagnostic "Batch file was not found: $Path"
        exit 2
    }
    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    if ((Get-Item -LiteralPath $resolvedPath).Length -gt 262144) {
        Write-CalcXDiagnostic 'Batch file must not exceed 256 KiB.'
        exit 2
    }

    $document = Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json -NoEnumerate
    if ($document -is [array]) {
        $sourceItems = @($document)
    } else {
        $itemsProperty = $document.PSObject.Properties['items']
        if (-not $itemsProperty) {
            Write-CalcXDiagnostic 'Batch JSON must be an array or an object with an items array.'
            exit 2
        }
        $sourceItems = @($itemsProperty.Value)
    }
    if ($sourceItems.Count -lt 1 -or $sourceItems.Count -gt $maxItems) {
        Write-CalcXDiagnostic "Batch must contain 1 to $maxItems items."
        exit 2
    }

    $items = @($sourceItems | ForEach-Object { Test-BatchItem -Item $_ })
    $request = [ordered]@{
        protocolVersion = Get-CalcXProtocolVersion
        requestId = New-CalcXRequestId
        command = 'batch'
        items = $items
    }
    $requestJson = $request | ConvertTo-Json -Compress -Depth 10
    if ($requestJson.Length -gt $maxPayloadCharacters) {
        Write-CalcXDiagnostic "Encoded batch request is too large; reduce the number or size of expressions."
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

    $payload = ConvertTo-CalcXBase64Url $requestJson
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
    $responsesById = @{}
    foreach ($match in [regex]::Matches($combinedOutput, [regex]::Escape($resultPrefix) + '([A-Za-z0-9_-]+)')) {
        try {
            $candidate = ConvertFrom-CalcXBase64Url $match.Groups[1].Value | ConvertFrom-Json
            if ($candidate.protocolVersion -eq (Get-CalcXProtocolVersion)) {
                $responsesById[$candidate.requestId] = $candidate
            }
        } catch { }
    }

    $summary = $null
    foreach ($match in [regex]::Matches($combinedOutput, [regex]::Escape($summaryPrefix) + '([A-Za-z0-9_-]+)')) {
        try {
            $candidate = ConvertFrom-CalcXBase64Url $match.Groups[1].Value | ConvertFrom-Json
            if ($candidate.protocolVersion -eq (Get-CalcXProtocolVersion) -and $candidate.requestId -eq $request.requestId) {
                $summary = $candidate
            }
        } catch { }
    }

    if ($null -eq $summary) {
        Write-CalcXDiagnostic "The test run did not return a valid batch summary (HDC exit $($testResult.ExitCode))."
        exit 13
    }
    foreach ($item in $items) {
        if (-not $responsesById.ContainsKey($item.requestId)) {
            Write-CalcXDiagnostic "The batch response for request '$($item.requestId)' is missing."
            exit 13
        }
        [Console]::Out.WriteLine(($responsesById[$item.requestId] | ConvertTo-Json -Compress -Depth 10))
    }
    [Console]::Out.WriteLine(($summary | ConvertTo-Json -Compress -Depth 10))
    if (-not $summary.ok) { exit 20 }
    if ($testResult.ExitCode -ne 0) {
        Write-CalcXDiagnostic "The batch completed, but aa test exited with code $($testResult.ExitCode)."
        exit 13
    }
    exit 0
} catch {
    Write-CalcXDiagnostic $_.Exception.Message
    exit 21
}
