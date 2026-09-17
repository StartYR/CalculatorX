# TopBar 沉浸光感与 Navigation 标题栏迁移计划

- 状态：API 26 手机竖屏验证完成，API 23 与其他设备形态待验收
- 编写日期：2026-09-18
- 适用分支：`feature/api-update`
- 目标 API：`26.0.0`
- 最低兼容 API：`6.1.0(23)`，保持不变
- 优先级：P0

## 1. 目标

将主页高频出现的 TopBar 纳入 ArkUI `Navigation` 标题栏，使菜单、撤销、重做、图形编辑和历史记录五类按钮能够在 API 26 设备上使用沉浸光感，同时保持 API 23 的原有模糊外观与现有交互。

本计划只调整主页容器和 TopBar，不同时迁移历史帮助弹窗、图形编辑全屏 Sheet 或设置页选择控件。

## 2. 当前实现与约束

### 2.1 页面结构

`entry/src/main/ets/pages/Index.ets` 当前使用一个全屏 `Stack`：

1. 动态计算模块位于底层；
2. `TopBar` 作为普通组件覆盖在内容区顶部；
3. 侧边栏打开后作为最上层覆盖组件出现；
4. 历史记录 Sheet 绑定在 `TopBar` 上；
5. 只有动态内容区在侧边栏打开时缩放，TopBar 本身不缩放。

### 2.2 TopBar 行为

`entry/src/main/ets/components/TopBar.ets` 当前承担：

- 左侧菜单入口；
- 科学、方程和矩阵模块的撤销/重做；
- 基础、科学、方程和矩阵模块的历史记录入口；
- 图形模块的函数编辑入口；
- 当前模块标题、Shift 状态和角度制状态；
- 维持标题居中的占位布局。

现有五个按钮分别使用半透明背景、`backgroundBlurStyle(BlurStyle.COMPONENT_THICK)`、边框和阴影。它们位于普通 `Row` 中，不属于 ArkUI 沉浸光感对普通组件的有效区域。

### 2.3 官方与 SDK 边界

- 普通组件的沉浸光感仅在 `Navigation`/`NavDestination` 标题栏或指定底部 TabBar 区域生效；
- `NavigationTitleOptions.systemMaterial` 从 API 26.0.0 提供，但其标题栏材质主要接管系统返回键、系统 menu 按钮及更多菜单背板；
- 当前 TopBar 使用自定义 Button，因此需要把组件放入标题栏，并为按钮自身设置通用 `systemMaterial`；
- `NavigationCustomTitle` 可提供自定义 Builder 和标题栏高度；
- `BarStyle.STACK` 让标题栏覆盖内容区，最接近当前悬浮 TopBar 的布局关系；
- 通用 `systemMaterial` 会接管背景、边框和阴影，不应在 API 26 路径继续叠加旧模糊样式；
- API 26 新接口必须使用直接、正向的 `deviceInfo.apiAvailable('26.0.0')` 分支保护。

## 3. 目标结构

迁移后仍以外层 `Stack` 管理主页面和侧边栏：

```text
Stack
├─ Navigation
│  ├─ content: 动态计算模块
│  └─ custom title: TopBar
└─ SideBarMenu（打开时覆盖）
```

关键选择：

- 不引入 `NavPathStack`，主页仍使用 `currentModule` 动态挂载计算模块；
- 不改设置、历史、帮助等页面现有的 router 路由；
- 不把侧边栏移入 Navigation；
- TopBar 使用“56vp 内容高度 + 实时状态栏高度”的自定义标题栏和 `BarStyle.STACK`；
- `EntryAbility` 将顶部系统避让区高度写入 `AppStorage` 并监听变化，TopBar 使用该值作为顶部内边距，不再依赖硬编码的 36vp；
- 历史记录 Sheet 仍绑定在 TopBar 调用点，内容、状态和材质不变。

## 4. 分阶段实施

### 阶段 0：保存计划

- [x] 新增并核对本计划；
- [x] 单独提交计划文档；
- [x] 计划提交前不修改 ArkTS 源码。

建议提交：

```text
docs: 新增 TopBar 沉浸光感迁移计划
```

### 阶段 1：迁移 Navigation 结构，暂不改变按钮材质

修改：

- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/components/TopBar.ets`

步骤：

- [x] 在 `Index` 中新增主页标题栏 Builder，集中创建 `TopBar` 并保留全部回调；
- [x] 用静态 `Navigation` 包裹动态计算内容；
- [x] 将 TopBar Builder 设置为 56vp 内容高度，并叠加实时状态栏高度；
- [x] 设置 `NavigationMode.Stack`、隐藏返回键，并使用 `BarStyle.STACK` 保持覆盖布局；
- [x] 保持外层 `Stack` 和 `SideBarMenu` 层级不变；
- [x] 使用窗口顶部系统避让区设置 TopBar 顶部内边距，保持左右 12vp 和按钮尺寸不变；
- [x] 保留所有 Semantic ID、标题状态、Shift 状态和事件回调；
- [x] 保留现有按钮模糊样式，先隔离结构变化与材质变化；
- [x] 构建 `entry@default/debug`。

检查点：

- ArkTS 构建成功；
- TopBar 只创建一次；
- 历史记录 Sheet 仍绑定到同一状态；
- 侧边栏打开时仍只缩放动态内容区；
- 模块可见性规则与迁移前一致。

建议提交：

```text
refactor: 将主页顶栏纳入 Navigation 标题栏
```

### 阶段 2：为 TopBar 按钮启用沉浸光感

修改：

- `entry/src/main/ets/utils/ImmersiveMaterialUtils.ets`
- `entry/src/main/ets/components/TopBar.ets`

步骤：

- [x] 新增 TopBar 专用 `ULTRA_THIN` 材质；
- [x] 开启 `colorInvert`、`interactive` 和系统默认点光源反馈；
- [x] 使用按钮 AttributeModifier 集中处理 API 26 材质和 API 23 旧样式；
- [x] 在 Modifier 内直接使用正向 `deviceInfo.apiAvailable('26.0.0')` 分支；
- [x] API 26 路径只设置 `systemMaterial`，不叠加旧背景、模糊、边框和阴影；
- [x] API 23 路径保留现有半透明背景、`COMPONENT_THICK` 模糊、边框和阴影；
- [x] 五类按钮共用同一个视觉 Modifier，宽度、点击行为和 Semantic ID 保持不变；
- [x] 构建 `entry@default/debug`，确认新增调用没有 API 26 兼容告警。

检查点：

- 菜单、撤销、重做、编辑和历史按钮均走统一材质路径；
- 中间标题与角度制徽章不被误设为材质组件；
- API 23 降级路径不依赖 API 26 类型或默认背景；
- 不再存在 TopBar 的五处直接 `backgroundBlurStyle` 调用，旧模糊只保留在 Modifier 的低版本分支。

建议提交：

```text
feat: 为主页顶栏启用沉浸光感
```

### 阶段 3：收敛文档与最终验证

- [x] 更新本计划为当前实施状态；
- [x] 更新 `docs/changes/2026-09-18-api-26-immersive-light.md`；
- [x] 扫描 TopBar、Navigation、`systemMaterial` 和旧模糊归属；
- [x] 执行 `git diff --check`；
- [x] 构建 `entry@ohosTest/debug` 与 `entry@default/release`；
- [x] release 后重新构建 `entry@default/debug`，恢复开发产物；
- [x] 初次迁移阶段未安装 HAP；后续经用户明确授权安装 debug HAP 验证修复。

建议提交：

```text
docs: 记录 TopBar 沉浸光感迁移
```

### 阶段 4：根据 API 26 真机反馈修正安全区与配色

- [x] 读取并监听 `TYPE_SYSTEM` 顶部避让区高度；
- [x] 扩展自定义标题栏高度，并将 TopBar 完整放到状态栏下方；
- [x] 保持 `BarStyle.STACK`，避免动态计算内容被标题栏整体下推；
- [x] API 26 按钮使用 `ButtonStyleMode.TEXTUAL`，移除默认强调色背景；
- [x] 构建、安装并启动 debug HAP；
- [x] 通过截图和 UI 树核对按钮边界、透明背景与菜单点击行为。

提交：

```text
fix: 修复 TopBar 安全区与按钮配色
```

## 5. 兼容与回退

- API 23 使用已有模糊按钮，不构造或调用 API 26 材质；
- `Navigation`、自定义标题栏、`BarStyle.STACK` 和 AttributeModifier 均低于最低 API 23，可作为共享结构；
- 若 Navigation 改变内容高度或安全区，先调整标题栏高度和布局方式，不用负 margin 抵消；
- 若侧边栏覆盖、历史 Sheet 或图形编辑入口退化，只回退阶段 1；
- 若材质造成对比度、动效或性能问题，只回退阶段 2，保留已经验证的 Navigation 结构；
- 不修改 TopBar 的模块可见性白名单和互斥动作枚举。

## 6. 验证矩阵

静态与构建验证：

- `entry@default/debug`
- `entry@ohosTest/debug`
- `entry@default/release`
- 生成配置仍为目标 API 26、最低 API 23
- 新增 API 无低版本兼容告警
- `git diff --check`

已完成真机验收：

- API 26 手机、深色模式、竖屏、科学计算模块；
- TopBar 四个可见按钮完整位于状态栏图标下方，UI 树无裁剪；
- 按钮背景为透明中性材质，菜单按钮可打开侧边栏。

后续真机验收：

- API 23；
- API 26 浅色模式；
- 基础、矩阵、方程、图形及无右侧动作模块；
- 菜单、撤销、重做、历史与图形编辑；
- 侧边栏打开/关闭、历史 Sheet 打开/关闭；
- 平板与横屏；
- 系统沉浸光感不同档位下的按钮对比度与反馈。

构建成功不能代替上述真机视觉与交互验收。

## 7. 完成标准

- TopBar 已位于 Navigation 自定义标题栏；
- 五类按钮在 API 26 使用 `ULTRA_THIN` 沉浸光感材质；
- API 23 保留原模糊样式；
- TopBar 的尺寸、模块规则、Semantic ID 和点击行为没有改变；
- 动态内容、侧边栏和历史 Sheet 的层级关系保持不变；
- 三种构建目标通过并恢复 debug 产物；
- 文档准确区分已完成的 API 26 手机验证和其余未执行场景。

## 8. 官方参考

- [开启沉浸光感](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-immersive-light-sense-enable)
- [Navigation 组件与标题栏 systemMaterial](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ts-basic-components-navigation)
- [沉浸式系统材质视效](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-immersive-light-sense-common-capability)

[返回 API 26 沉浸光感迁移计划](./api-26-immersive-light-migration.md)
