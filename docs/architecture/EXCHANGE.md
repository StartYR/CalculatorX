# 汇率架构

汇率换算是独立的 ArkTS 网络业务模块。它不使用 FormulaScreen、MathJSON 或 C++ CAS，而是在本地对远端汇率字典进行交叉换算。

## 1. 组件结构

```text
ExchangeRate
├── CurrencySelector       # 搜索、分组、索引和选择
├── ExchangeKeyboard       # 金额输入
├── CurrencyData           # 172 种货币/资产白名单
├── ExchangeTypes          # 列表项与响应类型
├── HarmonyOS HTTP         # 汇率 API
├── Network Connection     # 联网状态检测
└── PreferenceManager      # 列表、金额、汇率和时间戳
```

文件位于 [components/exchange/rates/](../../entry/src/main/ets/components/exchange/rates/)：

- `ExchangeRate.ets`：顶层控制器、换算、网络和列表状态
- `CurrencySelector.ets`：大型半模态货币选择器
- `ExchangeKeyboard.ets`：4×4 数字键盘
- `CurrencyData.ets`：代码、中文名、符号和关键词
- `ExchangeTypes.ets`：`CurrencyListItem`、`ExchangeApiResponse`

## 2. 初始化

`ExchangeRate.aboutToAppear()` 顺序执行：

```text
loadData()
  → 读取货币列表、activeId 和 baseAmount
  → 读取 rateMap
  → 读取 lastUpdateTimeStamp
  → 格式化更新时间

handleRefresh()
  → 检查网络和缓存
  → 必要时请求最新数据
```

货币列表为空或 JSON 损坏时恢复默认值：USD、CNY、HKD、EUR、GBP、JPY、KRW。默认金额为 100，默认活动列表项 ID 为 `1`。

## 3. 换算模型

远端汇率字典以 USD 为共同基准。当前活动卡片是输入货币，其余卡片实时显示目标金额：

```text
amountInUSD = inputAmount / rateFrom
result      = amountInUSD * rateTo
```

USD 汇率显式视为 1。输出使用 `toFixed(4)` 后再转回 number/string，以保留最多四位小数并去掉尾随零。

切换活动卡片时，先计算该卡片当前显示值，将其反写为新的 `baseAmount`，再切换 `activeId`，从而避免数值跳变。

若缓存中缺少某项汇率，当前实现以 1 作为兜底，因此排查异常数值时应优先检查 `rateMap` 是否包含目标代码。

## 4. 网络刷新状态机

[ExchangeRate.ets](../../entry/src/main/ets/components/exchange/rates/ExchangeRate.ets) 的 `handleRefresh()` 是唯一刷新入口。

```text
已经 refreshing？──是──► 返回
        │否
        ▼
connection.hasDefaultNetSync()
        │
        ├── 缓存同一自然小时 + 明确有网 ──► 反馈更新成功，不发真实请求
        ├── 明确无网 ──► 保留缓存，反馈失败
        └── 缓存过期/探网异常 ──► HTTP 真实请求
                                      │
                                      ├── 成功：替换 rateMap、持久化、更新时间
                                      └── 失败：保留缓存、状态文字 + Toast
```

### 请求参数

- API：`https://api.startyi.com/rates`
- 方法：GET
- 鉴权：`x-token` 请求头
- Token 来源：[ApiConfig.ets](../../entry/src/main/ets/utils/ApiConfig.ets)
- 连接超时：10 秒
- 读取超时：10 秒

`module.json5` 声明：

- `ohos.permission.INTERNET`
- `ohos.permission.GET_NETWORK_INFO`

### 缓存有效性

`isCacheValid()` 比较当前时间与 `lastUpdateTimeStamp` 的年、月、日和小时。两者处于同一自然小时即命中缓存；跨整点后下一次刷新执行真实请求。

成功或缓存命中反馈通过 `commitUpdateState()` 统一提交：更新时间戳、刷新顶部时间、显示成功/失败文字，并在失败时弹出 Toast。

## 5. 货币白名单

[CurrencyData.ets](../../entry/src/main/ets/components/exchange/rates/CurrencyData.ets) 包含 172 种条目，覆盖法定货币、BTC、贵金属和特别提款权等资产。

每个 `CurrencyInfo` 包含：

| 字段 | 用途 |
|------|------|
| `code` | API 和列表使用的代码 |
| `name` | 中文显示名称 |
| `symbol` | 金额前缀和圆形图标 |
| `keywords` | 国家、英文名和常用别称搜索 |

加载时构造 `CURRENCY_MAP`，供主列表按代码 O(1) 查询名称和符号。

## 6. CurrencySelector

[CurrencySelector.ets](../../entry/src/main/ets/components/exchange/rates/CurrencySelector.ets) 通过 `bindSheet` 以大型半模态页挂载。

默认状态：

- 11 种常用货币分组
- 按代码首字母生成 A-Z 分组
- AlphabetIndexer 与列表滚动双向联动
- 当前货币高亮并显示勾选

搜索状态同时匹配：

- 货币代码
- 中文名称
- 符号
- 中英文关键词和常用别称

纯英文/数字搜索使用连续匹配；其他输入使用按字符模糊正则。构造正则前会转义特殊字符，异常时降级为 `includes()` 搜索。

搜索框获得焦点后增加列表底部避让空间；搜索状态隐藏右侧字母索引。

## 7. 主列表交互

每张货币卡片包含：

- 左侧代码选择按钮
- 中文名称
- 货币符号和实时金额
- 当前输入态高亮

支持：

- 点击金额区域切换活动输入货币并唤起键盘
- 添加新项并立即打开选择器
- 左滑删除
- 长按拖拽排序
- 自动滚动活动卡片到可视区域中央
- 用户手动滚动时收起键盘

拖拽期间原列表项透明化，并使用复制卡片作为跟手反馈；Drop 后保存最终顺序。

## 8. ExchangeKeyboard

[ExchangeKeyboard.ets](../../entry/src/main/ets/components/exchange/rates/ExchangeKeyboard.ets) 的有效网格为四行四列，`0` 横跨两列。按键包括：

- 0–9
- 小数点
- AC
- 退格
- 确定
- 收起键盘

输入限制：

- 仅允许一个小数点
- 最长 15 个字符
- 退格到空时恢复 `0`
- 连续输入采用 500ms 防抖写盘

按键复用 KeyGestureWrapper、CalculatorConfigs 视觉函数和 HapticUtils。

## 9. 持久化

| Key | 类型 | 内容 |
|-----|------|------|
| `KEY_EXCHANGE_CURRENCY_LIST` | JSON string | 列表与排序 |
| `KEY_EXCHANGE_ACTIVE_ID` | string | 当前活动列表项 ID |
| `KEY_EXCHANGE_BASE_AMOUNT` | string | 输入金额 |
| `KEY_EXCHANGE_RATES` | JSON string | 最近成功获取的汇率字典 |
| `KEY_EXCHANGE_LAST_UPDATE` | number | 缓存时间戳 |

PreferenceManager 在应用启动时将这些值注入 AppStorage；ExchangeRate 初始化时读取，交互或刷新后落盘。

## 10. 修改边界

- 新增支持币种：修改 CurrencyData，并确认 API 返回对应代码。
- 修改 API：检查 ApiConfig、响应结构、超时、权限和缓存兼容性。
- 修改换算模型：确认远端基准币，保持活动卡片切换的数值连续性。
- 修改列表交互：同时验证 activeId、删除最后项、拖拽排序和键盘避让。
- 修改持久化结构：为旧 JSON/默认值保留兼容兜底。
