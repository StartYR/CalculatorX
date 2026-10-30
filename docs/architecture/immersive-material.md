# 沉浸光感公共层

沉浸光感按材质策略、组件表面、业务布局分层。公共层集中处理材质参数、显式关闭和低版本外观；业务模块持有布局、焦点、手势和键盘升降。

## 当前入口

| 入口 | 职责 |
| --- | --- |
| `utils/ImmersiveMaterialUtils.ets` | ArkUI 材质工厂、键盘语义材质缓存、HDS 材质参数及启用策略 |
| `components/common/ImmersiveVisualModifiers.ets` | 工具栏按钮、胶囊行、搜索框与 Select 展开菜单的材质及传统外观 |
| `components/common/ImmersiveSegmentedControl.ets` | 受控选项栏、加权布局、滑动高亮、触感与无障碍语义 |
| `components/common/keyboard/KeyboardKeySurface.ets` | 键盘单键的传统与光感表面，详见[键盘双渲染](keyboard-dual-rendering.md) |

TopBar 与进制工具栏使用不同的 Modifier，分别保留原有传统毛玻璃按钮和系统背景胶囊外观。公共层不强行统一不同用途的回退颜色。

## 材质与关闭语义

`createSheetMaterial`、`createDialogMaterial`、`createMenuMaterial`、`createSearchMaterial`、`createTopBarMaterial` 接受可选参数 `globalEnabled`，默认 `true`。`createKeyboardMaterial(role, shiftActive, globalEnabled)` 的第三个参数含义相同，键盘偏好仍由布局入口决定。

| 条件 | ArkUI 工厂返回值 |
| --- | --- |
| API 26.0.0 及以上，允许开启 | 对应用途的 `ImmersiveMaterial` |
| API 26.0.0 及以上，显式关闭 | `uiMaterial.Material.empty` |
| API 23–25 | `undefined`，不访问 API 26 枚举、构造器或空材质 |

`undefined` 表示恢复组件默认材质，不能当作 API 26 的关闭值。键盘工厂在读取缓存前判断关闭状态，避免复用材质绕过开关。关闭不会删除缓存或改写键盘偏好。

HDS 导航栏和底部栏通过 `createNavigationMaterial(globalEnabled)` 创建 `SystemMaterialParams`。HDS 的这组接口从 API 23 可用：开启时保持原来的 `ADAPTIVE`，由系统选择效果；关闭时返回 `MaterialType.NONE`。它与 API 26 的 ArkUI 材质不能混用同一类型或同一低版本判断。

## 调用与布局边界

普通表面通过对应 Modifier 调用：

```ts
.attributeModifier(new ImmersiveToolbarRowModifier(globalEnabled))
.attributeModifier(new ImmersiveToolbarButtonModifier(globalEnabled))
.attributeModifier(new ImmersiveSearchModifier(globalEnabled))
.attributeModifier(new ImmersiveSelectMenuModifier(globalEnabled))
```

以上是各自组件属性链的独立示例，不应全部应用于同一个组件。响应式状态变化时应传入新值构造 Modifier；不要在各页面共享一个可变 Modifier 实例。没有开关状态的固定用途可复用默认实例。

Modifier 在 API 26 关闭材质后恢复传统外观，重新开启前清除传统描边、阴影或模糊，防止两套效果残留叠加。Select 适配器仅控制展开菜单，不改变 Select 本体。

`ImmersiveSegmentedControl` 接收以下参数：

- `options`：标签、稳定且唯一的 `semanticId`、正数 `weight`。
- `selectedIndex`、`onSelect`：调用方持有选中状态及业务动作；重复选择是否产生业务操作仍由调用方决定。
- `controlHeight`：默认 38 vp；内部四周留白为 4 vp。
- `slideDuration`：默认 220 ms；仅作用于高亮胶囊，文字和业务回调不延迟。
- `globalEnabled`：默认 `true`；关闭材质不关闭选中动画或触感。

进制页面继续通过 `BASE_TOOLBAR_HEIGHT` 与 `BASE_SELECTION_SLIDE_DURATION` 传入尺寸和动画时长。模式项权重仍是 1 : 1 : 1.35，符号项权重仍是 1 : 1。

**表面封装不会自动创造材质生效区域。** 普通 Row、Button 与 Search 仍须位于系统支持的标题栏或横向底部 TabBar。进制工具栏、符号控制行和唤起按钮继续由 `BaseConverter` 持有局部 Tabs、阴影留白与层级；复杂键盘的完整容器继续留在业务模块。不通过跨组件 `@BuilderParam` 转交完整页面或键盘布局。

新 API 的构造与属性调用必须置于直接的正向 `deviceInfo.apiAvailable('26.0.0')` 分支。`isImmersiveMaterialEnabled` 与 `isKeyboardMaterialEnabled` 只用于布局/状态选择，不能代替新 API 调用处的静态兼容保护。

## 后续全局设置的接入契约

当前没有新增全局设置、Preferences 键或 AppStorage 键。所有可选 `globalEnabled` 参数默认 `true`，维持现有行为；现有“键盘沉浸光感”偏好默认值不变。

未来增加全局设置时，装配层负责响应式订阅并将值传入公共入口：

1. 普通界面材质与 Modifier 接收全局值；HDS 调用也必须传入，不能只覆盖 ArkUI `systemMaterial`。
2. 键盘路径使用 `isKeyboardMaterialEnabled(keyboardEnabled, globalEnabled)`，其结果是系统支持、全局允许、键盘偏好三者同时满足。布局入口依旧保留直接 API 保护。
3. 关闭全局后隐藏键盘设置项，但不改写键盘偏好；重新打开时恢复原选择。
4. 全局偏好沿用现有 Preferences → AppStorage → 响应式订阅路径，不由材质工厂读写存储，不增加第二套状态机制。
5. 菜单、Sheet、对话框应在打开时使用最新策略。长期持有的 `CustomDialogController` 当前在构造时创建选项，后续接入设置时必须同步处理其生命周期，不能仅修改工厂默认值或缓存一个旧布尔值。已打开浮层的更新/关闭重开策略也须在该功能中明确实现和验收。

因此当前完成的是公共接口与回退能力的准备，尚未提供可在运行时关闭整套应用光感的全局状态接线。后续仍需修改设置、启动与界面装配层；公共视觉组件无需再复制兼容分支。

## 验证

```powershell
node tools/test-immersive-material.mjs
pwsh -NoProfile -File tools/check-keyboard-architecture.ps1
pwsh -NoProfile -File tools/test-programmer-cli.ps1
```

宿主测试使用 SDK 替身覆盖 API 23–26、全局/键盘组合、显式关闭、缓存和 Modifier 样式往返。它不证明真实材质渲染、ArkTS 编译或响应式组件生命周期正确。设备验收仍需覆盖深浅色、低版本、阴影边界、选项切换、触摸与键盘布局。

[返回架构文档](../architecture.md)
