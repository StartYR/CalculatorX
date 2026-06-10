// entry/src/main/ets/pages/Index.ets
import font from '@ohos.font'
import web_webview from '@ohos.web.webview';
import testNapi from 'libentry.so';
import { TopKeyboard } from '../components/TopKeyboard';
import { BottomKeyboard } from '../components/BottomKeyboard';
import { getActionId } from '../utils/CalculatorConfigs';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { RoutePath } from '../utils/CalculatorConfigs';
import router from '@ohos.router';
import { PreferenceConfigs } from '../utils/CalculatorConfigs';

// PersistentStorage.persistProp('angleModeIndex', 0);

@Entry
@Component
struct Index {
  @StorageProp('answerOutputMode') answerOutputMode: number = 0;
  @StorageProp('isRad') isRad: boolean = false;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('decimalPrecision') decimalPrecision: number = 13;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;
  @StorageProp(PreferenceConfigs.KEY_COMBINATION_SELECT) combSelect: number = 1;
  @StorageProp(PreferenceConfigs.KEY_PERMUTATION_SELECT) permSelect: number = 1;
  @StorageLink('isRad') angleModeIndex: number = 0;
  webviewController: web_webview.WebviewController = new web_webview.WebviewController();

  @State isShift: boolean = false;
  @State lastAnsLatex: string = "0";      // 供 Ans 调用的上一次结果
  @State lastValidJson: string = "";      // 供 S⇄D 重新计算的纯净 AST
  @State isTempDecimal: boolean = false;  // 当前 S⇄D 面板的显示状态

  aboutToAppear() {
    font.registerFont({
      familyName: 'Cambria Math',
      familySrc: $rawfile('fonts/Cambria Math.ttf')
    });
    font.registerFont({
      familyName: 'Cambria Italic',
      familySrc: $rawfile('fonts/Cambria Italic.ttf')
    });
  }

