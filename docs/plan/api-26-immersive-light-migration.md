# API 26 沉浸光感迁移执行计划

- 状态：第一批迁移完成；TopBar 与基础键盘专项试点已通过，其他键盘进入全局规划
- 编写日期：2026-09-17
- 最近更新：2026-09-22
- 适用分支：`feature/api-update`
- 目标 API：`26.0.0`
- 最低兼容 API：`6.1.0(23)`，保持不变
- 执行原则：逐阶段修改、逐阶段验证；任一阶段未通过，不进入下一阶段

## 1. 计划目标

本计划用于将 CalculatorX 的目标 API 从 `6.1.1(24)` 升级到 `26.0.0`，并在继续兼容 API 23 的前提下，分批接入 ArkUI 沉浸光感。

这里的目标不是把所有 `backgroundBlurStyle` 或 `backdropBlur` 机械替换为系统材质。根据华为官方文档，弹窗、菜单、半模态转场及部分选择类组件可以在页面内生效；其他普通组件通常只在 `Navigation`/`NavDestination` 标题栏或指定底部 `TabBar` 区域生效。因此，迁移要以组件类型、所在容器、可读性和功耗为依据。

最终期望：

- API 26 设备获得与系统一致的材质、光影和弹出动效；
- API 23 设备继续使用现有视觉效果和交互，不因新 API 崩溃或丢失背景；
- 已经通过 UI Design Kit 接入的 HDS 导航材质保持原实现；
- 隐私声明、公式、键盘和图表等高可读性场景不因透光效果降低可用性；
- 每次视觉变化都能单独验证和回退。

## 2. 实施前基线

### 2.1 构建与应用配置

开始实施时的配置事实：

- `build-profile.json5`：`targetSdkVersion` 为 `6.1.1(24)`，`compatibleSdkVersion` 为 `6.1.0(23)`；
- `build-profile.json5.template`：版本配置与实际文件相同；
- `entry/src/main/module.json5`：尚未配置应用级 `ohos.arkui.UIMaterial.state`；
- 分支为 `feature/api-update`，开始编写本计划时工作树干净。

API 26 起版本号采用语义化格式，因此目标值应写为 `"26.0.0"`，不能继续沿用旧的 `X.Y.Z(N)` 格式。

### 2.2 现有模糊和材质使用

当前有效的直接模糊共 12 处：

| 场景 | 文件位置 | 数量 | 初步处理 |
| --- | --- | ---: | --- |
| 顶栏按钮 | `entry/src/main/ets/components/TopBar.ets` | 5 | 不直接替换；需先纳入 Navigation 标题栏 |
| 侧边栏全屏关闭遮罩 | `entry/src/main/ets/components/SideBarMenu.ets` | 1 | 保留现状 |
| 自定义滑动选择气泡 | `entry/src/main/ets/components/common/KeyGestureWrapper.ets` | 1 | 保留现状 |
| 货币列表渐变羽化层与搜索框 | `entry/src/main/ets/components/exchange/rates/CurrencySelector.ets` | 2 | 保留现状，后续按视觉需要单独评估 |
| 汇率键盘 | `entry/src/main/ets/components/exchange/rates/ExchangeKeyboard.ets` | 1 | 保留现状 |
| 图形键盘 | `entry/src/main/ets/components/graphing/GraphingKeyboard.ets` | 1 | 保留现状 |
| 隐私弹窗全屏背景遮罩 | `entry/src/main/ets/components/PrivacyDialog.ets` | 1 | 保留遮罩，只评估弹窗表面 |

已有 7 处 `systemMaterialEffect`：

- `entry/src/main/ets/pages/settings/Settings.ets`
- `entry/src/main/ets/pages/history/HistoryManager.ets` 两处
- `entry/src/main/ets/pages/settings/About.ets`
- `entry/src/main/ets/pages/settings/Credits.ets`
- `entry/src/main/ets/pages/HelpDocs.ets`
- `entry/src/main/ets/pages/DocViewer.ets`

这些位置属于 UI Design Kit 的 HDS 导航材质路径。官方文档明确区分 HDS `systemMaterialEffect` 与 ArkUI `uiMaterial` 的适用范围，迁移时不应为了统一写法而替换它们。

### 2.3 当前实施进度

