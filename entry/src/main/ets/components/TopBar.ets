// entry/src/main/ets/components/TopBar.ets

@Component
export struct TopBar {
  @Prop isShift: boolean = false;
  @Prop isRad: boolean = false;
  @Prop moduleTitle: string = '科学计算';

  onMenuClick?: () => void;
  onHistoryClick?: () => void;
  onUndoClick?: () => void; //  暴露撤销事件
  onRedoClick?: () => void; // 暴露重做事件

  build() {
    // 顶部悬浮控制栏
    Row() {
      // ================= 左侧组合：菜单 + 撤销 =================
      Row({ space: 8 }) {
        // 1. 设置菜单按钮
        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.slider_horizontal_2_1'))
            .fontSize(18)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(44) // 稍微缩小一点宽度，给中间留出更多呼吸空间
        .height(32)
        .backgroundColor('#54ffffff')
        .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
        .border({ width: 0.5, color: $r('sys.color.comp_divider'), radius: 16 })
        .shadow({ radius: 32, color: '#25000000', offsetX: 3, offsetY: 6 })
        .onClick(() => { if (this.onMenuClick) this.onMenuClick(); })

        // 2. [新增] 撤销按钮
        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrowshape_turn_up_left')) // 系统级撤销图标
            .fontSize(18)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(36)
        .height(32)
        .backgroundColor('#54ffffff')
        .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
        .border({ width: 0.5, color: $r('sys.color.comp_divider'), radius: 16 })
        .shadow({ radius: 32, color: '#25000000', offsetX: 3, offsetY: 6 })
        .onClick(() => { if (this.onUndoClick) this.onUndoClick(); })
      }

      // ================= 中间：动态状态岛 =================
      Row() {
        if (this.isShift) {
          // Shift 激活状态
          Text('⇧ SHIFT')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_emphasize'))
            .transition({ type: TransitionType.All, translate: { y: 15 }, opacity: 0 })
        } else {
          // 常规状态：模块名称 + Rad/Deg 徽章
          Row({ space: 6 }) {
            Text(this.moduleTitle)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))

            Text(this.isRad ? 'RAD' : 'DEG')
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_secondary'))
              .padding({ left: 4, right: 4, top: 2, bottom: 2 })
              .backgroundColor($r('sys.color.comp_background_tertiary'))
              .borderRadius(4)
          }
          .transition({ type: TransitionType.All, translate: { y: -15 }, opacity: 0 })
        }
      }
      .layoutWeight(1) // 占满中间剩余空间
      .height(32)
      .justifyContent(FlexAlign.Center)
      .clip(true)
      .animation({ duration: 300, curve: Curve.Friction })

      // ================= 右侧组合：重做 + 历史 =================
      Row({ space: 8 }) {
        // 3. 重做按钮
        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrowshape_turn_up_right')) // 系统级重做图标
            .fontSize(18)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(36)
        .height(32)
        .backgroundColor('#54ffffff')
        .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
        .border({ width: 0.5, color: $r('sys.color.comp_divider'), radius: 16 })
        .shadow({ radius: 32, color: '#25000000', offsetX: 3, offsetY: 6 })
        .onClick(() => { if (this.onRedoClick) this.onRedoClick(); })

        // 4. 历史记录按钮
        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrow_counterclockwise_clock'))
            .fontSize(18)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(44)
        .height(32)
        .backgroundColor('#54ffffff')
        .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
        .border({ width: 0.5, color: $r('sys.color.comp_divider'), radius: 16 })
        .shadow({ radius: 32, color: '#25000000', offsetX: 3, offsetY: 6 })
        .onClick(() => { if (this.onHistoryClick) this.onHistoryClick(); })
      }
    }
    .width('100%')
    .padding({ top: 36, left: 12, right: 12 })
  }
}