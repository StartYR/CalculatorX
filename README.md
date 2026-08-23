<div align="center">
  <a href="https://calcx.startyi.com/">
    <img src="https://img.startyi.com/CalcX/CalcX-icon.webp" width="180" alt="CalculatorX 图标">
  </a>

  <h1>CalculatorX</h1>

  <p><strong>面向 HarmonyOS NEXT 的原生科学与符号计算器</strong></p>
  <p>从基础运算、微积分和矩阵，到方程求解、函数图像与实时汇率换算。</p>

  <p>
    <a href="https://github.com/StarHeartY/CalculatorX/releases"><img src="https://img.shields.io/badge/Version-1.6.0-2d8b4c.svg" alt="Version 1.6.0"></a>
    <a href="https://developer.harmonyos.com/"><img src="https://img.shields.io/badge/Platform-HarmonyOS_NEXT-007dff.svg?logo=harmonyos" alt="HarmonyOS NEXT"></a>
    <a href="./LICENSE"><img src="https://img.shields.io/badge/License-GPLv3-0052cc.svg" alt="GPL-3.0"></a>
    <img src="https://img.shields.io/badge/Tech-ArkTS_%7C_C%2B%2B_%7C_Web-6c45a8.svg" alt="ArkTS, C++ and Web">
    <img src="https://img.shields.io/badge/CAS-Giac_%7C_SymEngine-c73d3d.svg" alt="Giac and SymEngine">
  </p>

  <p>
    <a href="https://appgallery.huawei.com/app/detail?id=com.startyi.calcx"><img src="https://img.shields.io/badge/AppGallery-立即下载-cf0a2c?style=for-the-badge&logo=huawei&logoColor=white" alt="从 AppGallery 下载"></a>
    <a href="https://github.com/StarHeartY/CalculatorX/releases"><img src="https://img.shields.io/badge/GitHub-Releases-24292f?style=for-the-badge&logo=github&logoColor=white" alt="GitHub Releases"></a>
    <a href="https://calcx.startyi.com/docs"><img src="https://img.shields.io/badge/使用帮助-00b4ab?style=for-the-badge&logo=readthedocs&logoColor=white" alt="CalculatorX 使用帮助"></a>
  </p>
</div>

---

## 产品一览

<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://img.startyi.com/CalcX/AdvMath_dark.webp">
    <img src="https://img.startyi.com/CalcX/AdvMath.webp" width="30%" alt="CalculatorX 科学计算">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://img.startyi.com/CalcX/Matrix_dark.webp">
    <img src="https://img.startyi.com/CalcX/Matrix.webp" width="30%" alt="CalculatorX 矩阵运算">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://img.startyi.com/CalcX/Graph_dark.webp">
    <img src="https://img.startyi.com/CalcX/Graph.webp" width="30%" alt="CalculatorX 函数图像">
  </picture>

  <p><em>科学计算 · 矩阵与线性代数 · 函数图像</em></p>
</div>

## 不只是一台计算器

CalculatorX 是一款为 HarmonyOS NEXT 打造的原生数学工具。它兼顾日常计算与进阶数学需求，既能给出高精度小数，也能保留分数、根式、π 和符号表达式等精确结果。

原生 ArkUI 负责流畅的键盘、手势和触感交互，MathLive 提供接近纸面公式的输入与排版，SymEngine 与 Giac 则共同承担代数、微积分、方程和矩阵计算。复杂能力被整合进统一、直观的移动端界面中。

## 核心功能

| 模块      | 主要能力 |
|---------|----------|
| 🧮 基础计算 | 四则运算、百分数、Ans 调用与连续退格 |
| 🔬 科学计算 | 三角与反三角、双曲函数、对数、指数、排列组合、求和求积、GCD/LCM、度分秒 |
| ∫ 微积分   | 符号求导、定积分、不定积分、极限及数值积分降级 |
| 🔢 矩阵与向量 | 1×1 至 6×6 矩阵、逆、转置、共轭转置、行列式、秩、rref、迹和特征值 |
| ✖️ 方程求解 | 一元方程与最多六元方程组，支持 `x/y/z/u/v/w` |
| 📈 函数图像 | 显函数、参数方程、极坐标、隐函数和独立点，最多同时显示 10 条 |
| 💱 汇率换算 | 172 种货币与资产、多币种同步换算、搜索、排序、整点缓存和离线使用 |
| 🕘 历史记录 | 按模块保存公式与结果，支持分类检索、回填和滑动删除 |
| 🎨 个性化  | 深浅色模式、RAD/DEG、答案格式、小数精度、启动页面和多档触感反馈 |

## 为什么选择 CalculatorX

- **精确与近似自由切换**：在符号结果、小数、分数、带分数和度分秒之间快速转换。
- **接近纸面的公式体验**：复杂分数、根式、积分、极限和矩阵均以清晰的 LaTeX 形式展示。
- **原生移动端交互**：Shift 第二功能、长按气泡菜单、连续按键、触感反馈和深浅色适配。
- **完整的函数图像能力**：多函数叠加、颜色区分、自定义定义域、拖拽平移和双指缩放。
- **统一的数学工作区**：计算、方程、矩阵、绘图、汇率和历史记录集中在一个应用中。
- **本地优先**：公式编辑、计算和历史记录主要在设备端完成；汇率支持本地缓存。

