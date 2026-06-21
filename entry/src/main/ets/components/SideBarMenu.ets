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
        // 头部：标志与独立的设置按钮
        Row() {
          // 左侧标志
          Row() {
            Text('Calc')
              .fontSize(28)
              .fontWeight(FontWeight.Bolder)
              .fontColor($r('sys.color.font_primary'))
            Text('X')
              .fontSize(28)
              .fontWeight(FontWeight.Bolder)
              .fontColor($r('sys.color.font_emphasize'))
          }

          Blank() // 弹性空白，把设置按钮完美推到最右侧

          // 右侧独立的圆形设置按钮
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.gearshape_fill'))
              .fontSize(20)
              .fontColor([$r('sys.color.icon_primary')])
          }
          .width(40)
          .height(40)
          .backgroundColor($r('sys.color.comp_background_tertiary')) // 极其微弱的底色，凸显圆形
          .onClick(() => {
            animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
            if (this.onSettingsClick) {
              this.onSettingsClick();
            }
          })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 64, bottom: 32 }) // 右侧增加了 24 的 padding 保持对称

        // 菜单项区域（加入 Scroll 容器，保证菜单再多也不会溢出屏幕）
        Scroll() {
          Column() {
            this.MenuButton($r('sys.symbol.clock'), '历史记录', () => { /* TODO */ })
            this.MenuButton($r('sys.symbol.clock'), '统计分析', () => { /* TODO */ })
            this.MenuButton($r('sys.symbol.xmark'), '方程求解', () => { /* TODO */ })
            this.MenuButton($r('sys.symbol.square_grid_2x2'), '矩阵与向量', () => { /* TODO */ })
            this.MenuButton($r('sys.symbol.clock'), '科学常数', () => { /* TODO */ })
            this.MenuButton($r('sys.symbol.clock'), '公式库', () => { /* TODO */ })
            this.MenuButton($r('sys.symbol.arrow_left_arrow_right'), '单位转换', () => { /* TODO */ })
            this.MenuButton($r('sys.symbol.scope'), '进制转换', () => { /* TODO */ })
            this.MenuButton($r('sys.symbol.scope'), '汇率', () => { /* TODO */ })
            this.MenuButton($r('sys.symbol.rectangle_portrait_wave_2'), '函数图像', () => { /* TODO */ })
            this.MenuButton($r('sys.symbol.clock'), '帮助', () => { /* TODO */ })
          }
          .width('100%')
        }
        .layoutWeight(1) // 自动占据下方剩余的全部垂直空间
        .scrollBar(BarState.Off) // 隐藏侧边滚动条，保持界面极致整洁
        .align(Alignment.Top) // 上对齐
        .padding({ bottom: 24 })
      }
      .width('65%')
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary')) // 保持上次改好的次级底色
      .borderRadius({ topRight: 32, bottomRight: 32 })
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

    // 按压反馈
    .stateStyles({
      pressed: {
        .backgroundColor($r('sys.color.comp_background_secondary'))
      },
      normal: {
        .backgroundColor($r('sys.color.comp_background_primary'))
      }
    })
    .onClick(onClick)
  }
}