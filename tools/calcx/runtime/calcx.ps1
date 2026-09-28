[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(Position = 1, ValueFromRemainingArguments)]
    [string[]]$CommandArguments = @(),

    [string]$Mode = 'standard',

    [string]$Angle = 'radian',

    [string]$Precision = 'auto',

    [string]$DeviceId,

    [int]$TimeoutSeconds = 30,

    [string]$HdcPath,

    [switch]$SelfTest,

    [switch]$ContinueOnFailure
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# 入口只解析命令并转交独立脚本；子进程退出码作为 CLI 的最终结果原样传递。
$commandRoot = Join-Path $PSScriptRoot 'commands'
$calculationScript = Join-Path $commandRoot 'Invoke-CalcXCalculation.ps1'
$batchScript = Join-Path $commandRoot 'Invoke-CalcXBatch.ps1'
$uiScript = Join-Path $commandRoot 'Invoke-CalcXUi.ps1'
$setupScript = Join-Path $commandRoot 'Invoke-CalcXSetup.ps1'
$formulaScript = Join-Path $commandRoot 'Invoke-CalcXFormula.ps1'
$scenarioScript = Join-Path $commandRoot 'Invoke-CalcXScenario.ps1'

function Show-CalcXHelp {
    [Console]::Out.WriteLine(@'
CalculatorX semantic CLI

PowerShell usage from the repository root:
  .\calcx '<latex>'
  .\calcx engine calculate '<latex>'
  .\calcx engine batch <json-file>
  .\calcx app status|start|stop
  .\calcx screen get|controls|find <semantic-id>
  .\calcx formula get|set <latex>|clear
  .\calcx settings get
  .\calcx setup settings set <key> <value>
  .\calcx scenario run <json-file> [-ContinueOnFailure]
  .\calcx ui click <semantic-id>
  .\calcx ui back
  .\calcx -SelfTest

CMD can omit .\, but PowerShell is recommended for LaTeX arguments.

Common options:
  -Mode standard|matrix|equation
  -Angle radian|degree
  -Precision auto|decimal-auto|0..15
  -DeviceId <id>
  -HdcPath <path>
  -TimeoutSeconds <5..300>
'@)
}

function Invoke-CalculationCommand {
    param([Parameter(Mandatory)][string]$Latex)

    $forwardArguments = @{
        Latex = $Latex
        Mode = $Mode
        Angle = $Angle
        Precision = $Precision
        TimeoutSeconds = $TimeoutSeconds
    }
    if ($DeviceId) {
        $forwardArguments.DeviceId = $DeviceId
    }
    if ($HdcPath) {
        $forwardArguments.HdcPath = $HdcPath
    }

    # 仅传递用户实际指定的设备选项，让公共设备选择逻辑处理单设备和多设备环境。
    & $calculationScript @forwardArguments
    return $LASTEXITCODE
}

function Invoke-BatchCommand {
    param([Parameter(Mandatory)][string]$Path)

    $forwardArguments = @{
        Path = $Path
        TimeoutSeconds = $TimeoutSeconds
    }
    if ($DeviceId) {
        $forwardArguments.DeviceId = $DeviceId
    }
    if ($HdcPath) {
        $forwardArguments.HdcPath = $HdcPath
    }

    & $batchScript @forwardArguments
    return $LASTEXITCODE
}

function Invoke-UiCommand {
    param(
        [Parameter(Mandatory)][string]$UiCommand,
        [string]$Target
    )

    $forwardArguments = @{
        Command = $UiCommand
        TimeoutSeconds = $TimeoutSeconds
    }
    if ($Target) {
        $forwardArguments.Target = $Target
    }
    if ($DeviceId) {
        $forwardArguments.DeviceId = $DeviceId
    }
    if ($HdcPath) {
        $forwardArguments.HdcPath = $HdcPath
    }
    & $uiScript @forwardArguments
    return $LASTEXITCODE
}

function Invoke-SetupSettingCommand {
    param(
        [Parameter(Mandatory)][string]$Setting,
        [Parameter(Mandatory)][string]$Value
    )

    $forwardArguments = @{
        Setting = $Setting
        Value = $Value
        TimeoutSeconds = $TimeoutSeconds
    }
    if ($DeviceId) { $forwardArguments.DeviceId = $DeviceId }
    if ($HdcPath) { $forwardArguments.HdcPath = $HdcPath }
    & $setupScript @forwardArguments
    return $LASTEXITCODE
}

function Invoke-FormulaCommand {
    param(
        [Parameter(Mandatory)][string]$FormulaCommand,
        [string]$Latex = ''
    )

    $forwardArguments = @{
        Command = $FormulaCommand
        Latex = $Latex
        TimeoutSeconds = $TimeoutSeconds
    }
    if ($DeviceId) { $forwardArguments.DeviceId = $DeviceId }
    if ($HdcPath) { $forwardArguments.HdcPath = $HdcPath }
    & $formulaScript @forwardArguments
    return $LASTEXITCODE
}

try {
    # 自测只检查纯协议编码，不启动应用或连接设备。
    if ($SelfTest) {
        & $calculationScript -SelfTest
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $batchScript -SelfTest
        exit $LASTEXITCODE
    }

    if ([string]::IsNullOrWhiteSpace($Command) -or $Command -in @('help', '--help', '-h')) {
        Show-CalcXHelp
        exit 0
    }

    if ($Command -eq 'engine') {
        if ($CommandArguments.Count -ne 2 -or $CommandArguments[0] -notin @('calculate', 'batch')) {
            [Console]::Error.WriteLine("Usage: .\calcx engine calculate '<latex>' | .\calcx engine batch <json-file>")
            exit 2
        }
        if ($CommandArguments[0] -eq 'batch') {
            exit (Invoke-BatchCommand -Path $CommandArguments[1])
        }
        exit (Invoke-CalculationCommand -Latex $CommandArguments[1])
    }

    if ($Command -eq 'app') {
        if ($CommandArguments.Count -ne 1 -or $CommandArguments[0] -notin @('status', 'start', 'stop')) {
            [Console]::Error.WriteLine('Usage: .\calcx app status|start|stop')
            exit 2
        }
        exit (Invoke-UiCommand -UiCommand $CommandArguments[0])
    }

    if ($Command -eq 'screen') {
        # 查询与查找使用同一 UI 树入口，find 必须给唯一语义 ID。
        if ($CommandArguments.Count -lt 1 -or $CommandArguments[0] -notin @('get', 'controls', 'find')) {
            [Console]::Error.WriteLine('Usage: .\calcx screen get|controls|find <semantic-id>')
            exit 2
        }
        if ($CommandArguments[0] -eq 'find') {
            if ($CommandArguments.Count -ne 2) {
                [Console]::Error.WriteLine('screen find requires exactly one semantic ID.')
                exit 2
            }
            exit (Invoke-UiCommand -UiCommand 'find' -Target $CommandArguments[1])
        }
        if ($CommandArguments.Count -ne 1) {
            [Console]::Error.WriteLine("screen $($CommandArguments[0]) does not accept a target.")
            exit 2
        }
        $uiCommand = if ($CommandArguments[0] -eq 'get') { 'screen' } else { 'controls' }
        exit (Invoke-UiCommand -UiCommand $uiCommand)
    }

    if ($Command -eq 'ui') {
        # 点击权限由 UI 子脚本的语义白名单再次限制，入口只校验命令形状。
        if ($CommandArguments.Count -eq 1 -and $CommandArguments[0] -eq 'back') {
            exit (Invoke-UiCommand -UiCommand 'back')
        }
        if ($CommandArguments.Count -eq 2 -and $CommandArguments[0] -eq 'click') {
            exit (Invoke-UiCommand -UiCommand 'click' -Target $CommandArguments[1])
        }
        [Console]::Error.WriteLine('Usage: .\calcx ui click <semantic-id> | .\calcx ui back')
        exit 2
    }

    if ($Command -eq 'formula') {
        if ($CommandArguments.Count -eq 1 -and $CommandArguments[0] -eq 'get') {
            exit (Invoke-UiCommand -UiCommand 'formula')
        }
        if ($CommandArguments.Count -eq 1 -and $CommandArguments[0] -eq 'clear') {
            exit (Invoke-FormulaCommand -FormulaCommand 'clear')
        }
        if ($CommandArguments.Count -eq 2 -and $CommandArguments[0] -eq 'set') {
            exit (Invoke-FormulaCommand -FormulaCommand 'set' -Latex $CommandArguments[1])
        }
        [Console]::Error.WriteLine('Usage: .\calcx formula get|set <latex>|clear')
        exit 2
    }

    if ($Command -eq 'settings') {
        if ($CommandArguments.Count -ne 1 -or $CommandArguments[0] -ne 'get') {
            [Console]::Error.WriteLine('Usage: .\calcx settings get')
            exit 2
        }
        exit (Invoke-UiCommand -UiCommand 'settings')
    }

    if ($Command -eq 'setup') {
        if ($CommandArguments.Count -ne 4 -or $CommandArguments[0] -ne 'settings' -or $CommandArguments[1] -ne 'set') {
            [Console]::Error.WriteLine('Usage: .\calcx setup settings set <key> <value>')
            exit 2
        }
        exit (Invoke-SetupSettingCommand -Setting $CommandArguments[2] -Value $CommandArguments[3])
    }

    if ($Command -eq 'scenario') {
        # 场景执行是独立脚本；继续失败策略与进程退出码仍由场景脚本决定。
        if ($CommandArguments.Count -ne 2 -or $CommandArguments[0] -ne 'run') {
            [Console]::Error.WriteLine('Usage: .\calcx scenario run <json-file> [-ContinueOnFailure]')
            exit 2
        }
        $forwardArguments = @{
            Path = $CommandArguments[1]
            TimeoutSeconds = $TimeoutSeconds
            ContinueOnFailure = $ContinueOnFailure
        }
        if ($DeviceId) { $forwardArguments.DeviceId = $DeviceId }
        if ($HdcPath) { $forwardArguments.HdcPath = $HdcPath }
        & $scenarioScript @forwardArguments
        exit $LASTEXITCODE
    }

    # 单个位置参数保留为旧版 LaTeX 快捷入口；带额外参数时不能猜测其含义。
    if ($CommandArguments.Count -gt 0) {
        [Console]::Error.WriteLine("Unknown command: $Command")
        exit 2
    }

    exit (Invoke-CalculationCommand -Latex $Command)
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 21
}
