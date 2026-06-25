/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file SideBarMenu.ets
 * @description
* * @author 易睿 (Yi Rui)
 * @date 2026
 */

import { GroupHeader, ItemDivider, MenuButton, MenuGroup } from './MenuComponents';

@Component
export struct SideBarMenu {
  @Link isSidebarOpen: boolean;
  onSettingsClick?: () => void;
  onHistoryClick?: () => void;

  // 用于实时记录手指拖拽的横向偏移量
  @State dragOffsetX: number = 0;

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

          Blank() // 弹性空白，把设置和历史记录按钮推到最右侧

          // 历史记录
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.arrow_counterclockwise_clock'))
              .fontSize(20)
              .fontColor([$r('sys.color.icon_primary')])
          }
          .width(40)
          .height(40)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .margin({ right: 12 }) // 按钮间距
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
            // 点击后先收起侧边栏，再触发外部回调
            animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
            if (this.onHistoryClick) {
              this.onHistoryClick();
            }
          })

          // 设置
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.gearshape_fill'))
              .fontSize(20)
              .fontColor([$r('sys.color.icon_primary')])
          }
          .width(40)
          .height(40)
          .backgroundColor($r('sys.color.comp_background_tertiary')) // 底色
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
            animateTo({ duration: 350, curve: Curve.Friction }, () => { this.isSidebarOpen = false; });
            if (this.onSettingsClick) {
              this.onSettingsClick();
            }
          })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 64, bottom: 16 })

        // 菜单项区域
        Scroll() {
          Column() {
            // ====================== 1. 模式 ==========================
            Column() {
              GroupHeader({ title: '模式' })
              MenuGroup() {
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
                MenuButton({ icon: $r('sys.symbol.foldline_screen'), title: '函数图像', onClickAction: () => { /* TODO */ } })
                ItemDivider()
                MenuButton({ icon: $r('sys.symbol.exponentiation'), title: '方程求解', onClickAction: () => { /* TODO */ } })
                ItemDivider()
                MenuButton({ icon: $r('sys.symbol.square_grid_2x2'), title: '矩阵与向量', onClickAction: () => { /* TODO */ } })
                ItemDivider()
                MenuButton({ icon: $r('sys.symbol.data'), title: '统计分析', onClickAction: () => { /* TODO */ } })
              }
            }
            .padding({ left: 16, right: 16, bottom: 12 })

            // ====================== 3. 转换 ==========================
            Column() {
              GroupHeader({ title: '转换' })
              MenuGroup() {
                MenuButton({ icon: $r('sys.symbol.arrow_left_arrow_right'), title: '单位转换', onClickAction: () => { /* TODO */ } })
                ItemDivider()
                MenuButton({ icon: $r('sys.symbol.gobackward_10'), title: '进制转换', onClickAction: () => { /* TODO */ } })
                ItemDivider()
                MenuButton({ icon: $r('sys.symbol.yuansign_arrow_2_circlepath'), title: '汇率', onClickAction: () => { /* TODO */ } })
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
      .width('70%')
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))
      .borderRadius({ topRight: 32, bottomRight: 32 })
      .shadow({ radius: 48, color: '#25000000', offsetX: 12, offsetY: 0 })

      // 👇 1. 实时绑定手势滑动的偏移量
      .translate({ x: this.dragOffsetX })
      .transition({ type: TransitionType.All, translate: { x: '-100%' } })
      // 👇 2. 挂载原生平移手势
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal })
          .onActionUpdate((event: GestureEvent) => {
            // 实时跟手：只允许向左拖拽（偏移量为负数），防止向右拉出屏幕边缘
            if (event.offsetX < 0) {
              this.dragOffsetX = event.offsetX;
            }
          })
          .onActionEnd((event: GestureEvent) => {
            // 手指松开时的判定逻辑
            // 如果向左滑动的距离超过 80px，或者向左甩动的速度极快 (velocityX < -500)
            if (this.dragOffsetX < -80 || event.velocityX < -500) {
              // 触发关闭动画
              animateTo({ duration: 350, curve: Curve.Friction }, () => {
                this.isSidebarOpen = false;
                this.dragOffsetX = 0; // 动画的同时将拖拽偏移量归零
              });
            } else {
              // 没达到关闭阈值，触发回弹动画，乖乖回到原位
              animateTo({ duration: 350, curve: Curve.Friction }, () => {
                this.dragOffsetX = 0;
              });
            }
          })
      )
      // .transition({ type: TransitionType.All, translate: { x: '-100%' } })
    }
    .width('100%')
    .height('100%')
  }
}