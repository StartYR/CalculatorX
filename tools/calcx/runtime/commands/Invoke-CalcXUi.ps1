[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('status', 'start', 'stop', 'screen', 'controls', 'formula', 'settings', 'find', 'click', 'back')]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$Target,

    [string]$DeviceId,

    [int]$TimeoutSeconds = 15,

    [string]$HdcPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'CalcXCli.Common.psm1') -Force

function Write-JsonResult {
    param([Parameter(Mandatory)][object]$Value)
    [Console]::Out.WriteLine(($Value | ConvertTo-Json -Compress -Depth 12))
}

function Get-CurrentAppLayout {
    $document = Get-CalcXLayoutDocument -HdcPath $resolvedHdc -DeviceId $selectedDevice -TimeoutSeconds $TimeoutSeconds
    return Get-CalcXAppLayout -Document $document
}

function Get-ScreenSummary {
    param([object]$AppLayout)

    if ($null -eq $AppLayout) {
        return [ordered]@{
            running = $false
            foreground = $false
            ability = $null
            route = $null
            module = $null
            overlays = @()
        }
    }
    $ids = @($AppLayout.Controls | ForEach-Object { $_.id } | Where-Object { $_ })
    $moduleControl = @($AppLayout.Controls | Where-Object { $_.id -match '^module\.([a-z-]+)\.page$' } | Select-Object -First 1)
    $module = if ($moduleControl.Count -gt 0) {
        [regex]::Match($moduleControl[0].id, '^module\.([a-z-]+)\.page$').Groups[1].Value
    } else {
        $indexRoot = @($AppLayout.Controls | Where-Object { $_.id -eq 'app.page.index' } | Select-Object -First 1)
        if ($indexRoot.Count -gt 0) {
            try { ($indexRoot[0].description | ConvertFrom-Json).module } catch { $null }
        } else { $null }
    }
    $route = if ($ids -contains 'app.page.settings') { 'settings' }
        elseif ($ids -contains 'app.page.history') { 'history' }
        elseif ($ids -contains 'app.page.index') { 'index' }
        else { $AppLayout.PagePath }
    return [ordered]@{
        running = $true
        foreground = $AppLayout.Foreground
        ability = $AppLayout.Ability
        route = $route
        module = $module
        overlays = @($ids | Where-Object { $_ -like 'overlay.*' })
    }
}

function Get-SemanticState {
    param([object]$AppLayout)

    $formula = [ordered]@{
        inputLatex = $null
        resultLatex = $null
        editorState = 'UNAVAILABLE'
        webReady = $false
        source = 'ui-tree'
    }
    $formulaControl = @($AppLayout.Controls | Where-Object { $_.id -eq 'calc.formula' } | Select-Object -First 1)
    if ($formulaControl.Count -gt 0 -and $formulaControl[0].description) {
        try {
            $formulaState = $formulaControl[0].description | ConvertFrom-Json
            $formula.inputLatex = $formulaState.inputLatex
            $formula.resultLatex = $formulaState.resultLatex
            $formula.editorState = $formulaState.editorState
            $formula.webReady = [bool]$formulaState.webReady
        } catch { }
    }

    $settings = [ordered]@{ source = 'ui-tree' }
    $indexRoot = @($AppLayout.Controls | Where-Object { $_.id -eq 'app.page.index' } | Select-Object -First 1)
    if ($indexRoot.Count -gt 0 -and $indexRoot[0].description) {
        try {
            $rootState = $indexRoot[0].description | ConvertFrom-Json
            foreach ($property in $rootState.settings.PSObject.Properties) {
                $settings[$property.Name] = $property.Value
            }
        } catch { }
    }
    $programmer = $null
    $programmerRoot = @($AppLayout.Controls | Where-Object { $_.id -eq 'base.programmer' } | Select-Object -First 1)
    if ($programmerRoot.Count -gt 0 -and $programmerRoot[0].description) {
        try { $programmer = $programmerRoot[0].description | ConvertFrom-Json } catch { }
    }
    return [pscustomobject]@{
        Formula = [pscustomobject]$formula
        Settings = [pscustomobject]$settings
        Programmer = $programmer
    }
}

