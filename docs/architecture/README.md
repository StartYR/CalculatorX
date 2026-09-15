# CalculatorX 架构专题

[← 返回架构主文档](../architecture.md)

本目录承载从主架构地图拆出的实现专题。首次接触项目请先阅读上一级的 [architecture.md](../architecture.md)。

## 目录

- [专题文档](#专题文档)
- [维护原则](#维护原则)

## 专题文档

| 文档 | 内容 |
|------|------|
| [modules-and-ui.md](modules-and-ui.md) | 壳、业务插件、共享组件和移动端交互 |
| [compute-pipeline.md](compute-pipeline.md) | LaTeX、MathJSON、N-API、SymEngine、Giac 和格式化 |
| [graphing.md](graphing.md) | 函数编辑、RPN 虚拟机、采样、Canvas 和手势 |
| [exchange.md](exchange.md) | 汇率网络、缓存、交叉换算、选择器和持久化 |
| [state-and-storage.md](state-and-storage.md) | EventHub、AppStorage、Preferences、RDB 和启动流程 |
| [troubleshooting.md](troubleshooting.md) | 按问题与功能调用链快速定位文件 |
| [project-structure.md](project-structure.md) | 完整工程目录、源码职责和文件跳转 |

## 维护原则

专题文档描述稳定的职责、协议与算法边界；易变化的视觉参数和代码行数应留在源码中。
