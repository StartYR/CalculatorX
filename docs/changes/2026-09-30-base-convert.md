# 进制转换三模式与交互完善

- 状态：实现完成，准备合并；验证范围与未覆盖项见下文
- 类型：功能 / 修复 / 界面优化 / 模块整理
- 分支：`feature/base-convert`
- 完成日期：2026-09-30
- 核对范围：与本地 `main` 的共同祖先 `ffe329b` 至本分支 `c86c4c2`
- 关联：[进制转换架构](../architecture/base-conversion.md)、[程序员模式首版](./2026-09-23-programmer-mode.md)

## 变更摘要

本分支在已合入 main 的程序员模式首版上，新增普通数值进制换算、IEEE754 目标精度四则运算与实时预览，并完善三模式的布局、输入反馈、长按复制、粘贴授权和键盘升降。

模块内标签统一为“数值 / 整数 / IEEE754”。数值模式面向不限固定字长的正负数与小数；整数和 IEEE754 继续分别处理固定字长位模式与浮点格式。三种模式使用独立输入状态。

本文件是本分支合并汇总。已有专题变更说明保留实现细节和阶段验证记录；生成 Release / Changelog 时按主题去重，不把本汇总与专题说明重复计为多项功能。

## 用户可见行为

### 数值换算

- 新会话默认选择“数值”；已有设置与历史恢复仍尊重原模式。
- 支持 HEX、DEC、OCT、BIN 的正负整数和有限小数输入，整数部分不截断至 64 bit，输入最多 256 字符。
- 小数显示上限可选 16、32、64、128 位，默认 32 位。循环小数或超过显示上限的结果带 `≈` 与省略标记。
- 切换进制或显示位数保留精确原值；“编辑原值”返回原输入进制，避免把截断显示当成精确输入。
- 当前进制行直接显示草稿，数值页不显示顶部表达式栏。专属键盘为五行四列，包含 0–9、A–F、小数点、变号、退格和 AC，不提供等号。
- 数值模式不支持算术表达式、指数、分数或进制前缀；HEX 中的 E 仍是数字。

详见 [numeric-base-conversion.md](./2026-09-29-numeric-base-conversion.md)。

### 整数与 IEEE754

- 修复点击数字本体不能选中进制的问题；文本和行内空白均可切换输入进制。
- 修复模式、位/编码标签、符号解释与其他状态控件的文字和选中高亮不同步。
- 整数继续支持 8/16/32/64 bit、符号解释、位运算、移位/旋转、标志位和编码观察；本分支主要完善其显示与交互。
- IEEE754 新增十进制四则表达式、科学记数法及括号粘贴；字面量与每步运算均按所选 binary16/32/64 的 roundTiesToEven 舍入。
- 有效浮点草稿实时更新结果与字段；`1e-`、末尾运算符等未完成输入保留最近有效预览，按 `=` 才确认并写入历史。
- IEEE754 格式改为下拉菜单。顶部原始位串输入不自动填充高位零，HEX/BIN 结果行仍按格式位宽补零。
- 当前 IEEE754 输入/显示为 DEC、HEX、BIN，尚未加入 OCT；HEX/BIN 用于原始位模式，算术输入限定十进制模式。

### 布局与键盘

- 模式选项、粘贴及帮助组成固定悬浮顶栏，滚动时仍可操作；顶栏及内容预留状态栏、应用标题栏和阴影空间。
- 帮助使用系统 `questionmark_circle` 图标，三个模式分别打开独立帮助弹窗。
- 数值统一右对齐。BIN 显式按每 32 个二进制数字分行，符号、小数点及近似标记不计入位数；末行不足 32 位不补零，窄屏按可用宽度缩放。
- 三个模式隐藏滚动条，保留纵向滚动和原生边缘回弹；移除重复的输入操作说明，减少页面占位。
- 按键主文字居中，长按提示独立显示；退格统一使用公共 SVG，0–9、A–F 使用等宽字体。
- 按键文字采用主色、强调色、次要色与危险/确认键白色分级，独立于背景颜色。
- 键盘悬浮于内容上层，底部间距统一为 `Math.max(0, navBarHeight - 8)`。
- 整数展开“位 / 编码”或 IEEE754 展开“字段”时，键盘向下滑出；收起当前面板时向上滑回。数值模式始终显示键盘。
- 键盘隐藏时显示双行 `△ / ⌨` 唤起按钮，使用 `Cambria Math`。按钮位于键盘下层，上滑动画完成后卸载，避免出现时遮盖尚未收起的键盘。
- 隐藏键盘及过渡中的唤起按钮按状态禁用触摸和无障碍遍历，内容底部随状态预留安全区。
- 进制模块的应用主顶栏不再显示撤销、重做和历史按钮；底层会话仍保留相应事件与历史回填协议。

