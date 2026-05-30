// entry/src/main/ets/pages/Index.ets
import font from '@ohos.font'
import web_webview from '@ohos.web.webview';
import testNapi from 'libentry.so';
import { TopKeyboard } from '../components/TopKeyboard';
import { BottomKeyboard } from '../components/BottomKeyboard';
import { getActionId } from '../utils/CalculatorConfigs';

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
        .width('100%')
        .height('30%')
        .backgroundColor('#F1F3F5')

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
      .backgroundColor('#E2E7ED')
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.navBarHeight })
    .backgroundColor('#E2E7ED')
  }

  handleButtonClick(btn: string | Resource) {
    let action = getActionId(btn);

    if (action === 'AC') {
      this.webviewController.runJavaScript(`document.getElementById('math-input').value = ''`);
    } else if (action === '⌫') {
      this.webviewController.runJavaScript(`document.getElementById('math-input').executeCommand('deleteBackward')`);
    } else if (action === '=') {
      this.insertToWeb("=");
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