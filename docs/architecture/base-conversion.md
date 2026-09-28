# 进制转换

[返回架构文档](../architecture.md) · [实施计划](../plan/programmer-mode-implementation.md)

进制转换模块提供“数值”“整数”“IEEE 754”三个标签，分别用于普通进制换算、固定字长运算和浮点位模式分析。新会话默认使用“数值”，已有偏好与历史仍恢复记录的标签。核心回归、ArkTS 单元测试和 debug 构建已通过，设备交互与视觉验收仍待完成。

## 模块结构

| 文件 | 职责 |
| --- | --- |
| `components/exchange/base/BaseConverter.ets` | 页面、按模式选择键盘布局、历史与双渲染容器 |
| `components/exchange/base/BaseKey.ets` | 单键公共表面、长按菜单与连续退格 |
| `components/exchange/base/BaseInspector.ets` | 位编辑、编码对照、浮点字段与帮助 |
| `utils/base/BinaryDisplay.ets` | 三种模式共用的二进制 32 位分行规则 |
| `utils/base/Natural.ets` | 低位在前的 bit 数组和精确非负整数算术 |
| `utils/base/IntegerEngine.ets` | 固定字长 Word、标志位、算术和编码 |
| `utils/base/IntegerExpression.ets` | ASCII token、括号与优先级求值 |
| `utils/base/Ieee754.ets` | 精确十进制舍入、浮点四则运算、字段解析和格式转换 |
| `utils/base/FloatExpression.ets` | 浮点十进制表达式、优先级与逐节点舍入 |
| `utils/base/NumericValue.ets` | 有符号精确有理数、四进制小数长除与近似标记 |
| `utils/base/NumericSession.ets` | 数值草稿、结果缓存、精确原值与输入进制切换 |
| `utils/base/BaseConversionSession.ets` | 独立模式草稿、确认与配置切换 |
| `utils/base/BaseConversionState.ets` | 设置、进程内会话与版本化历史 |

模块共用会话与状态使用 `BaseConversion` 前缀，固定字长运算与表达式使用 `Integer` 前缀。`BaseKey` 只持有单键交互；键盘布局、沉浸开关与 API 保护仍由 `BaseConverter` 管理。

核心不依赖 ArkUI、WebView、CAS 或 N-API。整数模式字长最多 64 位；数值模式没有固定字长，输入长度上限为 256 字符。bit 数组便于直接表达进位、移出位和符号扩展；双 32 位需要额外处理 JS 有符号位运算，十进制字符串则不便逐位编辑。完整 64 位整数不存入 `number`；只有 bit、索引和不超过 53 位的浮点有效数字临时转换使用 `number`。

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

支持 binary16 / binary32 / binary64，输入可选十进制、HEX 或 BIN 原始位串。浮点专属键盘支持指数、正负号、Infinity、NaN 和加减乘除；按 `=` 确认。十进制模式支持四则表达式，粘贴也支持括号；HEX/BIN 只接收原始位串，禁用算术键。

十进制先解析为精确有理数，再以 roundTiesToEven 直接舍入。格式转换根据有效数字和二进制指数完成，不经过简短十进制显示。同格式切换保留 payload；跨格式 NaN 生成同符号的规范 quiet NaN。

字面量先按当前格式编码，每个二元节点按 roundTiesToEven 独立舍入；乘除优先于加减，同级左结合。有限数的中间值由精确整数和二进制指数构造，不经过宿主 binary64 算术。溢出产生同符号无穷，下溢支持非正规数与带符号零；非零除零得到带符号无穷，`0/0`、`∞/∞`、`0×∞` 和异号无穷相加得到规范 quiet NaN。参与四则运算的 NaN 同样规范化，不模拟浮点异常标志。

新数字替换已确认结果，二元运算接续结果，重复 `=` 不重复计算。`e` 后的正负号属于指数；`±` 改变末尾操作数，未完成指数时切换指数符号。已确认值的 `±` 直接翻转符号位，保留 NaN payload。切换进制、格式或位编辑仍先确认草稿。

