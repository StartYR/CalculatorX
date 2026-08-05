/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file EquationSolver.ets
 * @description 方程求解核心业务面板组件
 * * @author 易睿 (Yi Rui)
 * @date 2026/7/24 22:52
 */

import { FormulaScreen } from './FormulaScreen';
import { HapticUtils } from '../utils/HapticUtils';
import { vibrator } from '@kit.SensorServiceKit';
import { getActionId, getFontFamily, getFontSize, getFontColor, getBgColor } from '../utils/CalculatorConfigs';
import { PreferenceConfigs } from '../utils/CalculatorConfigs';
import {
  icon_sqrt,
  icon_sqrtx,
  icon_power2,
  icon_power,
  icon_fraction,
  icon_abs,
  icon_backspace
} from '../utils/CalculatorConfigs';
import {KeyGestureWrapper} from './common/KeyGestureWrapper'

const icon_cases: Resource = $rawfile('icons/equation/icon_cases.svg');

// ================= 按键布局 =================
// Shift
const topShiftButtons: Array<string | Resource> = [
  '', '', '', '', '', '',
  icon_abs, icon_sqrtx, icon_power, 'i', 'm', 'n',
   'sin⁻¹', 'cos⁻¹', 'tan⁻¹', 'u', 'v', 'w'
];

// 顶部功能区
const topButtons: Array<string | Resource> = [
  '⇧Shift', icon_cases, '⇦', '⇨', '(', ')',
  icon_fraction, icon_sqrt, icon_power2, 'e','log', 'ln',
   'sin', 'cos', 'tan', 'x', 'y', 'z'
];

// 底部基础区
const bottomButtons: Array<string | Resource> = [
  '7', '8', '9', icon_backspace, 'AC',
  '4', '5', '6', '×', '÷',
  '1', '2', '3', '+', '−',
  '.', '0', 'π', '=', 'EXE',
];

// ================= 按键特征处理 =================
// 字体颜色
function getLocalFontColor(btn: string | Resource): ResourceColor {
  if (btn === 'π') return getFontColor('0');
  if (btn === '=') return getFontColor('+');
  return getFontColor(btn);
}

// 按钮颜色
function getLocalBgColor(btn: string | Resource, isShift: boolean): ResourceColor {
  if (btn === 'π') return getBgColor('0', false);
  if (btn === '=') return getBgColor('+', false);
  return getBgColor(btn, isShift);
}

// 字体大小
function getLocalFontSize(btn: string | Resource): number {
  if (btn === 'π') return getFontSize('0');
  return getFontSize(btn);
}

// 获取局部 Action ID
function getLocalActionId(btn: string | Resource): string {
  if (btn === icon_cases) return 'cases';
  return getActionId(btn);
}

