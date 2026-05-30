import font from '@ohos.font'
import web_webview from '@ohos.web.webview';
import testNapi from 'libentry.so';

@Entry
@Component
struct Index {
  webviewController: web_webview.WebviewController = new web_webview.WebviewController();

  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @State isShift: boolean = false;
  // ========== 新增：将 SVG 资源提取为单例引用 ==========
  private icon_sum: Resource = $rawfile('math-icons/icon_sum.svg');
  private icon_product: Resource = $rawfile('math-icons/icon_product.svg');
  private icon_integral: Resource = $rawfile('math-icons/icon_integral.svg');
  private icon_abs: Resource = $rawfile('math-icons/icon_abs.svg');
  private icon_sqrt: Resource = $rawfile('math-icons/icon_sqrt.svg');
  private icon_sqrt3: Resource = $rawfile('math-icons/icon_sqrt3.svg');
  private icon_sqrtx: Resource = $rawfile('math-icons/icon_sqrtx.svg');
  private icon_power2: Resource = $rawfile('math-icons/icon_power2.svg');
  private icon_power: Resource = $rawfile('math-icons/icon_power.svg');
  private icon_fraction: Resource = $rawfile('math-icons/icon_fraction.svg');
  // ========== 页面初始化时注册字体 ==========
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

  // ========== 字体路由逻辑 ==========
  getFontFamily(btn: string | Resource): string {
    if (typeof btn !== 'string') {
      return 'HarmonyOS Sans'; // 图标按钮使用系统默认占位即可
    }
    // 功能控制键（如清除、退格、等于号）使用系统无衬线字体，视觉上更干净
    if (['AC', '⌫', '='].includes(btn)) {
      return 'HarmonyOS Sans';
    }
    if (['y', 'z', 'i', 'e', 'π', 'ln', 'log'].includes(btn)) {
      return 'Cambria Italic';
    }
    // 其余所有的数字和数学符号，统一采用 Cambria Math
    return 'Cambria Math';
  }

  // 上方功能区 5 × 6：科学计算与微积分
  private topButtons: Array<string | Resource> = [
    '⇧Shift', 'RAD', '⇦', '⇨', 'Ans', 'i',
    'lim', 'd/dx',
    this.icon_sum,            // 替换这里
    this.icon_product,        // 替换这里
    this.icon_integral,       // 替换这里
    '∞',
    'x⁻¹', '!', 'nCr', 'nPr', 'ln', 'log',
    this.icon_abs,
    this.icon_sqrt,
    this.icon_sqrtx,
    this.icon_power2,
    this.icon_power,
    this.icon_fraction,
    'sin', 'cos', 'tan', ',', '(', ')',
  ];

  // 上方功能区 Shift
  private topShiftButtons: Array<string | Resource> = [
    '', 'DEG', '', '', '', '',                      // Shift 1: 弧度转角度
    '', '', '', '', '', '',                         // Shift 2
    '', '', '', '', 'eˣ', '10ˣ',                    // Shift 3: 对数的逆运算（指数）
    '', this.icon_sqrt3, '', '', '', '',                        // Shift 4: 常用立方根
    'sin⁻¹', 'cos⁻¹', 'tan⁻¹', '', '[', ']',        // Shift 5: 反三角函数、矩阵/区间中括号
  ];

