# 整数符号切换与沉浸光感公共层

- 状态：实现与静态检查完成，待真机视觉验收
- 类型：界面优化、公共视觉层重构
- 分支：`feature/base-conversion-2`
- 更新日期：2026-10-30

## 用户可见行为

整数模式将原来的单个符号切换按钮改为“有符号 / 无符号”胶囊切换栏，同时展示两个选项，当前项高亮。选项复用顶部模式栏的按钮与选中配色，控件保持在字长与位/编码按钮所在行。API 26.0.0 及以上使用与顶部模式栏相同的交互式沉浸光感。

符号切换栏与顶部“数值 / 整数 / IEEE754”模式栏共用独立的选中底色胶囊。选中项改变时，胶囊以 220 ms 缓入缓出动画移动；顶部保持原有 1 : 1 : 1.35 宽度比例，胶囊随目标选项同步调整宽度。文字高亮与业务状态立即更新。

点击另一项沿用原有符号解释切换流程；重复点击当前项只保留按键反馈，不确认草稿、不新增撤销记录。计算核心、位模式及设置保存逻辑未修改。

## 实现与兼容

- `ImmersiveSegmentedControl` 的响应式选中索引直接来自 `session.signed` 或 `session.mode`，不复制一份业务选择状态。
- 指示块按选项权重计算百分比宽度与位置，隐式动画仅作用于底色；公共组件中的 `SegmentButton` 使用透明背景，沿用文字、触感与语义 ID。装饰层不接收触摸或无障碍焦点。
- 动画时长集中于 `BaseConverter.ets` 的 `BASE_SELECTION_SLIDE_DURATION`；不使用定时器或完成回调修改选中状态，连续点击直接更新动画目标。
- 光感表面复用公共 `ImmersiveToolbarRowModifier` 与 `createTopBarMaterial()`，和顶部模式栏一样独立于键盘光感开关。
- 控制行在 API 26.0.0 正向分支内挂载到局部横向底部 TabBar，提供材质生效区域。上下预留阴影空间，外层保持原控制行高度并关闭裁切，避免扩大内容间距。
- API 23–25 直接渲染普通控制行，由已有 Modifier 回退到系统背景、边框及阴影，不创建沉浸材质；最低兼容版本不变。
- CLI 的 `base.signed` 改为明确选择有符号，不再反转状态；新增 `base.unsigned` 明确选择无符号，白名单及操作说明同步更新。重复调用同一目标不会再次切换。

## 验证

- `BaseConverter.ets` 的 CodeLinter 检查完成，三个 agent 均为 0 项诊断。
- `tools/test-programmer-cli.ps1` 通过，覆盖两个选择目标的白名单与既有场景静态检查；未执行设备操作。
- `git diff --check` 通过。
- 加入光感后的 `BaseConverter.ets` 再次通过 CodeLinter，三个 agent 均为 0 项诊断；对照顶部模式栏核对了直接 API 保护、低版本分支和材质调用。
- 加入滑动胶囊后再次通过 CodeLinter、CLI 静态检查和差异检查；原有控件语义 ID 保持不变。
- 本次未运行编译或构建。真机动画流畅度、快速连续切换、初始恢复位置、光感、阴影边界、滚动触摸、低版本回退及窄屏和大字体下同行布局仍需验收。

## 主要文件

- [BaseConverter.ets](../../entry/src/main/ets/components/exchange/base/BaseConverter.ets)
- [Invoke-CalcXUi.ps1](../../tools/calcx/runtime/commands/Invoke-CalcXUi.ps1)
- [CLI 操作说明](../calculation-cli-automation.md)

## 2026-10-30 公共层重构

- `ImmersiveMaterialUtils` 为 ArkUI 工厂提供默认开启的 `globalEnabled` 参数，API 26 显式关闭返回 `Material.empty`，API 23–25 不触碰新 API；键盘缓存服从关闭状态。
- 现有 8 个键盘布局入口通过 `isKeyboardMaterialEnabled` 选择路径，仍保留模块内的直接 API 保护和完整容器。
- HDS 导航栏与底部栏的 10 处材质配置集中为 `createNavigationMaterial`，开启保持 `ADAPTIVE`，显式关闭使用 `NONE`，保留 API 23 起的原有系统自适应行为。
- 工具栏行、标题栏按钮、搜索框与 Select 展开菜单的视觉适配器集中于 `ImmersiveVisualModifiers`。关闭/重新开启时恢复对应表面，低版本样式参数沿用原值。
- 模式和符号切换复用 `ImmersiveSegmentedControl`。页面仍持有 TabBar 生效区域、阴影留白、层级、尺寸参数和业务回调，未转交整页 Builder。
- 未新增设置项、存储键或全局响应式开关。未来设置接入仍需在装配层订阅并传递全局值，并处理长生命周期对话框的选项刷新；不改写键盘偏好。详见[沉浸光感公共层](../architecture/immersive-material.md)。

### 本次验证

- `tools/test-immersive-material.mjs` 通过：SDK 替身覆盖版本与双开关组合、显式关闭、缓存，以及同一属性对象的传统/光感往返。
- 键盘架构检查、程序员 CLI 静态检查与 `git diff --check` 通过。架构脚本补登记已有 `PreferenceDefaults.ets`，避免把启动默认值配置误报为业务层读取。
- 修改的 21 个 ArkTS 文件完成 CodeLinter：ESLint 0 项，performanceAgent 3 项，arkPerfCheck 18 项，均为性能建议。公共选项栏有两项“优先使用 Builder”的建议，因选中状态与标签需要响应式更新而保留组件；未关闭规则。
- 尝试独立 `CompileArkTS` 验证，但当前命令行 Hvigor 未注册该任务；查询模块任务只列出帮助与初始化，未进入源码编译。因此不能声明编译通过，未扩大到 HAP 全量打包或安装。
- 未进行真机材质、动画、主题切换和低版本设备验收。

### 构造函数字段兼容修复

用户编译反馈确认 `ImmersiveVisualModifiers` 的四处构造函数参数属性触发 `arkts-no-ctor-prop-decls`。四个类均改为独立声明 `private globalEnabled: boolean`，在普通构造函数中赋值；默认值与视觉策略不变。宿主材质测试通过，不能将 TypeScript 转译测试或 CodeLinter 结果当作 ArkTS 编译通过。本次修复未重新运行完整构建。

## 发布说明素材

整数模式改用“有符号 / 无符号”双选项切换栏，当前解释方式更直观，可直接选择目标模式；API 26 加入与顶部模式栏一致的沉浸光感，低版本保留传统外观。符号与模式切换均采用平滑滑动的胶囊高亮。
