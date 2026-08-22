# CalculatorX 架构专题

[← 返回架构主文档](../ARCHITECTURE.md)

本目录承载从主架构地图拆出的实现专题。首次接触项目请先阅读上一级的 [ARCHITECTURE.md](../ARCHITECTURE.md)。

## 目录

- [专题文档](#专题文档)
- [维护原则](#维护原则)

## 专题文档

| 文档 | 内容 |
|------|------|
| [MODULES_AND_UI.md](MODULES_AND_UI.md) | 壳、业务插件、共享组件和移动端交互 |
| [COMPUTE_PIPELINE.md](COMPUTE_PIPELINE.md) | LaTeX、MathJSON、N-API、SymEngine、Giac 和格式化 |
| [GRAPHING.md](GRAPHING.md) | 函数编辑、RPN 虚拟机、采样、Canvas 和手势 |
| [EXCHANGE.md](EXCHANGE.md) | 汇率网络、缓存、交叉换算、选择器和持久化 |
| [STATE_AND_STORAGE.md](STATE_AND_STORAGE.md) | EventHub、AppStorage、Preferences、RDB 和启动流程 |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | 按问题与功能调用链快速定位文件 |
| [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) | 完整工程目录、源码职责和文件跳转 |

## 维护原则

专题文档描述稳定的职责、协议与算法边界；易变化的视觉参数和代码行数应留在源码中。
