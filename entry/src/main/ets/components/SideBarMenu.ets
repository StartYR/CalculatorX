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

        // 菜单项区域
        Scroll() {
          Column() {
            // ====================== 1. 常用 ==========================
            Column() {
              this.GroupHeader('常用')
              Column({ space: 4 }) {
                this.MenuButton($r('sys.symbol.arrow_counterclockwise_clock'), '历史记录', () => { /* TODO */ })
              }
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(19)
              .clip(true)
              .padding({ left: 3, right: 3, top: 3, bottom: 3 })
            }
            .padding({ left: 16, right: 16, bottom: 12 })

            // ====================== 2. 进阶计算 ==========================
            Column() {
              this.GroupHeader('进阶计算')
              Column({ space: 4 }) {
                this.MenuButton($r('sys.symbol.rectangle_portrait_wave_2'), '函数图像', () => { /* TODO */ })
                this.ItemDivider()
                this.MenuButton($r('sys.symbol.exponentiation'), '方程求解', () => { /* TODO */ })
                this.ItemDivider()
                this.MenuButton($r('sys.symbol.square_grid_2x2'), '矩阵与向量', () => { /* TODO */ })
                this.ItemDivider()
                this.MenuButton($r('sys.symbol.xmark'), '统计分析', () => { /* TODO */ })
              }
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(19)
              .clip(true)
              .padding({ left: 3, right: 3, top: 3, bottom: 3 })
            }
            .padding({ left: 16, right: 16, bottom: 12 })

            // ====================== 3. 实用转换 ==========================
            Column() {
              this.GroupHeader('实用转换')
              Column({ space: 4 }) {
                this.MenuButton($r('sys.symbol.arrow_left_arrow_right'), '单位转换', () => { /* TODO */ })
                this.ItemDivider()
                this.MenuButton($r('sys.symbol.xmark'), '进制转换', () => { /* TODO */ })
                this.ItemDivider()
                this.MenuButton($r('sys.symbol.xmark'), '汇率', () => { /* TODO */ })
              }
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(19)
              .clip(true)
              .padding({ left: 3, right: 3, top: 3, bottom: 3 })
            }
            .padding({ left: 16, right: 16, bottom: 12 })

            // ====================== 4. 参考与帮助 ==========================
            Column() {
              this.GroupHeader('参考与帮助')
              Column({ space: 4 }) {
                this.MenuButton($r('sys.symbol.doc_plaintext'), '公式库', () => { /* TODO */ })
                this.ItemDivider()
                this.MenuButton($r('sys.symbol.e'), '科学常数', () => { /* TODO */ })
                this.ItemDivider()
                this.MenuButton($r('sys.symbol.questionmark_circle'), '帮助', () => { /* TODO */ })
              }
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(19)
              .clip(true)
              .padding({ left: 3, right: 3, top: 3, bottom: 3 })
            }
            .padding({ left: 16, right: 16, bottom: 32 }) // 底部多留点白，防止内容贴紧边缘
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
      .width('65%')
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))
      .borderRadius({ topRight: 32, bottomRight: 32 })
      .shadow({ radius: 48, color: '#25000000', offsetX: 12, offsetY: 0 })
      .transition({ type: TransitionType.All, translate: { x: '-100%' } })
    }
    .width('100%')
    .height('100%')
  }

  // ==================== UI 组件 ====================

  @Builder GroupHeader(title: string) {
    Text(title)
      .fontSize(14)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: 16, top: 12, bottom: 4 })
  }

  // 分隔线
  @Builder ItemDivider() {
    Row() {
      Divider()
        .strokeWidth(1)
        .color($r('sys.color.comp_divider')) // 鸿蒙原生分割线颜色
        .margin({ left: 44, right: 12 }) // 完美对齐文字与右侧边缘
    }
    .width('100%')
    // .height(0.14) // 高度为 0
    .margin({ top: -3, bottom: -3 }) // 负边距，完美吃掉 Column 额外生成的 4px 空间
    .zIndex(1) // 保证线浮在两个胶囊之间的缝隙顶层
    .hitTestBehavior(HitTestMode.None) // 防止这条看不见的线阻挡点击事件
  }

  // 菜单项
  @Builder
  MenuButton(icon: Resource, title: string, onClick: () => void) {
    Row() {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor([$r('sys.color.icon_secondary')])
        .margin({ right: 12 })

      Text(title)
        .fontSize(16)
        .fontColor($r('sys.color.font_primary'))

      Blank()

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('sys.color.icon_tertiary')])
    }
    .width('100%')
    .height(46)
    .padding({ left: 12, right: 12 })
    .margin(0)
    .borderRadius(16)
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