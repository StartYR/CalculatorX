# 键盘双渲染架构

CalculatorX 长期保留传统键盘与 API 26 沉浸光感键盘。两条路径共享按键数据和业务行为，并在表面、受支持区域容器和路径选择处明确分层。

## 1. 运行时路径

```text
按键内容、Action、Shift、触感、长按和业务状态
  ├─ KeyboardKeyRole ──► 传统背景映射
  └─ KeyboardKeyRole ──► API 26 沉浸材质映射

各键盘模块的 build() / 键盘挂载 Builder
  ├─ API 26 及以上 + 全局开关开启 ──► 沉浸容器
  └─ API 低于 26 或全局开关关闭 ──► 完整传统容器
```

发布默认值为 `false`。开关只控制计算键盘；TopBar、Sheet、菜单、搜索框和弹窗继续使用各自的材质策略。

## 2. 公共组件职责

公共实现位于 `entry/src/main/ets/components/common/keyboard/`。

| 文件 | 职责 |
| --- | --- |
| `KeyboardKeyTypes.ets` | 定义 `KeyboardKeyRole` 与 `KeyboardKeySpec` |
| `KeyboardVisualPolicy.ets` | 从按键内容解析语义，并把语义映射为传统背景 |
| `KeyboardKeySurface.ets` | 维护传统和沉浸两套 Button 属性链，并直接保护 API 26 调用 |

`ImmersiveMaterialUtils.ets` 负责创建并缓存材质实例。逐键 `systemMaterial(createKeyboardMaterial(...))` 只允许出现在 `KeyboardKeySurface.ets` 中。

## 3. 业务模块保留的职责

业务模块继续管理以下内容：

- Grid 排列、跨行、跨列和动态按键集合；
- Action 到计算命令的映射；
- Shift 状态机、触感、连续删除和长按候选；
- `KeyGestureWrapper`、气泡层级与菜单；
- 公式区、列表、焦点、Sheet 和展开收起动画。
- `KEY_KEY_IMMERSIVE_MATERIAL` 的响应式订阅，以及最外层 API 版本与路径选择。

每个键盘模块持有完整的传统容器与沉浸容器，并在自己的 `build()` 或键盘挂载 Builder 中直接选择路径。不要把包含模块状态或继续调用模块 Builder 的完整布局作为 `@BuilderParam` 传给另一个组件：该模式可以通过 ArkTS 构建，但在真机运行时会丢失 `this` 绑定并触发 `Cannot read property bind of undefined`。

图形主键盘的位移动画在传统路径和沉浸路径中挂载于不同层级，也继续由模块持有。

## 4. 新增双路径键盘

1. 用 `KeyboardKeyRole` 或 `createKeyboardKeySpec()` 声明每个按键的稳定语义。
2. 使用 `KeyboardKeySurface` 渲染 Button，通过 `@BuilderParam` 提供文字、图标或复合内容。
3. 把 Action、触感和复杂手势留在模块中；使用 `KeyGestureWrapper` 的模块应由包装器继续持有手势。
4. 在模块内实现完整传统容器和完整沉浸容器。
5. 在模块渲染入口订阅 `KEY_KEY_IMMERSIVE_MATERIAL`，并通过直接的 `if (deviceInfo.apiAvailable('26.0.0'))` 正向分支选择路径。
6. 模块不得直接导入 `createKeyboardMaterial()`。
7. 将新键盘加入 `tools/check-keyboard-architecture.ps1` 的模块清单。
8. 运行结构检查、语义单元测试和主包 debug 构建，再分别完成 API 26 双开关状态与 API 23 真机验证。

## 5. 停止抽取条件

出现以下任一情况时保留模块专用容器：

- 公共组件需要判断具体模块名；
- 需要超过三个用于表达模块差异的 boolean 参数；
- 需要负边距、屏幕坐标或隐藏 Tab 切换补丁；
- 公共层需要接管业务焦点、返回顺序或位移动画；
- 公共层需要接收或继续转交内容区、键盘区或完整容器的 `@BuilderParam`；
- 单模块问题无法在自身文件和公共表面之间清楚定位。

## 6. 检查命令

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
