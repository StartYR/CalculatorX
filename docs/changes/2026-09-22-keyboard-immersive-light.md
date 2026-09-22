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

每个键盘保留 `Legacy` 与 `Immersive` 两套明确的布局入口。API 26 正向分支先读取全局开关，再选择局部单 Tab 底部栏或完整旧布局；按键数据、业务 Action、触感、Shift 和长按逻辑继续共享。

键盘材质集中在 `ImmersiveMaterialUtils.ets` 中按六类角色缓存。沉浸按钮使用透明背景、零边框、零阴影和 `scale: 1.0`，避免旧表面与系统交互形变叠加。汇率和图形键盘使用与键盘等高的局部容器，保留原有 Stack 覆盖、占位和展开收起动画。图形定义域的 `TextInput.customKeyboard()` 内也使用同类局部容器。

## 兼容性与边界

- `targetSdkVersion` 保持 `26.0.0`，`compatibleSdkVersion` 保持 `6.1.0(23)`；
- `uiMaterial.ImmersiveMaterial` 的构造和使用位于直接的 `deviceInfo.apiAvailable('26.0.0')` 正向分支；
- 发布默认值为 `false`，已有用户不会在升级后被强制切换键盘外观；
- 小窗、横屏、平板、所有模块的 API 23 交叉覆盖和长期性能仍列为发布前回归项。

## 验证

- API 26 真机逐阶段验收了七类键盘的材质效果和业务交互；
- 基础键盘通过 API 23 回退、深浅色、系统光感强度联动和全部按键功能验证；
- 静态审计确认 9 处逐键材质调用均清除了旧背景、边框、阴影和点击缩放，并确认六类材质实例集中缓存；
- `entry@default/debug assembleHap` 最终构建成功；
- 构建仍包含项目既有的弃用、系统能力和第三方原生库告警，没有新增编译错误。

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

## 发布说明素材

新增可选的全局键盘沉浸光感：在 API 26 设备上，基础、矩阵、方程、科学、汇率和图形相关键盘均可显示系统原生逐键材质与触点光效，并保留深浅色语义层级；关闭开关或使用较低系统版本时继续显示经典键盘。

[返回分支变更说明](./README.md)
