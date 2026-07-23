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

const icon_M_power: Resource = $rawfile('icons/matrix/icon_M_power.svg');
const icon_abs: Resource = $rawfile('icons/matrix/icon_abs.svg');

// 主键盘
const matrixButtons: Array<string | Resource> = [
  '⇧Shift', '⇧', icon_fraction, 'M⁻¹', 'Mᵀ',
  '⇦', '⇩', '⇨', '(', ')',
  '7', '8', '9', icon_backspace, 'AC',
  '4', '5', '6', '×', '÷',
  '1', '2', '3', '+', '−',
  '.', '0', icon_dim, 'Ans', '='
];

// Shift 键盘
const matrixShiftButtons: Array<string | Resource> = [
  '', '', icon_M_power, 'det', 'Mᴴ',
  '', '', '', 'rref', 'eig',
  '', '', '', '', '',
  '', '', '', '⨯', '•',
  '', '', '', 'rank', 'tr',
  '', '', 'I', icon_abs, ''
];

@Component
struct MatrixKeyItem {
  // 1. 放宽类型声明
  btn: string | Resource = '';
  btnIndex: number = 0;
  @Link isShift: boolean;

  // 2. 放宽回调参数类型
  onKeyPress: (btn: string | Resource) => void = () => {};

  build() {
    Button() {
      // 使用 Stack 容器实现绝对定位，alignContent 控制副文字悬浮左上角
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
              .objectFit(ImageFit.Contain) // 【修复点 3】：Shift 的 SVG 同样需要比例保护
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
  }
}

@Component
export struct MatrixCalc {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;
  @State @Watch('onShiftChange') isShift: boolean = false;

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
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .clip(false)
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('45%')
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .padding({ bottom: this.navBarHeight })
    }
    .width('100%')
    .height('100%')
  }
}
