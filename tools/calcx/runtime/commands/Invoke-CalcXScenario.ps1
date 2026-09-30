[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Path,

    [string]$DeviceId,

    [int]$TimeoutSeconds = 30,

    [string]$HdcPath,

    [switch]$ContinueOnFailure
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'CalcXCli.Common.psm1') -Force

$rootScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'calcx.ps1'
$supportedCommands = @(
    'app.start', 'app.status',
    'screen.get', 'screen.controls', 'screen.find',
    'formula.get', 'formula.set', 'formula.clear', 'settings.get',
    'ui.click', 'ui.back',
    'engine.calculate', 'setup.settings.set',
    'assert', 'wait'
)

# 场景字段缺失时返回显式默认值，避免 PowerShell 的空值传播改变协议类型。
function Get-StepProperty {
    param(
        [Parameter(Mandatory)][psobject]$Step,
        [Parameter(Mandatory)][string]$Name,
        [object]$DefaultValue
    )
    $property = $Step.PSObject.Properties[$Name]
    if ($property -and $null -ne $property.Value) { return $property.Value }
    return $DefaultValue
}

# 只替换 ${name} 变量；未定义变量直接失败，防止断言静默比较错误文本。
function Resolve-ScenarioText {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][hashtable]$Variables
    )
    return [regex]::Replace($Text, '\$\{([A-Za-z_][A-Za-z0-9_]*)\}', {
        param($match)
        $name = $match.Groups[1].Value
        if (-not $Variables.ContainsKey($name)) {
            throw "Scenario variable '$name' is not defined."
        }
        return [string]$Variables[$name]
    })
}

