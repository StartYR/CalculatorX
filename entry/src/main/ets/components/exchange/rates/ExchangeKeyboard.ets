/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file ExchangeKeyboard.ets
 * @description 汇率模块的专属底部小键盘，针对数字输入与高频删除操作进行优化排布
 * @author 易睿 (Yi Rui)
 * @date 2026/8/16 17:58
 */

import { HapticUtils } from '../../../utils/HapticUtils';
import { getActionId, getFontFamily, getFontSize, getFontColor, getBgColor, icon_backspace, PreferenceConfigs } from '../../../utils/CalculatorConfigs';
import { KeyGestureWrapper } from '../../common/KeyGestureWrapper';

// ==================== 键盘数据源 ====================
// 精简后的汇率专属按键数组：移除减号与确定键，为 ⌫ 和 AC 留出跨行空间
export const exchangeButtons: Array<string | Resource> = [
  '7', '8', '9', icon_backspace,
  '4', '5', '6',
  '1', '2', '3', 'AC',
  '0', '.'
];

// ==================== 独立按键组件 ====================
@Component
export struct BottomKeyItem {
  btn: string | Resource = '';
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;
  customRadius?: number = 16;

  @State isShift: boolean = false;

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  build() {
    KeyGestureWrapper({
      actionId: getActionId(this.btn),
      targetBtn: this.btn,
      shiftBtn: '',
      moduleType: 'exchange', // 标明模块类型
      isShiftMode: $isShift,     // 无需 Shift 模式
      onKeyPress: this.onKeyPress,
      onMenuSelect: this.onMenuSelect
    }) {
      Button() {
        if (typeof this.btn === 'string') {
          Text(this.btn)
            .fontFamily(getFontFamily(this.btn))
            .fontSize(getFontSize(this.btn))
            .fontWeight(FontWeight.Medium)
            .fontColor(getFontColor(this.btn))
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
      .backgroundColor(getBgColor(this.btn, false))
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

// ==================== 底部键盘主组件 ====================
@Component
export struct ExchangeKeyboard {
  onKeyPress: (btn: string | Resource) => void = () => {};

  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;

  build() {
    Column() {
      Grid() {
        ForEach(exchangeButtons, (btn: string | Resource) => {
          GridItem() {
            BottomKeyItem({
              btn: btn,
              customRadius: 36,
              onKeyPress: (b: string | Resource) => {
                let action = getActionId(b);
                HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);
                this.onKeyPress(b);
              }
            })
          }
          // 核心布局魔法：利用网格坐标动态实现跨行/跨列
          .rowStart(btn === icon_backspace ? 0 : (btn === 'AC' ? 2 : undefined))
          .rowEnd(btn === icon_backspace ? 1 : (btn === 'AC' ? 3 : undefined))
          .columnStart((btn === icon_backspace || btn === 'AC') ? 3 : (btn === '0' ? 0 : undefined))
          .columnEnd((btn === icon_backspace || btn === 'AC') ? 3 : (btn === '0' ? 1 : undefined))
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
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(BlurStyle.Thin)
    .borderRadius({ topLeft: 36, topRight: 36 })
    .borderWidth(0.7)
    .borderColor($r('sys.color.comp_divider'))
    .shadow({ radius: 16, color: '#1A000000', offsetY: -12 })
    .padding({ bottom: this.navBarHeight - 16 })
  }
}