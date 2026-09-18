# 第三方开源软件声明 (Third-Party Notices)

CalculatorX 的实现依赖了优秀的开源项目与社区成果。根据相关开源许可证的要求，特在此说明本项目所使用的主要第三方库、官方主页及其许可协议。

---

## 核心数学与代数引擎 (Native CAS)

### 1. Giac / Xcas
- **用途**：核心微积分、积分、极限、方程求解与高级符号运算引擎
- **作者/项目方**：Bernard Parisse 等
- **项目主页**：[https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac.html](https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac.html)
- **开源许可证**：GNU General Public License v3.0 (GPLv3)

### 2. SymEngine
- **用途**：高性能基础计算机代数系统 (CAS)，负责轻量符号表达式展开与化简
- **项目主页**：[https://github.com/symengine/symengine](https://github.com/symengine/symengine)
- **开源许可证**：MIT License / 3-Clause BSD License

### 3. GMP (GNU Multiple Precision Arithmetic Library)
- **用途**：提供高精度与大数运算底层能力
- **项目主页**：[https://gmplib.org/](https://gmplib.org/)
- **开源许可证**：GNU Lesser General Public License v3.0 (LGPLv3)

---

## 前端公式交互与解析

### 4. MathLive & Compute Engine
- **用途**：前端 LaTeX 交互式编辑、公式排版及 MathJSON AST 解析中间层
- **作者/项目方**：Arno Gourdol (CortexJS)
- **项目主页**：[https://cortexjs.io/mathlive/](https://cortexjs.io/mathlive/)
- **开源许可证**：MIT License

---

## C++ 基础工具与通信

### 5. Boost C++ Libraries
- **用途**：提供高可靠的通用 C++ 泛型算法与底层数据结构支持
- **项目主页**：[https://www.boost.org/](https://www.boost.org/)
- **开源许可证**：Boost Software License 1.0 (BSL-1.0)

### 6. nlohmann/json
- **用途**：C++ 侧高效现代 JSON 解析与序列化库（负责 N-API 跨语言数据交换）
- **作者/项目方**：Niels Lohmann
- **项目主页**：[https://github.com/nlohmann/json](https://github.com/nlohmann/json)
- **开源许可证**：MIT License

---

## 许可证说明

* CalculatorX 自身代码基于 **[GNU General Public License v3.0](../LICENSE)** 开源发布，与 Giac/Xcas 及底层库的协议要求保持兼容。
* 各第三方组件的完整版权声明和许可全文请参见各项目官方主页及源码说明。