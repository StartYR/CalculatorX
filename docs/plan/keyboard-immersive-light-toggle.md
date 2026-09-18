# 计算按键沉浸光感开关实施计划

- 状态：待实施
- 编写日期：2026-09-19
- 适用分支：`feature/api-update-26`
- 目标 API：`26.0.0`
- 最低兼容 API：`6.1.0(23)`，保持不变
- 默认策略：开关默认关闭，关闭时保持当前按键外观

## 1. 目标

在设置页增加“按键沉浸光感”开关，让用户自行决定是否为计算键盘按键启用 API 26 的交互式沉浸光感。

- 关闭：计算键盘继续使用现有背景色、边框、阴影和按压反馈；TopBar、Sheet、菜单等已经单独接入的材质不受影响。
- 开启：受支持的计算键盘按键使用沉浸式系统材质、交互形变和点光源反馈。
- API 23 至 API 25：不调用 API 26 材质接口，按键继续使用现有视觉效果。
- 设置变更应立即重绘按键，不要求重新启动应用。

本计划中的“按键”特指计算器各模块的屏幕键盘按键，不包含设置项、历史记录操作、弹窗操作、TopBar、侧边栏或其他普通 `Button`。这样既能让设置名称与用户可感知范围一致，也能避免无边界增加 GPU 负载。

## 2. 当前实现与约束

### 2.1 设置与持久化基础

项目已有可复用的设置链路：

- `entry/src/main/ets/utils/CalculatorConfigs.ets`：集中定义首选项键；
- `entry/src/main/ets/utils/PreferenceManager.ets`：从首选项加载数据并写入 `AppStorage`；
- `entry/src/main/ets/entryability/EntryAbility.ets`：启动阶段读取并注入常用设置；
- `entry/src/main/ets/pages/settings/Settings.ets`：已有“触感反馈”等布尔开关，可沿用其即时更新和持久化模式。

计划使用以下命名：

- 首选项常量：`KEY_KEYBOARD_IMMERSIVE_LIGHT`；
- `AppStorage` 键：`keyboardImmersiveLight`；
- 默认值：`false`；
- 设置页语义 ID：`settings.keyboard-immersive-light`。

最终命名以实现阶段的类型检查结果为准，但不得在不同文件中混用多个字符串字面量。

### 2.2 材质基础

`entry/src/main/ets/utils/ImmersiveMaterialUtils.ets` 已集中创建 Sheet、弹窗、菜单、搜索框和 TopBar 材质。计算按键应新增专用工厂或 Modifier，不复用名称和职责均不相符的 TopBar 材质。

候选按键材质参数：

```text
style: ULTRA_THIN
interactive: true
lightEffect: {}
```

`colorInvert` 和 `materialColor` 不在第一步直接固定。当前按键颜色承担删除、Shift、等号、运算符和普通数字等语义，需要先在真机上确认材质是否会削弱这些区分，再决定使用自动反色、保留现有文字颜色，或建立少量带色材质变体。

### 2.3 当前按键接入点

当前需要评估的计算键盘共有 6 个文件、9 个按键组件：

| 模块 | 文件 | 按键组件 |
| --- | --- | --- |
| 基础计算 | `entry/src/main/ets/components/BasicCalc.ets` | `BasicKeyItem` |
| 科学计算 | `entry/src/main/ets/components/ScientificCalc.ets` | `TopKeyItem`、`BottomKeyItem` |
| 方程求解 | `entry/src/main/ets/components/EquationSolver.ets` | `TopKeyItem`、`BottomKeyItem` |
| 矩阵与向量 | `entry/src/main/ets/components/MatrixCalc.ets` | `MatrixKeyItem` |
| 汇率 | `entry/src/main/ets/components/exchange/rates/ExchangeKeyboard.ets` | `BottomKeyItem` |
| 函数图像 | `entry/src/main/ets/components/graphing/GraphingKeyboard.ets` | `TopKeyItem`、`BottomKeyItem` |

`KeyGestureWrapper.ets` 只负责长按、连续触发、菜单和滑动气泡，不统一管理所有按钮背景，因此不能只修改该文件。

### 2.4 API 26 与应用默认材质

