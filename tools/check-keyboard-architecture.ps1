[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot 'entry\src\main\ets'
$keyboardRoot = Join-Path $sourceRoot 'components\common\keyboard'

$surfacePath = Join-Path $keyboardRoot 'KeyboardKeySurface.ets'
$switchPath = Join-Path $keyboardRoot 'KeyboardRenderSwitch.ets'
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
  (Join-Path $sourceRoot 'pages\settings\Settings.ets'),
  $switchPath
)
$preferenceReferences = $allEtsFiles | Select-String -SimpleMatch 'KEY_KEY_IMMERSIVE_MATERIAL'
foreach ($match in $preferenceReferences) {
  if ($match.Path -notin $allowedPreferenceReaders) {
    $errors.Add("键盘沉浸开关读取未集中到渲染选择器: $($match.Path):$($match.LineNumber)")
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
  if ($moduleText -notmatch 'PageKeyboardHost|DockedKeyboardHost|KeyboardRenderSwitch') {
    $errors.Add("键盘模块未使用公共渲染入口: $modulePath")
  }
}

foreach ($guardPath in @($surfacePath, $switchPath)) {
  $guardText = Get-Content -LiteralPath $guardPath -Raw
  if ($guardText -notmatch "if \(deviceInfo\.apiAvailable\('26\.0\.0'\)\)") {
    $errors.Add("公共组件缺少直接 API 26 正向保护: $guardPath")
  }
}

if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Host 'Keyboard architecture checks passed.'