## 技术亮点

CalculatorX 采用 ArkTS、WebView 与 C++ 协作的混合架构：

```text
ArkUI 原生界面
  → MathLive 公式编辑与 MathJSON AST
  → N-API
  → SymEngine / Giac / FastMath / GraphingEngine
  → LaTeX 结果、Canvas 图像与本地历史记录
```

- **MathJSON 中间层**：由 Compute Engine 将 LaTeX 转换为结构化 AST，避免在 C++ 中直接解析复杂 LaTeX。
- **双 CAS 协同**：SymEngine 处理轻量符号表达式，Giac 接管积分、极限、方程和矩阵等高级运算。
- **高性能函数绘图**：表达式预编译为 RPN 指令，配合自适应采样、Marching Squares 和 `Float64Array` 绘制。
- **超大数处理**：FastMath 使用数量级与科学记数法节点处理无法直接展开的巨大阶乘和幂。
- **暗房渲染**：隐藏 WebView 离屏生成公式 PNG，不干扰前台编辑与计算。
- **原生持久化**：Preferences 保存设置与模块状态，RDB 保存结构化历史记录。

深入了解实现方式，请阅读 [CalculatorX 架构文档](docs/ARCHITECTURE.md)。

## 功能状态

### 已完成

- [x] 基础计算与科学计算
- [x] 符号微积分与答案格式切换
- [x] 矩阵与线性代数
- [x] 一元方程与多元方程组
- [x] 五种函数图像与多函数叠加
- [x] 汇率换算与本地缓存
- [x] 图文化历史记录
- [x] 主题、精度、触感和启动页面设置

### 开发中

- [ ] 统计分析
- [ ] 单位转换
- [ ] 进制转换

## 获取 CalculatorX

<p align="center">
  <a href="https://appgallery.huawei.com/app/detail?id=com.startyi.calcx"><img src="https://img.startyi.com/CalcX/AppGallery.webp" alt="从 AppGallery 获取 CalculatorX" height="64"></a>
  &emsp;&emsp;
  <a href="https://github.com/StarHeartY/CalculatorX/releases"><img src="https://img.startyi.com/CalcX/GitHub-Releases.webp" alt="从 GitHub Releases 获取 CalculatorX" height="64"></a>
</p>

- 普通用户推荐通过 **AppGallery** 安装和更新。
- 开发版本及历史安装包可在 **GitHub Releases** 获取。
- 功能用法、界面说明和常见问题请查看 [在线帮助](https://calcx.startyi.com/docs)。
- 遇到问题可以前往 [GitHub Issues](https://github.com/StarHeartY/CalculatorX/issues/new) 反馈。

## 开发者快速开始

### 环境要求

- DevEco Studio（支持 HarmonyOS NEXT SDK 6.1）
- Target SDK：`6.1.1 (24)`
- Compatible SDK：`6.1.0 (23)`
- CMake / BiSheng Native 工具链

### 克隆项目

```bash
git clone https://github.com/StarHeartY/CalculatorX.git
cd CalculatorX
```

使用 DevEco Studio 打开工程，完成 OHPM 同步和本地签名配置后，运行 `entry` 模块。具体目录约束、模块接入方式和提交规范见 [开发者协作规范](docs/CONTRIBUTING.md)。

## 项目文档

| 文档                                               | 内容 |
|--------------------------------------------------|------|
| [架构文档](docs/ARCHITECTURE.md)                     | 项目全貌、系统分层、核心数据流和专题索引 |
| [完整项目目录](docs/architecture/PROJECT_STRUCTURE.md) | ArkTS、C++、资源和关键配置结构 |
| [计算管线](docs/architecture/COMPUTE_PIPELINE.md)    | LaTeX、MathJSON、N-API、SymEngine 与 Giac |
| [函数图像架构](docs/architecture/GRAPHING.md)          | 编辑、RPN、采样、Canvas 与手势 |
| [汇率架构](docs/architecture/EXCHANGE.md)            | 网络刷新、缓存、货币选择和交叉换算 |
| [故障定位指南](docs/architecture/TROUBLESHOOTING.md)   | 按现象和调用链定位源码 |
| [贡献指南](docs/CONTRIBUTING.md)                     | 模块开发、状态管理和 Git 提交规范 |
| [更新日志](docs/CHANGELOG.md)                        | 历史版本与重要改动 |

## 参与贡献

欢迎提交 Issue、改进文档或参与功能开发。开始编码前，请先阅读 [CONTRIBUTING.md](docs/CONTRIBUTING.md)，了解 CalculatorX 的模块隔离、状态管理和提交规范。

## 版权与许可

CalculatorX 基于 [GNU General Public License v3.0](./LICENSE) 发布。

**Copyright © 2026 易睿（Yi Rui）. All rights reserved.**

<details>
  <summary><strong>软件著作权登记特别声明</strong></summary>

本项目（CalculatorX / CalcX）的核心架构、前端状态机及底层 C++ 代数引擎等全套源代码所有权归属于易睿本人。目前本项目由原作者推进中国计算机软件著作权登记审核流程。审查机构核对作者身份时，请以本声明及专属域名标识（startyi.com / calcx.startyi.com）为准。

This project is an original work. The author retains all rights to the core codebase during the software copyright registration process.

</details>
