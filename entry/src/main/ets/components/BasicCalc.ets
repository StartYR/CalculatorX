/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * * @file BasicCalc.ets
 * @description 基础计算器独立业务面板插件
 * * @author StartYi
 * @date 2026/6/26 02:20
 */

import { FormulaScreen } from './FormulaScreen';
import { HapticUtils } from '../utils/HapticUtils';
import { getActionId, getFontColor, PreferenceConfigs, icon_backspace } from '../utils/CalculatorConfigs';
import { getCalculatorKeySemanticId } from '../utils/SemanticIds';
import { KeyboardKeyRole } from './common/keyboard/KeyboardKeyTypes';
import { resolveKeyboardKeyRole } from './common/keyboard/KeyboardVisualPolicy';
import { KeyboardKeySurface } from './common/keyboard/KeyboardKeySurface';
import { PageKeyboardHost } from './common/keyboard/PageKeyboardHost';

// 按键布局
const basicButtons: Array<string | Resource> = [
  '÷', '×', icon_backspace, 'AC',
  '7', '8', '9', '−',
  '4', '5', '6', '+',
  '1', '2', '3', '=',
  '.', '0', '%', ''
];

// 字体大小
function getLocalFontSize(btn: string | Resource): number {
  if (btn === '+' || btn === '−' || btn === 'π' || btn === '×' || btn === '÷' || btn === '=') return 40;
  if (btn === 'AC') return 26;
  return 30;
}

function getKeyboardKeyRole(btn: string | Resource): KeyboardKeyRole {
  return resolveKeyboardKeyRole(btn, ['='], ['%']);
}

// 按键
@Component
struct BasicKeyItem {
  btn: string | Resource = '';
  immersive: boolean = false;
  @StorageProp(PreferenceConfigs.KEY_HAPTIC_FEEDBACK) hapticFeedback: boolean = true;
  private startDelayTimer: number = -1;
  private repeatDeleteTimer: number = -1;

  onKeyPress: (btn: string | Resource) => void = () => {};

  @Builder
  private KeyContentBuilder() {
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
        .draggable(false)
    }
  }

  private handleClick(): void {
    this.onKeyPress(this.btn as string);
  }

  private handleTouch(event: TouchEvent): void {
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
  }

  build() {
    KeyboardKeySurface({
      immersive: this.immersive,
      role: getKeyboardKeyRole(this.btn),
      keyBorderRadius: 40,
      horizontalPadding: 4,
      legacyScale: 0.92,
      legacyPressedOpacity: 0.75,
      semanticId: getCalculatorKeySemanticId(getActionId(this.btn)),
      keyAccessibilityText: getActionId(this.btn),
      onKeyClick: (): void => {
        this.handleClick();
      },
      onKeyTouch: (event: TouchEvent): void => {
        this.handleTouch(event);
      }
    }) {
      this.KeyContentBuilder()
    }
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

  @Builder
  private BasicKeyGridBuilder(immersive: boolean) {
    Grid() {
      ForEach(basicButtons, (btn: string | Resource, index: number) => {
        if (btn !== '') {
          GridItem() {
            BasicKeyItem({
              btn: btn,
              immersive: immersive,
              onKeyPress: (b: string | Resource): void => {
                this.handleKeyPress(b);
              }
            })
          }
          // 如果是等号 (索引 15)，强制其纵向跨越第 4 行和第 5 行 (索引从 0 开始：3 到 4)
          .rowStart(index === 15 ? 3 : undefined)
          .rowEnd(index === 15 ? 4 : undefined)
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

  @Builder
  private LegacyBasicKeyboardBuilder() {
    Column() {
      this.BasicKeyGridBuilder(false)
    }
    .width('100%')
    .height('55%')
    .backgroundColor($r('sys.color.comp_background_primary')) // 主背景色
    .borderRadius(40)
    .shadow({ radius: 16, color: '#1A000000', offsetY: -12 })
    .padding({ bottom: this.navBarHeight - 8 })
  }

  @Builder
  private ImmersiveBasicKeyboardBuilder() {
    Column() {
      this.BasicKeyGridBuilder(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(40)
    .shadow({ radius: 16, color: '#1A000000', offsetY: -12 })
    .padding({ bottom: this.navBarHeight - 8 })
  }

  @Builder
  private ContentAreaBuilder() {
    FormulaScreen({ moduleType: 'basic' })
      .width('100%')
      .height('100%')
  }

  build() {
    PageKeyboardHost({
      legacyContentHeight: '45%',
      immersiveBarHeight: '55%',
      contentArea: this.ContentAreaBuilder,
      legacyKeyboard: this.LegacyBasicKeyboardBuilder,
      immersiveKeyboard: this.ImmersiveBasicKeyboardBuilder
    })
  }
}
