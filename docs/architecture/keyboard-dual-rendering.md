# 键盘双渲染架构

CalculatorX 长期保留传统键盘与 API 26 沉浸光感键盘。两条路径共享按键数据和业务行为，并在按键表面、系统支持的容器和模块渲染入口处明确分层。

## 1. 路径选择与全局开关

设置页只在 API 26 及以上显示“键盘沉浸光感”开关。开关保存到 `PreferenceConfigs.KEY_KEY_IMMERSIVE_MATERIAL`，发布默认值为 `false`。各键盘模块通过 `@StorageProp` 订阅该值，因此设置变化会触发当前键盘重新选择路径。

模块渲染入口统一采用直接的正向 API 判断：

```ts
@StorageProp(PreferenceConfigs.KEY_KEY_IMMERSIVE_MATERIAL)
keyImmersiveMaterial: boolean = false;

build() {
  if (deviceInfo.apiAvailable('26.0.0')) {
    if (this.keyImmersiveMaterial) {
      this.ImmersiveLayout()
    } else {
      this.LegacyLayout()
    }
  } else {
    this.LegacyLayout()
  }
}
```

开关只控制计算键盘。TopBar、Sheet、菜单、搜索框和弹窗继续使用各自的材质策略。

### 1.1 传统键盘调用链

```text
模块 build() / 键盘挂载 Builder
  → API 低于 26，或全局开关关闭
  → Legacy...Layout / Legacy...KeyboardBuilder
  → 模块按键内容 Builder(immersive = false)
  → KeyItem
  → KeyboardKeySurface(immersive = false)
  → KeyboardKeySurface.LegacySurface()
```

传统路径保留原有容器、背景、边框、阴影、点击缩放和按下透明度。它不创建或调用键盘沉浸材质；API 23 至 API 25 始终完整走这条路径。

### 1.2 沉浸键盘调用链

```text
模块 build() / 键盘挂载 Builder
  → API 26 及以上，且全局开关开启
  → Immersive...Layout
  → 横向 Tabs + BarPosition.End + 单个 TabContent
  → .tabBar(Immersive...KeyboardBuilder)
  → 模块按键内容 Builder(immersive = true)
  → KeyItem
  → KeyboardKeySurface(immersive = true)
  → API 26 分支
  → .systemMaterial(createKeyboardMaterial(role, shiftActive))
```

`Tabs` 的底部 TabBar 为系统逐键沉浸光感提供受支持区域。沉浸按键使用透明背景、零边框、零阴影、固定 `scale: 1.0` 和不降低的按下透明度，避免传统表面效果与系统交互形变叠加。

## 2. 公共按键表面的调用方式

公共实现位于 `entry/src/main/ets/components/common/keyboard/`。

| 文件 | 职责 |
| --- | --- |
| `KeyboardKeyTypes.ets` | 定义 `KeyboardKeyRole` 与 `KeyboardKeySpec` |
| `KeyboardVisualPolicy.ets` | 从按键内容解析语义，并把语义映射为传统背景 |
| `KeyboardKeySurface.ets` | 维护传统和沉浸两套 Button 属性链，并直接保护 API 26 调用 |

模块的 `KeyItem` 使用同一个 `KeyboardKeySurface`，只通过 `immersive` 选择表面，并通过 `role` 提供稳定语义：

```ts
KeyboardKeySurface({
  immersive: this.immersive,
  role: resolveKeyboardKeyRole(this.btn),
  shiftActive: this.shiftActive,
  onKeyClick: (): void => {
    this.handleClick();
  },
  onKeyTouch: (event: TouchEvent): void => {
    this.handleTouch(event);
  }
}) {
  this.KeyContentBuilder()
}
```

`KeyboardKeyRole` 包含 `CORE`、`FUNCTION`、`OPERATOR`、`DANGER`、`EMPHASIS` 和 `SHIFT`。同一角色同时驱动传统背景与沉浸材质，保证两条路径的主色、副色、危险色、强调色和 Shift 状态含义一致。

`ImmersiveMaterialUtils.ets` 负责按语义创建并缓存材质实例。`FUNCTION` 与 `OPERATOR` 共用副色材质，Shift 的未激活与激活状态分别缓存。逐键 `systemMaterial(createKeyboardMaterial(...))` 只允许出现在 `KeyboardKeySurface.ets` 中，业务模块不得直接创建键盘材质。

## 3. 三类模块容器

两条调用链的入口相同，但完整容器由模块按布局类型持有：