当前 `entry/src/main/module.json5` 将 `ohos.arkui.UIMaterial.state` 设为 `default`。官方文档区分以下两种含义：

- `undefined`：恢复组件默认的沉浸光感行为；
- `uiMaterial.Material.empty`：明确关闭该组件的沉浸光感。

因此，为保证“关闭开关就是当前外观”，API 26 路径不能仅向按键传入 `undefined`，而应显式使用 `Material.empty`。API 23 至 API 25 则不能引用或调用 API 26 材质能力。

所有 API 26 构造、`Material.empty` 和 `systemMaterial` 调用都必须放在直接、正向的版本保护中：

```text
if (deviceInfo.apiAvailable('26.0.0')) {
  // 在此分支内调用 API 26 材质接口
}
```

不得依赖布尔辅助函数或否定提前返回来保护新 API 表达式，以免重新触发 ArkTS 最低版本兼容告警。

## 3. 设计原则

1. **默认不增加负载**：升级后默认关闭，不主动改变所有用户的键盘外观与功耗。
2. **只控制计算键盘**：不将设置开关扩展成应用内所有 `Button` 的全局样式开关。
3. **组件级控制**：保持应用级材质为 `default`，只对计算按键显式启用或关闭材质，不影响已经验收的其他场景。
4. **复用材质实例**：同类按键尽量共享材质对象，不在每次 `build()` 或每一个按键上重复构造完全相同的材质。
5. **保留语义颜色**：删除、Shift、等号等关键按键必须保持足够区分度；视觉统一不能降低可操作性。
6. **避免重复动效**：沉浸材质的交互形变与现有 `clickEffect`、`stateStyles` 叠加后若过强，应只在开启路径中收敛旧按压缩放和重复阴影。
7. **逐类键盘推进**：先用基础计算验证设计，再扩展到复杂键盘；图形键盘最后单独决定。

## 4. 分阶段实施

### 阶段 0：保存计划

本阶段只修改本文档。

- [x] 记录目标范围、兼容策略、性能风险和停止条件；
- [ ] 单独提交计划文档；
- [ ] 计划提交前不修改 ArkTS、JSON5 或资源文件。

建议提交：

```text
docs: 新增计算按键沉浸光感开关计划
```

### 阶段 1：建立设置与持久化链路

修改：

- `entry/src/main/ets/utils/CalculatorConfigs.ets`
- `entry/src/main/ets/utils/PreferenceManager.ets`
- `entry/src/main/ets/entryability/EntryAbility.ets`
- `entry/src/main/ets/pages/settings/Settings.ets`

步骤：

- [ ] 新增统一的首选项键，默认值为 `false`；
- [ ] 在启动与集中加载路径中写入 `AppStorage`，两条路径使用相同默认值；
- [ ] 在设置页“按键样式”分组增加“按键沉浸光感”开关；
- [ ] 增加简短说明，提示开启后可能增加 GPU 负载与功耗；
- [ ] API 23 至 API 25 上将开关显示为不可用并说明系统版本要求，避免出现可切换但无效果的设置；
- [ ] 切换时同时更新 `AppStorage` 和首选项，不要求重启；
- [ ] 保持其他设置项的顺序、样式和行为不变。

检查点：

- 首次安装和旧版本升级后的默认值均为关闭；
- 切换后离开设置页再返回，状态保持一致；
- 重启应用后设置仍能恢复；
- 此阶段尚未改变任何计算按键外观。

建议提交：

```text
feat: 新增按键沉浸光感设置
```

### 阶段 2：建立按键材质能力并在基础计算试点

修改：

- `entry/src/main/ets/utils/ImmersiveMaterialUtils.ets`
- `entry/src/main/ets/components/BasicCalc.ets`

步骤：

- [ ] 新增计算按键专用材质创建与关闭能力；
- [ ] 在直接、正向的 `apiAvailable('26.0.0')` 分支内构造或返回 API 26 材质；
- [ ] 对相同参数复用材质实例，避免基础键盘中的每个按键重复构造；
- [ ] `BasicKeyItem` 使用 `@StorageProp` 订阅开关；
- [ ] 开启时应用交互式沉浸材质，关闭时在 API 26 显式应用 `Material.empty`；
- [ ] API 23 至 API 25 完整保留现有背景、边框、阴影和按压反馈；
- [ ] 检查按键现有背景、边框、阴影、`clickEffect` 和 `stateStyles` 是否与材质重复；
- [ ] 只清理已证明由材质接管的 API 26 重复效果，不删除低版本降级样式。

