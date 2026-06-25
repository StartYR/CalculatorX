# 🧑‍💻 CalculatorX 开发者协作规范 (Contributing Guide)

欢迎参与 CalculatorX 的开发！为了保证项目在不断扩展（如新增基础计算、函数图像、线性代数等模块）的过程中，依然保持高内聚、低耦合的优雅架构，所有提交的代码必须严格遵守以下规范。


## 🏗️ 1. 目录结构与隔离铁律

在 CalculatorX 中，`entry/src/main/ets` 下的目录有着极其严格的职责划分，**严禁跨级污染**。

- 🚫 **`pages/` (页面层)**：**绝对禁止**在这里编写具体的计算器 UI 逻辑。这里只允许存放全屏级别的容器骨架（如 `Index.ets`, `HistoryManager.ets`）。
- 🧩 **`components/` (业务与 UI 层)**：所有新的功能模块（如 `ScientificCalc.ets`, `BasicCalc.ets`）必须作为一个独立的组件放在这里。组件内部应实现完全闭环。
- 🧠 **`utils/` (服务层)**：存放纯 TypeScript 逻辑。严禁在这里引入任何 UI 组件。N-API 调用、正则清洗、震动控制必须封装在这里（如 `CASBridge.ts`, `HapticUtils.ts`）。


## 🛠️ 2. 新增功能模块 SOP (标准作业程序)

当你要为 CalculatorX 添加一个全新的计算模块时，必须遵守“三步走”插拔规范：

### Step 1: 造积木 (封装独立组件)
在 `components/` 目录下新建模块文件（例如 `MatrixCalc.ets`）。该模块所需的所有局部状态（如 `@State currentInput`）必须封装在内部，**严禁**泄漏到 `Index.ets` 中。

### Step 2: 发射指令 (配置侧边栏)
在 `SideBarMenu.ets` 中添加对应的菜单项，并通过 `onModuleSwitch` 回调，将新模块的 ID（如 `'matrix'`）抛出。

### Step 3: 插积木 (主入口挂载)
在 `Index.ets` 的动态插槽（Column 区域）中，通过 `if-else` 或路由状态拦截该 ID，完成 `<MatrixCalc />` 的动态挂载。

## 🚦 3. 状态管理宪法

为了防止状态混乱，我们对 ArkUI 的状态装饰器使用做出以下严格限制：

- **全局状态 (`@StorageProp` / `AppStorage`)**：仅限真正的全局配置使用，如 `navBarHeight` (底栏避让)、`isRad` (全局角度制)、`hapticFeedback` (震动开关)。
- **局部状态 (`@State` / `@Prop`)**：按键输入状态、内部解析的 JSON AST、面板的展开收起（如 `isShift`），必须由组件自己通过 `@State` 内部消化。


## 📝 4. Git 提交规范 (Commit Message)

为了让 `CHANGELOG` 清晰可读，每次提交必须携带规范的前缀：

* `feat:` 新增功能（例如：`feat: 新增矩阵运算独立面板`）
* `fix:` 修复 Bug（例如：`fix: 修复组合数 nCr 在部分情况下的正则误杀`）
* `refactor:` 代码重构（例如：`refactor: 将科学计算器 UI 剥离为独立组件`）
* `style:` 代码格式化、UI 样式微调（不影响业务逻辑）
* `docs:` 文档更新（例如：`docs: 更新 README 路线图`）
* `perf:` 性能优化（例如：`perf: 接入 FastMath 模块实现 O(1) 阶乘计算`）

**提交示例**：
> feat: 新增历史记录功能
> 
> 1. 在 database 目录下新增 HistoryRepository 处理 RDB
> 2. 引入 HdsNavigation 规范全局历史记录页面
> 3. 支持跨组件 EventHub 广播回填公式



**“好的架构不是设计出来的，而是约束出来的。”**
感谢你为 CalculatorX 保持代码整洁所做的努力！