截至 2026-09-18，代码侧迁移已经完成：

- `targetSdkVersion` 已更新为 `26.0.0`，`compatibleSdkVersion` 仍为 `6.1.0(23)`；
- entry module 的 `ohos.arkui.UIMaterial.state` 已设为 `default`；
- 已为历史记录、数学说明和货币选择三个 Sheet 配置 `REGULAR` 材质；
- 已为矩阵维度、函数类型、隐私声明和特别鸣谢四个自定义弹窗配置 `ULTRA_THICK` 材质；
- 已为原生按键长按菜单配置 `THICK` 材质；
- API 26 专属材质构造均使用直接、正向的 `deviceInfo.apiAvailable('26.0.0')` 分支保护；自定义弹窗在 API 23 保留原背景，在 API 26 使用透明表面显示系统材质；
- 已完成 `entry@default/debug`、`entry@ohosTest/debug` 和 `entry@default/release` 构建，并在 release 后重新生成主包 debug 产物；生成配置保持最低 API 23；
- TopBar 的 Navigation 结构改造和基础计算键盘试点已在后续专项中完成；基础键盘确认可以通过自定义底部 TabBar 获得逐键原生材质，其他键盘按独立全局计划逐模块迁移。图形编辑全屏 Sheet、遮罩、自定义滑动气泡及渐变羽化仍保持原实现。

仍未完成的验证：

- API 23 与 API 26 真机安装、启动和交互回归；
- 深色、浅色以及系统沉浸光感不同档位下的视觉验收；
- 长列表、连续弹层操作的帧率、发热与功耗评估；
- DevEco Studio API Change Assistant 的人工检查。

因此，本计划尚未达到第 9 节的全部完成标准，不能据此宣称 API 23 运行兼容或 API 26 实际视觉已经通过。

## 3. 官方能力边界

执行时必须以以下边界为准：

1. 沉浸光感从 API 26.0.0 开始提供，应用的 `targetSdkVersion` 必须不低于 `26.0.0`。
2. `module.json5` 未配置 `ohos.arkui.UIMaterial.state` 时属于 `default` 模式；旧应用升级目标 API 后，受支持组件可能默认启用沉浸光感。
3. `default` 与 `enable` 均为开启状态，`disable` 为全局关闭；全局为 `disable` 时，组件级开启也不生效。
4. 弹窗、菜单、`bindSheet`、Toast、Popup、Tips、`Slider`、`Toggle`、`Select` 等支持在页面内生效。
5. 其他普通组件只在官方限定的 Navigation 标题栏或指定底部 TabBar 中生效；在任意普通 `Stack`、`Row`、`Column` 中添加材质属性不一定有效。
6. 材质会根据深浅色、设备算力和用户系统设置自适应，并会增加 GPU 负载。
7. `uiMaterial.Material.empty` 表示明确关闭组件材质；`undefined` 表示恢复组件默认行为，两者不能混用。

由此得到迁移结论：**不能把任意能使用模糊的组件都直接换成沉浸光感。** 应优先迁移系统支持的浮层容器，并对普通组件保留原模糊或先调整页面结构。

## 4. 总体迁移策略

迁移采用“先隔离、后开启、再显式优化”的顺序：

1. 先升级目标 API，但把应用级材质显式设为 `disable`，隔离 API 行为变化与视觉变化；
2. 完成 API 24 到 API 26 的兼容性检查后，将状态改为 `default`，观察系统自动适配结果；
3. 仅对高价值弹窗、Sheet 和菜单显式指定材质；
4. 对隐私弹窗、全屏 Sheet 和高频键盘区域谨慎处理；
5. 把 TopBar 的 Navigation 改造作为独立结构任务，不混入属性替换；
6. API 23 与 API 26 必须分别验证，不以 API 26 正常代替低版本兼容结论。

每个阶段只处理该阶段列出的文件。通过检查点后再保存阶段性提交；提交操作仍需当次明确授权。

## 5. 分阶段执行步骤

### 阶段 0：保存基线和建立验证清单

本阶段不改代码。

步骤：

