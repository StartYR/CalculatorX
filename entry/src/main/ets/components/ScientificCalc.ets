/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file ScientificCalc.ets
 * @description 科学计算器核心业务面板组件。
 * 本组件作为独立的业务模块，封装了科学计算器专用的双 Webview（前端渲染与后台暗房离线渲染）以及上下键盘。
 * 负责捕获用户输入、维护计算过程的局部状态（如 Ans、Shift、纯净 AST 等），
 * 并桥接 HapticUtils 与 EngineService 进行计算，最终通过 HistoryRepository 实现历史记录图文的持久化。
 * 此组件的剥离实现了 UI 业务层与 Index 全局主入口的彻底解耦。
 * * @author 易睿 (Yi Rui)
 * @date 2026/6/25 17:30
 */

import { FormulaScreen } from './FormulaScreen';
import { HapticUtils } from '../utils/HapticUtils';
import { vibrator } from '@kit.SensorServiceKit';
import { getActionId, getFontFamily, getFontSize, getFontColor, getBgColor } from '../utils/CalculatorConfigs';
import { keyContextMenuRegistry, CustomMenuItem, PreferenceConfigs } from '../utils/CalculatorConfigs';
import {
  CombinationOptions,
  PermutationOptions,
  icon_integral,
  icon_indef_integral,
  icon_abs, icon_sqrt,
  icon_sqrt3,
  icon_sqrtx,
  icon_power2,
  icon_power,
  icon_fraction,
  icon_power3,
  icon_exp,
  icon_inverse,
  icon_e_power,
  icon_comma,
  icon_fact,
  icon_sum,
  icon_product,
  icon_backspace
} from '../utils/CalculatorConfigs';

// ================= 1. 私有按键布局数组 =================
const topShiftButtons: Array<string | Resource> = [
  '', '', '', '', '', '',
  'm', 'n', 'd/dx', icon_indef_integral,'GCD', 'LCM',
  'a', 'b', 'c', 'd', icon_e_power, 'lg',
  'mod', icon_sqrt3, '%', icon_power3, icon_comma, icon_inverse,
  'sin⁻¹', 'cos⁻¹', 'tan⁻¹', 'x', 'y', 'z',
];

const topButtons: Array<string | Resource> = [
  '⇧Shift', 'R/D', '⇦', '⇨', 'S⇄D', 'i',
  '° \' \"', '∞', 'lim', icon_integral, icon_sum, icon_product,
  icon_fact, 'nCr', 'nPr', 'e', 'ln', 'log',
  icon_abs, icon_sqrt, icon_sqrtx, icon_power2, icon_power, icon_fraction,
  'sin', 'cos', 'tan', 'π', '(', ')',
];

const bottomButtons: Array<string | Resource> = [
  '7', '8', '9', icon_backspace, 'AC',
  '4', '5', '6', '×', '÷',
  '1', '2', '3', '+', '−',
  '.', '0', icon_exp, 'Ans', '=',
];

// ================= 2. 局部私有键盘组件 =================
@Component
struct TopKeyItem {
  btn: string | Resource = '';
  btnIndex: number = 0;
  @Link isShift: boolean;
  @StorageProp(PreferenceConfigs.KEY_COMBINATION_SELECT) combSelect: number = 1;
  @StorageProp(PreferenceConfigs.KEY_PERMUTATION_SELECT) permSelect: number = 1;
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;
  @State isMenuShow: boolean = false;

  private startDelayTimer: number = -1;
  private repeatMoveTimer: number = -1;

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  @Builder
  MenuBuilder() {
    Menu() {
      ForEach(keyContextMenuRegistry[this.btn as string] || [], (item: CustomMenuItem) => {
        MenuItem({ content: item.value })
          .onClick(() => {
            this.isMenuShow = false;
            this.onMenuSelect(item.actionCode);
          })
      })
    }
  }

