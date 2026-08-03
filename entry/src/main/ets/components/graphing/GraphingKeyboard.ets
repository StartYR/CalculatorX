/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file GraphingKeyboard.ets
 * @description 图形计算器专属键盘组件及按键配置
 * @author 易睿 (Yi Rui)
 * @date 2026/8/3 19:46
 */

import { HapticUtils } from '../../utils/HapticUtils';
import { getActionId, getFontFamily, getFontSize, getFontColor, getBgColor } from '../../utils/CalculatorConfigs';
import { PreferenceConfigs } from '../../utils/CalculatorConfigs';
import {
  icon_sqrt, icon_sqrt3, icon_sqrtx, icon_power2, icon_power3,
  icon_power, icon_fraction, icon_abs, icon_backspace
} from '../../utils/CalculatorConfigs';
import { KeyGestureWrapper } from '../common/KeyGestureWrapper';

// ==================== 按键布局配置 ====================
export const topShiftButtons: Array<string | Resource> = [
  '', '', '', '', '', '',
  icon_sqrt3, icon_abs, icon_power3, '', '', 'lg',
  'sin⁻¹', 'cos⁻¹', 'tan⁻¹', '', '', ''
];
export const topButtons: Array<string | Resource> = [
  '⇧Shift', '(', '⇦', '⇨', ')', '关闭',
  icon_sqrt, icon_sqrtx, icon_power2, icon_power,'log', 'ln',
  'sin', 'cos', 'tan', icon_fraction, 'x', 'θ'
];
export const bottomButtons: Array<string | Resource> = [
  '7', '8', '9', icon_backspace, 'AC',
  '4', '5', '6', '×', '÷',
  '1', '2', '3', '+', '−',
  '.', '0', 'π', 'e', '确定'
];

function getLocalFontColor(btn: string | Resource): ResourceColor {
  if (btn === 'π' || btn === 'e') return getFontColor('0');
  if (btn === '确定' || btn === '关闭') return getFontColor('=');
  return getFontColor(btn);
}

function getLocalBgColor(btn: string | Resource, isShift: boolean): ResourceColor {
  if (btn === 'π' || btn === 'e') return getBgColor('0', false);
  if (btn === '确定') return getBgColor('=', false);
  if (btn === '关闭') return Color.Red;
  return getBgColor(btn, isShift);
}

function getLocalFontSize(btn: string | Resource): number {
  if (btn === 'π' || btn === 'e') return getFontSize('0');
  return getFontSize(btn);
}

function getLocalActionId(btn: string | Resource): string {
  return getActionId(btn);
}

@Component
export struct TopKeyItem {
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
        Row().width('100%').height(6)
      }

      Row() {
        KeyGestureWrapper({
          actionId: getLocalActionId(this.btn),
          targetBtn: this.btn,
          shiftBtn: topShiftButtons[this.btnIndex] || '',
          moduleType: 'graphing',
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
          .padding({ left: 2, right: 2 })
          .backgroundColor(getLocalBgColor(this.btn, this.isShift))
          .shadow(ShadowStyle.OUTER_DEFAULT_SM)
          .borderWidth({ top: 1, left: 1, bottom: 0, right: 0 })
          .borderColor($r('app.color.btn_highlight'))
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .stateStyles({
            pressed: { .opacity(0.7).shadow(ShadowStyle.OUTER_DEFAULT_XS) },
            normal: { .opacity(1.0).shadow(ShadowStyle.OUTER_DEFAULT_SM) }
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
export struct BottomKeyItem {
  btn: string | Resource = '';
  @Link isShift: boolean;
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;
  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  build() {
    KeyGestureWrapper({
      actionId: getLocalActionId(this.btn),
      targetBtn: this.btn,
      shiftBtn: '',
      moduleType: 'graphing',
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
      .borderWidth({ top: 1, left: 1, bottom: 0, right: 0 })
      .borderColor($r('app.color.btn_highlight'))
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .stateStyles({
        pressed: { .opacity(0.7).shadow(ShadowStyle.OUTER_DEFAULT_XS) },
        normal: { .opacity(1.0).shadow(ShadowStyle.OUTER_DEFAULT_SM) }
      })
    }
  }
}