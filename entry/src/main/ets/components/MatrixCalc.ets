/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file MatrixCalc.ets
 * @description 矩阵与线性代数核心业务面板组件
 * * @author 易睿 (Yi Rui)
 * @date 2026/7/3 02:32
 */

import { FormulaScreen } from './FormulaScreen';
import { HapticUtils } from '../utils/HapticUtils';
import { getActionId, getFontFamily, getFontSize, getFontColor, getBgColor } from '../utils/CalculatorConfigs';
import { icon_backspace, icon_fraction, icon_dim } from '../utils/CalculatorConfigs';
import Logger from '../utils/Logger'

const icon_M_power: Resource = $rawfile('icons/matrix/icon_M_power.svg');
const icon_abs: Resource = $rawfile('icons/matrix/icon_abs.svg');

// 主键盘
const matrixButtons: Array<string | Resource> = [
  '⇧Shift', '⇧', icon_fraction, 'M⁻¹', 'Mᵀ',
  '⇦', '⇩', '⇨', '(', ')',
  '7', '8', '9', icon_backspace, 'AC',
  '4', '5', '6', '×', '∘',
  '1', '2', '3', '+', '−',
  '.', '0', icon_dim, 'Ans', '='
];

// Shift 键盘
const matrixShiftButtons: Array<string | Resource> = [
  '', '', 'det', icon_M_power, 'Mᴴ',
  '', '', '', 'rref', 'eig',
  '', '', '', '', '',
  '', '', '', '', '', // ⊗
  '', '', '', 'rank', 'tr',
  '', 'i', 'I', icon_abs, ''
];

@Component
struct MatrixKeyItem {
  btn: string | Resource = '';
  btnIndex: number = 0;
  @Link isShift: boolean;

  // 长按连发的定时器状态
  private startDelayTimer: number = -1;
  private repeatTimer: number = -1;

  // 回调参数
  onKeyPress: (btn: string | Resource) => void = () => {};

