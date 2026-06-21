// entry/src/main/ets/components/TopBar.ets

@Component
export struct TopBar {
  // 向外暴露的点击事件，由父组件 (Index) 来决定点击后干什么
  onMenuClick?: () => void;
  onHistoryClick?: () => void;

  build() {
    // 顶部悬浮控制栏
    Row() {
      // 左侧：设置菜单按钮
      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.slider_horizontal_2_1'))
          .fontSize(18)
          .fontColor([$r('sys.color.icon_primary')])
      }
      .width(48)
      .height(32)
      .backgroundColor('#54ffffff')
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
      .border({
        width: 0.5,
        color: $r('sys.color.comp_divider'),
        radius: 16
      })
      .shadow({
        radius: 32,
        color: '#25000000',
        offsetX: 3,
        offsetY: 6
      })
      .onClick(() => {
        if (this.onMenuClick) {
          this.onMenuClick();
        }
      })

      // 中间：弹性占位组件
      Blank()

      // 右侧：历史记录按钮
      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.arrow_counterclockwise_clock'))
          .fontSize(18)
          .fontColor([$r('sys.color.icon_primary')])
      }
      .width(48)
      .height(32)
      .backgroundColor('#54ffffff')
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
      .border({
        width: 0.5,
        color: $r('sys.color.comp_divider'),
        radius: 16
      })
      .shadow({
        radius: 32,
        color: '#25000000',
        offsetX: 3,
        offsetY: 6
      })
      .onClick(() => {
        if (this.onHistoryClick) {
          this.onHistoryClick();
        }
      })
    }
    .width('100%')
    .padding({ top: 36, left: 12, right: 12 })
  }
}