- [ ] 记录当前分支、工作树状态和目标/最低 API 配置；
- [ ] 在 API 23 与 API 26 测试设备上记录深色、浅色界面的基线截图；
- [ ] 覆盖历史记录 Sheet、数学说明 Sheet、矩阵维度弹窗、函数类型弹窗、原生长按菜单、隐私弹窗、鸣谢弹窗和货币选择 Sheet；
- [ ] 记录系统“沉浸光感”设置状态和设备类型；
- [ ] 确认用户数据、历史记录和设置均有可恢复路径。

检查点：基线资料足以判断后续变化是 API 升级、默认材质还是显式材质造成的。

### 阶段 1：只升级目标 API，暂时关闭沉浸光感

修改文件：

- `build-profile.json5`
- `build-profile.json5.template`
- `entry/src/main/module.json5`

步骤：

- [ ] 将两个构建配置中的 `targetSdkVersion` 同步改为 `"26.0.0"`；
- [ ] 保持 `compatibleSdkVersion` 为 `"6.1.0(23)"`；
- [ ] 在 entry module 顶层 `metadata` 中显式加入 `ohos.arkui.UIMaterial.state = disable`；
- [ ] 使用 DevEco Studio API Change Assistant 检查 API 24 到 26 的 ArkTS 与 C API 行为变化；
- [ ] 单独记录必须适配的问题，不在本阶段混入材质视觉修改；
- [ ] 检查新增 API 的低版本保护告警，确认最低 API 未被工具自动抬高。

检查点：

- 两份构建配置一致；
- entry module 的 metadata 层级正确，没有误写到 `ExtensionAbility` 的 metadata 中；
- API Change Assistant 的结果已处理或形成明确待办；
- 获得构建授权后，API 23 与 API 26 均能启动并完成主要计算与导航流程；
- 由于材质仍为 `disable`，界面不应出现大范围计划外视觉变化。

停止条件：出现编译错误、API 23 启动失败、三方库不兼容或非材质类行为变化时，先处理升级兼容性，不进入阶段 2。

### 阶段 2：启用默认沉浸光感并观察系统行为

修改文件：

- `entry/src/main/module.json5`

步骤：

- [ ] 将应用级状态从 `disable` 改为 `default`；
- [ ] 暂不为单个组件写入固定材质；
- [ ] 观察系统自动适配的 AlertDialog、Toast、Tips、Select、Slider、Toggle、AlphabetIndexer 气泡、菜单和 Sheet；
- [ ] 检查现有不透明背景、边框和阴影是否遮住系统材质；
- [ ] 记录自动适配已足够、需要显式优化、必须关闭三类结果。

选择 `default` 而不是一开始使用 `enable`，是为了保留系统默认策略和用户个性设置。只有官方行为或实际设备结果证明 `default` 不满足需求时，才评估改为 `enable`。

检查点：API 26 的默认变化已被完整记录，且 API 23 的现有视觉和交互仍正常。

停止条件：出现明显文字对比度下降、浮层边界不清、动画干扰操作或设备发热/掉帧时，先对具体组件关闭或回退，不进行批量显式迁移。

### 阶段 3：第一批高价值显式迁移

本阶段优先处理系统原生支持、使用频率高、迁移收益明确的浮层。

| 优先级 | 场景 | 文件与入口 | 计划动作 |
| --- | --- | --- | --- |
| P0 | 历史记录 Sheet | `pages/Index.ets` 的 `bindSheet` | 为 Sheet 设置系统材质，移除或调整遮挡材质的不透明背景 |
| P0 | 数学说明 Sheet | `pages/settings/Settings.ets` 的 `bindSheet` | 使用适合半模态内容的材质，并检查与 HDS 标题栏衔接 |
| P0 | 矩阵维度弹窗 | `components/MatrixCalc.ets` 的 `CustomDialogController` | 为弹窗控制器设置材质，清理自定义白底、重复阴影和边框 |
| P0 | 函数类型弹窗 | `components/graphing/GraphingEditSheet.ets` 的 `CustomDialogController` | 为弹窗控制器设置材质，保证函数类型按钮对比度 |
| P1 | 原生按键长按菜单 | `components/common/KeyGestureWrapper.ets` 的 `bindContextMenu` | 使用菜单材质；不改同文件的自定义滑动气泡 |

实施要求：