  // 下方数字区 4 × 5：基础运算
  private bottomButtons: string[] = [
    '7', '8', '9', '⌫', 'AC',
    '4', '5', '6', '×', '÷',
    '1', '2', '3', '+', '-',
    '.', '0', 'e', 'π', '=',
  ];

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
        // ========== 上方功能区：5 × 6 ==========
        Grid() {
          // 注意：这里给 ForEach 增加了第二个参数 index，方便你以后扩展真正的 Shift 功能
          ForEach(this.topButtons, (btn: string | Resource, index: number) => {
            GridItem() {
              Column() {
                // Shift 副功能文本区
                Row() {
                  if (typeof this.topShiftButtons[index] === 'string') {
                    Text(this.topShiftButtons[index] as string)
                      .fontFamily(this.getFontFamily(this.topShiftButtons[index]))
                      .fontSize(15)
                      .fontColor('#ff805300')
                      .textAlign(TextAlign.Center)
                      .width('100%')
                  } else {
                    Image(this.topShiftButtons[index] as Resource)
                      .width(24)
                      .height(24)
                      .fillColor('#8A94A6')
                      .objectFit(ImageFit.Contain)
                  }
                }
                .width('100%')
                .height(16)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .margin({ bottom: 1 })

                // 2. 原本的主按钮（去掉了固定的 height('100%')，改为自适应）
                Button() {
                  if (typeof btn === 'string') {
                    Text(btn)
                      .fontFamily(this.getFontFamily(btn))
                      .fontSize(this.getFontSize(btn))
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.getFontColor(btn))
                  } else {
                    Image(btn)
                      .width(36)
                      .height(36)
                      .fillColor('#4A5568')
                  }
                }
                .type(ButtonType.Normal)
                .borderRadius(12)
                .width('100%')
                .layoutWeight(1) // 让主按钮自动填满除 '?' 之外的剩余高度
                .padding({ left: 2, right: 2, top: 0, bottom: 0 })
                .backgroundColor(this.getBgColor(btn))
                .onClick(() => {
                  // 1. 如果点击的是 Shift 本身，切换它的状态，然后直接结束
                  if (btn === '⇧Shift') {
                    this.isShift = !this.isShift;
                    return;
                  }

                  // 2. 如果 Shift 处于激活状态，并且当前按键有对应的副功能
                  if (this.isShift && this.topShiftButtons[index] !== '') {
                    // 把副功能的指令丢给你的处理函数
                    this.handleButtonClick(this.topShiftButtons[index]);
                    // 科学计算器的标准逻辑：执行一次副功能后，自动取消 Shift 状态
                    this.isShift = false;
                  } else {
                    // 3. 正常点击，或者该按键没有副功能，走主功能逻辑
                    this.handleButtonClick(btn);
                  }
                })
              }
              .width('100%')
              .height('100%')
            }
          })
        }
        .rowsTemplate('1fr 1fr 1fr 1fr 1fr')
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
        .rowsGap(4) // 因为 GridItem 内部自带了 Text 的高度，这里的 rowsGap 可以根据预览器效果适当调小或调大
        .columnsGap(5)
        .padding({ left: 10, right: 10, top: 12, bottom: 6 })
        .width('100%')
        .height('55%')

        // ========== 下方数字区：4 × 5 ==========
        Grid() {
          ForEach(this.bottomButtons, (btn: string) => {
            GridItem() {
              Button(btn)
                .fontFamily(this.getFontFamily(btn))
                .type(ButtonType.Normal)
                .borderRadius(16)
                .width('100%')
                .height('100%')
                .padding({ left: 4, right: 4 })
                .fontSize(this.getFontSize(btn))
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getFontColor(btn))
                .backgroundColor(this.getBgColor(btn))
                .onClick(() => {
                  this.handleButtonClick(btn);
                })
            }
          })
        }
        .rowsTemplate('1fr 1fr 1fr 1fr')
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
        .rowsGap(12)
        .columnsGap(8)
        .padding({ left: 10, right: 10, top: 6, bottom: 0 })
        .width('100%')
        .height('45%')
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
    // --- 统一转换为标识符 ---
    let action = this.getActionId(btn);

    // --- 2. 特殊指令处理 ---
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
    } else if (action === '⇧Shift' || action === 'RAD' || action === 'DEG') {
      // 状态切换按钮，暂不向屏幕输出
      return;
    } else {

      // --- 3. LaTeX 公式映射 ---
      let latexChar = action; // 默认兜底：如果没有 case 匹配，就输出原字符

      switch (action) {
        // 基础运算与常数
        case '×':       latexChar = "\\times "; break;
        case '÷':       latexChar = "\\div "; break;
        case 'π':       latexChar = "\\pi "; break;
        case '∞':       latexChar = "\\infty "; break;
        case 'i':       latexChar = "i"; break;
        case 'Ans':     latexChar = "\\text{Ans}"; break;
        case ',':       latexChar = ","; break;

        // 结构化排版
        case 'fraction': latexChar = "\\frac{\\placeholder{}}{\\placeholder{}}"; break;
        case 'sqrt':     latexChar = "\\sqrt{\\placeholder{}}"; break;
        case 'sqrt3':       latexChar = "\\sqrt[3]{\\placeholder{}}"; break;
        case 'sqrtx':    latexChar = "\\sqrt[\\placeholder{}]{\\placeholder{}}"; break;
        case 'power2':   latexChar = "^2"; break;
        case 'power':    latexChar = "^{\\placeholder{}}"; break;
        case 'x⁻¹':      latexChar = "^{-1}"; break;
        case 'abs':     latexChar = "\\left| \\placeholder{} \\right|"; break;
        case '[':       latexChar = "\\left[ \\placeholder{} \\right]"; break;
        case ']':       latexChar = "\\right]"; break;

        // 代数与函数
        case '!':       latexChar = "!"; break;
        case 'nCr':     latexChar = "\\binom{\\placeholder{}}{\\placeholder{}}"; break;
        case 'nPr':     latexChar = "{}^{\\placeholder{}}\\text{P}_{\\placeholder{}}"; break;
        case 'eˣ':      latexChar = "e^{\\placeholder{}}"; break;
        case '10ˣ':     latexChar = "10^{\\placeholder{}}"; break;
        case 'ln':      latexChar = "\\ln\\left(\\placeholder{}\\right)"; break;
        case 'log':     latexChar = "\\log_{\\placeholder{}}\\left(\\placeholder{}\\right)"; break;

        // 三角函数
        case 'sin':     latexChar = "\\sin\\left(\\placeholder{}\\right)"; break;
        case 'cos':     latexChar = "\\cos\\left(\\placeholder{}\\right)"; break;
        case 'tan':     latexChar = "\\tan\\left(\\placeholder{}\\right)"; break;
        case 'sin⁻¹':   latexChar = "\\arcsin\\left(\\placeholder{}\\right)"; break;
        case 'cos⁻¹':   latexChar = "\\arccos\\left(\\placeholder{}\\right)"; break;
        case 'tan⁻¹':   latexChar = "\\arctan\\left(\\placeholder{}\\right)"; break;

        // 微积分与极限
        case 'integral': latexChar = "\\int_{\\placeholder{}}^{\\placeholder{}}"; break;
        case 'sum':     latexChar = "\\sum_{\\placeholder{}}^{\\placeholder{}}"; break;
        case 'product': latexChar = "\\prod_{\\placeholder{}}^{\\placeholder{}}"; break;
        case 'd/dx':    latexChar = "\\frac{d}{dx}"; break;
        case 'lim':     latexChar = "\\lim_{x \\to \\placeholder{}}"; break;
      }

      // 发送给 Webview 渲染
      this.insertToWeb(latexChar);
    }
  }

  insertToWeb(str: string) {
    let safeString = JSON.stringify(str);
    this.webviewController.runJavaScript(`insertMath(${safeString})`);
  }

  // 按钮颜色
  getBgColor(btn: string | Resource): string {
    let action = this.getActionId(btn);

    if (action === 'AC' || action === '⌫') return '#FFE5E5';
    if (action === '=') return '#007DFF';
    if (['+', '-', '×', '÷', '(', ')'].includes(action)) return '#FFFFFF';
    if (action === '⇧Shift') return this.isShift ? '#FF6B00' : '#ff805300';
    // 图标按钮统一用浅灰白背景
    if (['fraction', 'sqrt', 'power', 'abs', 'sum', 'product', 'integral'].includes(action)) return '#F4F5F7';
    return '#F4F5F7';
  }

  // 字体大小
  getFontSize(btn: string | Resource): number {
    if (typeof btn !== 'string') return 14; // 图标按钮不需要 fontSize，这里是占位
    if (btn >= '0' && btn <= '9') return 24;
    if (btn === '+' || btn === '-' || btn === '×' || btn === '÷' || btn === '=' || btn === 'π' || btn === 'e' || btn === '.') return 28;
    if (['sin⁻¹', 'cos⁻¹', 'tan⁻¹', 'd/dx', 'lim'].includes(btn)) return 20;
    if (['sin', 'cos', 'tan', 'log', 'ln'].includes(btn)) return 20;
    if (['∫', '∑', '∏', '∞'].includes(btn)) return 22;
    if (['eˣ', '10ˣ'].includes(btn)) return 18;
    if (btn === 'AC' || btn === '⌫') return 20;
    if (btn === '⇦'|| btn === '⇨') return 30;
    if (btn === '⇧Shift') return 16;
    return 20;
  }

  // 字体颜色
  getFontColor(btn: string | Resource): string {
    if (typeof btn !== 'string') return '#4A5568'; // 图标按钮颜色由 fillColor 控制，这里占位
    if (btn === 'AC' || btn === '⌫') return '#FA2A2D';
    if (btn === '=' || btn === '⇧Shift') return '#FFFFFF';
    if (['+', '-', '×', '÷', '(', ')'].includes(btn)) return '#007DFF';
    if (this.topButtons.includes(btn as string)) return '#4A5568';
    return '#182431';
  }

  // 图标映射
  getActionId(btn: string | Resource): string {
    if (typeof btn === 'string') {
      return btn;
    }
    if (btn === this.icon_fraction)      return 'fraction';
    if (btn === this.icon_sqrt)          return 'sqrt';
    if (btn === this.icon_sqrt3)         return 'sqrt3';
    if (btn === this.icon_sqrtx)         return 'sqrtx';
    if (btn === this.icon_power2)        return 'power2';
    if (btn === this.icon_power)         return 'power';
    if (btn === this.icon_abs)           return 'abs';
    if (btn === this.icon_sum)           return 'sum';
    if (btn === this.icon_product)       return 'product';
    if (btn === this.icon_integral)      return 'integral';

    return '';
  }
}
