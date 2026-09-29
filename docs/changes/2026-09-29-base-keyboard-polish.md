# 进制键盘显示与浮点输入修复

- 状态：实现与本地验证完成，待设备验收
- 类型：修复 / 界面优化
- 分支：`feature/base-convert`
- 完成日期：2026-09-29
- 关联：[进制转换架构](../architecture/base-conversion.md)

## 行为变化

- 整数键盘的长按提示独立贴近底部，主文字在按键中居中。提示层不拦截触摸。
- 三种模式的退格键复用公共 `icon_backspace.svg`，保留连续退格行为。
- IEEE 切换进制、编辑位时，顶部输入框使用不补零的原始位串；HEX/BIN 结果行仍按格式位宽补零。
- 字体颜色独立于背景角色：0–9、A–F 为主色；AC、退格、等号为白色；四则运算、MOD、AND、SHL、SHR 为强调色；其余为次要色。禁用键继续降低透明度。
- 三种模式隐藏滚动条，滚动和边缘回弹继续有效。

## 调整入口

`BaseKey.ets` 的 `LONG_PRESS_HINT_BOTTOM` 控制长按提示距底边的距离，当前为 2 vp；`keyFontColor` 维护字体分级。主文字与提示分别布局，调整提示距离不会移动主文字。

## 验证

- 程序员核心与会话：259,736 项断言通过，含 binary16/32/64 的短位串、零值、位编辑和历史恢复。
- ArkTS 本地测试：17 项通过，0 failure / error。
- debug `assembleHap`、相关 CodeLinter、键盘架构检查及差异空白检查通过。
- 构建保留既有 API 弃用、异常传播等警告。未执行真机视觉、长按交互或双渲染效果验收。

## 2026-09-30 底部间距修复

三模式共用键盘的底部内边距改为 `Math.max(0, this.navBarHeight - 8)`，去除额外叠加的 8 vp；导航栏较小时避免负间距。传统与沉浸布局共用此参数。模块 CodeLinter 与差异空白检查通过；未构建，实际底距待真机验证。

## 2026-09-30 复制菜单与字体

- 三模式的进制数值行统一长按弹出“复制完整数字”，复制对应进制的完整显示文本，不包含二进制排版换行；顶部表达式栏仍使用文本选择。
- 键盘仅 `0–9`、`A–F` 使用显示区同款 `monospace` 字体，运算符字号保持原配置。
- 唤起键盘按钮的 `△`、`⌨` 指定 `Cambria Math`；设备缺少该字体时由系统回退，未打包字体文件。
- `BaseConverter.ets` 的 `BASE_KEYBOARD_RESTORE_WIDTH`（144 vp）、`BASE_KEYBOARD_RESTORE_HEIGHT`（48 vp）分别控制可见宽高，`restoreButtonBottom()` 的 `Math.max(this.navBarHeight, 12) + 12` 控制底距。宽度同步用于阴影容器，高度同步用于滚动内容安全区。
- 初次修改通过 CodeLinter，但设备反馈菜单不弹出且 ArkTSCheck 报 UI 语法错误；已将三处普通箭头函数改为直接绑定 `RadixCopyMenu.bind(this, radix)`。修复后 CodeLinter、差异检查和 debug `assembleHap` 通过，并核对编译产物中的菜单绑定；尚未进行修复后的设备长按与复制验收。

## 发布说明素材

优化进制键盘文字居中、退格图标和字体层级，隐藏滚动条，并修复 IEEE 输入框自动补高位零的问题。
