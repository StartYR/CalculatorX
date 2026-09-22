# 全局计算键盘沉浸光感

- 状态：已完成
- 类型：功能 / 重构
- 分支：`feature/api-26-sensation`
- 完成日期：2026-09-22

## 变更摘要

CalculatorX 的全部计算键盘现在可以在 API 26 设备上使用系统原生逐键沉浸光感。设置页新增“键盘沉浸光感”开关，默认关闭；开启后使用独立沉浸键盘，关闭后恢复完整经典键盘。

## 用户可见行为

- 基础、矩阵、方程、科学、汇率、图形主键盘和图形定义域键盘均受同一开关控制；
- 沉浸按键保留数字、函数、运算、危险、强调以及 Shift 状态的视觉层级；
- 深色和浅色模式分别使用适配后的材质赋色，系统降低沉浸光感强度时按键效果会同步降低；
- 开关关闭时使用原有背景、边框、阴影和点击缩放，TopBar、Sheet、菜单和弹窗等现有材质不受该开关影响；
- API 低于 26 时不显示设置项，并始终进入经典键盘路径。

## 设计与实现

键盘使用统一的语义与按键表面基础设施。`KeyboardKeyRole` 同时驱动传统背景与沉浸材质，`KeyboardKeySurface` 集中维护两套 Button 属性链。按键数据、业务 Action、触感、Shift、长按逻辑和最外层路径选择继续由模块持有。

两套调用方式如下：

- 传统路径：模块入口在 API 低于 26 或开关关闭时调用完整传统容器，按键内容以 `immersive = false` 进入 `KeyboardKeySurface.LegacySurface()`；
- 沉浸路径：模块入口在 API 26 及以上且开关开启时调用完整沉浸容器，键盘通过单 Tab 的底部 TabBar 建立系统支持区域，按键内容以 `immersive = true` 进入 `systemMaterial(createKeyboardMaterial(...))`。

七类键盘均在模块内持有完整的传统与沉浸容器，并在模块内直接读取全局开关和选择路径。公共 Host 与公共渲染选择器虽能通过 ArkTS 构建，但传入的完整布局在真机运行时会丢失 Builder 的 `this` 绑定，因此已经移除。长期复用只覆盖按键类型、语义策略、按键表面和材质缓存；模块继续持有版本判断、设置订阅、完整容器、公式区、焦点与动画，便于新增键盘和独立定位问题。详细调用链、模块模板和新增键盘清单见[键盘双渲染架构](../architecture/keyboard-dual-rendering.md)。

键盘材质集中在 `ImmersiveMaterialUtils.ets` 中按语义缓存。沉浸按钮使用透明背景、零边框、零阴影和 `scale: 1.0`，避免旧表面与系统交互形变叠加。汇率和图形键盘使用与键盘等高的局部容器，保留原有 Stack 覆盖、占位和展开收起动画。图形定义域的 `TextInput.customKeyboard()` 内也使用同类局部容器。

## 兼容性与边界

- `targetSdkVersion` 保持 `26.0.0`，`compatibleSdkVersion` 保持 `6.1.0(23)`；
- `uiMaterial.ImmersiveMaterial` 的构造和使用位于直接的 `deviceInfo.apiAvailable('26.0.0')` 正向分支；
- 逐键材质调用只存在于公共按键表面，全局键盘开关由七个模块渲染入口和设置基础设施读取；
- 发布默认值为 `false`，已有用户不会在升级后被强制切换键盘外观；
- 小窗、横屏、平板、所有模块的 API 23 交叉覆盖和长期性能仍列为发布前回归项。

## 验证

- API 26 真机逐阶段验收了七类键盘的材质效果和业务交互；
- 基础键盘通过 API 23 回退、深浅色、系统光感强度联动和全部按键功能验证；
- 静态审计确认逐键材质调用只存在于 `KeyboardKeySurface.ets`，沉浸表面已清除旧背景、边框、阴影和点击缩放，并确认六类材质实例集中缓存；
- `entry@default/debug assembleHap` 最终构建成功；
- debug HAP 在连接设备上覆盖安装成功；
- 公共语义映射单元测试通过，键盘架构只读检查通过；
- 构建仍包含项目既有的弃用、系统能力和第三方原生库告警，没有新增编译错误。

公共 Host 和公共渲染选择器版本都曾在 API 26 真机冷启动科学计算时因 `@BuilderParam` 丢失绑定而崩溃。完全移除跨组件布局 Builder 转交后，科学计算冷启动以及函数图像切换科学计算均已在连接设备上通过；运行日志未出现新的 `TypeError`、`RuntimeError` 或 `bind of undefined`。最后一次观察到的应用进程退出由用户手动关闭应用触发，不属于崩溃。API 23 全模块交叉覆盖、小窗、横屏、平板、长期性能，以及其余模块在最终架构版本下的完整交互回归仍需发布前验证。

## 主要文件

- `entry/src/main/ets/utils/ImmersiveMaterialUtils.ets`
- `entry/src/main/ets/utils/CalculatorConfigs.ets`
- `entry/src/main/ets/utils/PreferenceManager.ets`
- `entry/src/main/ets/pages/settings/Settings.ets`
- `entry/src/main/ets/components/BasicCalc.ets`
- `entry/src/main/ets/components/MatrixCalc.ets`
- `entry/src/main/ets/components/EquationSolver.ets`
- `entry/src/main/ets/components/ScientificCalc.ets`
- `entry/src/main/ets/components/exchange/rates/ExchangeKeyboard.ets`
- `entry/src/main/ets/components/graphing/GraphingEditSheet.ets`
- `entry/src/main/ets/components/graphing/GraphingKeyboard.ets`
- `entry/src/main/ets/components/common/keyboard/`
- `tools/check-keyboard-architecture.ps1`
- `docs/architecture/keyboard-dual-rendering.md`

## 发布说明素材

新增可选的全局键盘沉浸光感：在 API 26 设备上，基础、矩阵、方程、科学、汇率和图形相关键盘均可显示系统原生逐键材质与触点光效，并保留深浅色语义层级；关闭开关或使用较低系统版本时继续显示经典键盘。

[返回分支变更说明](./README.md)
