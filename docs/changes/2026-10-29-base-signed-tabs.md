# 整数符号解释双选项切换

- 状态：实现与静态检查完成，待真机视觉验收
- 类型：界面优化
- 分支：`feature/base-conversion-2`
- 完成日期：2026-10-29

## 用户可见行为

整数模式将原来的单个符号切换按钮改为“有符号 / 无符号”胶囊切换栏，同时展示两个选项，当前项高亮。选项复用顶部模式栏的 `BaseChip`、等宽布局和选中配色，控件保持在字长与位/编码按钮所在行。API 26.0.0 及以上使用与顶部模式栏相同的交互式沉浸光感。

点击另一项沿用原有符号解释切换流程；重复点击当前项只保留按键反馈，不确认草稿、不新增撤销记录。计算核心、位模式及设置保存逻辑未修改。

## 实现与兼容

- 选中态直接来自 `session.signed`，不新增独立 UI 状态。
- 光感表面复用 `baseToolbarVisualModifier` 与 `createTopBarMaterial()`，和顶部模式栏一样独立于键盘光感开关。
- 控制行在 API 26.0.0 正向分支内挂载到局部横向底部 TabBar，提供材质生效区域。上下预留阴影空间，外层保持原控制行高度并关闭裁切，避免扩大内容间距。
- API 23–25 直接渲染普通控制行，由已有 Modifier 回退到系统背景、边框及阴影，不创建沉浸材质；最低兼容版本不变。
- CLI 的 `base.signed` 改为明确选择有符号，不再反转状态；新增 `base.unsigned` 明确选择无符号，白名单及操作说明同步更新。重复调用同一目标不会再次切换。

## 验证

- `BaseConverter.ets` 的 CodeLinter 检查完成，三个 agent 均为 0 项诊断。
- `tools/test-programmer-cli.ps1` 通过，覆盖两个选择目标的白名单与既有场景静态检查；未执行设备操作。
- `git diff --check` 通过。
- 加入光感后的 `BaseConverter.ets` 再次通过 CodeLinter，三个 agent 均为 0 项诊断；对照顶部模式栏核对了直接 API 保护、低版本分支和材质调用。
- 本次未运行编译或构建。真机光感、阴影边界、滚动触摸、低版本回退及窄屏和大字体下同行布局仍需验收。

## 主要文件

- [BaseConverter.ets](../../entry/src/main/ets/components/exchange/base/BaseConverter.ets)
- [Invoke-CalcXUi.ps1](../../tools/calcx/runtime/commands/Invoke-CalcXUi.ps1)
- [CLI 操作说明](../calculation-cli-automation.md)

## 发布说明素材

整数模式改用“有符号 / 无符号”双选项切换栏，当前解释方式更直观，可直接选择目标模式；API 26 加入与顶部模式栏一致的沉浸光感，低版本保留传统外观。
