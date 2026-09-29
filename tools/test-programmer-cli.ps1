[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
$scriptPath = Join-Path $PSScriptRoot 'calcx/runtime/commands/Invoke-CalcXUi.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'CLI script contains syntax errors.' }
# 只加载纯 UI 树解析与白名单函数，不执行设备入口。
foreach ($name in @('Get-SemanticState', 'Assert-SemanticTargetAllowed')) {
  $definition = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
  }, $true)
  . ([scriptblock]::Create($definition.Extent.Text))
}
# 位模式作为 JSON 字符串传输，覆盖 64 位全 1，不能先转换为浮点 number。
$description = @{ data = @{ settings = @{ width = 64 }; bits = 'FFFFFFFFFFFFFFFF' }; integerConfirmed = $true; error = '' } | ConvertTo-Json -Depth 5
$layout = [pscustomobject]@{ Controls = @([pscustomobject]@{ id = 'base.programmer'; description = $description }) }
$state = Get-SemanticState $layout
if ($state.Programmer.data.bits -ne 'FFFFFFFFFFFFFFFF' -or $state.Programmer.data.settings.width -ne 64) {
  throw 'Programmer semantic state was not recovered.'
}
$empty = Get-SemanticState ([pscustomobject]@{ Controls = @() })
if ($null -ne $empty.Programmer) { throw 'Absent programmer mode must report null.' }
foreach ($id in @('base.key.1', 'base.key.equals', 'base.key.exponent', 'base.mode.float', 'base.radix.16', 'base.float.width', 'base.mode.numeric', 'base.numeric.source', 'base.keyboard.show')) {
  Assert-SemanticTargetAllowed $id
}
# 剪贴板和逐位修改等目标不在自动化点击白名单，拒绝范围外或无效字长。
foreach ($id in @('base.paste', 'base.bit.63', 'base.programmer', 'base.float.width.128', 'base.float.width.32', 'base.mode.unknown', 'base.numeric.precision', 'base.keyboard.hide')) {
  $rejected = $false
  try { Assert-SemanticTargetAllowed $id } catch { $rejected = $true }
  if (-not $rejected) { throw "Unexpected clickable target: $id" }
}
# 只静态检查场景内点击目标的权限；通过此检查不代表执行过真机交互。
foreach ($scenarioName in @('programmer-ui-smoke', 'numeric-ui-smoke', 'base-keyboard-panel-smoke')) {
  $scenario = Get-Content -LiteralPath (Join-Path $PSScriptRoot "calcx/tests/scenarios/$scenarioName.json") -Raw | ConvertFrom-Json
  foreach ($step in $scenario.steps) {
    if ($step.command -eq 'ui.click') { Assert-SemanticTargetAllowed $step.target }
  }
}
Write-Host 'Programmer CLI state, whitelist and scenario checks passed (no device actions).'
