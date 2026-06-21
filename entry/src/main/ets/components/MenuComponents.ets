// entry/src/main/ets/components/MenuComponents.ets

// ==================== UI 组件库 ====================

@Component
export struct GroupHeader {
  @Prop title: string;

  build() {
    Text(this.title)
      .fontSize(14)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: 16, top: 12, bottom: 4 })
  }
}

// 分隔线
@Component
export struct ItemDivider {
  build() {
    Row() {
      Divider()
        .strokeWidth(1)
        .color($r('sys.color.comp_divider')) // 鸿蒙原生分割线颜色
        .margin({ left: 44, right: 12 }) // 完美对齐文字与右侧边缘
    }
    .width('100%')
    .margin({ top: -3, bottom: -3 }) // 负边距，完美吃掉 Column 额外生成的 4px 空间
    .zIndex(1) // 保证线浮在两个胶囊之间的缝隙顶层
    .hitTestBehavior(HitTestMode.None) // 防止这条看不见的线阻挡点击事件
  }
}

// 菜单项
@Component
export struct MenuButton {
  @Prop icon: Resource;
  @Prop title: string;
  onClickAction?: () => void;

  build() {
    Row() {
      SymbolGlyph(this.icon)
        .fontSize(20)
        .fontColor([$r('sys.color.icon_secondary')])
        .margin({ right: 12 })

      Text(this.title)
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
    .onClick(() => {
      if (this.onClickAction) {
        this.onClickAction();
      }
    })
  }
}

// 菜单项容器（分组卡片底板）
@Component
export struct MenuGroup {
  @BuilderParam content: () => void;

  build() {
    Column({ space: 4 }) {
      if (this.content) {
        this.content()
      }
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(19)
    .clip(true)
    .padding({ left: 3, right: 3, top: 3, bottom: 3 })
  }
}