/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * * @file EquationSolver.ets
 * @description 方程求解核心业务面板组件
 * * @author StartYi
 * @date 2026/7/24 22:52
 */

import { FormulaScreen } from './FormulaScreen';
import { HapticUtils } from '../utils/HapticUtils';
import { vibrator } from '@kit.SensorServiceKit';
import { getActionId, getFontFamily, getFontSize, getFontColor } from '../utils/CalculatorConfigs';
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
import { KeyboardKeyRole } from './common/keyboard/KeyboardKeyTypes';
import { resolveKeyboardKeyRole } from './common/keyboard/KeyboardVisualPolicy';
import { KeyboardKeySurface } from './common/keyboard/KeyboardKeySurface';
import deviceInfo from '@ohos.deviceInfo';

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

function getEquationKeyboardKeyRole(btn: string | Resource): KeyboardKeyRole {
  return resolveKeyboardKeyRole(btn, ['EXE'], ['π'], ['=']);
}

// ================= 键盘组件 =================
@Component
struct TopKeyItem {
  btn: string | Resource = '';
  btnIndex: number = 0;
  immersive: boolean = false;
  @Link isShift: boolean;
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  @Builder
  private KeyContentBuilder() {
    Stack({ alignContent: Alignment.Center }) {
      if (typeof this.btn === 'string') {
        Text(this.btn)
          .fontFamily(getFontFamily(this.btn))
          .fontSize(getLocalFontSize(this.btn))
          .fontWeight(FontWeight.Medium)
          .fontColor(getLocalFontColor(this.btn))
          .textAlign(TextAlign.Center)
          .maxLines(1)
      } else {
        Image(this.btn)
          .width('100%')
          .height('100%')
          .constraintSize({ maxWidth: 42, maxHeight: 42 })
          .objectFit(ImageFit.Contain)
          .fillColor($r('sys.color.font_secondary'))
          .draggable(false)
      }
    }
    .width('100%')
    .height('100%')
  }

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
          KeyboardKeySurface({
            immersive: this.immersive,
            role: getEquationKeyboardKeyRole(this.btn),
            shiftActive: this.isShift,
            keyBorderRadius: 12,
            horizontalPadding: 2
          }) {
            this.KeyContentBuilder()
          }
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
  immersive: boolean = false;
  @Link isShift: boolean;
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  @Builder
  private KeyContentBuilder() {
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
      KeyboardKeySurface({
        immersive: this.immersive,
        role: getEquationKeyboardKeyRole(this.btn),
        keyBorderRadius: 16,
        horizontalPadding: 4
      }) {
        this.KeyContentBuilder()
      }
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
  @StorageProp(PreferenceConfigs.KEY_KEY_IMMERSIVE_MATERIAL) keyImmersiveMaterial: boolean = false;

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

  @Builder
  private TopKeyboardBuilder(immersive: boolean) {
    Grid() {
      ForEach(topButtons, (btn: string | Resource, index: number) => {
        GridItem() {
          TopKeyItem({
            btn: btn,
            btnIndex: index,
            immersive: immersive,
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
    .height('45%')
  }

  @Builder
  private BottomKeyboardBuilder(immersive: boolean) {
    Grid() {
      ForEach(bottomButtons, (btn: string | Resource) => {
        GridItem() {
          BottomKeyItem({
            btn: btn,
            immersive: immersive,
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
    .height('55%')
  }

  @Builder
  private LegacyEquationKeyboardBuilder() {
    Column() {
      this.TopKeyboardBuilder(false)
      this.BottomKeyboardBuilder(false)
    }
    .width('100%')
    .height('55%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(24)
    .shadow({ radius: 16, color: '#1A000000', offsetY: -4 })
    .padding({ bottom: this.navBarHeight - 8 })
  }

  @Builder
  private ImmersiveEquationKeyboardBuilder() {
    Column() {
      this.TopKeyboardBuilder(true)
      this.BottomKeyboardBuilder(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(24)
    .shadow({ radius: 16, color: '#1A000000', offsetY: -4 })
    .padding({ bottom: this.navBarHeight - 8 })
  }

  @Builder
  private LegacyEquationLayout() {
    Column() {
      FormulaScreen({ moduleType: 'equation' })
        .height('45%')
        .width('100%')

      this.LegacyEquationKeyboardBuilder()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }

  @Builder
  private ImmersiveEquationLayout() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        FormulaScreen({ moduleType: 'equation' })
          .height('100%')
          .width('100%')
      }
      .tabBar(this.ImmersiveEquationKeyboardBuilder)
    }
    .vertical(false)
    .scrollable(false)
    .animationDuration(0)
    .barHeight('55%')
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }

  build() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.keyImmersiveMaterial) {
        this.ImmersiveEquationLayout()
      } else {
        this.LegacyEquationLayout()
      }
    } else {
      this.LegacyEquationLayout()
    }
  }
}
