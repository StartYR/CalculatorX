# API 26 与沉浸光感迁移

- 状态：已完成，准备合并；API 23 与其他设备形态的真机验证待后续执行
- 类型：功能、兼容性配置、重构
- 分支：`feature/api-update`
- 完成日期：2026-09-18

## 变更摘要

CalculatorX 的目标 API 已从 `6.1.1(24)` 升级到 `26.0.0`，最低兼容 API 继续保持 `6.1.0(23)`。应用使用系统默认沉浸光感策略，并为 TopBar、适合材质化的常用 Sheet、自定义弹窗和原生菜单显式配置系统材质。

本次没有把所有模糊效果机械替换为沉浸光感。TopBar 已迁入 `Navigation` 自定义标题栏，以满足普通组件使用沉浸光感的容器要求；全屏遮罩、键盘、自定义滑动气泡和渐变羽化等场景继续保留原有实现，避免在不适合的区域牺牲可读性与性能。

同一分支还统一了现有 ArkTS/C++ 文件头中的作者标识，并将项目级 `AGENTS.md` 纳入版本控制。这些属于协作与源码元数据维护，不改变应用运行行为，也不纳入用户向发布说明。

## 用户可见行为

- API 26 设备上的历史记录、数学说明和货币选择 Sheet 使用 `REGULAR` 沉浸光感材质。
- 矩阵维度、函数类型、隐私声明和特别鸣谢弹窗使用 `ULTRA_THICK` 材质。
- 计算按键的原生长按菜单使用 `THICK` 材质；同组件中的自定义滑动选择气泡保持原有模糊效果。
- 设置页的角度单位、答案输出、启动页、颜色模式和振动风格五个 `Select` 弹出菜单使用 `THICK` 材质。
- 主页 TopBar 的菜单、撤销、重做、图形编辑和历史记录按钮使用 `ULTRA_THIN` 材质，并开启颜色反转、交互反馈和系统默认点光源效果。
- 全局历史记录的删除操作位于 HDS 标题栏菜单中，沿用标题栏的自适应材质；当前分类没有记录时不显示。
- 历史记录帮助弹窗，以及半模态历史和全局历史的清空确认弹窗使用 `ULTRA_THICK` 材质。
- 应用级 `ohos.arkui.UIMaterial.state` 设为 `default`，由系统继续适配支持的原生组件和用户设置。
- API 23 路径不会构造 API 26 材质；TopBar 保留原有半透明背景、模糊、边框和阴影，自定义弹窗仍使用原有不透明背景。

## 设计与实现

`ImmersiveMaterialUtils.ets` 集中提供 Sheet、弹窗、菜单和 TopBar 四类材质。每个 API 26 专属构造器都在函数内部直接使用正向 `deviceInfo.apiAvailable('26.0.0')` 分支保护；不可用时返回 `undefined`，让组件回到原有行为。

主页使用静态 `Navigation` 包裹动态计算模块，并将 TopBar 作为自定义标题栏；`BarStyle.STACK` 保持标题栏覆盖内容的原布局关系，外层侧边栏层级和历史记录 Sheet 绑定不变。标题栏以 56vp 作为内容高度，并叠加窗口实时上报的状态栏避让高度；TopBar 使用同一避让值设置顶部内边距，保证按钮完整位于系统状态栏下方。

TopBar 的五类按钮共用同一个 `AttributeModifier`：API 26 先使用无强调背景的 `ButtonStyleMode.TEXTUAL`，再应用系统材质；API 23 才应用旧模糊外观，避免两套视觉叠加，也避免默认按钮强调色透入材质。

自定义弹窗通过同一版本判断选择表面背景：API 26 使用透明表面显示系统材质，API 23 保留原系统背景色。隐私弹窗的全屏 `backdropBlur(50)` 和遮罩没有移除，以维持合规文本与底层内容的视觉隔离。

设置页五个 `Select` 共用一个 `AttributeModifier`，只有在直接正向的 API 26 可用性分支中调用 `menuSystemMaterial`。全局历史删除操作则迁入 HDS 标题栏原生菜单，继续使用既有的 HDS 自适应材质，并保留“当前分类存在记录时才显示”的规则。

已有的 7 处 HDS `systemMaterialEffect` 属于 UI Design Kit 导航材质，继续保留，不改写成 ArkUI `uiMaterial`。

## 兼容性与边界