  build() {
    Column() {
      if (this.btnIndex >= 6) {
        Row() {
          if (typeof topShiftButtons[this.btnIndex] === 'string') {
            Text(topShiftButtons[this.btnIndex] as string)
              .fontFamily(getFontFamily(topShiftButtons[this.btnIndex]))
              .fontSize(15)
              .fontColor('#ffac8100')
              .textAlign(TextAlign.Center)
              .width('100%')
          } else {
            Image(topShiftButtons[this.btnIndex] as Resource)
              .width(24)
              .height(24)
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

      Button() {
        if (this.btn === 'nCr') {
          Image(CombinationOptions[this.combSelect].icon)
            .width('100%')
            .height(36)
            .objectFit(ImageFit.Contain)
            .fillColor($r('sys.color.font_secondary'))
        } else if (this.btn === 'nPr') {
          Image(PermutationOptions[this.permSelect].icon)
            .width('100%')
            .height(36)
            .objectFit(ImageFit.Contain)
            .fillColor($r('sys.color.font_secondary'))
        } else if (typeof this.btn === 'string') {
          Text(this.btn)
            .fontFamily(getFontFamily(this.btn))
            .fontSize(getFontSize(this.btn))
            .fontWeight(FontWeight.Medium)
            .fontColor(getFontColor(this.btn))
        } else {
          Image(this.btn)
            .width(36)
            .height(36)
            .fillColor($r('sys.color.font_secondary'))
        }
      }
      .type(ButtonType.Normal)
      .borderRadius(12)
      .width('100%')
      .layoutWeight(1)
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
        if (this.btn === '⇧Shift') {
          this.isShift = !this.isShift;
          return;
        }

        if (this.isShift && topShiftButtons[this.btnIndex] !== '') {
          this.onKeyPress(topShiftButtons[this.btnIndex]);
          this.isShift = false;
        } else {
          this.onKeyPress(this.btn);
        }
      })
      .onTouch((event: TouchEvent) => {
        if (this.btn === '⇦' || this.btn === '⇨') {
          if (event.type === TouchType.Down) {
            clearTimeout(this.startDelayTimer);
            clearInterval(this.repeatMoveTimer);

            this.startDelayTimer = setTimeout(() => {
              this.repeatMoveTimer = setInterval(() => {
                this.onKeyPress(this.btn as string);
              }, 80);
            }, 500);
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            clearTimeout(this.startDelayTimer);
            clearInterval(this.repeatMoveTimer);
          }
        }
      })
      .bindContextMenu(this.isMenuShow, this.MenuBuilder, {
        onDisappear: () => { this.isMenuShow = false; }
      })
      .gesture(
        LongPressGesture({ repeat: false, duration: 300 }).onAction(() => {
          if (typeof this.btn === 'string' && keyContextMenuRegistry[this.btn]) {
            if (this.hapticFeedback) {
              vibrator.startVibration({
                type: 'preset',
                effectId: 'haptic.effect.sharp',
                count: 1
              }, { usage: 'touch' }).catch(() => {});
            }
            this.isMenuShow = true;
          }
        })
      )
    }
    .width('100%')
    .height('100%')
  }
}

@Component
struct BottomKeyItem {
  btn: string | Resource = '';
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;
  @State isMenuShow: boolean = false;

  private startDelayTimer: number = -1;
  private repeatDeleteTimer: number = -1;

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  @Builder
  MenuBuilder() {
    Menu() {
      ForEach(keyContextMenuRegistry[this.btn as string] || [], (item: CustomMenuItem) => {
        MenuItem({ content: item.value })
          .onClick(() => {
            this.isMenuShow = false;
            this.onMenuSelect(item.actionCode);
          })
      })
    }
  }

  build() {
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
      }
    }
    .type(ButtonType.Normal)
    .borderRadius(16)
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
    .bindContextMenu(this.isMenuShow, this.MenuBuilder, {
      onDisappear: () => { this.isMenuShow = false; }
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 300 }).onAction(() => {
        if (typeof this.btn === 'string' && keyContextMenuRegistry[this.btn]) {
          if (this.hapticFeedback) {
            vibrator.startVibration({
              type: 'preset',
              effectId: 'haptic.effect.sharp',
              count: 1
            }, { usage: 'touch' }).catch(() => {});
          }
          this.isMenuShow = true;
        }
      })
    )
  }
}

// ================= 3. 科学计算器主外壳 =================
@Component
export struct ScientificCalc {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;

  @State @Watch('onShiftChange') isShift: boolean = false; // @Watch 监听器

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

  // 无脑向 FormulaScreen 传达按键意图
  private handleButtonClick(btn: string | Resource) {
    let action = getActionId(btn);
    HapticUtils.playVibration(action, this.hapticFeedback, this.vibrationCurve);
    getContext(this).eventHub.emit('screen_handle_action', action, this.isShift);
  }

  private handleButtonLongPress(actionCode: string) {
    getContext(this).eventHub.emit('screen_handle_action', actionCode, this.isShift);
  }

  build() {
    Column() {
      // 1. 挂载万能屏幕，占位 33%
      FormulaScreen({ moduleType: 'scientific' })
        .height('33%')
        .width('100%')

      // 2. 挂载科学专属的上下双键盘，占位 67%
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
          })
        }
        .rowsTemplate('8fr 10fr 10fr 10fr 10fr')
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
        .rowsGap(4)
        .columnsGap(4)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .clip(false)
        .width('100%')
        .height('57%')

        // 底部基础键盘
        Grid() {
          ForEach(bottomButtons, (btn: string | Resource) => {
            GridItem() {
              BottomKeyItem({
                btn: btn,
                onKeyPress: (b: string | Resource): void => { this.handleButtonClick(b); },
                onMenuSelect: (c: string): void => { this.handleButtonLongPress(c); }
              })
            }
          })
        }
        .rowsTemplate('1fr 1fr 1fr 1fr')
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
        .rowsGap(8)
        .columnsGap(6)
        .padding({ left: 10, right: 10, top: 6, bottom: 0 })
        .clip(false)
        .width('100%')
        .height('43%')
      }
      .width('100%')
      .height('67%')
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .padding({ bottom: this.navBarHeight })
    }
    .width('100%')
    .height('100%')
  }
}