- [ ] 使用 API 26 的官方组件级 `systemMaterial` 接口，不用新的 `backgroundBlurStyle` 模拟材质；
- [ ] 弹窗优先评估 `ULTRA_THICK`，菜单优先评估 `THICK`，Sheet 从默认样式开始，不把建议值直接当成最终值；
- [ ] 删除背景、边框或阴影前逐项对照深色与浅色，避免在 API 23 降级路径中变透明；
- [ ] 将新 API 集中在小型兼容层或最少数量的调用点，按官方 API 兼容性保护指导处理 API 23 路径；
- [ ] 每个场景单独修改、单独验证，禁止一次批量替换全部模糊属性。

检查点：五个场景在 API 26 上有清晰材质层次，在 API 23 上仍有完整背景、可读文字和可点击区域。

### 阶段 4：第二批谨慎迁移

| 优先级 | 场景 | 文件与入口 | 计划动作 |
| --- | --- | --- | --- |
| P1 | 首次启动隐私弹窗 | `components/PrivacyDialog.ets` | 只为弹窗表面评估 `ULTRA_THICK`；保留全屏 `backdropBlur(50)` 与遮罩 |
| P1 | 特别鸣谢弹窗 | `pages/settings/About.ets` | 为底部 CustomDialog 评估系统材质，检查列表滚动与圆角 |
| P1 | 货币选择 Sheet | `components/exchange/rates/ExchangeRate.ets` | 从默认 Sheet 材质开始，检查搜索、列表和键盘切换 |
| P2 | 图形编辑全屏 Sheet | `components/graphing/GraphingCalc.ets` | 暂缓；先评估长时间显示时的功耗、图表透出和公式可读性 |

隐私弹窗属于合规界面，可读性和操作确定性优先于视觉统一。若材质导致正文、链接、“拒绝”或“同意”按钮对比度不足，应保留原不透明弹窗表面。

检查点：合规文本无透底干扰，按钮对比度明确；长列表、滚动和输入过程没有明显掉帧。

### 阶段 5：TopBar 的结构性改造决策

`TopBar.ets` 的五处 `backgroundBlurStyle(BlurStyle.COMPONENT_THICK)` 位于普通布局中，不在 ArkUI 沉浸光感对普通组件的有效区域内。直接改成 `systemMaterial` 很可能不生效，因此本阶段先做结构决策。

候选方案：

1. 将主页 TopBar 纳入 ArkUI `Navigation`/`NavDestination` 标题栏，再对标题栏内按钮使用沉浸光感；
2. 继续使用当前自定义 TopBar 和模糊效果，不为视觉统一承担导航结构改造风险。

执行前必须单独评估：

- 侧边栏入口、撤销/重做、历史入口和模块标题的状态传递；
- 安全区、横竖屏、手机和平板布局；
- Semantic ID 与现有 UI 自动化定位；
- HDS Navigation 与主页自定义布局是否能稳定组合；
- 标题栏重构对页面高度和计算键盘空间的影响。

该阶段是独立功能改造。未经单独确认，不应作为 API 26 升级的必做项。

### 阶段 6：清理与最终收敛

步骤：

- [ ] 删除已经被系统材质完整取代且没有低版本用途的重复模糊、阴影或背景；
- [ ] 保留 SideBar 全屏遮罩、键盘、自定义滑动气泡、渐变羽化等不属于直接迁移目标的模糊；
- [ ] 对不适合材质的默认开启组件使用组件级关闭，而不是关闭整个应用的沉浸光感；
- [ ] 扫描所有 `backgroundBlurStyle`、`backdropBlur`、`systemMaterial` 和 `systemMaterialEffect`，核对每处归属；
- [ ] 更新对应变更说明和版本摘要；
- [ ] 在发布前重新执行 API Change Assistant 与双版本回归。

## 6. API 23 兼容策略

最低版本保持 API 23 并不自动保证所有 API 26 写法都能在旧设备安全运行。实施时遵循以下规则：

- 只在 `targetSdkVersion = 26.0.0` 后引入沉浸光感 API；
- 对 API 26 专属接口使用官方 ArkTS API 兼容性保护方案，并处理 DevEco Studio 的兼容性告警；
- 不在 API 23 路径中依赖 API 26 枚举、构造器或默认材质背景；
- 移除旧背景前先证明 API 23 有明确的降级样式；
- 组件级兼容逻辑尽量集中，避免在每个页面复制版本判断；
- 以 API 23 真机运行结果作为最终兼容证据，静态检查或 API 26 构建成功不能代替它。

