// entry/src/main/ets/components/SideBarMenu.ets
import { GroupHeader, ItemDivider, MenuButton, MenuGroup } from './MenuComponents';

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
        .padding({ left: 24, right: 24, top: 64, bottom: 16 })

        // 菜单项区域 (极致清爽版)
        Scroll() {
          Column() {
            // ====================== 1. 常用 ==========================
            Column() {
              GroupHeader({ title: '常用' })
              MenuGroup() {
                MenuButton({ icon: $r('sys.symbol.arrow_counterclockwise_clock'), title: '历史记录', onClickAction: () => { /* TODO */ } })
                ItemDivider()
                MenuButton({ icon: $r('sys.symbol.calculator_1'), title: '基础计算', onClickAction: () => { /* TODO */ } })
                ItemDivider()
                MenuButton({ icon: $r('sys.symbol.calculator'), title: '科学计算', onClickAction: () => { /* TODO */ } })
              }
            }
            .padding({ left: 16, right: 16, bottom: 12 })

            // ====================== 2. 进阶 ==========================
            Column() {
              GroupHeader({ title: '进阶' })
              MenuGroup() {
                MenuButton({ icon: $r('sys.symbol.rectangle_portrait_wave_2'), title: '函数图像', onClickAction: () => { /* TODO */ } })
                ItemDivider()
                MenuButton({ icon: $r('sys.symbol.exponentiation'), title: '方程求解', onClickAction: () => { /* TODO */ } })
                ItemDivider()
                MenuButton({ icon: $r('sys.symbol.square_grid_2x2'), title: '矩阵与向量', onClickAction: () => { /* TODO */ } })
                ItemDivider()
                MenuButton({ icon: $r('sys.symbol.square_grid_2x2'), title: '统计分析', onClickAction: () => { /* TODO */ } })
              }
            }
            .padding({ left: 16, right: 16, bottom: 12 })

            // ====================== 3. 转换 ==========================
            Column() {
              GroupHeader({ title: '转换' })
              MenuGroup() {
                MenuButton({ icon: $r('sys.symbol.arrow_left_arrow_right'), title: '单位转换', onClickAction: () => { /* TODO */ } })
                ItemDivider()
                MenuButton({ icon: $r('sys.symbol.square_grid_2x2'), title: '进制转换', onClickAction: () => { /* TODO */ } })
                ItemDivider()
                MenuButton({ icon: $r('sys.symbol.square_grid_2x2'), title: '汇率', onClickAction: () => { /* TODO */ } })
              }
            }
            .padding({ left: 16, right: 16, bottom: 12 })

            // ====================== 4. 参考 ==========================
            Column() {
              GroupHeader({ title: '参考' })
              MenuGroup() {
                MenuButton({ icon: $r('sys.symbol.doc_plaintext'), title: '公式库', onClickAction: () => { /* TODO */ } })
                ItemDivider()
                MenuButton({ icon: $r('sys.symbol.e'), title: '科学常数', onClickAction: () => { /* TODO */ } })
                ItemDivider()
                MenuButton({ icon: $r('sys.symbol.questionmark_circle'), title: '帮助', onClickAction: () => { /* TODO */ } })
              }
            }
            .padding({ left: 16, right: 16, bottom: 32 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 触底触顶回弹
        .fadingEdge(true)//
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
}