  build() {
    // 使用 Stack 作为最外层，使设置按钮能够悬浮于顶层
    Stack({ alignContent: Alignment.TopStart }) {

      // 原本的主体布局，保持不变
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

      // 左上角设置按钮
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.gearshape_fill'))
          .fontSize(22)
          .fontColor([$r('sys.color.icon_primary')])
      }
      .width(44)
      .height(44)
      .margin({ top: 48, left: 16 })
      .backgroundColor(Color.Transparent)
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK)
      .onClick(() => {
        router.pushUrl({ url: RoutePath.SETTINGS });
      })

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }

  handleButtonClick(btn: string | Resource) {
    // 提前解析按键类型，供计算和震动引擎共同使用
    let action = getActionId(btn);

    // 1. 判断“触感反馈”总开关是否打开
    if (this.hapticFeedback) {
      let effectId = 'haptic.effect.sharp'; // 声明默认效果

      if (this.vibrationCurve === 0) {
        // 自动模式（基于按键类型的差异化震动）
        if (action === '=' || action === 'AC' || action === '⌫') {
          // 高权重操作：hard
          effectId = 'haptic.effect.hard';
        } else if (['+', '-', '×', '÷'].includes(action as string)) {
          // 运算符操作：sharp
          effectId = 'haptic.effect.sharp';
        } else {
          // 普通数字与函数：soft
          effectId = 'haptic.effect.soft';
        }

      } else {
        // 全局统一震感（用户选择）
        if (this.vibrationCurve === 1) {
          effectId = 'haptic.effect.sharp';
        } else if (this.vibrationCurve === 2) {
          effectId = 'haptic.effect.soft';
        } else if (this.vibrationCurve === 3) {
          effectId = 'haptic.effect.hard';
        }
      }

      // 触发系统原生震动
      vibrator.startVibration({
        type: 'preset',
        effectId: effectId,
        count: 1
      }, { usage: 'touch' }).catch((err: BusinessError) => {
        console.warn(`震动拦截: ${err.message}`);
      });
    }

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

      // 发送给 C++
      let cppResponse: string = testNapi.calculate(this.lastValidJson, this.isRad, cppPrecisionMode);
      if (cppResponse.includes("Error")) {
        console.error("C++ 转换错误: "+ cppResponse);
      }
      this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
    } else if (action === '=') {
      this.webviewController.runJavaScript(
        'window.getFormula()',
        (error, rawLatexResult) => {
          if (error) return;

          // 1. 去除首尾引号并处理转义，还原最纯净的 LaTeX
          let rawLatex = rawLatexResult.replace(/^"|"$/g, '').replace(/\\\\/g, '\\');

          // 2.定义带类型的正则替换器
          let repC = (m: string, n1: string | undefined, n2: string | undefined, r1: string | undefined, r2: string | undefined): string => {
            return `\\operatorname{nCr}\\left(${n1 || n2},${r1 || r2}\\right)`;
          };
          let repP = (m: string, n1: string | undefined, n2: string | undefined, r1: string | undefined, r2: string | undefined): string => {
            return `\\operatorname{nPr}\\left(${n1 || n2},${r1 || r2}\\right)`;
          };
          let repFlatC = (m: string, n: string, r: string): string => {
            return `\\operatorname{nCr}\\left(${n},${r}\\right)`;
          };
          let repFlatP = (m: string, n: string, r: string): string => {
            return `\\operatorname{nPr}\\left(${n},${r}\\right)`;
          };

          // --- 度分秒 (DMS) 的正则替换器 ---
          let repDMS3 = (m: string, d: string, mnt: string, s: string): string => { return `\\operatorname{dms}\\left(${d},${mnt},${s}\\right)`; };
          let repDMS2 = (m: string, d: string, mnt: string): string => { return `\\operatorname{dms}\\left(${d},${mnt},0\\right)`; };
          let repDMS_DS = (m: string, d: string, s: string): string => { return `\\operatorname{dms}\\left(${d},0,${s}\\right)`; };
          let repDMS1 = (m: string, d: string): string => { return `\\operatorname{dms}\\left(${d},0,0\\right)`; };

          let cleanedLatex = rawLatex
          // --- 组合 (C) 的 5 种样式防御 ---
            .replace(/\\mathrm\{C\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))\^(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repC)
            .replace(/\\binom(?:\{(.+?)\}|([a-zA-Z0-9.]))(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repC)
            .replace(/\{\}\^(?:\{(.+?)\}|([a-zA-Z0-9.]))\\mathrm\{C\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repC)
            .replace(/\{\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))\\mathrm\{C\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repC)
            .replace(/\\mathrm\{C\}\\left\((.+?),\s*(.+?)\\right\)/g, repFlatC)

            // --- 排列 (P/A) 的 5 种样式防御 ---
            .replace(/\\mathrm\{A\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))\^(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repP)
            .replace(/\\mathrm\{P\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))\^(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repP)
            .replace(/\{\}\^(?:\{(.+?)\}|([a-zA-Z0-9.]))\\mathrm\{P\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repP)
            .replace(/\{\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))\\mathrm\{P\}_(?:\{(.+?)\}|([a-zA-Z0-9.]))/g, repP)
            .replace(/\\mathrm\{P\}\\left\((.+?),\s*(.+?)\\right\)/g, repFlatP)

            // 微积分求导
            .replace(/\\frac\{d\}\{dx\}/g, '\\operatorname{diff}')

            // --- 度分秒拦截 ---
            // 匹配完整的 12°34'56"
            .replace(/([0-9.]+)\^\{\\circ\}\s*([0-9.]+)\^\{\\prime\}\s*([0-9.]+)\^\{\\prime\s*\\prime\}/g, repDMS3)
            // 匹配缺秒的 12°34' (负向先行断言防止误杀)
            .replace(/([0-9.]+)\^\{\\circ\}\s*([0-9.]+)\^\{\\prime\}(?!\s*\\prime)/g, repDMS2)
            // 匹配缺分的 12°56"
            .replace(/([0-9.]+)\^\{\\circ\}\s*([0-9.]+)\^\{\\prime\s*\\prime\}/g, repDMS_DS)
            // 匹配只有度的 12°
            .replace(/([0-9.]+)\^\{\\circ\}/g, repDMS1);

          // 给反斜杠和引号加上双重转义，防止破坏 JS 边界
          let safeLatex = cleanedLatex.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\n/g, "\\n");

          // 内存静默转换 JSON
          let injectJs = `
        (function() {
          try {
            let tempMf = document.createElement('math-field');
            tempMf.style.position = 'absolute';
            tempMf.style.visibility = 'hidden';
            tempMf.style.pointerEvents = 'none';
            document.body.appendChild(tempMf);

            tempMf.value = '${safeLatex}';
            let jsonAst = tempMf.getValue('math-json');
            document.body.removeChild(tempMf);

            return JSON.stringify(jsonAst);
          } catch (e) {
            return JSON.stringify(["Error", "JS_Parse_Crash: " + e.toString()]);
          }
        })();
      `;

          this.webviewController.runJavaScript(injectJs, (err, jsonResult) => {
            if (err) return;

            let cleanJsonString = '';
            try {
              cleanJsonString = JSON.parse(jsonResult);
              if (typeof cleanJsonString === 'string') {
                cleanJsonString = JSON.parse(cleanJsonString);
              }
            } catch (e) {
              cleanJsonString = jsonResult;
            }

            let jsonStrToSave = typeof cleanJsonString === 'string' ? cleanJsonString : JSON.stringify(cleanJsonString);
            this.lastValidJson = jsonStrToSave;

            console.info(`【清洗后传给C++的JSON】: ${typeof cleanJsonString === 'string' ? cleanJsonString : JSON.stringify(cleanJsonString)}`);

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

            let cppResponse: string = testNapi.calculate(typeof cleanJsonString === 'string' ? cleanJsonString : JSON.stringify(cleanJsonString), this.isRad, cppPrecisionMode);

            if (cppResponse.includes("Error")) {
              console.error("C++ 计算错误: " + cppResponse);
              this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
            } else {
              // 把成功的计算结果存入 Ans
              this.lastAnsLatex = cppResponse;

              // 如果是自动模式(-1)，则通过判断结果里有没有小数点来判断是否为小数
              if (cppPrecisionMode === -1) {
                this.isTempDecimal = cppResponse.includes('.');
              } else {
                this.isTempDecimal = true;
              }
              this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
            }

          });
        }
      );
    } else if (action === '⇦') {
      this.webviewController.runJavaScript(`document.getElementById('math-input').executeCommand('moveToPreviousChar')`);
    } else if (action === '⇨') {
      this.webviewController.runJavaScript(`document.getElementById('math-input').executeCommand('moveToNextChar')`);
    } else if (action === 'R/D') {
      this.isRad = this.isRad === false ? true : false;// 状态翻转：0 变 1，1 变 0
      // this.playVibration();
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
        case 'integral': latexChar = "\\int_{\\placeholder{}}^{\\placeholder{}}\\left(\\placeholder{}\\right)d\\placeholder{}"; break;
        case 'indef_integral': latexChar = "\\int\\left(\\placeholder{}\\right)d\\placeholder{}"; break;
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

    // 调用 C++ 引擎重新渲染形态
    let cppResponse: string = testNapi.calculate(this.lastValidJson, this.isRad, cppPrecisionMode);
    if (cppResponse.includes("Error")) {
      console.error("C++ 转换错误: " + cppResponse);
    }
    // 让前端屏幕显示最新渲染出来的形态
    this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
  }

  insertToWeb(str: string) {
    let safeString = JSON.stringify(str);
    this.webviewController.runJavaScript(`insertMath(${safeString})`);
  }
}