- `targetSdkVersion` 为 `26.0.0`，`compatibleSdkVersion` 仍为 `6.1.0(23)`。
- TopBar 已迁入 `Navigation` 自定义标题栏；模块可见性规则、按钮尺寸、Semantic ID 和事件回调保持不变。
- 顶部安全距离来自 `TYPE_SYSTEM` 避让区并随窗口变化更新，不使用固定状态栏高度。
- 侧边栏关闭遮罩、货币列表羽化与搜索框、汇率键盘、图形键盘、自定义滑动气泡和隐私弹窗全屏背景模糊保持现状。
- API 26 当前只完成手机深色与浅色竖屏的有限验收；API 23 和其余设备、主题及布局场景仍需分别安装和验证。

## 后续独立分支

以下项目不再继续加入本分支，后续单独建分支设计和验证：

- 重构历史记录 Sheet 顶部，使其进入受支持的 Navigation 标题栏容器后再迁移标题区按钮；
- 为货币选择搜索框制作沉浸光感原型，并在真机上比较输入态、键盘展开和列表滚动时的可读性；
- 评估图形编辑全屏 Sheet 的长时间显示功耗、图表透出和公式可读性，再决定是否迁移整个容器。

API 23 真机启动与关键交互回归仍是发布前验证项；当前分支只证明新 API 调用具有静态兼容保护，不把 API 26 构建成功当作 API 23 运行证据。

## 验证

- `entry@default/debug` 构建成功。
- `entry@ohosTest/debug` 构建成功。
- `entry@default/release` 构建成功，随后重新构建 `entry@default/debug`，开发输出已恢复为 debug。
- 生成配置确认 `compileSdkVersion = 26.0.0.105`、目标 API 为 26、最低 API 为 23，主包 metadata 中的材质状态为 `default`。
- 新增的沉浸光感调用没有产生 API 26 兼容告警。构建仍报告项目既有弃用/异常处理告警，以及图形模块两处 `Circle.fill` 的 SDK 重载兼容告警；本次未改写这些无关代码。
- 设置页 `Select` 菜单、全局历史标题栏菜单与三个历史弹窗的改动均已通过 `entry@default/debug` 构建。
- 已静态复核保留的 `backgroundBlurStyle`、`backdropBlur` 和 HDS `systemMaterialEffect` 归属。
- 已在 API 26 手机上安装并启动 debug HAP，完成深色竖屏截图与 UI 树检查：四个可见 TopBar 按钮完整位于系统状态图标下方，背景为透明中性材质；实际点击菜单按钮可正常打开侧边栏。
- 已在同一 API 26 手机上完成浅色竖屏检查：设置页“角度单位”代表性 `Select` 菜单可正常展开，菜单材质、圆角、选中态与文字对比正常；其余四个 `Select` 复用同一 Modifier。
- 全局历史删除按钮位于 HDS 标题栏材质区且显隐正常；历史帮助弹窗、半模态历史与全局历史的清空确认弹窗均正常显示材质。两次清空确认均选择取消，没有删除设备历史数据。
- 尚未执行 API 23、平板、横屏、全部模块、全部系统材质档位、帧率、发热或功耗验证，也未执行 DevEco Studio API Change Assistant 的人工检查。

本次文档收尾前的三个提交只涉及项目说明、文件头作者标识和新工具文件的头注释；这些非功能性调整完成后未重复构建，使用分支差异与格式检查收尾。

## 主要文件

- `build-profile.json5.template`
- `entry/src/main/module.json5`
- `entry/src/main/ets/entryability/EntryAbility.ets`
- `entry/src/main/ets/utils/ImmersiveMaterialUtils.ets`
- `entry/src/main/ets/components/TopBar.ets`
- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/pages/settings/Settings.ets`
- `entry/src/main/ets/pages/settings/About.ets`
- `entry/src/main/ets/components/MatrixCalc.ets`
- `entry/src/main/ets/components/PrivacyDialog.ets`
- `entry/src/main/ets/components/HistorySheet.ets`
- `entry/src/main/ets/components/common/KeyGestureWrapper.ets`
- `entry/src/main/ets/components/graphing/GraphingEditSheet.ets`
- `entry/src/main/ets/components/exchange/rates/ExchangeRate.ets`
- `entry/src/main/ets/pages/history/HistoryManager.ets`
- `AGENTS.md`

## 发布说明素材

目标 API 升级至 26，并为主页 TopBar、历史记录、数学说明、货币选择、常用弹窗和原生长按菜单接入系统沉浸光感；最低兼容 API 仍为 23，不适合材质化的键盘、遮罩和局部视觉模糊继续保留原有效果。

[返回分支变更说明](README.md)