# 每一步隔离在新的 CLI 进程中，收集逐行 JSON 和退出码供后续断言使用。
function Invoke-RootCommand {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $pwshPath = (Get-Process -Id $PID).Path
    $processArguments = @('-NoProfile', '-File', $rootScript) + $Arguments
    if ($DeviceId) { $processArguments += @('-DeviceId', $DeviceId) }
    if ($HdcPath) { $processArguments += @('-HdcPath', $HdcPath) }
    $processArguments += @('-TimeoutSeconds', "$TimeoutSeconds")
    $result = Invoke-CalcXProcessWithTimeout -FilePath $pwshPath -ArgumentList $processArguments `
        -TimeoutSeconds ([Math]::Max($TimeoutSeconds + 5, 10))
    $jsonValues = [Collections.Generic.List[object]]::new()
    foreach ($line in $result.StdOut -split "`r?`n") {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $jsonValues.Add(($line | ConvertFrom-Json)) } catch { }
    }
    return [pscustomobject]@{
        ExitCode = $result.ExitCode
        StdOut = $result.StdOut
        StdErr = $result.StdErr
        Values = @($jsonValues)
        LastValue = if ($jsonValues.Count -gt 0) { $jsonValues[$jsonValues.Count - 1] } else { $null }
    }
}

# 点分路径只遍历 JSON 属性，任何缺失节点统一返回空值。
function Get-ValueAtPath {
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][string]$PropertyPath
    )
    $current = $Value
    foreach ($segment in $PropertyPath.Split('.')) {
        if ($null -eq $current) { return $null }
        $property = $current.PSObject.Properties[$segment]
        if (-not $property) { return $null }
        $current = $property.Value
    }
    return $current
}

function Get-CommandArguments {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][psobject]$Step,
        [Parameter(Mandatory)][hashtable]$Variables
    )
    switch ($Command) {
        'app.start' { return @('app', 'start') }
        'app.status' { return @('app', 'status') }
        'screen.get' { return @('screen', 'get') }
        'screen.controls' { return @('screen', 'controls') }
        'screen.find' {
            $target = Resolve-ScenarioText ([string](Get-StepProperty $Step 'target' '')) $Variables
            return @('screen', 'find', $target)
        }
        'formula.get' { return @('formula', 'get') }
        'formula.set' {
            $latex = Resolve-ScenarioText ([string](Get-StepProperty $Step 'latex' '')) $Variables
            return @('formula', 'set', $latex)
        }
        'formula.clear' { return @('formula', 'clear') }
        'settings.get' { return @('settings', 'get') }
        'ui.click' {
            $target = Resolve-ScenarioText ([string](Get-StepProperty $Step 'target' '')) $Variables
            return @('ui', 'click', $target)
        }
        'ui.back' { return @('ui', 'back') }
        'engine.calculate' {
            $latex = Resolve-ScenarioText ([string](Get-StepProperty $Step 'latex' '')) $Variables
            $arguments = @('engine', 'calculate', $latex)
            foreach ($option in @(@('mode', '-Mode'), @('angle', '-Angle'), @('precision', '-Precision'))) {
                $value = [string](Get-StepProperty $Step $option[0] '')
                if ($value) { $arguments += @($option[1], $value) }
            }
            return $arguments
        }
        'setup.settings.set' {
            $setting = Resolve-ScenarioText ([string](Get-StepProperty $Step 'setting' '')) $Variables
            $value = Resolve-ScenarioText ([string](Get-StepProperty $Step 'value' '')) $Variables
            return @('setup', 'settings', 'set', $setting, $value)
        }
        default { throw "Unsupported executable scenario command: $Command" }
    }
}

# control.exists 使用 find 的退出码；其余断言读取当前 screen.get 快照。
function Test-ScenarioAssertion {
    param(
        [Parameter(Mandatory)][psobject]$Step,
        [Parameter(Mandatory)][hashtable]$Variables
    )
    $path = Resolve-ScenarioText ([string](Get-StepProperty $Step 'path' '')) $Variables
    $expected = Get-StepProperty $Step 'equals' $null
    if (-not $path) { throw 'assert requires path.' }
    if ($path -eq 'control.exists') {
        $target = Resolve-ScenarioText ([string](Get-StepProperty $Step 'target' '')) $Variables
        $result = Invoke-RootCommand @('screen', 'find', $target)
        return [pscustomobject]@{ Passed = $result.ExitCode -eq 0; Expected = $true; Actual = $result.ExitCode -eq 0; Evidence = $result.LastValue }
    }
    $snapshot = Invoke-RootCommand @('screen', 'get')
    if ($snapshot.ExitCode -ne 0 -or $null -eq $snapshot.LastValue) {
        return [pscustomobject]@{ Passed = $false; Expected = $expected; Actual = $null; Evidence = $snapshot.StdErr.Trim() }
    }
    $actual = Get-ValueAtPath -Value $snapshot.LastValue -PropertyPath $path
    return [pscustomobject]@{
        Passed = [string]$actual -ceq [string]$expected
        Expected = $expected
        Actual = $actual
        Evidence = $snapshot.LastValue
    }
}

try {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-CalcXDiagnostic "Scenario file was not found: $Path"
        exit 2
    }
    $document = Get-Content -Raw -LiteralPath (Resolve-Path -LiteralPath $Path) | ConvertFrom-Json
    $version = Get-StepProperty $document 'version' 1
    if ($version -ne 1) {
        Write-CalcXDiagnostic 'Scenario version must be 1.'
        exit 2
    }
    $steps = @(Get-StepProperty $document 'steps' @())
    if ($steps.Count -lt 1 -or $steps.Count -gt 200) {
        Write-CalcXDiagnostic 'Scenario must contain 1 to 200 steps.'
        exit 2
    }
    # 变量属于本次场景运行，不跨文件或步骤重新加载。
    $variables = @{}
    $variablesProperty = $document.PSObject.Properties['variables']
    if ($variablesProperty -and $variablesProperty.Value) {
        foreach ($property in $variablesProperty.Value.PSObject.Properties) {
            $variables[$property.Name] = $property.Value
        }
    }

    $failed = 0
    $completed = 0
    for ($index = 0; $index -lt $steps.Count; $index++) {
        $step = $steps[$index]
        $command = [string](Get-StepProperty $step 'command' '')
        if ($command -notin $supportedCommands) {
            $outcome = [ordered]@{ ok = $false; error = "Unsupported scenario command: $command" }
        } else {
            $stopwatch = [Diagnostics.Stopwatch]::StartNew()
            try {
                if ($command -eq 'assert') {
                    $assertion = Test-ScenarioAssertion -Step $step -Variables $variables
                    $outcome = [ordered]@{
                        ok = $assertion.Passed
                        expected = $assertion.Expected
                        actual = $assertion.Actual
                        evidence = $assertion.Evidence
                    }
                } elseif ($command -eq 'wait') {
                    # wait 重复读取新快照，而非反复检查启动时缓存的状态。
                    $stepTimeout = [int](Get-StepProperty $step 'timeoutSeconds' 10)
                    $deadline = [DateTime]::UtcNow.AddSeconds($stepTimeout)
                    $assertion = $null
                    do {
                        $assertion = Test-ScenarioAssertion -Step $step -Variables $variables
                        if ($assertion.Passed) { break }
                        Start-Sleep -Milliseconds 200
                    } while ([DateTime]::UtcNow -lt $deadline)
                    $outcome = [ordered]@{
                        ok = $assertion.Passed
                        expected = $assertion.Expected
                        actual = $assertion.Actual
                        evidence = $assertion.Evidence
                    }
                } else {
                    $arguments = Get-CommandArguments -Command $command -Step $step -Variables $variables
                    $result = Invoke-RootCommand $arguments
                    $outcome = [ordered]@{
                        ok = $result.ExitCode -eq 0
                        exitCode = $result.ExitCode
                        result = $result.LastValue
                        error = $result.StdErr.Trim()
                    }
                }
            } catch {
                $outcome = [ordered]@{ ok = $false; error = $_.Exception.Message }
            } finally {
                $stopwatch.Stop()
            }
            $outcome['durationMs'] = $stopwatch.ElapsedMilliseconds
        }

        $completed++
        if (-not $outcome.ok) { $failed++ }
        # 每一步输出一行机器可读结果；失败时是否继续由 ContinueOnFailure 决定。
        [Console]::Out.WriteLine(([ordered]@{
            type = 'step'
            index = $index
            command = $command
            outcome = $outcome
        } | ConvertTo-Json -Compress -Depth 14))
        if (-not $outcome.ok -and -not $ContinueOnFailure) { break }
    }

    $summary = [ordered]@{
        type = 'summary'
        protocolVersion = Get-CalcXProtocolVersion
        requestId = New-CalcXRequestId
        ok = $failed -eq 0 -and $completed -eq $steps.Count
        name = [string](Get-StepProperty $document 'name' (Split-Path -Leaf $Path))
        total = $steps.Count
        completed = $completed
        failed = $failed
        stoppedEarly = $completed -lt $steps.Count
    }
    [Console]::Out.WriteLine(($summary | ConvertTo-Json -Compress))
    exit $(if ($summary.ok) { 0 } else { 20 })
} catch {
    Write-CalcXDiagnostic $_.Exception.Message
    exit 21
}
