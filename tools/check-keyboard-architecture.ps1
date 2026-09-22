[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot 'entry\src\main\ets'
$keyboardRoot = Join-Path $sourceRoot 'components\common\keyboard'

$surfacePath = Join-Path $keyboardRoot 'KeyboardKeySurface.ets'
$removedSwitchPath = Join-Path $keyboardRoot 'KeyboardRenderSwitch.ets'
$materialPath = Join-Path $sourceRoot 'utils\ImmersiveMaterialUtils.ets'

$keyboardModules = @(
  'components\BasicCalc.ets',
  'components\MatrixCalc.ets',
  'components\EquationSolver.ets',
  'components\ScientificCalc.ets',
  'components\exchange\rates\ExchangeKeyboard.ets',
  'components\graphing\GraphingKeyboard.ets'
) | ForEach-Object { Join-Path $sourceRoot $_ }

$renderModules = $keyboardModules + (Join-Path $sourceRoot 'components\graphing\GraphingEditSheet.ets')

$errors = [System.Collections.Generic.List[string]]::new()

$allEtsFiles = Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.ets'
$surfaceCalls = $allEtsFiles | Select-String -SimpleMatch '.systemMaterial(createKeyboardMaterial('
foreach ($match in $surfaceCalls) {
  if ($match.Path -ne $surfacePath) {
    $errors.Add("键盘材质表面调用散落在公共表面之外: $($match.Path):$($match.LineNumber)")
  }
}

$allowedMaterialFiles = @($surfacePath, $materialPath)
foreach ($file in $allEtsFiles) {
  if ($file.FullName -notin $allowedMaterialFiles) {
    $fileText = Get-Content -LiteralPath $file.FullName -Raw
    if ($fileText -match 'createKeyboardMaterial') {
      $errors.Add("业务模块直接引用键盘材质工厂: $($file.FullName)")
    }
  }
}

$allowedPreferenceReaders = @(
  (Join-Path $sourceRoot 'utils\CalculatorConfigs.ets'),
  (Join-Path $sourceRoot 'utils\PreferenceManager.ets'),
  (Join-Path $sourceRoot 'entryability\EntryAbility.ets'),
  (Join-Path $sourceRoot 'pages\settings\Settings.ets')
) + $renderModules
$preferenceReferences = $allEtsFiles | Select-String -SimpleMatch 'KEY_KEY_IMMERSIVE_MATERIAL'
foreach ($match in $preferenceReferences) {
  if ($match.Path -notin $allowedPreferenceReaders) {
    $errors.Add("键盘沉浸开关读取出现在非渲染入口: $($match.Path):$($match.LineNumber)")
  }
}

foreach ($modulePath in $keyboardModules) {
  $moduleText = Get-Content -LiteralPath $modulePath -Raw
  if ($moduleText -notmatch 'KeyboardKeySurface') {
    $errors.Add("键盘模块未使用公共按键表面: $modulePath")
  }
}

foreach ($modulePath in $renderModules) {
  $moduleText = Get-Content -LiteralPath $modulePath -Raw
  if ($moduleText -notmatch '@StorageProp\(PreferenceConfigs\.KEY_KEY_IMMERSIVE_MATERIAL\)') {
    $errors.Add("键盘模块未订阅沉浸开关: $modulePath")
  }
  if ($moduleText -notmatch "if \(deviceInfo\.apiAvailable\('26\.0\.0'\)\)") {
    $errors.Add("键盘模块缺少直接 API 26 正向保护: $modulePath")
  }
}

$surfaceText = Get-Content -LiteralPath $surfacePath -Raw
if ($surfaceText -notmatch "if \(deviceInfo\.apiAvailable\('26\.0\.0'\)\)") {
  $errors.Add("公共按键表面缺少直接 API 26 正向保护: $surfacePath")
}

if (Test-Path -LiteralPath $removedSwitchPath) {
  $errors.Add("不应恢复通过 @BuilderParam 转交完整布局的渲染选择器: $removedSwitchPath")
}

if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Host 'Keyboard architecture checks passed.'
