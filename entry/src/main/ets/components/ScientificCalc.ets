/**
 * @file ScientificCalc.ets
 * @description 科学计算器核心业务面板组件。
 * 本组件作为独立的业务模块，封装了科学计算器专用的双 Webview（前端渲染与后台暗房离线渲染）以及上下键盘。
 * 负责捕获用户输入、维护计算过程的局部状态（如 Ans、Shift、纯净 AST 等），
 * 并桥接 HapticUtils 与 EngineService 进行计算，最终通过 HistoryRepository 实现历史记录图文的持久化。
 * 此组件的剥离实现了 UI 业务层与 Index 全局主入口的彻底解耦。
 */

import web_webview from '@ohos.web.webview';
import { TopKeyboard } from './TopKeyboard';
import { BottomKeyboard } from './BottomKeyboard';
import { getActionId, PreferenceConfigs } from '../utils/CalculatorConfigs';
import { HistoryRepository } from '../database/HistoryRepository';
import { EngineService } from '../utils/EngineService';
import { HapticUtils } from '../utils/HapticUtils';

@Component
export struct ScientificCalc {
  // 全局配置属性
  @StorageProp('answerOutputMode') answerOutputMode: number = 0;
  @StorageProp('isRad') isRad: boolean = false;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('decimalPrecision') decimalPrecision: number = 13;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;
  @StorageProp(PreferenceConfigs.KEY_COMBINATION_SELECT) combSelect: number = 1;
  @StorageProp(PreferenceConfigs.KEY_PERMUTATION_SELECT) permSelect: number = 1;
  @StorageLink('isRad') angleModeIndex: number = 0;

  // 内部 Webview 控制器：为了保证组件的高内聚，我们在组件内部进行实例化
  webviewController: web_webview.WebviewController = new web_webview.WebviewController();
  renderWebController: web_webview.WebviewController = new web_webview.WebviewController();

  // ================= 科学计算器专属局部状态 =================
  // 绝不让这些局部变量污染未来的全局环境
  @State isShift: boolean = false;
  @State lastAnsLatex: string = "0";      // 供 Ans 调用的上一次结果
  @State lastValidJson: string = "";      // 供 S⇄D 重新计算的纯净 AST
  @State isTempDecimal: boolean = false;  // 当前 S⇄D 面板的显示状态

  build() {
    Stack() {
      // 1. 核心布局区
      Column() {
        // 公式显示区
        Web({
          src: $rawfile('calculator.html'),
          controller: this.webviewController
        })
          .darkMode(WebDarkMode.Auto)
          .width('100%')
          .height('30%')
          .backgroundColor(Color.Transparent)

        // 键盘区域
        Column() {
          TopKeyboard({
            isShift: $isShift,
            onKeyPress: (btn: string | Resource): void => { this.handleButtonClick(btn); },
            onMenuSelect: (actionCode: string): void => { this.handleButtonLongPress(actionCode); }
          })

          BottomKeyboard({
            onKeyPress: (btn: string | Resource): void => { this.handleButtonClick(btn); },
            onMenuSelect: (actionCode: string): void => { this.handleButtonLongPress(actionCode); }
          })
        }
        .width('100%')
        .height('70%')
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .padding({ bottom: this.navBarHeight })
      }
      .width('100%')
      .height('100%')

      // 2. 暗房 Webview
      Web({
        src: $rawfile('render.html'),
        controller: this.renderWebController
      })
        .width(1000)
        .height(2000)
        .position({ x: -5000, y: -5000 })
        .backgroundColor(Color.Transparent)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        // 注册通信桥梁，把 ArkTS 的方法暴露给 render.html
        .javaScriptProxy({
          object: {
            onImageReady: (jsonStr: string) => {
              try {
                let parsed = JSON.parse(jsonStr) as Record<string, string>;
                if (parsed['error']) {
                  console.error("暗房报错: " + parsed['error']);
                  return;
                }
                // 在这里执行真正的数据库异步插入
                HistoryRepository.insertRecord({
                  moduleType: 'scientific',
                  inputContent: parsed['inputLatex'],
                  outputContent: parsed['outputLatex'],
                  inputBase64: parsed['inputBase64'],
                  outputBase64: parsed['outputBase64'],
                  timestamp: Date.now(),
                }).then((rowId: number) => {
                  console.info(`HistoryRepository: 历史记录图文保存成功, rowId = ${rowId}`);
                });
              } catch (e) {
                console.error("解析暗房回传数据失败");
              }
            }
          },
          name: "arktsBridge",           // 前端通过 window.arktsBridge 访问
          methodList: ["onImageReady"],  // 暴露给前端的方法名
          controller: this.renderWebController
        })
    }
    .width('100%')
    .height('100%')
  }

