# 程序员模式

[返回架构文档](../architecture.md) · [实施计划](../plan/programmer-mode-implementation.md)

程序员模式首版包含固定字长整数和 IEEE 754 表示。普通数值转换尚未实现。核心回归、ArkTS 单元测试和 debug 构建已通过，设备交互与视觉验收仍待完成。

## 模块结构

| 文件 | 职责 |
| --- | --- |
| `components/exchange/base/BaseConverter.ets` | 页面、五列键盘、菜单、历史与双渲染容器 |
| `components/exchange/base/ProgrammerInspector.ets` | 位编辑、编码对照、浮点字段与帮助 |
| `utils/base/Natural.ets` | 低位在前的 bit 数组和精确非负整数算术 |
| `utils/base/ProgrammerEngine.ets` | 固定字长 Word、标志位、算术和编码 |
| `utils/base/ProgrammerExpression.ets` | ASCII token、括号与优先级求值 |
| `utils/base/Ieee754.ets` | 精确十进制舍入、字段解析和格式转换 |
| `utils/base/ProgrammerSession.ets` | 独立模式草稿、确认与配置切换 |
| `utils/base/ProgrammerState.ets` | 设置、进程内会话与版本化历史 |

核心不依赖 ArkUI、WebView、CAS 或 N-API。字长最多 64 位，bit 数组便于直接表达进位、移出位和符号扩展；双 32 位需要额外处理 JS 有符号位运算，十进制字符串则不便逐位编辑。完整 64 位整数不存入 `number`；只有 bit、索引和不超过 53 位的浮点有效数字临时转换使用 `number`。

## 整数操作

- HEX / DEC / OCT / BIN 同步显示，点击行切换输入进制。非十进制按字长补零；长值横向滚动，可复制。
- 8 / 16 / 32 / 64 bit 对应 BYTE / WORD / DWORD / QWORD。有符号采用补码。切换符号解释保持位模式；扩宽按符号设置扩展，缩窄保留低位并提示数值变化。
- 十进制正字面量允许同宽完整无符号位模式，再按符号设置解释；负字面量不能小于同宽补码最小值。无混合进制前缀。粘贴按当前进制解析。
- 优先级：括号 → 一元正负 / NOT → `* / MOD` → `+ - ADC SBB` → 移位 / 旋转 → AND → XOR → OR。每步按字长截断。有符号除法向零截断，余数符号跟随被除数。
- 新数字替换已确认结果，二元操作继续使用结果。重复 `=` 保持结果，不重复最后操作。退格编辑表达式，AC 清空当前模式。
- 不完整草稿保留最近有效值；确认时显示语法、范围和除零错误，不写历史。切换配置先确认草稿，失败时保留原配置。

### 键盘与标志

| 按键 | 长按能力 |
| --- | --- |
| AND | OR、XOR、NOT |
| SHL | ROL、RCL |
| SHR | SAR、ROR、RCR |
| + / − | ADC / SBB |
| 退格 | 连续删除 |

本版使用原生上下文菜单，以 `···` 提示副功能，没有自定义滑动气泡。

加减更新 CF / OF / ZF / SF；乘除、MOD、逻辑运算只定义 ZF / SF。减法 CF=1 表示借位。移位 CF 为最后移出的 bit；单步 SHL 的 OF 是结果符号与 CF 的异或，SHR 的 OF 为原符号位，SAR 的 OF=0，其余 OF 未定义。旋转只定义 CF，未定义标志显示 `—`。

普通移位计数达到字长后得到零或符号填充；循环按字长取模，带进位循环按字长+1 取模。计数为零保持此前已确认操作的标志。补码模式下解释为负数的计数被拒绝。C-in 独立保持，不自动接收 CF。这些规则不模拟特定 CPU。

位面板从高位到低位排列，每行一个 byte，点击翻转并同步表达式。编码面板区分“按数学值生成编码”和“将当前位模式解释为各编码”，展示负零、不可表示状态及范围。原码/反码不参与完整算术。

## IEEE 754

支持 binary16 / binary32 / binary64，输入可选十进制、HEX 或 BIN 原始位串。浮点专属键盘支持指数、正负号、Infinity 和 NaN；按 `=` 确认，不执行浮点四则运算。

十进制先解析为精确有理数，再以 roundTiesToEven 直接舍入。格式转换根据有效数字和二进制指数完成，不经过简短十进制显示。同格式切换保留 payload；跨格式 NaN 生成同符号的规范 quiet NaN。

字段面板显示符号、存储指数、偏置、实际指数、尾数、有效数字形式和精确的“整数 × 2 的幂”解释。分类包括正负零、正规/非正规数、无穷、quiet/signaling NaN。位编辑切换至 HEX 以保留 payload。不同字段采用不同颜色，64 位数据可滚动、复制和编辑。

## 界面与兼容

显示区滚动，键盘固定在底部；整数为五列六行。位视图、编码、帮助默认折叠。两种模式分别维护草稿、字长、进制和位模式。

遵循[双渲染架构](keyboard-dual-rendering.md)：页面直接检查 API 26，订阅 `KEY_KEY_IMMERSIVE_MATERIAL`；启用时在横向单 Tab 底部 TabBar 挂载键盘。API 23–25 或关闭开关时走传统 Column。按键统一使用 `KeyboardKeySurface`，业务层不创建材质，不跨组件转交整页 Builder。

## 状态与历史

- `KEY_PROGRAMMER_SETTINGS`（`programmer.settings.v1`）保存模式、整数进制/字长/符号、浮点格式/进制；不落盘草稿、错误和 C-in。
- `ProgrammerMemory` 在进程内保留模块往返会话。撤销/重做最多 50 个快照，离开组件后撤销栈清空。
- 确认成功写 RDB，`module_type=base`。`extra_params` 使用 `kind=programmer, version=1`，包含配置、位模式、输入、整数标志和 C-in；非活动模式只保存最近有效值。
- 相同表达式在不同上下文中不会被去重；表结构不变，无迁移。全局“转换”分类包括 `conversion,base`。
- 顶栏历史通过 `event_programmer_restore` 传递完整记录。点输入恢复表达式及配置，点输出恢复结果，浮点以 HEX 回填以保留 payload。全局历史页仍使用复制行为。

## 验证与定位

```powershell
node tools/test-programmer.mjs
pwsh -NoProfile -File tools/test-programmer-cli.ps1
pwsh -NoProfile -File tools/check-keyboard-architecture.ps1
```

宿主机测试需要 Node.js 24，以内置类型擦除执行纯 `.ets` 核心，使用 BigInt / DataView 独立参照。不能代替 ArkTS 编译。ArkTS 用例在 `entry/src/test/Programmer.test.ets`，已注册现有套件。

debug 下 `base.programmer` 的 accessibilityDescription 提供 `{ data, error, integerConfirmed, floatConfirmed }`。CLI `screen get` 返回 `programmer` 字段，其他模块返回 null；release 不暴露机器 JSON。设备场景为 `tools/calcx/tests/scenarios/programmer-ui-smoke.json`，尚未在设备执行。

计算问题检查核心/会话测试；显示不同步检查 `ProgrammerSession`；历史恢复检查 `extra_params`；光感检查 API、偏好、TabBar 区域与公共表面。API 26 双开关、API 23 回退、深浅色、小窗口、长按和历史操作仍需设备验收。
