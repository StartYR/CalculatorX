// entry/src/main/ets/components/SideBarMenu.ets

@Component
export struct SideBarMenu {
  @Link isSidebarOpen: boolean;
  onSettingsClick?: () => void;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 底层：全屏模糊遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.2)') // 稍微调低透明度，让底层的模糊更透亮
        .backgroundBlurStyle(BlurStyle.Thin)
        .onClick(() => {
          // 【动效优化】：使用原生的阻尼减速曲线，收起更丝滑
          animateTo({ duration: 350, curve: Curve.Friction }, () => {
            this.isSidebarOpen = false;
          });
        })
        .transition({ type: TransitionType.All, opacity: 0 })

      // 2. 顶层：左侧抽屉面板
      Column() {
        // 头部：CalculatorX 标志区
        Row() {
          Text('Calc')
            .fontSize(28)
            .fontWeight(FontWeight.Bolder)
            .fontColor($r('sys.color.font_primary'))
          Text('X')
            .fontSize(28)
            .fontWeight(FontWeight.Bolder)
            .fontColor($r('sys.color.font_emphasize')) // 使用系统强调色（如蓝色）点缀
        }
        .width('100%')
        .padding({ left: 24, top: 64, bottom: 40 })

        // 菜单项：使用精装版的组件
        this.MenuButton($r('sys.symbol.clock'), '历史记录', () => {
          animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
          // TODO: 触发历史记录逻辑
        })

        this.MenuButton($r('sys.symbol.gearshape_fill'), '设置', () => {
          animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
          if (this.onSettingsClick) {
            this.onSettingsClick();
          }
        })

      }
      .width('75%')
      .height('100%')
      .backgroundColor($r('sys.color.background_primary'))
      // 【UI 优化】：右侧大圆角，彻底摆脱“门板”感
      .borderRadius({ topRight: 32, bottomRight: 32 })
      // 增加更柔和深邃的悬浮阴影
      .shadow({ radius: 48, color: '#25000000', offsetX: 12, offsetY: 0 })
      .transition({ type: TransitionType.All, translate: { x: '-100%' } })
    }
    .width('100%')
    .height('100%')
  }

  // 提取的精致菜单项构造器
  @Builder
  MenuButton(icon: Resource, title: string, onClick: () => void) {
    Row() {
      // 图标加上一个微弱的圆形底色，视觉更聚焦
      Row() {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor([$r('sys.color.icon_primary')])
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(18)

      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .margin({ left: 16 })
    }
    .width('88%')
    .height(56)
    .padding({ left: 12, right: 12 })
    .margin({ bottom: 8 })
    .borderRadius(16)
    // 【UI 优化】：自带原生按压反馈
    .stateStyles({
      pressed: {
        .backgroundColor($r('sys.color.comp_background_secondary'))
      },
      normal: {
        .backgroundColor(Color.Transparent)
      }
    })
    .onClick(onClick)
  }
}