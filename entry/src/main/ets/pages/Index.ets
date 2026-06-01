// entry/src/main/ets/pages/Index.ets
import font from '@ohos.font'
import web_webview from '@ohos.web.webview';
import testNapi from 'libentry.so';
import { TopKeyboard } from '../components/TopKeyboard';
import { BottomKeyboard } from '../components/BottomKeyboard';
import { getActionId } from '../utils/CalculatorConfigs';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
struct Index {
  webviewController: web_webview.WebviewController = new web_webview.WebviewController();
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @State isShift: boolean = false;

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
    Column() {
      // 公式显示区
      Web({
        src: $rawfile('calculator.html'),
        controller: this.webviewController
      })
      // 将当前的深浅色状态下发给 Webview
        .darkMode(WebDarkMode.Auto)
        .width('100%')
        .height('30%')
        // 把背景色交给 HTML 内部的 CSS 变量控制
        .backgroundColor(Color.Transparent)

      // 键盘区域
      Column() {
        TopKeyboard({
          isShift: $isShift,
          onKeyPress: (btn: string | Resource): void => { this.handleButtonClick(btn); }
        })

        BottomKeyboard({
          onKeyPress: (btn: string | Resource): void => { this.handleButtonClick(btn); }
        })
      }
      .width('100%')
      .height('70%')
      .backgroundColor($r('sys.color.comp_background_secondary')) // 键盘背景区换成系统的二级背景色 Token
      .padding({ bottom: this.navBarHeight })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary')) // 整个页面的最底层大背景，换成系统的主背景色 Token
  }

  handleButtonClick(btn: string | Resource) {
    vibrator.startVibration({
      type: 'preset',
      effectId: 'haptic.effect.sharp', // 触感反馈
      count: 1
    }, { usage: 'touch' }).catch((err: BusinessError) => {
      console.warn(`震动拦截: ${err.message}`);
    });

    let action = getActionId(btn);

    if (action === 'AC') {
      this.webviewController.runJavaScript('clearMath()');
    } else if (action === '⌫') {
      this.webviewController.runJavaScript('deleteMath()');
    } else if (action === '=') {
      this.webviewController.runJavaScript(
        'window.getMathJSON()',
        (error, result) => {
          if (error) return;

          let cleanJsonString = '';
          try {
            cleanJsonString = JSON.parse(result);
          } catch (e) {
            cleanJsonString = result;
          }

          // 1. 调用 C++ 引擎计算结果
          let cppResponse: string = testNapi.calculate(cleanJsonString);

          // 2. 将结果发回给 Webview 的下方结果区显示！
          if (cppResponse !== "Error") {
            // 使用 JSON.stringify 保证 LaTeX 字符串（包含斜杠等特殊字符）安全传入 JS
            this.webviewController.runJavaScript(`window.showResult(${JSON.stringify(cppResponse)})`);
          } else {
            console.error("C++ Calculation Error");
          }
        }
      );
    } else if (action === '⇦') {
      this.webviewController.runJavaScript(`document.getElementById('math-input').executeCommand('moveToPreviousChar')`);
    } else if (action === '⇨') {
      this.webviewController.runJavaScript(`document.getElementById('math-input').executeCommand('moveToNextChar')`);
    } else if (action === 'RAD' || action === 'DEG') {
      // 状态切换按钮，暂不向屏幕输出
      return;
    } else {
      let latexChar = action;
      switch (action) {
        case '×':       latexChar = "\\times "; break;
        case '÷':       latexChar = "\\div "; break;
        case 'π':       latexChar = "\\pi "; break;
        case '∞':       latexChar = "\\infty "; break;
        case 'i':       latexChar = "i"; break;
        case 'Ans':     latexChar = "\\text{Ans}"; break;
        case ',':       latexChar = ","; break;
        case 'fraction': latexChar = "\\frac{\\placeholder{}}{\\placeholder{}}"; break;
        case 'sqrt':     latexChar = "\\sqrt{\\placeholder{}}"; break;
        case 'sqrt3':    latexChar = "\\sqrt[3]{\\placeholder{}}"; break;
        case 'sqrtx':    latexChar = "\\sqrt[\\placeholder{}]{\\placeholder{}}"; break;
        case 'power2':   latexChar = "^2"; break;
        case 'power':    latexChar = "^{\\placeholder{}}"; break;
        case 'x⁻¹':      latexChar = "^{-1}"; break;
        case 'abs':      latexChar = "\\left| \\placeholder{} \\right|"; break;
        case '[':        latexChar = "\\left[ \\placeholder{} \\right]"; break;
        case ']':        latexChar = "\\right]"; break;
        case '!':        latexChar = "!"; break;
        case 'nCr':      latexChar = "\\binom{\\placeholder{}}{\\placeholder{}}"; break;
        case 'nPr':      latexChar = "{}^{\\placeholder{}}\\text{P}_{\\placeholder{}}"; break;
        case 'eˣ':       latexChar = "e^{\\placeholder{}}"; break;
        case '10ˣ':      latexChar = "10^{\\placeholder{}}"; break;
        case 'ln':       latexChar = "\\ln\\left(\\placeholder{}\\right)"; break;
        case 'log':      latexChar = "\\log_{\\placeholder{}}\\left(\\placeholder{}\\right)"; break;
        case 'sin':      latexChar = "\\sin\\left(\\placeholder{}\\right)"; break;
        case 'cos':      latexChar = "\\cos\\left(\\placeholder{}\\right)"; break;
        case 'tan':      latexChar = "\\tan\\left(\\placeholder{}\\right)"; break;
        case 'sin⁻¹':    latexChar = "\\arcsin\\left(\\placeholder{}\\right)"; break;
        case 'cos⁻¹':    latexChar = "\\arccos\\left(\\placeholder{}\\right)"; break;
        case 'tan⁻¹':    latexChar = "\\arctan\\left(\\placeholder{}\\right)"; break;
        case 'integral': latexChar = "\\int_{\\placeholder{}}^{\\placeholder{}}"; break;
        case 'sum':      latexChar = "\\sum_{\\placeholder{}}^{\\placeholder{}}"; break;
        case 'product':  latexChar = "\\prod_{\\placeholder{}}^{\\placeholder{}}"; break;
        case 'd/dx':     latexChar = "\\frac{d}{dx}"; break;
        case 'lim':      latexChar = "\\lim_{x \\to \\placeholder{}}"; break;
      }
      this.insertToWeb(latexChar);
    }
  }

  insertToWeb(str: string) {
    let safeString = JSON.stringify(str);
    this.webviewController.runJavaScript(`insertMath(${safeString})`);
  }
}