/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file BasicCalc.ets
 * @description 基础计算器独立业务面板插件
 * * @author 易睿 (Yi Rui)
 * @date 2026/6/26 02:20
 */

import { FormulaScreen } from './FormulaScreen';
import { HapticUtils } from '../utils/HapticUtils';
import { getActionId, getFontFamily, getFontSize, getFontColor, getBgColor, PreferenceConfigs, icon_backspace } from '../utils/CalculatorConfigs';

// 1. 私有按键布局数组
const basicButtons: Array<string | Resource> = [
  '×', '÷', icon_backspace, 'AC',
  '7', '8', '9', '%',
  '4', '5', '6', '−',
  '1', '2', '3', '+',
  '.', '0', 'Ans', '='
];

// 2. 局部私有基础按键积木
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
          .fontFamily(getFontFamily(this.btn))
          .fontSize(getFontSize(this.btn) + 2)
          .fontWeight(FontWeight.Medium)
          .fontColor(getFontColor(this.btn))
      } else {
        Image(this.btn)
          .width(48)
          .height(40)
          .fillColor(getFontColor(this.btn))
      }
    }
    .type(ButtonType.Normal)
    .borderRadius(20)
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

// 3. 基础计算器外壳组件
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
      // 挂载万能屏幕，占位 45% (严格恢复原代码设置)
      FormulaScreen({ moduleType: 'basic' })
        .height('45%')
        .width('100%')

      // 组装内聚的基础键盘，占位 55% (严格恢复原代码设置)
      Grid() {
        ForEach(basicButtons, (btn: string | Resource) => {
          GridItem() {
            BasicKeyItem({
              btn: btn,
              onKeyPress: (b: string | Resource): void => { this.handleKeyPress(b); } // 修复 ArkTS 类型检测
            })
          }
        })
      }
      .rowsTemplate('1fr 1fr 1fr 1fr 1fr')
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsGap(14)
      .columnsGap(12)
      .padding({ left: 16, right: 16, top: 10, bottom: 16 })
      .clip(false)
      .width('100%')
      .height('55%')
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: this.navBarHeight })
    .backgroundColor($r('sys.color.background_primary'))
  }
}