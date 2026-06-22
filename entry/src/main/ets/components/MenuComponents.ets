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
  marginLeft: number = 44; // 允许外部传入左边距，默认为 44

  build() {
    Row() {
      Divider()
        .strokeWidth(1)
        .color($r('sys.color.comp_background_tertiary'))
        .margin({ left: this.marginLeft, right: 12 })
    }
    .width('100%')
    .margin({ top: -3, bottom: -3 })
    .zIndex(1)
    .hitTestBehavior(HitTestMode.None)
  }
}

// 菜单项 (支持无图标、支持副标题的完全体)
@Component
export struct MenuButton {
  // 👇 将图标改为可选属性，去掉 @Prop
  icon?: Resource;
  @Prop title: string;
  // 👇 新增：可选的副标题
  subTitle?: string;
  @Prop isCustomSvg: boolean = false;
  onClickAction?: () => void;

  build() {
    Row() {
      // 1. 图标区（如果有才渲染）
      if (this.icon) {
        if (this.isCustomSvg) {
          Image(this.icon)
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
            .fillColor($r('sys.color.icon_secondary'))
            .margin({ right: 12 })
        } else {
          SymbolGlyph(this.icon)
            .fontSize(20)
            .fontColor([$r('sys.color.icon_secondary')])
            .margin({ right: 12 })
        }
      }

      // 2. 文本区
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontWeight(this.subTitle ? FontWeight.Medium : FontWeight.Regular) // 如果有副标题，主标题稍微加粗一点，层级更分明
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.subTitle) {
          Text(this.subTitle)
            .fontSize(14)
            .fontColor($r('sys.color.font_tertiary'))
            .margin({ top: 4 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)

      .layoutWeight(1) // 让文本容器占据所有剩余空间，把右侧箭头挤过去

      // 3. 箭头区
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('sys.color.icon_tertiary')])
        .margin({ left: 12 })
    }
    .width('100%')
    .constraintSize({ minHeight: 46 }) // 使用最小高度，如果副标题很长，卡片会自动被撑高
    .padding({ left: 12, right: 12, top: 12, bottom: 12 }) // 增加上下内边距，让双行文本呼吸感更好
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