真机检查：

- 数字、运算符、删除和等号的颜色区分；
- 深色与浅色模式下的文字对比度；
- 快速连续点击和长按删除；
- 开关运行时切换是否立即生效；
- 按键材质阴影是否被网格、键盘容器或圆角裁剪；
- 交互形变与现有缩放是否出现重复或突兀反馈。

停止条件：基础键盘出现明显掉帧、点击延迟、颜色语义丢失或无法稳定降级时，不扩展到其他键盘。

建议提交：

```text
feat: 为基础计算按键接入可选沉浸光感
```

### 阶段 3：扩展到常规计算键盘

按以下顺序逐个文件接入，每完成一类键盘即进行针对性检查：

1. `ScientificCalc.ets`；
2. `EquationSolver.ets`；
3. `MatrixCalc.ets`；
4. `ExchangeKeyboard.ets`。

每类键盘的共同步骤：

- [ ] 由各 `KeyItem` 直接订阅同一个全局设置；
- [ ] 共用阶段 2 已验证的材质与关闭 Modifier，不复制构造逻辑；
- [ ] 保留空占位按钮、菜单气泡和非键盘操作按钮的原行为；
- [ ] 检查 Shift、组合/排列样式、矩阵入口、确认键等特殊状态；
- [ ] 检查上下两层键盘的圆角、间距和阴影是否完整；
- [ ] 快速切换模块，确认设置状态和材质不会滞留或闪烁。

建议拆分为两个小提交：

```text
feat: 为科学与方程按键接入沉浸光感
feat: 为矩阵与汇率按键接入沉浸光感
```

### 阶段 4：单独评估函数图像键盘

函数图像页面同时承担图形绘制与键盘交互，比其他模块更容易出现 GPU 竞争。该阶段不因“全局开关”而自动放行。

步骤：

- [ ] 在显示多个复杂函数的测试场景中记录关闭开关时的交互基线；
- [ ] 临时接入 `GraphingKeyboard.ets` 的 `TopKeyItem` 和 `BottomKeyItem`；
- [ ] 对比开启前后的绘图缩放、平移、键盘连续点击、页面切换、帧率、触摸延迟和发热；
- [ ] 检查自定义域键盘、普通图形键盘和空占位按钮；
- [ ] 只有真机表现可接受时才保留接入，否则恢复图形键盘现状，并在设置说明中明确不覆盖函数图像键盘。

通过时建议提交：

```text
feat: 为函数图像按键接入沉浸光感
```

未通过时不提交临时实现，只在计划和变更说明中记录验证结论。

### 阶段 5：收敛视觉、验证与文档

- [ ] 根据真机结果确定是否需要中性、危险、Shift、强调等少量材质变体；
- [ ] 仅在必要时使用半透明 `materialColor`，避免不透明颜色遮住材质滤镜；
- [ ] 确认关闭开关后所有计算键盘与实施前视觉一致；
- [ ] 扫描 `systemMaterial`、`Material.empty`、旧阴影和按键背景的归属；
- [ ] 运行 `git diff --check` 和项目现有 ArkTS 检查；
- [ ] 构建主包 debug，确认 API 26 调用没有最低 API 兼容告警；
- [ ] 在最终收敛时构建 `entry@ohosTest/debug` 与主包 release，并重新生成开发用 debug 产物；
- [ ] 更新分支变更说明，准确区分静态检查、构建、安装和真机性能验证。

建议提交：

```text
fix: 收敛计算按键沉浸光感视觉
docs: 记录按键沉浸光感开关实施结果
```

## 5. 性能策略

官方文档明确提示沉浸光感会使用大量 GPU 资源。系统会根据设备算力等级和用户的系统设置调整表现，但仍需控制应用侧的同时可见数量和重复构造。

实施时采用以下策略：

