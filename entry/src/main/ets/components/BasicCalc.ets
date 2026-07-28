/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file BasicCalc.ets
 * @description 基础计算器独立业务面板插件
 * * @author 易睿 (Yi Rui)
 * @date 2026/6/26 02:20
 */

import { FormulaScreen } from './FormulaScreen';
import { HapticUtils } from '../utils/HapticUtils';
import { getActionId, getFontColor, getBgColor, PreferenceConfigs, icon_backspace } from '../utils/CalculatorConfigs';

// 按键布局
const basicButtons: Array<string | Resource> = [
  '×', '÷', icon_backspace, 'AC',
  '7', '8', '9', '%',
  '4', '5', '6', '−',
  '1', '2', '3', '+',
  '.', '0', 'Ans', '='
];

function getLocalFontSize(btn: string | Resource): number {
  if (btn === '+' || btn === '−' || btn === 'π' || btn === '×' || btn === '÷' || btn === '=') return 40;
  if (btn === 'Ans' || btn === 'AC') return 26;
  return 30;
}

// 按键
@Component
struct BasicKeyItem {
  btn: string | Resource = '';
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;
  private startDelayTimer: number = -1;
  private repeatDeleteTimer: number = -1;

  onKeyPress: (btn: string | Resource) => void = () => {};

  build() {
    Button() {
      if (typeof this.btn === 'string') {
        Text(this.btn)
          .fontFamily('HarmonyOS Sans')
          .fontSize(getLocalFontSize(this.btn))
          .fontWeight(FontWeight.Medium)
          .fontColor(getFontColor(this.btn))
      } else {
        Image(this.btn)
          .width(48)
          .height(48)
          .fillColor(getFontColor(this.btn))
      }
    }
    .type(ButtonType.Normal)
    .borderRadius(40)
    .width('100%')
    .height('100%')
    .padding({ left: 4, right: 4 })
    .backgroundColor(getBgColor(this.btn, false))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .borderWidth({ top: 1, left: 1, bottom: 0, right: 0 })
    .borderColor($r('app.color.btn_highlight'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
    .stateStyles({
      pressed: { .opacity(0.75).shadow(ShadowStyle.OUTER_DEFAULT_XS) },
      normal: { .opacity(1.0).shadow(ShadowStyle.OUTER_DEFAULT_SM) }
    })
    .onClick(() => {
      this.onKeyPress(this.btn as string);
    })
    .onTouch((event: TouchEvent) => {
      if (this.btn === icon_backspace) {
        if (event.type === TouchType.Down) {
          clearTimeout(this.startDelayTimer);
          clearInterval(this.repeatDeleteTimer);

          this.startDelayTimer = setTimeout(() => {
            this.repeatDeleteTimer = setInterval(() => {
              this.onKeyPress(this.btn as string);
            }, 80);
          }, 500);
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          clearTimeout(this.startDelayTimer);
          clearInterval(this.repeatDeleteTimer);
        }
      }
    })
  }
}

// 外壳组件
@Component
export struct BasicCalc {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;

  // 作为传声筒，无脑呼叫 FormulaScreen
  private handleKeyPress(btn: string | Resource) {
    let action = getActionId(btn);
    HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);
    getContext(this).eventHub.emit('screen_handle_action', action, false);
  }

  build() {
    Column() {
      // 屏幕，占位 45%
      FormulaScreen({ moduleType: 'basic' })
        .height('45%')
        .width('100%')

      Column() {
        Grid() {
          ForEach(basicButtons, (btn: string | Resource) => {
            GridItem() {
              BasicKeyItem({
                btn: btn,
                onKeyPress: (b: string | Resource): void => { this.handleKeyPress(b); }
              })
            }
          })
        }
        .rowsTemplate('1fr 1fr 1fr 1fr 1fr')
        .columnsTemplate('1fr 1fr 1fr 1fr')
        .rowsGap(12)
        .columnsGap(18)
        .padding({ left: 16, right: 16, top: 20, bottom: 5 })
        .clip(false)
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('55%')
      .backgroundColor($r('sys.color.comp_background_primary')) // 主背景色
      .borderRadius(40)
      .padding({ bottom: this.navBarHeight - 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }
}