  build() {
    Button() {
      // 副文字悬浮左上角
      Stack({ alignContent: Alignment.TopStart }) {

        // ================= 1. 主功能文字或图标 =================
        if (typeof this.btn === 'string') {
          Text(this.btn)
            .fontFamily(getFontFamily(this.btn))
            .fontSize(getFontSize(this.btn))
            .fontWeight(FontWeight.Medium)
            .fontColor(getFontColor(this.btn))
            .width('100%')
            .height('100%')
            .textAlign(TextAlign.Center)
        } else {
          Column() {
            Image(this.btn)
              .width(48)
              .height(40)
              .fillColor(getFontColor(this.btn))
              .objectFit(ImageFit.Contain)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }

        // ================= 2. Shift 副功能文字或图标 =================
        if (matrixShiftButtons[this.btnIndex] !== '') {
          if (typeof matrixShiftButtons[this.btnIndex] === 'string') {
            Text(matrixShiftButtons[this.btnIndex] as string)
              .fontFamily(getFontFamily(matrixShiftButtons[this.btnIndex] as string))
              .fontSize(12)
              .fontColor('#ffac8100')
              .padding({ left: 6, top: 4 })
          } else {
            Image(matrixShiftButtons[this.btnIndex] as Resource)
              .width(14)
              .height(14)
              .fillColor('#ffac8100')
              .margin({ left: 6, top: 4 })
              .objectFit(ImageFit.Contain)
          }
        }
      }
      .width('100%')
      .height('100%')
    }
    .type(ButtonType.Normal)
    .borderRadius(16)
    .width('100%')
    .height('100%')
    .padding({ left: 2, right: 2 })
    .backgroundColor(getBgColor(this.btn, this.isShift))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .borderWidth({ top: 1, left: 1, bottom: 0, right: 0 })
    .borderColor($r('app.color.btn_highlight'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
    .stateStyles({
      pressed: { .opacity(0.7).shadow(ShadowStyle.OUTER_DEFAULT_XS) },
      normal: { .opacity(1.0).shadow(ShadowStyle.OUTER_DEFAULT_SM) }
    })
    .onClick(() => {
      if (this.btn === '⇧Shift') {
        this.isShift = !this.isShift;
        return;
      }

      if (this.isShift && matrixShiftButtons[this.btnIndex] !== '') {
        this.onKeyPress(matrixShiftButtons[this.btnIndex]);
        this.isShift = false;
      } else {
        this.onKeyPress(this.btn);
      }
    })

    // 挂载触摸事件，实现四个方向键与删除键的长按连发
    .onTouch((event: TouchEvent) => {
      // 识别需要连发的按键（四个方向键以及退格键）
      if (this.btn === '⇦' || this.btn === '⇨' || this.btn === '⇧' || this.btn === '⇩' || this.btn === icon_backspace) {
        if (event.type === TouchType.Down) {
          clearTimeout(this.startDelayTimer);
          clearInterval(this.repeatTimer);

          // 按下 500ms 后开始连发
          this.startDelayTimer = setTimeout(() => {
            // 每 80ms 触发一次
            this.repeatTimer = setInterval(() => {
              // 兜底逻辑：处理连发时的 Shift 状态
              if (this.isShift && matrixShiftButtons[this.btnIndex] !== '') {
                this.onKeyPress(matrixShiftButtons[this.btnIndex]);
                this.isShift = false;
              } else {
                this.onKeyPress(this.btn);
              }
            }, 80);
          }, 500);
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          // 手指松开或滑出时，清空定时器
          clearTimeout(this.startDelayTimer);
          clearInterval(this.repeatTimer);
        }
      }
    })
  }
}

@Component
export struct MatrixCalc {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;
  @State @Watch('onShiftChange') isShift: boolean = false;

  // 弹窗控制器
  dialogController: CustomDialogController = new CustomDialogController({
    builder: DimDialog({
      onConfirm: (rows: number, cols: number) => {
        // 核心步骤：根据动态获取的行列数，组装 LaTeX 矩阵字符串
        let matrixLatex = '\\begin{bmatrix} ';

        for (let i = 0; i < rows; i++) {
          for (let j = 0; j < cols; j++) {
            matrixLatex += '\\placeholder{}'; // 填入 MathLive 专属占位符
            if (j < cols - 1) {
              matrixLatex += ' & '; // 同行元素用 & 隔开
            }
          }

          if (i < rows - 1) {
            matrixLatex += ' \\\\ '; // 不同行之间用 \\ 换行
          }
        }

        matrixLatex += ' \\end{bmatrix}';

        // 将组装好的史诗级巨型 LaTeX 字符串，直接扔给 FormulaScreen 进行渲染
        getContext(this).eventHub.emit('screen_handle_action', matrixLatex, false);
      }
    }),
    alignment: DialogAlignment.Center, // 居中弹出
    customStyle: true,                 // 开启自定义样式以去除系统默认白底
    autoCancel: true                   // 允许点击遮罩层关闭
  })

  onShiftChange() {
    getContext(this).eventHub.emit('event_shift_change', this.isShift);
  }

  aboutToAppear() {
    getContext(this).eventHub.on('screen_shift_consumed', () => {
      this.isShift = false;
    });
  }

  aboutToDisappear() {
    getContext(this).eventHub.off('screen_shift_consumed');
  }

  private handleButtonClick(btn: string | Resource) {
    let action = '';

    // 优先拦截本组件私有的资源/按键
    if (btn === icon_M_power) action = 'M_power';
    else if (btn === icon_abs) action = 'abs'
    else {
      // 通用按键交由全局统管
      action = getActionId(btn);
    }

    // 触发马达震动反馈
    HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);

    // 3. 核心逻辑分流
    if (action === 'dim') {
      this.dialogController.open();
      Logger.info("[MatrixCalc] 触发矩阵选择窗口");
    } else if (action !== '') {
      // 绝大多数按键发送给 FormulaScreen 的 MathLive 进行渲染
      // 注意：这里的 Shift 传 false，因为 MatrixKeyItem 的 onClick 中已经把 Shift 翻译成了最终算子
      getContext(this).eventHub.emit('screen_handle_action', action, false);
    }

    // 发送动作指令
    // getContext(this).eventHub.emit('screen_handle_action', action, false);
  }

  build() {
    Column() {
      FormulaScreen({ moduleType: 'matrix' })
        .width('100%')
        .height('55%')

      Column() {
        Grid() {
          ForEach(matrixButtons, (btn: string | Resource, index: number) => {
            GridItem() {
              MatrixKeyItem({
                btn: btn,
                btnIndex: index,
                isShift: $isShift,
                onKeyPress: (b: string | Resource): void => { this.handleButtonClick(b); }
              })
            }
          })
        }
        .rowsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
        .rowsGap(8)
        .columnsGap(6)
        .padding({ left: 10, right: 10, top: 6, bottom: 0 })
        .clip(false)
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('45%')
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .padding({ bottom: this.navBarHeight - 8 })
    }
    .width('100%')
    .height('100%')
  }
}

@CustomDialog
struct DimDialog {
  controller: CustomDialogController
  onConfirm: (rows: number, cols: number) => void = () => {}

  @State selRow: number = 3;
  @State selCol: number = 3;

  private dimArray: number[] = [1, 2, 3, 4, 5, 6];

  build() {
    Column({ space: 20 }) {
      Text(`矩阵维度: ${this.selRow} × ${this.selCol}`)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontFamily('sans-serif')
        .margin({ top: 10 })

      Grid() {
        ForEach(this.dimArray, (r: number) => {
          ForEach(this.dimArray, (c: number) => {
            GridItem() {
              Row()
                .width('100%')
                .aspectRatio(1)
                .backgroundColor(r <= this.selRow && c <= this.selCol ? '#ae007dff' : $r('sys.color.comp_background_secondary'))
                .borderRadius(6)
                .animation({ duration: 150, curve: Curve.EaseOut })
                .onClick(() => {
                  this.selRow = r;
                  this.selCol = c;
                })
            }
          })
        })
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
      .rowsGap(6)
      .columnsGap(6)
      .width(260)
      .height(260)
      .padding(10)

      Row() {
        Button('取消')
          .type(ButtonType.Capsule)
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
          .onClick(() => this.controller.close())

        Button('创建矩阵')
          .type(ButtonType.Capsule)
          .backgroundColor($r('sys.color.comp_background_emphasize'))
          .fontColor(Color.White)
          .layoutWeight(1)
          .onClick(() => {
            this.onConfirm(this.selRow, this.selCol);
            this.controller.close();
          })
      }
      .width('100%')
      .padding({ left: 10, right: 10, bottom: 10 })
    }
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(24)
    .width(320)
  }
}