- 开关默认关闭，不在升级后自动增加所有用户的渲染负载；
- 同类按键共享材质实例，不为每个按键长期持有一份等价对象；
- 不把不可见页面或非键盘按钮纳入开关；
- 不同时重做键盘容器材质，避免按键与整块键盘形成双层滤镜；
- 图形键盘单独验证，不以其他键盘流畅代替图形页面结论；
- 构建成功只证明代码可编译，不能证明帧率、温度、功耗和触摸延迟可接受。

如条件允许，真机对比至少记录：

- 快速点击 30 秒后的响应和温度感受；
- 长按删除与连续触发是否稳定；
- 科学键盘 Shift 往返切换；
- 多模块连续切换；
- 深色、浅色与系统不同沉浸光感档位；
- 函数图像页面显示多个复杂函数时的绘图和键盘交互。

## 6. 兼容与回退

- 设置链路失败：只回退阶段 1，不接入任何按键材质；
- 基础计算试点失败：回退阶段 2，保留已确认无副作用的设置项前提是它不会形成无效入口，否则一并回退；
- 单类键盘失败：只回退该文件的接入，不影响已经验证的键盘；
- 图形键盘性能不合格：不纳入图形键盘，其他模块仍可保留；
- API 23 至 API 25 出现透明背景、崩溃或兼容告警：立即停止扩展，恢复该路径原样；
- 关闭开关无法恢复当前外观：视为阻断问题，不进入最终提交；
- 材质导致删除、Shift、等号等关键按键辨识度下降：先恢复语义颜色，再考虑继续扩展。

Git 回退以阶段性小提交为单位，不使用会覆盖用户改动的强制重置命令。

## 7. 验证矩阵

| 维度 | 最低覆盖 |
| --- | --- |
| 系统 API | API 23、API 26 |
| 开关状态 | 关闭、开启、运行时往返切换 |
| 主题 | 浅色、深色 |
| 系统沉浸光感 | 测试设备可用的不同档位 |
| 键盘 | 基础、科学、方程、矩阵、汇率；图形单独验收 |
| 交互 | 单击、快速连续点击、长按、Shift、菜单、模块切换 |
| 视觉 | 文字对比度、语义颜色、圆角、边框、阴影和裁剪 |
| 性能 | 帧率感受、触摸延迟、发热；条件允许时使用性能工具记录 |

验证证据必须明确区分：

- 配置与静态检查；
- 编译或构建成功；
- HAP 安装和应用启动；
- API 23 运行兼容；
- API 26 材质实际效果；
- 人工视觉与性能验收。

## 8. 完成标准

- 设置页存在含义明确的开关，默认关闭并能持久化；
- 关闭时计算键盘保持当前外观，现有 TopBar、Sheet 和菜单材质不受影响；
- 开启时已批准范围内的按键显示交互式沉浸光感并立即响应设置变化；
- 删除、Shift、等号、运算符和普通按键仍有清楚的视觉层次；
- API 26 新接口均使用工具可识别的直接正向兼容保护；
- API 23 至 API 25 不构造或调用 API 26 材质，并保留完整背景与交互；
- 材质实例得到复用，没有明显的逐按键重复构造；
- 图形键盘只有通过独立性能验收后才纳入开关；
- 所有计划内构建与真机验证结果已记录，未执行项目没有被描述为通过；
- 实施过程按计划拆分为可单独回退的小提交。

## 9. 本计划不包含

- 本文编写阶段不修改任何 ArkTS、JSON5、资源或测试代码；
- 不把应用内全部 `Button` 自动改成沉浸光感；
- 不修改 TopBar、Sheet、菜单、侧边栏或历史记录现有材质策略；
- 不同时为整个键盘容器增加新的沉浸材质；
- 不借此任务重构全部按键组件或统一无关样式；
- 不因 API 26 能力提高最低兼容版本；
- 不在未经真机验证时宣称性能、功耗或 API 23 兼容已经通过。

## 10. 官方参考

- [沉浸光感简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-immersive-light-sense-overview)
- [开启沉浸光感](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-immersive-light-sense-enable)
- [沉浸式系统材质视效](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-immersive-light-sense-common-capability)
- [ArkUI_ImmersiveMaterial](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/capi-arkui-nativemodule-arkui-immersivematerial)

[返回 API 26 沉浸光感迁移计划](./api-26-immersive-light-migration.md)