function Assert-SemanticTargetAllowed {
    param([Parameter(Mandatory)][string]$SemanticId)
    $allowed = $SemanticId -match '^(?:nav\.|module\.|calc\.key\.|settings\.|overlay\.sidebar\.dismiss$)'
    $allowed = $allowed -or $SemanticId -match '^base\.(?:key\.[a-z0-9-]+|mode\.(?:integer|float)|radix\.(?:2|8|10|16)|float\.width\.(?:16|32|64)|signed|carry|bits|encoding|help)$'
    if (-not $allowed) {
        throw "Target is outside the semantic click whitelist: $SemanticId"
    }
}

try {
    if ($TimeoutSeconds -lt 5 -or $TimeoutSeconds -gt 120) {
        Write-CalcXDiagnostic 'TimeoutSeconds must be from 5 through 120.'
        exit 2
    }
    if ($Command -in @('find', 'click') -and [string]::IsNullOrWhiteSpace($Target)) {
        Write-CalcXDiagnostic "$Command requires a semantic ID target."
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

    if ($Command -eq 'start') {
        $result = Invoke-CalcXProcessWithTimeout -FilePath $resolvedHdc `
            -ArgumentList @('-t', $selectedDevice, 'shell', 'aa', 'start', '-a', 'EntryAbility', '-b', (Get-CalcXBundleName)) `
            -TimeoutSeconds $TimeoutSeconds
        if ($result.ExitCode -ne 0) {
            Write-CalcXDiagnostic "Unable to start CalculatorX (exit $($result.ExitCode)): $($result.StdErr.Trim())"
            exit 13
        }
        $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
        do {
            $appLayout = Get-CurrentAppLayout
            if ($null -ne $appLayout -and $appLayout.Foreground) { break }
            Start-Sleep -Milliseconds 150
        } while ([DateTime]::UtcNow -lt $deadline)
        if ($null -eq $appLayout) {
            Write-CalcXDiagnostic 'CalculatorX did not appear in the UI tree before timeout.'
            exit 14
        }
        Write-JsonResult ([ordered]@{
            protocolVersion = Get-CalcXProtocolVersion
            requestId = New-CalcXRequestId
            ok = $true
            executionPath = 'ui'
            command = 'app.start'
            screen = Get-ScreenSummary $appLayout
        })
        exit 0
    }

    if ($Command -eq 'stop') {
        $result = Invoke-CalcXProcessWithTimeout -FilePath $resolvedHdc `
            -ArgumentList @('-t', $selectedDevice, 'shell', 'aa', 'force-stop', (Get-CalcXBundleName)) `
            -TimeoutSeconds $TimeoutSeconds
        Write-JsonResult ([ordered]@{
            protocolVersion = Get-CalcXProtocolVersion
            requestId = New-CalcXRequestId
            ok = $result.ExitCode -eq 0
            executionPath = 'ui'
            command = 'app.stop'
        })
        exit $(if ($result.ExitCode -eq 0) { 0 } else { 13 })
    }

    $appLayout = Get-CurrentAppLayout
    if ($Command -eq 'status') {
        Write-JsonResult ([ordered]@{
            protocolVersion = Get-CalcXProtocolVersion
            requestId = New-CalcXRequestId
            ok = $true
            executionPath = 'ui-tree'
            command = 'app.status'
            screen = Get-ScreenSummary $appLayout
        })
        exit 0
    }
    if ($null -eq $appLayout) {
        Write-CalcXDiagnostic 'CalculatorX is not present in the current UI tree. Run app start first.'
        exit 13
    }

    if ($Command -eq 'screen') {
        $semanticControls = @($appLayout.Controls | Where-Object { $_.id })
        $semanticState = Get-SemanticState $appLayout
        Write-JsonResult ([ordered]@{
            protocolVersion = Get-CalcXProtocolVersion
            requestId = New-CalcXRequestId
            ok = $true
            executionPath = 'ui-tree'
            command = 'screen.get'
            screen = Get-ScreenSummary $appLayout
            formula = $semanticState.Formula
            settings = $semanticState.Settings
            programmer = $semanticState.Programmer
            controlCount = $semanticControls.Count
        })
        exit 0
    }


    if ($Command -in @('formula', 'settings')) {
        $semanticState = Get-SemanticState $appLayout
        Write-JsonResult ([ordered]@{
            protocolVersion = Get-CalcXProtocolVersion
            requestId = New-CalcXRequestId
            ok = $true
            executionPath = 'ui-tree'
            command = if ($Command -eq 'formula') { 'formula.get' } else { 'settings.get' }
            value = if ($Command -eq 'formula') { $semanticState.Formula } else { $semanticState.Settings }
        })
        exit 0
    }

    if ($Command -eq 'controls') {
        Write-JsonResult ([ordered]@{
            protocolVersion = Get-CalcXProtocolVersion
            requestId = New-CalcXRequestId
            ok = $true
            executionPath = 'ui-tree'
            command = 'screen.controls'
            controls = @($appLayout.Controls | Where-Object { $_.id })
        })
        exit 0
    }

    if ($Command -eq 'back') {
        $before = Get-ScreenSummary $appLayout
        $result = Invoke-CalcXProcessWithTimeout -FilePath $resolvedHdc `
            -ArgumentList @('-t', $selectedDevice, 'shell', 'uitest', 'uiInput', 'keyEvent', 'Back') `
            -TimeoutSeconds $TimeoutSeconds
        if ($result.ExitCode -ne 0) {
            Write-CalcXDiagnostic "Back input failed (exit $($result.ExitCode)): $($result.StdErr.Trim())"
            exit 13
        }
        Start-Sleep -Milliseconds 150
        $afterLayout = Get-CurrentAppLayout
        Write-JsonResult ([ordered]@{
            protocolVersion = Get-CalcXProtocolVersion
            requestId = New-CalcXRequestId
            ok = $true
            executionPath = 'ui'
            command = 'ui.back'
            before = $before
            after = Get-ScreenSummary $afterLayout
        })
        exit 0
    }

    $matches = @($appLayout.Controls | Where-Object { $_.id -ceq $Target })
    if ($matches.Count -ne 1) {
        Write-CalcXDiagnostic "Expected one visible semantic target '$Target', found $($matches.Count)."
        exit 15
    }
    $control = $matches[0]
    if ($Command -eq 'find') {
        Write-JsonResult ([ordered]@{
            protocolVersion = Get-CalcXProtocolVersion
            requestId = New-CalcXRequestId
            ok = $true
            executionPath = 'ui-tree'
            command = 'screen.find'
            control = $control
        })
        exit 0
    }

    Assert-SemanticTargetAllowed $Target
    if (-not $control.visible -or -not $control.enabled) {
        Write-CalcXDiagnostic "Semantic target '$Target' is not visible and enabled."
        exit 16
    }
    if (-not $control.clickable -and $Target -notmatch '^(?:calc\.key\.|module\.)') {
        Write-CalcXDiagnostic "Semantic target '$Target' is not reported as clickable."
        exit 16
    }
    $center = Get-CalcXBoundsCenter -Bounds $control.bounds
    $before = Get-ScreenSummary $appLayout
    $result = Invoke-CalcXProcessWithTimeout -FilePath $resolvedHdc `
        -ArgumentList @('-t', $selectedDevice, 'shell', 'uitest', 'uiInput', 'click', "$($center.X)", "$($center.Y)") `
        -TimeoutSeconds $TimeoutSeconds
    if ($result.ExitCode -ne 0) {
        Write-CalcXDiagnostic "Semantic click failed (exit $($result.ExitCode)): $($result.StdErr.Trim())"
        exit 13
    }
    Start-Sleep -Milliseconds 150
    $afterLayout = Get-CurrentAppLayout
    Write-JsonResult ([ordered]@{
        protocolVersion = Get-CalcXProtocolVersion
        requestId = New-CalcXRequestId
        ok = $true
        executionPath = 'ui'
        command = 'ui.click'
        target = $Target
        before = $before
        after = Get-ScreenSummary $afterLayout
    })
    exit 0
} catch [TimeoutException] {
    Write-CalcXDiagnostic $_.Exception.Message
    exit 14
} catch {
    Write-CalcXDiagnostic $_.Exception.Message
    exit 21
}
