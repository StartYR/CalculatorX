/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * @file ScientificCalc.ets
 * @description 科学计算器核心业务面板组件。
 * 本组件作为独立的业务模块，封装了科学计算器专用的双 Webview（前端渲染与后台暗房离线渲染）以及上下键盘。
 * 负责捕获用户输入、维护计算过程的局部状态（如 Ans、Shift、纯净 AST 等），
 * 并桥接 HapticUtils 与 EngineService 进行计算，最终通过 HistoryRepository 实现历史记录图文的持久化。
 * 此组件的剥离实现了 UI 业务层与 Index 全局主入口的彻底解耦。
 * @author 易睿 (Yi Rui)
 * @date 2026/6/25 17:30
 */

import { FormulaScreen } from './FormulaScreen';
import { HapticUtils } from '../utils/HapticUtils';
import { KeyGestureWrapper } from './common/KeyGestureWrapper';
import { getActionId, getFontFamily, getFontSize, getFontColor, getBgColor } from '../utils/CalculatorConfigs';
import { PreferenceConfigs } from '../utils/CalculatorConfigs';
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

// ================= 按键布局数组 =================
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

// ================= 键盘组件 =================
@Component
struct TopKeyItem {
  btn: string | Resource = '';
  btnIndex: number = 0;
  @Link isShift: boolean;
  @StorageProp(PreferenceConfigs.KEY_COMBINATION_SELECT) combSelect: number = 1;
  @StorageProp(PreferenceConfigs.KEY_PERMUTATION_SELECT) permSelect: number = 1;

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  build() {
    // 注入底层交互包装器
    KeyGestureWrapper({
      actionId: getActionId(this.btn),
      targetBtn: this.btn,
      shiftBtn: topShiftButtons[this.btnIndex] || '',
      moduleType: 'scientific',
      isShiftMode: $isShift,
      onKeyPress: this.onKeyPress,
      onMenuSelect: this.onMenuSelect
    }) {
      //  UI 结构
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
                .width('100%')
                .height('100%')
                .constraintSize({ maxWidth: 24, maxHeight: 16 })
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
          Stack({ alignContent: Alignment.Center }) {
            if (this.btn === 'nCr') {
              Image(CombinationOptions[this.combSelect].icon)
                .width('100%')
                .height('100%')
                .constraintSize({ maxHeight: 40 })
                .objectFit(ImageFit.Contain)
                .fillColor($r('sys.color.font_secondary'))
            } else if (this.btn === 'nPr') {
              Image(PermutationOptions[this.permSelect].icon)
                .width('100%')
                .height('100%')
                .constraintSize({ maxHeight: 40 })
                .objectFit(ImageFit.Contain)
                .fillColor($r('sys.color.font_secondary'))
            } else if (typeof this.btn === 'string') {
              Text(this.btn)
                .fontFamily(getFontFamily(this.btn))
                .fontSize(getFontSize(this.btn) + 1)
                .fontWeight(FontWeight.Medium)
                .fontColor(getFontColor(this.btn))
                .textAlign(TextAlign.Center)
                .maxLines(1)
            } else {
              Image(this.btn)
                .width('100%')
                .height('100%')
                .constraintSize({ maxWidth: 40, maxHeight: 40 })
                .objectFit(ImageFit.Contain)
                .fillColor($r('sys.color.font_secondary'))
                .draggable(false)
            }
          }
          .width('100%')
          .height('100%')
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
      }
      .width('100%')
      .height('100%')
    }
  }
}

@Component
struct BottomKeyItem {
  btn: string | Resource = '';
  @State dummyShift: boolean = false; // 用于满足底层 Wrapper 对 @Link 的双向绑定需求

  onKeyPress: (btn: string | Resource) => void = () => {};
  onMenuSelect: (actionCode: string) => void = () => {};

  build() {
    // 注入底层交互包装器
    KeyGestureWrapper({
      actionId: getActionId(this.btn),
      targetBtn: this.btn,
      shiftBtn: '',
      moduleType: 'scientific',
      isShiftMode: $dummyShift,
      onKeyPress: this.onKeyPress,
      onMenuSelect: this.onMenuSelect
    }) {
      Button() {
        Stack({ alignContent: Alignment.Center }) {
          if (typeof this.btn === 'string') {
            Text(this.btn)
              .fontFamily(getFontFamily(this.btn))
              .fontSize(getFontSize(this.btn) + 1)
              .fontWeight(FontWeight.Medium)
              .fontColor(getFontColor(this.btn))
              .textAlign(TextAlign.Center)
              .maxLines(1)
          } else if (this.btn === icon_exp) {
            // 指数图标位于高度充足的基础按键区，保留原始尺寸，避免 Contain 因 SVG 留白将有效图形过度缩小
            Image(this.btn)
              .width(48)
              .height(40)
              .fillColor(getFontColor(this.btn))
              .draggable(false)
          } else {
            Image(this.btn)
              .width('100%')
              .height('100%')
              .constraintSize({ maxWidth: 50, maxHeight: 42 })
              .objectFit(ImageFit.Contain)
              .fillColor(getFontColor(this.btn))
              .draggable(false)
          }
        }
        .width('100%')
        .height('100%')
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
      // 同样彻底清空所有自带的手势拦截代码！
    }
  }
}

// ================= 主外壳 =================
@Component
export struct ScientificCalc {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @StorageProp('vibrationCurve') vibrationCurve: number = 0;
  @StorageProp('hapticFeedback') hapticFeedback: boolean = true;
  @StorageProp('activeBubbleId') activeBubbleId: string = '';

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

  // 向 FormulaScreen 传达按键
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
      // 1. 挂载屏幕
      FormulaScreen({ moduleType: 'scientific' })
        .height('33%')
        .width('100%')

      // 2. 挂载上下双键盘
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
            .zIndex(this.activeBubbleId === getActionId(btn) ? 100 : 0)
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
            // 应用动态提权层级机制
            .zIndex(this.activeBubbleId === getActionId(btn) ? 100 : 0)
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
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(24)
      .shadow({ radius: 16, color: '#1A000000', offsetY: -4 })
      .padding({ bottom: this.navBarHeight - 8 })
      // 将大量静态按键合并为一个缓存渲染组，降低侧边栏缩放动画期间的重复绘制负载
      .renderGroup(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }
}
