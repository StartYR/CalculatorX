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

// 主键盘
const matrixButtons: Array<string> = [
  'Shift', '⇧', 'Dim', 'M⁻¹', 'Mᵀ',
  '⇦', '⇩', '⇨', '(', ')',
  '7', '8', '9', '⌫', 'AC',
  '4', '5', '6', '×', '÷',
  '1', '2', '3', '+', '−',
  '.', '0', 'a/b', 'Ans', '='
];

// Shift 键盘
const matrixShiftButtons: Array<string> = [
  '', '', 'I', 'det', 'Mᴴ',
  '', '', '', 'rref', 'eig',
  '', '', '', '', '',
  '', '', '', '叉乘', '点乘',
  '', '', '', 'rank', 'tr',
  '', '', '^', '绝对值', ''
];

@Component
struct MatrixKeyItem {
  btn: string = '';
  btnIndex: number = 0;
  @Link isShift: boolean; // 接收父组件的 Shift 状态双向绑定

  onKeyPress: (btn: string) => void = () => {};

  build() {
    Column() {
      //  Shift 占位与显示逻辑
      Row() {
        if (matrixShiftButtons[this.btnIndex] !== '') {
          Text(matrixShiftButtons[this.btnIndex])
            .fontFamily(getFontFamily(matrixShiftButtons[this.btnIndex]))
            .fontSize(15)
            .fontColor('#ffac8100') // 严格照搬科学计算器的橘黄色
            .textAlign(TextAlign.Center)
            .width('100%')
        }
      }
      .width('100%')
      .height(16)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 1 })

      Button() {
        Text(this.btn)
          .fontFamily(getFontFamily(this.btn))
          .fontSize(getFontSize(this.btn))
          .fontWeight(FontWeight.Medium)
          .fontColor(getFontColor(this.btn))
      }
      .type(ButtonType.Normal)
      .borderRadius(12) // 照搬 TopKeyItem 的圆角
      .width('100%')
      .layoutWeight(1) // 自动撑满剩余高度
      .padding({ left: 2, right: 2, top: 0, bottom: 0 })
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
        if (this.btn === 'Shift') {
          this.isShift = !this.isShift;
          return;
        }

        // 兜底逻辑：如果 Shift 激活但该键无 Shift 功能，执行原功能
        if (this.isShift && matrixShiftButtons[this.btnIndex] !== '') {
          this.onKeyPress(matrixShiftButtons[this.btnIndex]);
          this.isShift = false; // 触发后自动复位
        } else {
          this.onKeyPress(this.btn);
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

@Component
export struct MatrixCalc {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;

  // 增加 Shift 状态及事件监听 (完全照搬 ScientificCalc)
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

  private handleButtonClick(btn: string) {
    let action = getActionId(btn);
    // 触发马达震动反馈
    HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);

    // TODO: 后续补充具体的按键逻辑与维度弹窗
  }

  build() {
    Column() {
      // ================= 1. 纯净公式显示区 (高度设定为 55%) =================
      FormulaScreen({ moduleType: 'matrix' })
        .width('100%')
        .height('55%')

      // ================= 2. 专属矩阵键盘区域 (高度压缩至 45%) =================
      Column() {
        Grid() {
          // 注意这里增加了 index 用于映射 Shift 数组
          ForEach(matrixButtons, (btn: string, index: number) => {
            GridItem() {
              MatrixKeyItem({
                btn: btn,
                btnIndex: index,       // 传入数组索引
                isShift: $isShift,     // 双向绑定 Shift 状态
                onKeyPress: (b: string): void => { this.handleButtonClick(b); }
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