详见 [base-floating-toolbar.md](./2026-09-29-base-floating-toolbar.md)、[base-adaptive-keyboard.md](./2026-09-29-base-adaptive-keyboard.md)、[base-keyboard-polish.md](./2026-09-29-base-keyboard-polish.md)。专题中的尺寸数值反映编写时状态，最终布局以 `BaseConverter.ets` 的参数为准。

### 复制与粘贴

- 三模式的进制数值行统一长按弹出“复制完整数字”，不再进入文本选择；顶部表达式仍可选择文本。
- 复制完整显示文本，BIN 不携带排版换行；近似数值保留显示标记，不冒充精确原值。
- 数值行长按阈值为 350 ms，菜单出现时调用公共触感工具，遵循振动开关与曲线配置。
- 菜单最终使用无参 `@Builder` 直接引用及显隐状态控制，修复带参数绑定虽可编译、运行时却不显示菜单的问题。
- 粘贴入口使用普通透明按钮，保留外层光感与传统回退。点击后检查文本类型，并申请 `ohos.permission.READ_PASTEBOARD`，授权成功才读取内容。
- 粘贴成功、拒绝授权、空文本和无效输入均使用 Toast，不增加页面行高；失败不替换当前输入或新增撤销记录。
- 申请权限时防重复触发；授权等待期间会话已改变时，不继续应用原次粘贴。

## 设计与实现

### 模块职责

- `components/exchange/base/` 保存页面、单键和检查面板；主组件为 `BaseConverter`，复用 `BaseKey` 与 `BaseInspector`。
- `utils/base/` 使用 `BaseConversionSession` / `BaseConversionState` 管理三模式状态；整数计算与表达式分别归于 `IntegerEngine` / `IntegerExpression`，浮点归于 `IEEE754` / `FloatExpression`，普通数值归于 `NumericValue` / `NumericSession`。
- `NumericValue` 以精确整数构造有理数，`NumericSession` 分离原始输入、草稿与近似显示；浮点计算直接按目标格式舍入，避免经过宿主浮点数造成二次舍入。
- `BinaryDisplay` 负责按数字位数分组；模式及标志控件通过响应式属性更新。
- 键盘继续复用公共 `KeyboardKeySurface` 与项目双渲染路径。同步调整架构引用、测试导入和 CLI 检查，补充数值边界及状态契约注释。

### 状态与历史

- Preferences 保存模式、进制、字长、有无符号和小数显示位数等配置。
- 当前输入、未完成草稿和预览仍只保留在进程内；模块往返可恢复，进程结束后不能恢复上次完整会话。
- 整数与 IEEE754 确认后写入现有 `module_type=base` 历史。扩展数据版本 2 兼容版本 1，包含数值模式精确来源；数据库表结构不变。
- 数值键盘无确认键，本分支不主动新增数值历史，但支持已有历史记录恢复。
- 浮点预览与确认位模式分离，预览不覆盖已确认的 NaN payload；历史恢复保持其既有确认语义。

## 兼容性与发布边界

- 项目最低兼容 API 为 23，目标 API 为 26。键盘在 API 26 且全局光感开关开启时使用沉浸路径，其余走传统布局；悬浮顶栏和唤起按钮使用各自的 API 保护与回退。
- IEEE754 四则运算中的 NaN 会规范化，不模拟处理器浮点异常标志或其他舍入模式；原始位编辑继续保留 payload。
- 剪贴板权限已声明用途与前台使用场景。此前安装曾因签名 Profile 缺少相应 ACL 返回 `9568289`；维护者随后反馈已按官方文档重新签名，后续专题记录包含覆盖安装成功。该反馈不代表商用发布签名资格已完成核验。
- 官网协议页面属于另一个仓库，本次合并不包含其部署；历史专题中的协议源文件修改记录不等于网页已经上线。
- 汇率未知值显示 `--` 的修复已在 main 独立完成，不属于本分支交付；合并时保留 main 的汇率行为。
- 持久化补强与进制转换跨重启会话保存本分支仅形成[实施计划](../plan/persistence-hardening-and-base-session.md)，尚未修改 `PreferenceManager` 或接入会话落盘。已有存储问题与后续阶段见该计划。

## 验证

### 既有阶段验证记录

以下结果来自关联专题及架构文档中的阶段记录，未在本次文档整理时重新执行，不能视为合并后完整回归：

