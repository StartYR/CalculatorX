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
  'components\exchange\base\BaseConverter.ets',
  'components\graphing\GraphingKeyboard.ets'
) | ForEach-Object { Join-Path $sourceRoot $_ }

# 普通键盘和图像编辑键盘均应直接订阅开关与 API 保护，但材质构造归公共表面所有。
$renderModules = $keyboardModules + (Join-Path $sourceRoot 'components\graphing\GraphingEditSheet.ets')

$errors = [System.Collections.Generic.List[string]]::new()

$allEtsFiles = Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.ets'
# 检查调用位置与引用范围，避免仅靠某个组件的运行路径漏掉兼容性回归。
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
  # 进制模块通过独立单键组件使用公共表面；渲染入口仍在 BaseConverter 中检查。
  if ($modulePath -eq (Join-Path $sourceRoot 'components\exchange\base\BaseConverter.ets')) {
    $keyPath = Join-Path $sourceRoot 'components\exchange\base\BaseKey.ets'
    if ($moduleText -notmatch "import \{ BaseKey \} from './BaseKey'" -or $moduleText -notmatch 'BaseKey\(\{') {
      $errors.Add("进制键盘未连接单键组件: $modulePath")
    }
    if (-not (Test-Path -LiteralPath $keyPath)) {
      $errors.Add("进制单键组件不存在: $keyPath")
    } elseif ((Get-Content -LiteralPath $keyPath -Raw) -notmatch 'KeyboardKeySurface\(\{') {
      $errors.Add("进制单键未使用公共按键表面: $keyPath")
    }
  } elseif ($moduleText -notmatch 'KeyboardKeySurface') {
    $errors.Add("键盘模块未使用公共按键表面: $modulePath")
  }
}

# 正向 API 26 分支须留在每个渲染入口，低版本才能完整走传统键盘路径。
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

# 整页 Builder 经中转组件传递会破坏沉浸材质的受支持区域。
if (Test-Path -LiteralPath $removedSwitchPath) {
  $errors.Add("不应恢复通过 @BuilderParam 转交完整布局的渲染选择器: $removedSwitchPath")
}

if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Host 'Keyboard architecture checks passed.'
