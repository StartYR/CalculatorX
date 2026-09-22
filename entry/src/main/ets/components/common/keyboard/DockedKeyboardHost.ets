import { KeyboardRenderSwitch } from './KeyboardRenderSwitch';

/**
 * 无位移动画的悬浮键盘双路径容器骨架。
 */
@Component
export struct DockedKeyboardHost {
  immersiveHeight: number = 260;

  @BuilderParam legacyKeyboard: () => void;
  @BuilderParam immersiveKeyboard: () => void;

  @Builder
  private LegacyLayout() {
    this.legacyKeyboard()
  }

  @Builder
  private ImmersiveLayout() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        Column()
          .width('100%')
          .height('100%')
      }
      .tabBar(this.immersiveKeyboard)
    }
    .vertical(false)
    .scrollable(false)
    .animationDuration(0)
    .barHeight('100%')
    .width('100%')
    .height(this.immersiveHeight)
  }

  build() {
    KeyboardRenderSwitch({
      legacyContent: this.LegacyLayout,
      immersiveContent: this.ImmersiveLayout
    })
  }
}