  // ================= 核心操作逻辑 =================

  handleButtonClick(btn: string | Resource) {
    // 提前解析按键类型，供计算和震动引擎共同使用
    let action = getActionId(btn);

    // [重构] 触发系统原生震动，调用抽离的 HapticUtils
    HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);

    if (action === 'AC') {
      this.webviewController.runJavaScript('clearMath()');
    } else if (action === '⌫') {
      this.webviewController.runJavaScript('deleteMath()');
    } else if (action === 'S⇄D') {
      if (!this.lastValidJson) return;

      let cppPrecisionMode = -1;

      // 拦截 Shift 状态
      if (this.isShift) {
        // 带分数
        cppPrecisionMode = -4;
        // 消费掉 Shift 状态，恢复正常键盘
        this.isShift = false;
      } else {
        // 假分数
        this.isTempDecimal = !this.isTempDecimal;
        cppPrecisionMode = this.isTempDecimal ? (this.decimalPrecision === 16 ? -2 : this.decimalPrecision) : -3;
      }

      // [重构] 发送给 C++，调用抽离的 EngineService
      let cppResponse: string = EngineService.calculateNative(this.lastValidJson, this.isRad, cppPrecisionMode);
      if (cppResponse.includes("Error")) {
        console.error("C++ 转换错误: "+ cppResponse);
      }
      this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
    } else if (action === '=') {
      this.webviewController.runJavaScript(
        'window.getFormula()',
        (error, rawLatexResult) => {
          if (error) return;

          // 1. 保留原始 LaTeX 以供图片渲染使用
          let rawLatex = rawLatexResult.replace(/^"|"$/g, '').replace(/\\\\/g, '\\');

          // 2. [重构] 调用 EngineService 进行多层防御性正则清洗
          let cleanedLatex = EngineService.cleanRawLatex(rawLatexResult);

          // 3. [重构] 调用 EngineService 生成注入 JS
          let injectJs = EngineService.generateInjectJs(cleanedLatex);

          this.webviewController.runJavaScript(injectJs, (err, jsonResult) => {
            if (err) return;

            // 4. [重构] 调用 EngineService 解析返回的 JSON
            let cleanJsonString = EngineService.parseWebJsonResult(jsonResult);
            this.lastValidJson = cleanJsonString;

            console.info(`【清洗后传给C++的JSON】: ${cleanJsonString}`);

            // ===== 将前端双状态映射为 C++ 单一控制码 =====
            let cppPrecisionMode = -1;
            if (this.answerOutputMode === 0) {
              cppPrecisionMode = -1;
            } else {
              if (this.decimalPrecision === 16) {
                cppPrecisionMode = -2;
              } else {
                cppPrecisionMode = this.decimalPrecision;
              }
            }

            // 5. [重构] 调用 EngineService 触发 C++ 计算
            let cppResponse: string = EngineService.calculateNative(cleanJsonString, this.isRad, cppPrecisionMode);

            if (cppResponse.includes("Error")) {
              console.error("C++ 计算错误: " + cppResponse);
              this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
            } else {
              // 把成功的计算结果存入 Ans
              this.lastAnsLatex = cppResponse;

              // 发送指令给暗房
              this.renderWebController.runJavaScript(
                `window.exportLatexToPng(${JSON.stringify(rawLatex)}, ${JSON.stringify(cppResponse)})`
              );

              // 如果是自动模式(-1)，则通过判断结果里有没有小数点来判断是否为小数
              if (cppPrecisionMode === -1) {
                this.isTempDecimal = cppResponse.includes('.');
              } else {
                this.isTempDecimal = true;
              }
              this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
            }
          });
        });
    } else if (action === '⇦') {
      this.webviewController.runJavaScript(`document.getElementById('math-input').executeCommand('moveToPreviousChar')`);
    } else if (action === '⇨') {
      this.webviewController.runJavaScript(`document.getElementById('math-input').executeCommand('moveToNextChar')`);
    } else if (action === 'R/D') {
      this.isRad = this.isRad === false ? true : false;// 状态翻转：0 变 1，1 变 0
      return;
    } else {
      let latexChar = action;
      switch (action) {
        case '×':        latexChar = "\\times "; break;
        case '÷':        latexChar = "\\div "; break;
        case '−':        latexChar = "-"; break;
        case 'π':        latexChar = "\\pi "; break;
        case '∞':        latexChar = "\\infty "; break;
        case 'i':        latexChar = "i"; break;
        case 'comma':    latexChar = ","; break;
        case 'fraction': latexChar = "\\frac{\\placeholder{}}{\\placeholder{}}"; break;
        case 'sqrt':     latexChar = "\\sqrt{\\placeholder{}}"; break;
        case 'sqrt3':    latexChar = "\\sqrt[3]{\\placeholder{}}"; break;
        case 'sqrtx':    latexChar = "\\sqrt[\\placeholder{}]{\\placeholder{}}"; break;
        case 'power2':   latexChar = "^2"; break;
        case 'power3':   latexChar = "^3"; break;
        case 'power':    latexChar = "^{\\placeholder{}}"; break;
        case 'inverse':  latexChar = '^{-1}'; break;
        case 'e_power':  latexChar = 'e^{\\placeholder{}}'; break;
        case 'icon_exp': latexChar = '\\times 10^{\\placeholder{}}'; break;
        case 'abs':      latexChar = "\\left| \\placeholder{} \\right|"; break;
        case 'fact':     latexChar = "!"; break;
        case 'ln':       latexChar = "\\ln\\left(\\placeholder{}\\right)"; break;
        case 'lg':       latexChar = '\\lg\\left(\\placeholder{}\\right)'; break;
        case 'log':      latexChar = "\\log_{\\placeholder{}}\\left(\\placeholder{}\\right)"; break;
        case 'sin':      latexChar = "\\sin\\left(\\placeholder{}\\right)"; break;
        case 'cos':      latexChar = "\\cos\\left(\\placeholder{}\\right)"; break;
        case 'tan':      latexChar = "\\tan\\left(\\placeholder{}\\right)"; break;
        case 'sin⁻¹':    latexChar = "\\arcsin\\left(\\placeholder{}\\right)"; break;
        case 'cos⁻¹':    latexChar = "\\arccos\\left(\\placeholder{}\\right)"; break;
        case 'tan⁻¹':    latexChar = "\\arctan\\left(\\placeholder{}\\right)"; break;
        case 'integral': latexChar = "\\int_{\\placeholder{}}^{\\placeholder{}}\\left(\\placeholder{}\\right)dx"; break;
        case 'indef_integral': latexChar = "\\int\\left(\\placeholder{}\\right)dx"; break;
        case 'sum':      latexChar = "\\sum_{x=\\placeholder{}}^{\\placeholder{}}\\left(\\placeholder{}\\right)"; break;
        case 'product':  latexChar = "\\prod_{x=\\placeholder{}}^{\\placeholder{}}\\left(\\placeholder{}\\right)"; break;
        case 'd/dx':     latexChar = "\\frac{d}{dx}\\left(\\placeholder{}\\right)"; break;
        case 'lim':      latexChar = "\\lim_{x \\to \\placeholder{}}\\left(\\placeholder{}\\right)"; break;
        case '%':        latexChar = '\\%'; break;
        case 'mod':      latexChar = '\\bmod '; break;
        case 'GCD':      latexChar = '\\gcd\\left(\\placeholder{}, \\placeholder{}\\right)'; break;
        case 'LCM':      latexChar = '\\operatorname{lcm}\\left(\\placeholder{}, \\placeholder{}\\right)'; break;

        case '° \' \"':  this.webviewController.runJavaScript('insertDMS()'); return;

        case 'Ans':
          if (this.lastAnsLatex === "0") {
            latexChar = "0"; // 初始状态
          } else {
            latexChar = "\\left(" + this.lastAnsLatex + "\\right)";
          }
          break;

        case 'nCr':
          let combTemplates = [
            "\\binom{\\placeholder{}}{\\placeholder{}}",                 // 0: 国际规范 \binom{n}{r}
            "\\mathrm{C}_{\\placeholder{}}^{\\placeholder{}}",           // 1: C角标 Cₙᵏ C_n^r
            "{}^{\\placeholder{}}\\mathrm{C}_{\\placeholder{}}",         // 2: 左上标 ⁿCᵣ ^nC_r
            "{}_{\\placeholder{}}\\mathrm{C}_{\\placeholder{}}",         // 3: 左下标 ₙCᵣ _nC_r
            "\\mathrm{C}\\left(\\placeholder{}, \\placeholder{}\\right)" // 4: 平铺 C(n,r)
          ];
          latexChar = combTemplates[this.combSelect];
          break;

        case 'nPr':
          let permTemplates = [
            "\\mathrm{A}_{\\placeholder{}}^{\\placeholder{}}",           // 0: A角标 Aₙᵏ A_n^r
            "\\mathrm{P}_{\\placeholder{}}^{\\placeholder{}}",           // 1: P角标 Pₙʳ P_n^r
            "{}^{\\placeholder{}}\\mathrm{P}_{\\placeholder{}}",         // 2: 左上标 ⁿPᵣ ^nP_r
            "{}_{\\placeholder{}}\\mathrm{P}_{\\placeholder{}}",         // 3: 左下标 ₙPᵣ _nP_r
            "\\mathrm{P}\\left(\\placeholder{}, \\placeholder{}\\right)" // 4: 平铺 P(n,r)
          ];
          latexChar = permTemplates[this.permSelect];
          break;
      }
      this.insertToWeb(latexChar);
    }
  }

  // 长按菜单指令分发
  handleButtonLongPress(actionCode: string) {
    if (!this.lastValidJson) return;

    let cppPrecisionMode = -1;

    switch (actionCode) {
      case 'LONG_SD_DEC':   // 强制度分秒转回小数
        this.isTempDecimal = true;
        cppPrecisionMode = (this.decimalPrecision === 16 ? -2 : this.decimalPrecision);
        break;
      case 'LONG_SD_FRAC':  // 强制假分数
        this.isTempDecimal = false;
        cppPrecisionMode = -3;
        break;
      case 'LONG_SD_MIXED': // 强制带分数
        this.isTempDecimal = false;
        cppPrecisionMode = -4;
        break;
      case 'LONG_SD_DMS':   // 强制逆向度分秒格式化渲染！
        cppPrecisionMode = -5; // 将全新的控制码发送给 C++
        break;
      default:
        return;
    }

    // [重构] 调用 EngineService 引擎重新渲染形态
    let cppResponse: string = EngineService.calculateNative(this.lastValidJson, this.isRad, cppPrecisionMode);
    if (cppResponse.includes("Error")) {
      console.error("C++ 转换错误: " + cppResponse);
    }
    // 让前端屏幕显示最新渲染出来的形态
    this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
  }

  // 向 Web 插入 LaTeX 代码
  insertToWeb(str: string) {
    let safeString = JSON.stringify(str);
    this.webviewController.runJavaScript(`insertMath(${safeString})`);
  }
}