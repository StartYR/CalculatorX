import deviceInfo from '@ohos.deviceInfo';
import { createKeyboardMaterial } from '../../../utils/ImmersiveMaterialUtils';
import { KeyboardKeyRole } from './KeyboardKeyTypes';
import { getLegacyKeyboardBackground } from './KeyboardVisualPolicy';

/**
 * 计算按键的公共双路径表面。
 *
 * 组件只负责按钮外观和基础事件透传，按键内容、业务动作及复杂手势由调用方持有。
 */
@Component
export struct KeyboardKeySurface {
  immersive: boolean = false;
  role: KeyboardKeyRole = KeyboardKeyRole.CORE;
  shiftActive: boolean = false;
  keyBorderRadius: number = 16;
  horizontalPadding: number = 4;
  useLayoutWeight: boolean = false;
  legacyScale: number = 0.9;
  legacyPressedOpacity: number = 0.7;
  semanticId: string = '';
  keyAccessibilityText: string = '';

  @BuilderParam content: () => void;

  onKeyClick: () => void = () => {};
  onKeyTouch: (event: TouchEvent) => void = () => {};

  @Builder
  private LegacySurface() {
    Button() {
      this.content()
    }
    .type(ButtonType.Normal)
    .id(this.semanticId.length > 0 ? this.semanticId : undefined)
    .accessibilityText(this.keyAccessibilityText.length > 0 ? this.keyAccessibilityText : undefined)
    .borderRadius(this.keyBorderRadius)
    .width('100%')
    .height(this.useLayoutWeight ? undefined : '100%')
    .layoutWeight(this.useLayoutWeight ? 1 : undefined)
    .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
    .backgroundColor(getLegacyKeyboardBackground(this.role, this.shiftActive))
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .borderWidth({ top: 1, left: 1, bottom: 0, right: 0 })
    .borderColor($r('app.color.btn_highlight'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: this.legacyScale })
    .stateStyles({
      pressed: { .opacity(this.legacyPressedOpacity).shadow(ShadowStyle.OUTER_DEFAULT_XS) },
      normal: { .opacity(1.0).shadow(ShadowStyle.OUTER_DEFAULT_SM) }
    })
    .onClick(this.onKeyClick)
    .onTouch(this.onKeyTouch)
  }

  build() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.immersive) {
        Button() {
          this.content()
        }
        .type(ButtonType.Normal)
        .id(this.semanticId.length > 0 ? this.semanticId : undefined)
        .accessibilityText(this.keyAccessibilityText.length > 0 ? this.keyAccessibilityText : undefined)
        .borderRadius(this.keyBorderRadius)
        .width('100%')
        .height(this.useLayoutWeight ? undefined : '100%')
        .layoutWeight(this.useLayoutWeight ? 1 : undefined)
        .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
        .buttonStyle(ButtonStyleMode.TEXTUAL)
        .backgroundColor(Color.Transparent)
        .borderWidth(0)
        .shadow({ radius: 0 })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 1.0 })
        .stateStyles({
          pressed: { .opacity(1.0).shadow({ radius: 0 }) },
          normal: { .opacity(1.0).shadow({ radius: 0 }) }
        })
        .systemMaterial(createKeyboardMaterial(this.role, this.shiftActive))
        .onClick(this.onKeyClick)
        .onTouch(this.onKeyTouch)
      } else {
        this.LegacySurface()
      }
    } else {
      this.LegacySurface()
    }
  }
}