十进制表达式或 HEX/BIN 草稿有效时，DEC/HEX/BIN、分类、位与字段面板同步预览；`1e`、`1e-`、末尾运算符和超宽位串保留最近有效预览，并提示继续输入或修正。`floatText` 保存草稿，`floatPreviewBits` 保存最近有效预览，`floatBits` 只保存已确认结果；显示统一通过 `displayedFloatBits()` 读取。预览不写历史，不覆盖确认的 NaN payload。浮点粘贴同样先预览，按 `=` 才确认；原始位编辑与已确认值变号仍直接更新位串。

字段面板显示符号、存储指数、偏置、实际指数、尾数、有效数字形式和精确的“整数 × 2 的幂”解释。分类包括正负零、正规/非正规数、无穷、quiet/signaling NaN。位编辑切换至 HEX 以保留 payload。不同字段采用不同颜色，64 位数据可滚动、复制和编辑。

## 数值换算

- 支持 HEX / DEC / OCT / BIN 的正负数和有限小数，例如 `-FF.A`（HEX）对应 `-255.625`（DEC）。完整数值不经过 `number`，整数部分不截断至 64 bit。
- 输入只接受当前进制数字、一个小数点和开头的正负号；最多 256 字符。支持 `.5`、`1.`、小写 HEX 粘贴，不接受进制前缀、指数、分数或算术表达式；HEX 的 `E` 是数字。
- 输入值表示为带独立符号的 `Natural` 分子/分母。按输入进制及小数位数构造分母，长除生成各目标进制的位数，原值始终精确保留。
- 小数显示上限可选 16 / 32 / 64 / 128 位，默认为 32。循环小数及超过上限的有限小数向零截断，显示 `≈` 与省略号。整数部分完整保留；数值行右对齐并自动换行，支持长按复制。
- 数值模式不显示顶部表达式栏，当前进制行直接显示输入草稿（含负号、小数点）；其他进制实时换算，无效草稿时保留最近有效结果并显示未完成提示。数值键盘不提供 `=`；切换进制后输入数字替换结果；`±` 改变精确原值的符号，AC 只清空数值标签。
- 切换进制与显示位数不重新解析近似文本。当前目标进制是近似显示时禁止直接退格，可点“编辑原值”回到原输入进制编辑，或直接输入新数值。复制出的近似标记也不会被当成有效输入接收。
- 四种显示结果在值或精度改变时缓存，组件重绘与进制切换复用结果。会话快照同时保留草稿、预览、原始输入和显示配置，三个标签互不覆盖。

## 界面与兼容

显示区滚动，键盘固定在底部；整数与 IEEE 为五列六行，数值键盘为四列五行。位视图、编码、帮助默认折叠。三个标签分别维护草稿与配置；数值页隐藏表达式栏、字长、符号解释、标志位与位编辑控件。IEEE 格式使用 binary16 / binary32 / binary64 下拉菜单。三个标签的滚动条隐藏，保留滚动与回弹。IEEE 顶部编辑文本不自动补高位零，HEX/BIN 结果行仍按位宽补零。

三个标签的 BIN 均按每 32 个二进制数字显式分行，每组独立单行并按可用宽度缩放字形，不依赖自然换行。符号、小数点与近似标记不计入位数；末行不足 32 位时不补零。长按二进制内容可复制不含排版换行的完整文本。

遵循[双渲染架构](keyboard-dual-rendering.md)：页面直接检查 API 26，订阅 `KEY_KEY_IMMERSIVE_MATERIAL`；启用时在横向单 Tab 底部 TabBar 挂载键盘。API 23–25 或关闭开关时走传统 Column。按键统一使用 `KeyboardKeySurface`，业务层不创建材质，不跨组件转交整页 Builder。