| 类型 | 模块 | 传统路径 | 沉浸路径 |
| --- | --- | --- | --- |
| 页面型 | 基础、矩阵、方程、科学、程序员 | `Column` 同时排列显示区和传统键盘 | 单个横向 `Tabs`：内容区放在 `TabContent`，沉浸键盘放在底部 TabBar |
| 悬浮型 | 汇率、图形定义域 | 直接挂载与键盘等高的传统 Builder | 与键盘等高的局部单 Tab `Tabs`，不接管页面其余区域 |
| 图形主键盘 | `GraphingEditSheet` | `LegacyGraphingKeyboardBuilder()` | `ImmersiveGraphingKeyboardLayout()`，在 `GraphingKeyboardDockBuilder()` 内选择 |

图形主键盘的展开收起位移动画属于 `GraphingEditSheet`，因此传统与沉浸容器都在该模块中完成选择和动画挂载。图形定义域键盘继续由 `TextInput.customKeyboard()` 使用自己的完整容器。

## 4. 业务模块与公共层的边界

业务模块继续管理以下内容：

- Grid 排列、跨行、跨列和动态按键集合；
- Action 到计算命令的映射；
- Shift 状态机、触感、连续删除和长按候选；
- `KeyGestureWrapper`、气泡层级与菜单；
- 公式区、列表、焦点、Sheet 和展开收起动画；
- `KEY_KEY_IMMERSIVE_MATERIAL` 的响应式订阅，以及最外层 API 版本与路径选择。

每个键盘模块必须持有完整的传统容器与沉浸容器，并在自己的 `build()` 或键盘挂载 Builder 中直接选择路径。完整布局不得作为 `@BuilderParam` 传给另一个组件，也不得恢复已删除的 `KeyboardRenderSwitch`、`PageKeyboardHost` 或 `DockedKeyboardHost`。

跨组件转交包含模块状态或继续调用模块 Builder 的完整布局，可以通过 ArkTS 构建，但在真机运行时可能丢失 `this` 绑定并触发 `Cannot read property bind of undefined`。公共层只复用稳定的数据、语义策略和单个按键表面。

## 5. 新增双路径键盘

1. 用 `KeyboardKeyRole` 或 `createKeyboardKeySpec()` 声明每个按键的稳定语义。
2. 使用 `KeyboardKeySurface` 渲染 Button，通过 `@BuilderParam` 仅提供单个按键的文字、图标或复合内容。
3. 把 Action、触感和复杂手势留在模块中；使用 `KeyGestureWrapper` 的模块应由包装器继续持有手势。
4. 先实现共享的按键内容 Builder，并用 `immersive: boolean` 把当前路径传到 `KeyItem`。
5. 在模块内实现完整传统容器和完整沉浸容器；沉浸容器使用横向、不可滚动、无切换动画的单 Tab `Tabs`。
6. 在模块渲染入口订阅 `KEY_KEY_IMMERSIVE_MATERIAL`，并通过直接的 `if (deviceInfo.apiAvailable('26.0.0'))` 正向分支选择路径。
7. 模块不得直接导入 `createKeyboardMaterial()`。
8. 将新键盘加入 `tools/check-keyboard-architecture.ps1` 的模块清单。
9. 运行结构检查、语义单元测试和主包 debug 构建，再分别完成 API 26 双开关状态与 API 23 真机验证。

## 6. 停止抽取条件

出现以下任一情况时保留模块专用容器：

- 公共组件需要判断具体模块名；
- 需要超过三个用于表达模块差异的 boolean 参数；
- 需要负边距、屏幕坐标或隐藏 Tab 切换补丁；
- 公共层需要接管业务焦点、返回顺序或位移动画；
- 公共层需要接收或继续转交内容区、键盘区或完整容器的 `@BuilderParam`；
- 单模块问题无法在自身文件和公共表面之间清楚定位。

## 7. 检查命令

```powershell
pwsh -NoProfile -File .\tools\check-keyboard-architecture.ps1

$devEcoHome = '<DevEco Studio 安装目录>'
$env:DEVECO_SDK_HOME = Join-Path $devEcoHome 'sdk'
& (Join-Path $devEcoHome 'tools\hvigor\bin\hvigorw.bat') `
  --mode module `
  -p product=default `
  -p module=entry@default `
  -p buildMode=debug `
  test `
  --no-daemon
```

主包结构或 API 发生变化时，另运行 `entry@default/debug assembleHap`。构建和单元测试不能代替真机上的材质、焦点、手势与低版本回退验证。

[返回架构文档](../architecture.md)