| 范围 | 已记录结果 | 证据 |
| --- | --- | --- |
| 数值核心与会话 | 宿主测试 5,982 项断言；当时 ArkTS 本地测试 16 项通过 | [数值换算说明](./2026-09-29-numeric-base-conversion.md) |
| 程序员与浮点输入 | 宿主测试 259,736 项断言；当时 ArkTS 本地测试 17 项通过 | [键盘修复说明](./2026-09-29-base-keyboard-polish.md) |
| 粘贴校验 | 15 项宿主用例覆盖成功、空文本、格式错误、超长与读取失败 | [悬浮顶栏说明](./2026-09-29-base-floating-toolbar.md) |
| 键盘升降 | 174 项宿主断言及动画回调检查，覆盖面板、恢复及失效回调 | [自适应键盘说明](./2026-09-29-base-adaptive-keyboard.md) |
| 编译与静态检查 | 多个阶段记录 CodeLinter、键盘架构、CLI 静态检查及 debug 构建通过 | 上述专题；构建仍有既有 API 弃用和异常传播告警 |
| 复制菜单设备检查 | 记录三模式共 11 个进制行菜单可见；时长调整后抽查三条渲染路径，短按不弹、长按弹出且可再次打开 | [键盘修复说明](./2026-09-29-base-keyboard-polish.md) |

维护者另反馈复制菜单手动测试通过、长按时长与触感调整效果正常。自动化菜单检查未点击复制项，不能将其记为设备剪贴板内容验证。

### 本次合并文档核对

- 根据 `git log main..HEAD`、`git diff main...HEAD`、当前源码和专题记录整理最终行为。
- 检查本文相对文件链接与 `git diff --check`。
- 本次仅修改文档，未重新运行核心测试、编译、构建、安装或设备 UI 场景。

### 仍未完整覆盖

- 合并后全量回归，以及 API 23 回退、API 26 双渲染、深浅色、大字体、窄屏/横屏的完整设备矩阵。
- 真机快速连续切换面板时的动画、触摸与无障碍行为。
- 剪贴板授权拒绝/撤回后的完整设备流程、三模式复制文本的逐项设备比对和发布签名核验。
- `numeric-ui-smoke.json`、`base-keyboard-panel-smoke.json` 等新增设备场景的完整执行；场景文件存在或静态检查通过不代表设备测试已通过。

## 主要文件

- [BaseConverter.ets](../../entry/src/main/ets/components/exchange/base/BaseConverter.ets)：三模式装配、顶栏、输入行、帮助、复制粘贴及键盘升降。
- [BaseKey.ets](../../entry/src/main/ets/components/exchange/base/BaseKey.ets)、[BaseInspector.ets](../../entry/src/main/ets/components/exchange/base/BaseInspector.ets)：单键显示与位/编码/字段面板。
- [BaseConversionSession.ets](../../entry/src/main/ets/utils/base/BaseConversionSession.ets)、[BaseConversionState.ets](../../entry/src/main/ets/utils/base/BaseConversionState.ets)：会话、设置及历史恢复。
- [NumericValue.ets](../../entry/src/main/ets/utils/base/NumericValue.ets)、[NumericSession.ets](../../entry/src/main/ets/utils/base/NumericSession.ets)：精确数值换算与草稿。
- [IEEE754.ets](../../entry/src/main/ets/utils/base/IEEE754.ets)、[FloatExpression.ets](../../entry/src/main/ets/utils/base/FloatExpression.ets)、[BinaryDisplay.ets](../../entry/src/main/ets/utils/base/BinaryDisplay.ets)：浮点运算与二进制分行。
- [module.json5](../../entry/src/main/module.json5)：剪贴板权限声明；[string.json](../../entry/src/main/resources/base/element/string.json)：权限用途、帮助及交互文案。
- [test-numeric.mjs](../../tools/test-numeric.mjs)、[test-programmer.mjs](../../tools/test-programmer.mjs)、[Numeric.test.ets](../../entry/src/test/Numeric.test.ets)、[Programmer.test.ets](../../entry/src/test/Programmer.test.ets)：核心与会话回归。

## 发布说明素材

进制转换新增“数值”模式，支持不限固定字长的大整数、正负数和小数换算，保留精确原值并标记近似结果。IEEE754 新增按所选格式舍入的四则运算与实时预览。优化悬浮模式栏、帮助弹窗、32 位二进制分行和键盘字体；位、编码及浮点字段面板支持键盘自动升降。统一进制数值长按复制，缩短触发时间并加入触感反馈，完善普通粘贴按钮的授权与 Toast 提示。当前输入仍仅在进程内保留，跨重启恢复将在后续提供。

---

[返回分支变更说明规范](./README.md)
