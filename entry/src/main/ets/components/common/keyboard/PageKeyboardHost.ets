import { KeyboardRenderSwitch } from './KeyboardRenderSwitch';

/**
 * 页面型计算器的双路径容器骨架。
 */
@Component
export struct PageKeyboardHost {
  legacyContentHeight: string = '45%';
  immersiveBarHeight: string = '55%';

  @BuilderParam contentArea: () => void;
  @BuilderParam legacyKeyboard: () => void;
  @BuilderParam immersiveKeyboard: () => void;

  @Builder
  private LegacyLayout() {
    Column() {
      Column() {
        this.contentArea()
      }
      .width('100%')
      .height(this.legacyContentHeight)

      this.legacyKeyboard()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }

  @Builder
  private ImmersiveLayout() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        Column() {
          this.contentArea()
        }
        .width('100%')
        .height('100%')
      }
      .tabBar(this.immersiveKeyboard)
    }
    .vertical(false)
    .scrollable(false)
    .animationDuration(0)
    .barHeight(this.immersiveBarHeight)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_tertiary'))
  }

  build() {
    KeyboardRenderSwitch({
      legacyContent: this.LegacyLayout,
      immersiveContent: this.ImmersiveLayout
    })
  }
}
