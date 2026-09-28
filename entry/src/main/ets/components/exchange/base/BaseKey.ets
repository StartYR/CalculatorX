/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file BaseKey.ets
 * @description 进制转换单键表面、长按菜单与连续退格
 * @author StartYi
 * @date 2026/09/28 20:23
 */
import { icon_backspace } from '../../../utils/CalculatorConfigs';
import { getCalculatorKeySemanticId } from '../../../utils/SemanticIds';
import { KeyboardKeySurface } from '../../common/keyboard/KeyboardKeySurface';
import { KeyboardKeyRole } from '../../common/keyboard/KeyboardKeyTypes';

// 长按提示独立贴近底边，不参与主文字的居中布局。
const LONG_PRESS_HINT_BOTTOM: number = 2;

function keyRole(key: string): KeyboardKeyRole {
  if (key === 'AC' || key === '⌫') return KeyboardKeyRole.DANGER;
  if (key === '=') return KeyboardKeyRole.EMPHASIS;
  if (/^[0-9A-F]$/.test(key) || key === '.') return KeyboardKeyRole.CORE;
  return KeyboardKeyRole.OPERATOR;
}

function alternatives(key: string): string[] {
  if (key === 'AND') return ['OR', 'XOR', 'NOT'];
  if (key === 'SHL') return ['ROL', 'RCL'];
  if (key === 'SHR') return ['SAR', 'ROR', 'RCR'];
  if (key === '+') return ['ADC'];
  if (key === '-') return ['SBB'];
  return [];
}

// 渲染路径由页面选择；单键只管理输入回调、长按菜单和退格计时器。
@Component
export struct BaseKey {
  @Prop keyText: string = '';
  @Prop immersive: boolean = false;
  @Prop available: boolean = true;
  @Prop integerMode: boolean = true;
  onPress: (key: string) => void = () => {};
  private repeatTimer: number = -1;
  private delayTimer: number = -1;
  private repeated: boolean = false;

  private stopRepeat(): void {
    // 长按退格的两个计时器随按键释放或组件消失一并取消，避免后台继续删字。
    clearTimeout(this.delayTimer);
    clearInterval(this.repeatTimer);
  }
  aboutToDisappear(): void { this.stopRepeat(); }

  @Builder
  private MenuBuilder() {
    Menu() {
      ForEach(alternatives(this.keyText), (key: string) => {
        MenuItem({ content: key }).onClick(() => this.onPress(key))
      })
    }
  }

  @Builder
  private Surface() {
    // 两种键盘共用按键语义与业务回调，沉浸开关只改变公共表面的渲染路径。
    KeyboardKeySurface({
      immersive: this.immersive, role: keyRole(this.keyText), keyBorderRadius: 16,
      semanticId: this.keyText === 'e' ? 'base.key.exponent' :
        getCalculatorKeySemanticId(this.keyText === '-' ? '−' : this.keyText === '*' ? '×' : this.keyText === '/' ? '÷' : this.keyText)
          .replace('calc.key.', 'base.key.'),
      keyAccessibilityText: this.keyText + (this.available ? '' : '，当前进制不可用') +
        (this.integerMode && alternatives(this.keyText).length ? '，长按更多操作' : ''),
      // 长按已经触发连续退格时，释放后的 click 不再额外删字。
      onKeyClick: () => { if (this.available && !this.repeated) this.onPress(this.keyText); },
      onKeyTouch: (event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.repeated = false;
          if (this.keyText === '⌫') {
            this.stopRepeat();
            this.delayTimer = setTimeout(() => {
              this.repeated = true;
              this.onPress('⌫');
              this.repeatTimer = setInterval(() => this.onPress('⌫'), 70);
            }, 450);
          }
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) this.stopRepeat();
      }
    }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.keyText === '⌫') {
          Image(icon_backspace)
            .width(48).height(48)
            .constraintSize({ maxWidth: '100%', maxHeight: '100%' })
            .objectFit(ImageFit.Contain)
            .fillColor($r('sys.color.font_on_primary'))
            .draggable(false)
        } else {
          Text(this.keyText === '*' ? '×' : this.keyText === '/' ? '÷' : this.keyText === '-' ? '−' : this.keyText)
            .fontSize(this.keyText.length > 2 ? 16 : 23)
            .fontWeight(FontWeight.Medium)
            .fontColor(keyRole(this.keyText) === KeyboardKeyRole.DANGER || this.keyText === '=' ?
              $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
        }
        if (this.integerMode && alternatives(this.keyText).length > 0) {
          Stack({ alignContent: Alignment.Bottom }) {
            Text('···')
              .fontSize(10)
              .fontColor($r('sys.color.font_secondary'))
              .margin({ bottom: LONG_PRESS_HINT_BOTTOM })
          }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
        }
      }.width('100%').height('100%')
    }
  }

  build() {
    if (this.integerMode && alternatives(this.keyText).length > 0) {
      Stack() {
        this.Surface()
      }
        .width('100%')
        .height('100%')
        .enabled(this.available)
        .opacity(this.available ? 1 : 0.3)
        .bindContextMenu(this.MenuBuilder, ResponseType.LongPress)
    } else {
      Stack() {
        this.Surface()
      }
        .width('100%')
        .height('100%')
        .enabled(this.available)
        .opacity(this.available ? 1 : 0.3)
    }
  }
}
