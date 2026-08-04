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
  icon_sqrt3, icon_abs, icon_power3, 'y', 't', 'θ',
  'sin⁻¹', 'cos⁻¹', 'tan⁻¹', '', '', ''
];
export const topButtons: Array<string | Resource> = [
  '⇧Shift', '(', '⇦', '⇨', ')', '关闭',
  icon_sqrt, icon_sqrtx, icon_power2, icon_power,icon_fraction, 'x',
  'sin', 'cos', 'tan', 'log', 'ln', 'lg'
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

  customRadius?: number = 16;

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
      .borderRadius(this.customRadius)
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

// ==================== 定义域专属纯净数字键盘 ====================
export const domainButtons: Array<string | Resource> = [
  '7', '8', '9', icon_backspace,
  '4', '5', '6', 'AC',
  '1', '2', '3', '−', // 使用你已经处理好映射的优雅减号
  '0', '.', '确定'
];

@Component
export struct DomainKeyboard {
  // 占位状态，用于满足 BottomKeyItem 对 @Link isShift 的要求
  @State private isShift: boolean = false;

  // 暴露给外部的回调，专门处理点击事件
  onKeyPress: (btn: string | Resource) => void = () => {};

  // --- 获取全局状态 ---
  @StorageProp('navBarHeight') navBarHeight: number = 0; // 用于底部避让
  @StorageProp('vibrationCurve') vibrationCurve: number = 0; // 震动反馈参数
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true; // 震动开关

  build() {
    Column() {
      Grid() {
        ForEach(domainButtons, (btn: string | Resource) => {
          GridItem() {
            BottomKeyItem({
              btn: btn,
              isShift: $isShift,
              customRadius: 36,
              onKeyPress: (b: string | Resource) => {
                let action = getActionId(b);
                HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);

                // 将点击事件向上传递给控制器
                this.onKeyPress(b);
              }
            })
          }
          .columnStart(btn === '0' ? 0 : undefined)
          .columnEnd(btn === '0' ? 1 : undefined)
        }, (btn: string | Resource) => typeof btn === 'string' ? btn : 'icon_backspace')
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsTemplate('1fr 1fr 1fr 1fr')
      .columnsGap(8)
      .rowsGap(8)
      .width('100%')
      .height(260)
      .padding({ left: 10, right: 10, top: 12, bottom: 8 })
    }
    .width('100%')
    // .backgroundColor($r('sys.color.comp_background_primary'))
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(BlurStyle.Thin)
    .borderRadius({ topLeft: 36, topRight: 36 })
    .padding({ bottom: this.navBarHeight - 16})
  }
}