## 7. 验证矩阵

获得明确构建和真机测试授权后，至少覆盖以下组合：

| 维度 | 最低覆盖 |
| --- | --- |
| 系统 API | API 23、API 26 |
| 主题 | 浅色、深色 |
| 沉浸光感设置 | 开启、关闭或系统提供的可选档位 |
| 设备 | 手机；条件允许时增加平板 |
| 算力 | 至少记录一台实际测试设备的全局材质等级 |
| 页面状态 | 首次启动、普通启动、弹窗、Sheet、菜单、键盘展开、列表滚动 |

每个迁移组件检查：

- 背景层次和文字对比度；
- 圆角、边框、阴影是否重复；
- 出现与消失动效是否自然；
- 点击、长按、拖动、返回和遮罩关闭是否正常；
- 滚动内容与底层内容是否造成视觉干扰；
- API 23 是否保留完整降级背景；
- API 26 在系统关闭沉浸光感时是否仍可用；
- 连续操作是否出现掉帧、发热或异常 GPU 占用。

验证证据必须区分：

- 静态配置检查；
- 编译或构建成功；
- 应用安装和启动成功；
- API 23 运行兼容；
- API 26 实际材质效果；
- 人工视觉与交互验收。

## 8. 回退与停止规则

- 阶段 1 失败：恢复 `targetSdkVersion` 为 `6.1.1(24)`，不保留任何 API 26 UI 调用；
- 阶段 2 失败：将应用级状态恢复为 `disable`，继续定位默认材质造成的问题；
- 单个组件失败：仅回退该组件的显式材质，保留已验证组件；
- TopBar 改造失败：恢复原自定义 TopBar 和五处模糊，不影响其他弹窗与 Sheet；
- 任一阶段发现 API 23 透明背景、崩溃或关键交互退化：立即停止后续迁移；
- 任何隐私合规文本可读性下降：优先恢复原弹窗表面，不以材质一致性为由继续上线。

## 9. 完成标准

满足以下条件后，本计划才可标记为完成：

- `targetSdkVersion` 已统一为 `26.0.0`，`compatibleSdkVersion` 仍为 `6.1.0(23)`；
- API Change Assistant 中与项目相关的问题已处理或有明确接受理由；
- 应用级材质状态的最终选择有真机证据；
- 第一批浮层逐项完成迁移或明确记录不迁移原因；
- 第二批场景完成可读性和功耗评估；
- 现有 HDS `systemMaterialEffect` 未被错误替换；
- 所有保留的直接模糊都有明确用途；
- API 23 与 API 26 的深浅色、关键交互和启动流程均通过验证；
- 变更说明准确区分配置、静态检查、构建和真机验证；
- 未经验证的 TopBar 结构改造没有被混入发布。

## 10. 本计划不包含

- 本文编写阶段不修改目标 API、module metadata 或任何 UI 源码；
- 不因为新增材质而重做 CalculatorX 的整体视觉设计；
- 不把 HDS 导航材质迁移成 ArkUI 材质；
- 不强制材质化全屏遮罩、键盘、图表画布或所有自定义气泡；
- 不在未授权时执行编译、构建、安装、真机测试、提交或发布。

## 11. 官方参考

相关专项计划：

- [TopBar 沉浸光感迁移计划](./topbar-immersive-light-navigation-migration.md)
- [基础计算键盘沉浸光感试点计划](./basic-keyboard-immersive-light-prototype.md)
- [全局计算键盘沉浸光感迁移计划](./global-keyboard-immersive-light-migration.md)

- [沉浸光感简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-immersive-light-sense-overview)
- [开启沉浸光感](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-immersive-light-sense-enable)
- [沉浸式系统材质视效](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-immersive-light-sense-common-capability)
- [API 26 版本号格式调整说明](https://developer.huawei.com/consumer/cn/doc/doccenter-release-notes/version-number-26)
- [应用升级适配指导——向 26.0.0 升级](https://developer.huawei.com/consumer/en/doc/harmonyos-releases/upgrade-adaptation)

[返回项目 README](../../README.md)
