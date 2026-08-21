<div align="center">
  <h1 align="center">
    <a href="https://calcx.startyi.com/"><img src="https://img.startyi.com/CalcX/CalcX-icon.webp" width="190"></a>
    
[CalculatorX](https://calcx.startyi.com) - 专业符号计算器
  </h1>

**打破移动端计算瓶颈，探索数学的无限可能**

[![Changelog](https://img.shields.io/badge/Changelog-v1.1.0-2d8b4c.svg)](CHANGELOG.md)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-0052cc.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-HarmonyOS_NEXT-007dff.svg?logo=harmonyos)](https://developer.harmonyos.com/)
[![Tech Stack](https://img.shields.io/badge/Tech-ArkTS_%7C_C%2B%2B_%7C_Web-6c45a8.svg)](#)
[![Engine](https://img.shields.io/badge/CAS-Giac_%7C_SymEngine-c73d3d.svg)](#)

[![官网](https://img.shields.io/badge/官网-calcx.startyi.com-1890ff?style=for-the-badge&logo=googlechrome&logoColor=white)](https://calcx.startyi.com)
[![帮助](https://img.shields.io/badge/帮助-Documentation-00b4ab?style=for-the-badge&logo=readthedocs&logoColor=white)](https://calcx.startyi.com/docs)
[![Issue](https://img.shields.io/badge/Issue-Bug_Report-e34f26?style=for-the-badge&logo=github&logoColor=white)](https://github.com/StarHeartY/CalculatorX/issues/new)

</div>

## 📝 项目简介

**CalculatorX** 是一款专为 HarmonyOS 打造的**专业级符号计算器 (CAS)**。它不仅仅是一个计算工具，更是一个移动端的数学与工程工作站。

支持**精确符号运算**与**高精度数值计算**双模式输出。通过创新的“前端原生 UI + Web 离线渲染 + 双 C++ 底层引擎”三层解耦架构，CalculatorX 成功将桌面级的解析能力装进了口袋。无论是基础的四则运算、三角函数，还是复杂的微积分、极限，还是高阶的矩阵与向量运算、超大数极速解析，它都能游刃有余。

## ✨ 核心亮点 (Highlights)

- ⚡ **工业级双引擎**：静态链接 **Giac** 与 **SymEngine**，提供无可匹敌的代数化简与符号求导积分能力。
- 🌌 **O(1) 大数极速解析**：独立的 `FastMath` 降维模块，瞬间计算 $10^{9000000000000000000}$ 级别的极限数字。
- 🖨️ **LaTeX 渲染**：深度定制 Web 容器，完美呈现复杂的嵌套根号、极限与积分等各种数学公式排版。
- 🧮 **科学计算**：支持求导、积分、极限、排列组合、求和求积、三角函数与反三角函数、互余函数与双曲函数、复数、分数、取余等多种高级运算。
- 🔢 **矩阵与线性代数**：支持多维矩阵操作，轻松应对行列式、逆矩阵、转置、特征值提取及向量点乘/叉乘等复杂线代需求。
- 📈 **函数图像绘制**：支持多种图像：普通显函数 $f(x)$ 、极坐标方程 $r(\theta)$ 、参数方程 $x(t),y(t)$ 、隐函数 $f(x,y)$ 四种图像绘制，支持同时显示 $10$ 个函数图像，以不同颜色区分。

## 🖼️ 视觉效果

<div align="center">
  <!-- AdvMath 图片 -->
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://img.startyi.com/CalcX/AdvMath_dark.webp">
    <img src="https://img.startyi.com/CalcX/AdvMath.webp" width="30%" />
  </picture>
  <!-- Matrix 图片 -->
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://img.startyi.com/CalcX/Matrix_dark.webp">
    <img src="https://img.startyi.com/CalcX/Matrix.webp" width="30%" />
  </picture>
  <!-- Graph 图片 -->
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://img.startyi.com/CalcX/Graph_dark.webp">
    <img src="https://img.startyi.com/CalcX/Graph.webp" width="30%" />
  </picture>

  <p><em>高等数学微积分计算&#8195;&#8195;&#8195;|&#8195;&#8195;&#8195;&#8195;矩阵与向量运算&#8195;&#8195;&#8195;|&#8195;&#8195;&#8195;&#8195;函数图像&#8195;&#8195;&#8195;&#8195;</em></p>
</div>


## 🏗️ 架构概览

CalculatorX 采用深度融合的三层架构，彻底打破了传统前端计算器的性能天花板：

1.  **UI 调度层 (ArkTS)**：声明式构建原生悬浮面板与手势驱动的侧边栏，通过 N-API 统一调度底层资源。
2.  **渲染降维层 (Web SandBox)**：基于离线 MathLive 库，负责高清 LaTeX 渲染，并将二维公式“降维”为结构化 MathJSON 交由底层处理。
3.  **计算核心层 (C++ & N-API)**：由 Giac 处理符号逻辑，SymEngine 与自研 `FastMath` 处理极速数值运算，`ErrorHandler` 状态机实现错误拦截机制。

> 💡 **想要深入了解我们的架构设计？**
> 请参阅 📖 [CalculatorX 核心架构设计文档](docs/ARCHITECTURE.md)。

## 🚀 路线图 (Roadmap)

**已完成的功能：**
- [x] 跨端通信打通：ArkTS / Web / C++ 三端零延迟数据流转。
- [x] 引擎融合：成功交叉编译 SymEngine 与 Giac，构建手写 AST 翻译器。
- [x] 🧮 **科学计算和基础计算**功能。
- [x] 📋 **历史记录**：关系型数据库实现历史记录的长期存储。
- [x] 🔢 **矩阵与向量**：实现矩阵与向量的相关计算。
- [x] 📈 **函数图像可视化**：显函数 $f(x)$ 、极坐标方程 $r(\theta)$ 、参数方程 $x(t),y(t)$ 、隐函数 $f(x,y)$ 四种图像绘制。
- [x] ✖️ **方程求解**：多项式求根。

**下一步规划：**
- [ ] 🔄 **转换**：全面的单位转换、进制转换与汇率换算。（正在开发）
- [ ] 📊 **数据与统计**。

## 🛠️ 快速上手 (Quick Start)

**开发环境要求**：
* IDE: **DevEco Studio** (支持 HarmonyOS NEXT)
* API Version: **21+**

阅读 🧑‍💻 [开发者协作规范](docs/CONTRIBUTING.md)，了解项目目录规范与代码解耦原则。

**克隆与运行**：
```bash
git clone https://github.com/StarHeartY/CalculatorX.git
```

## 📥 获取 (Get)

<p align="center">
  <a href="https://appgallery.huawei.com/app/detail?id=com.startyi.calcx" target="_blank"><img src="https://img.startyi.com/CalcX/AppGallery.webp" alt="Explore it on AppGallery" height="64" /></a>
  &emsp;&emsp;
  <a href="https://github.com/StarHeartY/CalculatorX/releases" target="_blank"><img src="https://img.startyi.com/CalcX/GitHub-Releases.webp" alt="GitHub Releases" height="64" /></a>
</p>

## 📄 版权与许可（License）

本项目基于 **[GPL-3.0 License](./LICENSE)** 开源协议发布。

**Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.**

**Special Declaration for Software Copyright Registration (软著登记特别声明):**
本项目（CalculatorX / CalcX）的核心架构、前端状态机及底层 C++ 代数引擎等全套源代码所有权均归属于**易睿**本人。
目前本项目正由原作者全权推进中国计算机软件著作权登记审核流程。审查机构核对作者身份时，请以本声明及专属域名标识（startyi.com / calcx.startyi.com）为准。

*This project is an original work. The author retains all rights to the core codebase during the software copyright registration process.*