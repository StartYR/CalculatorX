# 进制转换悬浮顶栏

- 状态：界面实现与静态检查完成，待设备验收
- 类型：界面优化
- 分支：`feature/base-convert`
- 完成日期：2026-09-29
- 关联：[进制转换架构](../architecture/base-conversion.md)

## 行为变化

- 模式选项、粘贴和帮助固定在页面顶部，不随内容滚动。
- 粘贴结果改用 Toast，不占用页面行高；失败保留当前输入和撤销记录。
- 左侧为“数值 / 整数 / IEEE 754”胶囊式选项栏，右侧为独立的粘贴和帮助按钮。
- 帮助使用 `sys.symbol.questionmark_circle`；三个模式分别弹出原生帮助窗口，不在滚动页内展开。
- 顶栏保留状态栏与应用标题栏的安全距离，滚动内容预留顶栏高度。
- API 26 使用局部横向底部 TabBar 提供光感生效区域，复用 TopBar 材质；低版本使用普通背景、边框和阴影。顶栏光感独立于键盘光感开关。

## 布局参数与阴影

`BaseConverter.ets` 顶部集中维护布局参数，单位为 vp：

- `BASE_TOOLBAR_TOP_OFFSET = 60`：可见顶栏距系统状态栏底部的距离。
- `BASE_TOOLBAR_HEIGHT = 44`：可见顶栏高度，胶囊圆角、帮助按钮及选项高度随之变化。
- `BASE_CONTENT_TOP_GAP = 12`：初始滚动内容与顶栏底部的距离；内容首行距屏幕顶部为状态栏高度加上述三个值。
- `BASE_PAGE_TOP_OFFSET = 56`：滚动视口距状态栏底部的距离，避开应用标题栏。
- `BASE_TOOLBAR_SHADOW_GUTTER = 24`：上下阴影留白，不改变顶栏可见位置。

顶栏、Tabs 及外层容器关闭裁切，TabBar 内部预留透明阴影空间；透明容器允许触摸向下传递。阴影完整性及留白区域的滚动手势仍需真机验收。

## 验证

CodeLinter、键盘架构检查和差异空白检查通过。帮助弹窗调整另通过资源 JSON 解析与模块 CodeLinter，未重新构建或进行设备验收。粘贴处理函数另经 15 项宿主用例验证，使用真实会话、模拟剪贴板与 Toast，覆盖三模式成功、空文本、无效格式、超长和读取失败。本次按界面调整范围未执行构建；未进行真机光感、窄屏和滚动交互验收。

## 2026-09-30 粘贴授权与玻璃外观

粘贴入口采用普通透明 `Button`，由外层提供沉浸光感和低版本回退。点击后先检查是否有文本，再通过系统申请 `ohos.permission.READ_PASTEBOARD`；授权成功才读取文本。拒绝、空剪贴板与异常均通过 Toast 提示，不影响手动输入。申请期间防止重复触发，输入会话改变后不继续应用粘贴。

权限已在 `module.json5` 中声明，并配置用途说明和前台使用场景。受限权限的 ACL/商用发布资格需要在开发者后台及签名配置中另行确认，代码声明和构建成功不代表平台审批完成。参考[官方权限指南](https://raw.githubusercontent.com/openharmony/docs/master/zh-cn/application-dev/basic-services/pasteboard/get-pastedata-permission-guidelines.md)。

官网用户协议与隐私政策源文件同步更新至 v1.3.0，生效日期为 2026 年 9 月 30 日，说明读取时机、目的、处理范围、本地历史保存及撤回权限；网站发布单独进行。

模块 CodeLinter、权限流程宿主检查、差异空白检查及 debug `assembleHap` 构建通过。构建仍有 API 弃用和异常传播等警告；未进行真机授权、深浅主题和低版本验收，也未验证商用签名权限资格。

## 安装前的签名权限检查

2026-09-30 真机安装返回 `9568289`，明确指向 `ohos.permission.READ_PASTEBOARD`。核对当前调试与发布 Profile，以及构建出的 signed HAP，三者的 `acls.allowed-acls` 均为空；因此构建、签名成功并不意味着安装器允许授予声明的受限权限。

修复需要为 `com.startyi.calcx` 获取包含 `ohos.permission.READ_PASTEBOARD` 的有效签名 Profile，并在 DevEco Studio 的 Project Structure → Signing Configs 中配置给当前 `default` 签名项。调试 Profile 还需包含目标设备，证书需与签名密钥匹配；发布 Profile 需另行办理。重新签名后应核对 HAP 内 Profile 的 ACL，再覆盖安装验证。不可直接编辑已签名的 `.p7b` 来添加权限，也不应通过卸载应用处理此错误。

当前尚未取得带该权限的新 Profile，安装问题未修复；普通按钮、权限声明和运行时授权流程保留。

## 发布说明素材

进制转换新增悬浮模式栏和独立快捷按钮，滚动时仍可切换模式、粘贴及打开帮助。
