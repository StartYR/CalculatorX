// entry/src/main/ets/pages/Index.ets
import font from '@ohos.font'
import web_webview from '@ohos.web.webview';
import testNapi from 'libentry.so';
import { TopKeyboard } from '../components/TopKeyboard';
import { BottomKeyboard } from '../components/BottomKeyboard';
import { getActionId } from '../utils/CalculatorConfigs';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import router from '@ohos.router';
PersistentStorage.persistProp('vibrationCurve', 0);

PersistentStorage.persistProp('isRad', false);
PersistentStorage.persistProp('vibrationIntensity', 50);
PersistentStorage.persistProp('decimalPrecision', 6);
PersistentStorage.persistProp('combinationSelectIndex', 1);
PersistentStorage.persistProp('permutationSelectIndex', 1);
PersistentStorage.persistProp('hapticFeedback', true);
PersistentStorage.persistProp('vibrationIntensity', 2);
PersistentStorage.persistProp('colorModeIndex', 2);

@Entry
@Component
struct Index {
  @StorageProp('isRad') isRad: boolean = false;
  webviewController: web_webview.WebviewController = new web_webview.WebviewController();
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('vibrationIntensity') vibrationIntensity: number = 20;

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
            onKeyPress: (btn: string | Resource): void => { this.handleButtonClick(btn); }
          })

          BottomKeyboard({
            onKeyPress: (btn: string | Resource): void => { this.handleButtonClick(btn); }
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
        router.pushUrl({ url: 'pages/Settings' });
      })

    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }

  handleButtonClick(btn: string | Resource) {
    // vibrator.startVibration({
    //   type: 'preset',
    //   effectId: 'haptic.effect.sharp',
    //   count: 1
    // }, { usage: 'touch' }).catch((err: BusinessError) => {
    //   console.warn(`震动拦截: ${err.message}`);
    // });

    if (this.vibrationIntensity > 0) {
      if (this.vibrationCurve === 0) {
        // 模式 0：自定义时长 (直接使用滑块的毫秒数)
        vibrator.startVibration({
          type: 'time',
          duration: this.vibrationIntensity
        }, { usage: 'touch' }).catch((err: BusinessError) => {
          console.warn(`震动拦截: ${err.message}`);
        });
      } else {
        // 模式 1 或 2：调用鸿蒙原生曲线 (此时滑块仅作为是否大于0的总开关)
        let effectId = this.vibrationCurve === 1 ? 'haptic.effect.sharp' : 'haptic.effect.soft';
        vibrator.startVibration({
          type: 'preset',
          effectId: effectId,
          count: 1
        }, { usage: 'touch' }).catch((err: BusinessError) => {
          console.warn(`震动拦截: ${err.message}`);
        });
      }
    }

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

          let cppResponse: string = testNapi.calculate(cleanJsonString, this.isRad);

          if (cppResponse !== "Error") {
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
    } else if (action === 'R/D') {
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