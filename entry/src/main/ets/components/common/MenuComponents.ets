/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file MenuComponents.ets
 * @description 菜单组件库，提供无状态的纯 UI 积木
 * @author 易睿 (Yi Rui)
 * @date 2026
 */
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
        .strokeWidth(0.75)
        .color($r('sys.color.comp_divider'))
        .margin({ left: this.marginLeft, right: 12 })
    }
    .width('100%')
    .margin({ top: -4, bottom: -4 })
    .zIndex(1)
    .hitTestBehavior(HitTestMode.None)
  }
}

// 菜单项 (支持无图标、支持副标题、支持自定义右侧内容)
@Component
export struct MenuButton {
  icon?: Resource; // 可选图标
  @Prop title: string;
  subTitle?: string; // 可选副标题
  @Prop isCustomSvg: boolean = false;
  onClickAction?: () => void;

  @Prop showRightArrow: boolean = true; // 可选右侧箭头
  @BuilderParam rightContent?: () => void; // 允许外部传入自定义的右侧内容（如打钩图标、Switch开关等）

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
          .fontWeight(FontWeight.Regular)
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
      .layoutWeight(1) // 让文本容器占据所有剩余空间

      // 3. 右侧内容区
      if (this.rightContent) {
        // 如果外部传入了自定义内容，优先渲染自定义内容
        this.rightContent()
      } else if (this.showRightArrow) {
        // 否则根据布尔值决定是否渲染默认箭头
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.icon_tertiary')])
          .margin({ left: 12 })
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 46 })
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
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