按键主文字居中，长按提示通过独立底部图层显示；退格复用公共 SVG。字体颜色由 `BaseKey.keyFontColor` 独立决定，不改变按键背景角色，具体分级与验证见[键盘显示修复](../changes/2026-09-29-base-keyboard-polish.md)。

## 状态与历史

- `KEY_PROGRAMMER_SETTINGS`（`programmer.settings.v1`）保存模式、整数进制/字长/符号、浮点格式/进制、数值输入进制/小数显示位数；缺失数值配置的旧设置恢复为十进制与 32 位小数，不落盘草稿、错误和 C-in。
- `BaseConversionMemory` 在进程内保留模块往返会话。撤销/重做最多 50 个快照，包含各模式草稿、预览有效性、最近预览值和数值精确来源；离开组件后撤销栈清空。
- 整数与 IEEE 确认成功写 RDB；数值键盘无确认键，当前不主动新增历史，但兼容已有记录恢复。`module_type=base`。`extra_params` 使用 `kind=programmer, version=2`（兼容读取版本 1），包含配置、位模式、输入、整数标志和 C-in；非活动整数模式保存最近有效值，非活动浮点模式保存最近确认结果。数值模式保存最近有效的 `numericSourceText` 和 `numericSourceRadix`，恢复时重建精确有理数；浮点预览与无效草稿不进入版本化历史。版本 2 缺失或损坏的数值来源会被拒绝。
- 相同表达式在不同上下文中不会被去重；表结构不变，无迁移。全局“转换”分类包括 `conversion,base`。
- 顶栏历史通过 `event_programmer_restore` 传递完整记录。点输入恢复表达式及配置，点输出恢复结果，浮点以 HEX 回填以保留 payload。数值恢复原有显示进制和精确来源，“编辑原值”可回到来源进制。全局历史页仍使用复制行为。

## 验证与定位

```powershell
node tools/test-programmer.mjs
node tools/test-numeric.mjs
pwsh -NoProfile -File tools/test-programmer-cli.ps1
pwsh -NoProfile -File tools/check-keyboard-architecture.ps1
```

宿主机测试需要 Node.js 24，以内置类型擦除执行纯 `.ets` 核心，使用 BigInt / DataView 独立参照。不能代替 ArkTS 编译。ArkTS 用例在 `entry/src/test/Programmer.test.ets` 和 `Numeric.test.ets`，均已注册现有套件。

debug 下 `base.programmer` 的 accessibilityDescription 提供 `{ data, error, integerConfirmed, floatConfirmed, numericConfirmed, numericInput, numericPreviewValid }`。CLI `screen get` 返回 `programmer` 字段，其他模块返回 null；release 不暴露机器 JSON。设备场景为 `tools/calcx/tests/scenarios/` 下的 `programmer-ui-smoke.json` 与 `numeric-ui-smoke.json`，尚未在设备执行。

计算问题检查核心/会话测试；显示不同步检查 `BaseConversionSession`；历史恢复检查 `extra_params`；光感检查 API、偏好、TabBar 区域与公共表面。API 26 双开关、API 23 回退、深浅色、小窗口、长按和历史操作仍需设备验收。

### 2026-09-28 增量验证

IEEE 四则运算与预览已通过宿主核心测试 259,706 项断言、模块 CodeLinter、CLI 静态检查、键盘架构检查和 `entry:default@CompileArkTS`（含资源编译）。新增 ArkTS 单元用例尚未在 Hypium 运行。编译有异常传播提示及既有 API 弃用/权限警告；未做 HAP 打包或设备验收。

### 2026-09-29 数值模式验证

数值核心与会话通过 5,982 项宿主断言，既有程序员测试通过 259,706 项断言；`entry@default/debug test` 共 16 项通过，0 failure / error。`entry@default/debug assembleHap`、模块 CodeLinter、键盘架构与 CLI 静态检查通过。设备侧点击、长按、窄屏换行与双渲染路径尚未验收。
