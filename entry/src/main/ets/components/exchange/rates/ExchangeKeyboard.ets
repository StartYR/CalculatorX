/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 *
 * @file ExchangeKeyboard.ets
 * @description 汇率模块的专属底部小键盘，1+1+1+1 功能键阶梯色彩布局
 * @author StartYi
 * @date 2026/8/20
 */

import { HapticUtils } from '../../../utils/HapticUtils';
import { getActionId, getFontFamily, getFontSize, getFontColor, icon_backspace, PreferenceConfigs } from '../../../utils/CalculatorConfigs';
import { KeyGestureWrapper } from '../../common/KeyGestureWrapper';
import { KeyboardKeyRole } from '../../common/keyboard/KeyboardKeyTypes';
import { resolveKeyboardKeyRole } from '../../common/keyboard/KeyboardVisualPolicy';
import { KeyboardKeySurface } from '../../common/keyboard/KeyboardKeySurface';
import deviceInfo from '@ohos.deviceInfo';

// ==================== 键盘数据源 ====================
// 恢复错落有致的标准 4 列布局
export const exchangeButtons: Array<string | Resource> = [
  '7', '8', '9', icon_backspace,
  '4', '5', '6','AC',
  '1', '2', '3', '⌨⇩',
  '0', '.', '确定'
];

function getExchangeKeyboardKeyRole(btn: string | Resource): KeyboardKeyRole {
  return resolveKeyboardKeyRole(btn, ['确定']);
}

// ==================== 独立按键组件 ====================
@Component
export struct BottomKeyItem {
  btn: string | Resource = '';
  immersive: boolean = false;
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;
  customRadius: number = 16;
  @State isShift: boolean = false; // 用于满足 KeyGestureWrapper 的双向绑定要求

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  @Builder
  private KeyContentBuilder() {
    if (typeof this.btn === 'string') {
      Text(this.btn)
        .fontFamily(getFontFamily(this.btn))
        .fontSize(getFontSize(this.btn))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.btn === '确定' ? getFontColor('=') : getFontColor(this.btn))
    } else {
      Image(this.btn)
        .width(48)
        .height(40)
        .fillColor(getFontColor(this.btn))
        .draggable(false)
    }
  }

  build() {
    KeyGestureWrapper({
      actionId: getActionId(this.btn),
      targetBtn: this.btn,
      shiftBtn: '',
      moduleType: 'exchange',
      isShiftMode: $isShift,
      onKeyPress: this.onKeyPress,
      onMenuSelect: this.onMenuSelect
    }) {
      KeyboardKeySurface({
        immersive: this.immersive,
        role: getExchangeKeyboardKeyRole(this.btn),
        keyBorderRadius: this.customRadius,
        horizontalPadding: 4
      }) {
        this.KeyContentBuilder()
      }
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
  @StorageProp(PreferenceConfigs.KEY_KEY_IMMERSIVE_MATERIAL) keyImmersiveMaterial: boolean = false;

  @Builder
  private KeyboardGridBuilder(immersive: boolean) {
    Grid() {
      ForEach(exchangeButtons, (btn: string | Resource) => {
        GridItem() {
          BottomKeyItem({
            btn: btn,
            immersive: immersive,
            customRadius: 36,
            onKeyPress: (b: string | Resource) => {
              let action = getActionId(b);
              HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);
              this.onKeyPress(b);
            }
          })
        }
        // 所有按钮都是 1×1，只有 0 横跨两列
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

  @Builder
  private LegacyKeyboardBuilder() {
    Column() {
      this.KeyboardGridBuilder(false)
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

  @Builder
  private ImmersiveKeyboardBuilder() {
    Column() {
      this.KeyboardGridBuilder(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(BlurStyle.Thin)
    .borderRadius({ topLeft: 36, topRight: 36 })
    .borderWidth(0.7)
    .borderColor($r('sys.color.comp_divider'))
    .shadow({ radius: 16, color: '#1A000000', offsetY: -12 })
    .padding({ bottom: this.navBarHeight - 16 })
  }

  @Builder
  private ImmersiveKeyboardLayout() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        Column()
          .width('100%')
          .height('100%')
      }
      .tabBar(this.ImmersiveKeyboardBuilder)
    }
    .vertical(false)
    .scrollable(false)
    .animationDuration(0)
    .barHeight('100%')
    .width('100%')
    .height(260 + this.navBarHeight - 16)
  }

  build() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.keyImmersiveMaterial) {
        this.ImmersiveKeyboardLayout()
      } else {
        this.LegacyKeyboardBuilder()
      }
    } else {
      this.LegacyKeyboardBuilder()
    }
  }
}
