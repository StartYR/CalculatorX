# 完整项目目录

[← 返回架构主文档](../ARCHITECTURE.md)

本文档以单一树形结构展示 CalculatorX 的工程目录。业务源码和关键配置展开到文件级；文档、字体、图标、第三方依赖和生成产物等非核心目录只说明用途，不展开内部文件。


```text
CalculatorX/
├── .github/                               # GitHub 社区治理：行为准则、安全策略、Issue 模板
├── AppScope/                              # HarmonyOS 应用级配置：Bundle、版本、全局字符串与应用图标
├── docs/                                  # 📚 项目文档：架构、规划、变更日志、贡献指南与技术审查
├── hvigor/                                # Hvigor 构建系统配置
├── entry/                                 # 📦 主 HAP 模块
│   ├── build-profile.json5                # entry 模块构建配置
│   ├── hvigorfile.ts                      # entry 模块 Hvigor 脚本
│   ├── obfuscation-rules.txt              # ArkTS 混淆规则
│   ├── oh-package.json5                   # entry 模块依赖声明
│   ├── src/
│   │   ├── main/
│   │   │   ├── ets/                       # 📱 ArkTS 前端逻辑与视图层
│   │   │   │   ├── entryability/
│   │   │   │   │   └── EntryAbility.ets  # 应用入口：偏好初始化、主题应用、主页加载、全屏布局与导航条避让
│   │   │   │   ├── entrybackupability/
│   │   │   │   │   └── EntryBackupAbility.ets
│   │   │   │   │                         # 备份扩展能力（当前为基础实现）
│   │   │   │   │
│   │   │   │   ├── pages/                # 🧭 全局页面与骨架层（Shell）
│   │   │   │   │   ├── Index.ets         # 主枢纽：动态挂载插件、全局事件、侧边栏和历史抽屉
│   │   │   │   │   ├── DocViewer.ets     # 文档查看器：隐私政策、用户协议等应用内文档
│   │   │   │   │   ├── HelpDocs.ets      # 帮助页面：加载 rawfile/docs 的 Nextra 静态站点
│   │   │   │   │   ├── history/
│   │   │   │   │   │   └── HistoryManager.ets
│   │   │   │   │   │                     # 全局历史页：分类检索、图文展示、复制与删除
│   │   │   │   │   └── settings/
│   │   │   │   │       ├── Settings.ets  # 设置主页：主题、角度、触感、格式、精度与启动页
│   │   │   │   │       ├── About.ets     # 关于页面：版本、许可与开发者信息
│   │   │   │   │       └── Credits.ets   # 鸣谢页面：第三方库与贡献者
│   │   │   │   │
│   │   │   │   ├── components/           # 🧩 业务插件与共享 UI 组件
│   │   │   │   │   ├── ScientificCalc.ets
│   │   │   │   │   │                     # 科学计算器：Shift 双层键盘、三角/微积分/排列组合等
│   │   │   │   │   ├── BasicCalc.ets     # 基础计算器：四则、百分数、Ans、连续退格
│   │   │   │   │   ├── MatrixCalc.ets    # 矩阵插件：1×1–6×6 模板与线性代数运算
│   │   │   │   │   ├── EquationSolver.ets
│   │   │   │   │   │                     # 方程求解：2–6 行方程组，支持 x/y/z/u/v/w 六个未知数
│   │   │   │   │   ├── StatisticsCalc.ets
│   │   │   │   │   │                     # 统计分析插件（占位，开发中）
│   │   │   │   │   ├── UnitConverter.ets # 单位转换插件（占位，开发中）
│   │   │   │   │   ├── FormulaScreen.ets # 双 WebView 中枢：按键分发、计算调度、显示与历史入库
│   │   │   │   │   ├── TopBar.ets        # 顶栏：菜单、撤销/重做、状态岛和历史入口
│   │   │   │   │   ├── SideBarMenu.ets   # 侧边栏：模块分组、手势关闭与弹性回弹
│   │   │   │   │   ├── HistorySheet.ets  # 当前模块历史半模态抽屉
│   │   │   │   │   ├── PrivacyDialog.ets # 隐私协议确认弹窗
│   │   │   │   │   │
│   │   │   │   │   ├── common/           # 🧱 通用 UI 与交互积木
│   │   │   │   │   │   ├── KeyGestureWrapper.ets
│   │   │   │   │   │   │                 # 按键手势基座：连续触发、菜单、滑动气泡、Shift 等策略
│   │   │   │   │   │   ├── UniversalHistoryList.ets
│   │   │   │   │   │   │                 # 通用历史列表：日期分组、图文混排、回填与滑动删除
│   │   │   │   │   │   └── MenuComponents.ets
│   │   │   │   │   │                     # 无状态菜单积木：标题、分隔线、按钮与分组容器
│   │   │   │   │   │
│   │   │   │   │   ├── graphing/         # 📈 函数图像子系统：五种类型、最多十条叠加
│   │   │   │   │   │   ├── GraphingCalc.ets
│   │   │   │   │   │   │                 # 顶层枢纽：状态、事件、图例与 Sheet 生命周期
│   │   │   │   │   │   ├── GraphingCanvas.ets
│   │   │   │   │   │   │                 # Canvas 绘图、Float64Array、Pan/Pinch 与帧率节流
│   │   │   │   │   │   ├── GraphingEditSheet.ets
│   │   │   │   │   │   │                 # 函数 CRUD、焦点、定义域与类型选择
│   │   │   │   │   │   ├── GraphingKeyboard.ets
│   │   │   │   │   │   │                 # 动态变量键盘、Shift 层与定义域数字键盘
│   │   │   │   │   │   └── GraphingTypes.ets
│   │   │   │   │   │                     # FunctionType 与 GraphFunctionItem 类型
│   │   │   │   │   │
│   │   │   │   │   └── exchange/         # 🔄 转换类插件
│   │   │   │   │       ├── BaseConverter.ets
│   │   │   │   │       │                 # 进制转换插件（占位，开发中）
│   │   │   │   │       └── rates/        # 💱 汇率换算子系统
│   │   │   │   │           ├── ExchangeRate.ets
│   │   │   │   │           │             # 主控制器：交叉换算、联网刷新、缓存、列表增删排序
│   │   │   │   │           ├── ExchangeKeyboard.ets
│   │   │   │   │           │             # 汇率专属数字键盘：金额、AC、退格、确定与收起
│   │   │   │   │           ├── CurrencySelector.ets
│   │   │   │   │           │             # 货币选择器：搜索、常用分组、A-Z 索引与高亮
│   │   │   │   │           ├── CurrencyData.ets
│   │   │   │   │           │             # 172 种货币/资产：代码、名称、符号与搜索关键词
│   │   │   │   │           └── ExchangeTypes.ets
│   │   │   │   │                         # CurrencyListItem 与 API 响应类型
│   │   │   │   │
│   │   │   │   ├── utils/                # 🧠 核心服务、配置与纯逻辑
│   │   │   │   │   ├── EngineService.ets # LaTeX 清洗、JS 注入、MathJSON 与 N-API 调度
│   │   │   │   │   ├── InputTranslator.ets
│   │   │   │   │   │                     # 70+ ActionID → 标准 LaTeX，含排列组合样式
│   │   │   │   │   ├── HapticUtils.ets   # Auto/Sharp/Soft/Hard 四档触感曲线
│   │   │   │   │   ├── CalculatorConfigs.ets
│   │   │   │   │   │                     # 图标、按键视觉、路由与 PreferenceConfigs
│   │   │   │   │   ├── PreferenceManager.ets
│   │   │   │   │   │                     # Preferences 读写、落盘与 AppStorage 批量注入
│   │   │   │   │   ├── ApiConfig.ets     # 本地汇率 API 配置
│   │   │   │   │   ├── ApiConfig.template.ets
│   │   │   │   │   │                     # 可公开复用的 API 配置模板
│   │   │   │   │   └── Logger.ets        # ArkTS hilog 日志门面
│   │   │   │   │
│   │   │   │   └── database/
│   │   │   │       └── HistoryRepository.ets
│   │   │   │                             # RDB：建表/索引、去重、每模块100条、查询与删除
│   │   │   │
│   │   │   ├── cpp/                      # ⚙️ C++ 计算机代数与图像采样引擎
│   │   │   │   ├── CMakeLists.txt        # N-API 构建：静态链接 Giac、SymEngine、Boost 与 GMP
│   │   │   │   ├── engine.cpp            # N-API calculate()：模式路由、精度分发与 ArrayBuffer 返回
│   │   │   │   ├── core/
│   │   │   │   │   ├── parser.cpp/.h     # MathJSON → SymEngine 递归解析与特殊节点处理
│   │   │   │   │   ├── MatrixParser.cpp/.h
│   │   │   │   │   │                     # 矩阵 AST → 二维结构 → Giac 指令
│   │   │   │   │   ├── giac_bridge.cpp/.h
│   │   │   │   │   │                     # 积分、极限、方程、矩阵与 Romberg 降级
│   │   │   │   │   ├── GraphingEngine.cpp/.h
│   │   │   │   │   │                     # RPN 虚拟机、自适应采样与 Marching Squares
│   │   │   │   │   └── ErrorHandler.h   # 六类业务错误码与前端消息映射
│   │   │   │   ├── utils/
│   │   │   │   │   ├── FastMath.cpp/.h  # 超大阶乘/幂的数量级与科学记数法节点
│   │   │   │   │   ├── FormatUtils.cpp/.h
│   │   │   │   │   │                     # DMS、分数、浮点、方程和全局 LaTeX 格式化
│   │   │   │   │   └── Logger.h         # C++ hilog 日志宏
│   │   │   │   ├── include/              # nlohmann/json 与 GMP 头文件
│   │   │   │   ├── libs/arm64-v8a/       # GMP 预编译静态库
│   │   │   │   ├── third_party/          # Giac、SymEngine、Boost 固定版本源码包
│   │   │   │   └── types/libentry/
│   │   │   │       ├── Index.d.ts        # ArkTS 侧 N-API 类型声明
│   │   │   │       └── oh-package.json5
│   │   │   │
│   │   │   ├── resources/                # 🎨 HarmonyOS 资源与本地 Web 沙箱
│   │   │   │   ├── base/                 # 通用颜色、尺寸、字符串、媒体与页面配置
│   │   │   │   ├── dark/                 # 深色模式颜色资源
│   │   │   │   └── rawfile/
│   │   │   │       ├── calculator.html   # MathLive 输入/结果、自适应字号与光标追踪
│   │   │   │       ├── render.html       # 离屏公式截图：html2canvas → Base64 → ArkTS
│   │   │   │       ├── compute-engine.min.js
│   │   │   │       │                     # MathJSON Compute Engine
│   │   │   │       ├── mathlive.min.js   # MathLive 公式编辑与排版
│   │   │   │       ├── html2canvas.min.js
│   │   │   │       │                     # HTML → Canvas 截图库
│   │   │   │       ├── mathlive-fonts.css
│   │   │   │       ├── mathlive-static.css
│   │   │   │       ├── fonts/            # Cambria Math 与 KaTeX 数学字体
│   │   │   │       ├── icons/            # 数学、矩阵、方程和菜单 SVG 图标
│   │   │   │       ├── help/             # 应用内帮助图片
│   │   │   │       └── docs/             # Nextra 静态帮助站点（HTML、图片与 _next 产物）
│   │   │   │
│   │   │   └── module.json5              # Ability、设备类型、页面与网络/振动权限声明
│   │   │
│   │   ├── mock/                          # Native 模块 Preview/Mock 配置
│   │   ├── test/                          # 本地 ArkTS 单元测试
│   │   └── ohosTest/                      # HarmonyOS 设备测试模块
│   │
│   ├── .cxx/                              # CMake/Native 构建缓存与解压依赖（自动生成）
│   └── .idea/                             # entry 模块 IDE 元数据
│
├── .clang-tidy                            # C/C++ 静态检查规则
├── .clangd                                # clangd 配置
├── .gitignore                             # Git 忽略规则
├── build-profile.json5                    # 工程级产品、签名与模块构建配置
├── build-profile.json5.template           # 可公开复用的构建配置模板
├── code-linter.json5                      # ArkTS/ETS 代码检查规则
├── hvigorfile.ts                          # 工程级 Hvigor 构建脚本
├── local.properties.template              # 本地 SDK/工具链路径模板
├── oh-package.json5                       # 工程依赖声明
├── oh-package-lock.json5                  # 工程依赖锁文件
├── README.md                              # 项目介绍、功能与构建说明
├── LICENSE                                # 开源许可证
├── oh_modules/                            # OHPM 安装依赖（自动生成）
├── .hvigor/                               # Hvigor 构建缓存（自动生成）
├── .idea/                                 # IDE 工程元数据
└── .git/                                  # Git 仓库内部数据
```

---

[← 返回架构主文档](../ARCHITECTURE.md)