// ================= 键盘组件 =================
@Component
struct TopKeyItem {
  btn: string | Resource = '';
  btnIndex: number = 0;
  @Link isShift: boolean;
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  build() {
    Column() {
      if (this.btnIndex >= 6) {
        Row() {
          if (typeof topShiftButtons[this.btnIndex] === 'string') {
            Text(topShiftButtons[this.btnIndex] as string)
              .fontFamily(getFontFamily(topShiftButtons[this.btnIndex]))
              .fontSize(17)
              .fontColor('#ffac8100')
              .textAlign(TextAlign.Center)
              .width('100%')
          } else {
            Image(topShiftButtons[this.btnIndex] as Resource)
              .width(30)
              .height(30)
              .fillColor('#ffac8100')
              .objectFit(ImageFit.Contain)
          }
        }
        .width('100%')
        .height(16)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 1 })
      } else {
        Row()
          .width('100%')
          .height(6)
      }
      Row() {
        KeyGestureWrapper({
          actionId: getLocalActionId(this.btn),
          targetBtn: this.btn,
          shiftBtn: topShiftButtons[this.btnIndex] || '', // 传入对应的 Shift 按键
          moduleType: 'equation',
          isShiftMode: $isShift,
          onKeyPress: this.onKeyPress,
          onMenuSelect: this.onMenuSelect
        }) {

          Button() {
            if (typeof this.btn === 'string') {
              Text(this.btn)
                .fontFamily(getFontFamily(this.btn))
                .fontSize(getLocalFontSize(this.btn))
                .fontWeight(FontWeight.Medium)
                .fontColor(getLocalFontColor(this.btn))
            } else {
              Image(this.btn)
                .width(36)
                .height(36)
                .fillColor($r('sys.color.font_secondary'))
                .draggable(false)
            }
          }
          .type(ButtonType.Normal)
          .borderRadius(12)
          .width('100%')
          .height('100%')
          .padding({
            left: 2,
            right: 2,
            top: 0,
            bottom: 0
          })
          .backgroundColor(getLocalBgColor(this.btn, this.isShift))
          .shadow(ShadowStyle.OUTER_DEFAULT_SM)
          .borderWidth({
            top: 1,
            left: 1,
            bottom: 0,
            right: 0
          })
          .borderColor($r('app.color.btn_highlight'))
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .stateStyles({
            pressed: {
              .opacity(0.7).shadow(ShadowStyle.OUTER_DEFAULT_XS)
            },
            normal: {
              .opacity(1.0).shadow(ShadowStyle.OUTER_DEFAULT_SM)
            }
          })
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}

@Component
struct BottomKeyItem {
  btn: string | Resource = '';
  @Link isShift: boolean;
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};


  build() {
    KeyGestureWrapper({
      actionId: getLocalActionId(this.btn),
      targetBtn: this.btn,
      shiftBtn: '', // 底部基础按键没有对应的 Shift
      moduleType: 'equation',
      // 底部的按键不需要双向绑定 isShift，所以传一个常数占位即可，因为它们也不触发直接 Shift
      isShiftMode: $isShift,
      onKeyPress: this.onKeyPress,
      onMenuSelect: this.onMenuSelect
    }) {
      Button() {
        if (typeof this.btn === 'string') {
          Text(this.btn)
            .fontFamily(getFontFamily(this.btn))
            .fontSize(getLocalFontSize(this.btn))
            .fontWeight(FontWeight.Medium)
            .fontColor(getLocalFontColor(this.btn))
        } else {
          Image(this.btn)
            .width(48)
            .height(40)
            .fillColor(getFontColor(this.btn))
            .draggable(false)
        }
      }
      .type(ButtonType.Normal)
      .borderRadius(16)
      .width('100%')
      .height('100%')
      .padding({ left: 4, right: 4 })
      .backgroundColor(getLocalBgColor(this.btn, false))
      .shadow(ShadowStyle.OUTER_DEFAULT_SM)
      .borderWidth({
        top: 1,
        left: 1,
        bottom: 0,
        right: 0
      })
      .borderColor($r('app.color.btn_highlight'))
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .stateStyles({
        pressed: {
          .opacity(0.7).shadow(ShadowStyle.OUTER_DEFAULT_XS)
        },
        normal: {
          .opacity(1.0).shadow(ShadowStyle.OUTER_DEFAULT_SM)
        }
      })
    }
  }
}

// ================= 方程求解器主外壳 =================
@Component
export struct EquationSolver {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('activeBubbleId') activeBubbleId: string = '';
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
    let action = getLocalActionId(btn);
    HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);
    getContext(this).eventHub.emit('screen_handle_action', action, this.isShift);
  }

  private handleButtonLongPress(actionCode: string) {
    getContext(this).eventHub.emit('screen_handle_action', actionCode, this.isShift);
  }

  build() {
    Column() {
      // 屏幕占比调整为 45%，并打上 equation 标签
      FormulaScreen({ moduleType: 'equation' })
        .height('45%')
        .width('100%')

      // 上下双键盘
      Column() {
        // 顶部高级键盘
        Grid() {
          ForEach(topButtons, (btn: string | Resource, index: number) => {
            GridItem() {
              TopKeyItem({
                btn: btn,
                btnIndex: index,
                isShift: $isShift,
                onKeyPress: (b: string | Resource): void => { this.handleButtonClick(b); },
                onMenuSelect: (c: string): void => { this.handleButtonLongPress(c); }
              })
            }
            .zIndex(this.activeBubbleId === getLocalActionId(btn) ? 100 : 0)
          })
        }
        .rowsTemplate('33fr 40fr 40fr')
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
        .rowsGap(6)
        .columnsGap(4)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .clip(false)
        .width('100%')
        .height('45%') // 上键盘占比

        // 底部基础键盘
        Grid() {
          ForEach(bottomButtons, (btn: string | Resource) => {
            GridItem() {
              BottomKeyItem({
                btn: btn,
                isShift: $isShift,
                onKeyPress: (b: string | Resource): void => { this.handleButtonClick(b); },
                onMenuSelect: (c: string): void => { this.handleButtonLongPress(c); }
              })
            }
            .zIndex(this.activeBubbleId === getLocalActionId(btn) ? 100 : 0)
          })
        }
        .rowsTemplate('1fr 1fr 1fr 1fr')
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
        .rowsGap(8)
        .columnsGap(6)
        .padding({ left: 10, right: 10, top: 6, bottom: 0 })
        .clip(false)
        .width('100%')
        .height('55%') // 下键盘占比
      }
      .width('100%')
      .height('55%') // 键盘总高度
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(24)
      .shadow({ radius: 16, color: '#1A000000', offsetY: -4 })
      .padding({ bottom: this.navBarHeight - 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }
}