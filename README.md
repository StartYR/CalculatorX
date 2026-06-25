<div align="center">

# 🚀 CalculatorX (CalcX)

**打破移动端计算瓶颈，探索数学的无限可能**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-HarmonyOS_NEXT-black.svg?logo=harmonyos)](#)
[![Tech Stack](https://img.shields.io/badge/Tech-ArkTS_%7C_C%2B%2B_%7C_Web-blue)](#)
[![Engine](https://img.shields.io/badge/CAS-Giac_%7C_SymEngine-red)](#)


[🌐 访问官网](https://calcx.startyi.com) • [📖 查看使用帮助](https://calcx.startyi.com/help) • [🐛 提交 Issue](#)

</div>


## 📝 项目简介

**CalculatorX** 是一款专为 HarmonyOS 打造的**专业级符号计算器 (CAS)**。它不仅仅是一个计算工具，更是一个移动端的数学与工程工作站。

它支持**精确符号运算**与**高精度数值计算**双模式输出。通过创新的“前端原生 UI + Web 离线渲染 + 双 C++ 底层引擎”三层解耦架构，CalculatorX 成功将桌面级的解析能力装进了口袋。无论是基础的四则运算、三角函数，还是复杂的微积分、极限、泰勒展开，甚至是 $O(1)$ 极速解析 $10^{10^{19}}$ 级别的宇宙级大数，它都能游刃有余。


## ✨ 核心亮点 (Highlights)

* ⚡ **工业级双引擎**：静态链接 **Giac** 与 **SymEngine**，提供无可匹敌的代数化简与符号求导积分能力。
* 🌌 **O(1) 大数极速解析**：独立的 `FastMath` 降维模块，瞬间征服 $10^{9000000000000000000}$ 级别的极限数字计算。
* 🖨️ **出版级 LaTeX 渲染**：深度定制 Web 容器，完美呈现复杂的嵌套根号、极限与积分排版。
* 🧩 **可插拔的架构设计**：严格遵循单页面应用 (SPA) 逻辑，科学计算、基础计算、历史记录等面板均作为独立组件动态挂载。
* 📳 **极致的原生交互**：深度适配鸿蒙原生点击光效与 Haptic 触感反馈，拥有随动侧边栏与悬浮胶囊导航。


## 🖼️ 视觉探索

<div align="center">
  <img src="docs/image/README/file-20260611144436467.webp" width="22%" />
  <img src="docs/image/README/file-20260611144436443.webp" width="33%" />
  <img src="docs/image/README/file-20260611152708145.webp" width="33%" />
  <p><em>（深浅模式无缝切换 | 高等数学微积分计算 | 极限大数瞬间解析）</em></p>
</div>


## 🏗️ 架构概览

CalculatorX 采用深度融合的三层架构，彻底打破了传统前端计算器的性能天花板：

1.  **UI 调度层 (ArkTS)**：声明式构建原生悬浮面板与手势驱动的侧边栏，通过 N-API 统一调度底层资源。
2.  **渲染降维层 (Web SandBox)**：基于离线 MathLive 库，负责高清 LaTeX 渲染，并将二维公式“降维”为结构化 MathJSON 交由底层处理。
3.  **计算核心层 (C++ & N-API)**：由 Giac 处理符号逻辑，SymEngine 与自研 `FastMath` 处理极速数值运算，搭配 `ErrorHandler` 状态机实现 0 闪退拦截。

> 💡 **想要深入了解我们的架构设计？**
> 请参阅完整的 [📖 CalculatorX 核心架构设计文档](docs/ARCHITECTURE.md) *(施工中)*，详细了解壳与插件模型以及跨端数据流转机制。


## 🚀 路线图 (Roadmap)

**当前里程碑：核心科学计算器（已完成）**
- [x] 跨端通信打通：ArkTS / Web / C++ 三端零延迟数据流转。
- [x] 引擎融合：成功交叉编译 SymEngine 与 Giac，构建手写 AST 翻译器。
- [x] 历史记录持久化：基于 RDB 实现带有原生沉浸光感的全局与局部历史回溯。
- [x] 系统级适配：适配深浅模式、原生 Haptic 阻尼震动与屏幕避让。

**下一代规划：全能数学矩阵（规划中）**
- [ ] 📈 **函数图像可视化**：2D 极坐标/参数方程绘图。
- [ ] ✖️ **方程与线性代数**：多项式求根与高维矩阵运算。
- [ ] 🔄 **多维工具箱**：跨学科单位转换与自定义公式库。
- [ ] 📊 **数据与统计**：支持 CSV 数据导入的批量描述性统计。


## 🛠️ 快速上手 (Quick Start)

**开发环境要求**：
* IDE: **DevEco Studio** (支持 HarmonyOS NEXT)
* API Version: **21+**
* C++ 交叉编译工具链已内置于 CMakeLists 流程中，首次编译可能需要 1-3 分钟解压 `boost` 与 `giac` 离线包。

**克隆与运行**：
```bash
git clone [https://github.com/YourUsername/CalculatorX.git](https://github.com/YourUsername/CalculatorX.git)
```