// entry/src/main/ets/pages/About.ets
import router from '@ohos.router';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';

@Entry
@Component
struct About {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  private scrollerForScroll: Scroller = new Scroller();

  @Builder ItemDivider() {
    Divider()
      .strokeWidth(1)
      .color($r('sys.color.comp_divider'))
      .margin({ left: 48, right: 16 })
  }

  build() {
    HdsNavigation() {
      Scroll(this.scrollerForScroll) {
        Column() {
          Row().width('100%').height(108)

          // ====================== App 图标与版本 ==========================
          Column() {
            // App 图标
            Image($r('app.media.foreground'))
              .width(80)
              .height(80)
              .borderRadius(18) // 圆角弧度
              .shadow({ radius: 16, color: 'rgba(0, 0, 0, 0.08)', offsetY: 6 }) // 保留一层悬浮阴影

            Text('CalculatorX')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
              .margin({ top: 20 })

            Text('Version 0.1.2 Beta (HarmonyOS)')
              .fontSize(14)
              .fontColor($r('sys.color.font_tertiary'))
              .margin({ top: 6, bottom: 40 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // ====================== 特别鸣谢 ==========================
          Column() {
            Column() {
              Row() {
                SymbolGlyph($r('sys.symbol.gift'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('特别鸣谢')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                Text('SymEngine')
                  .fontSize(14)
                  .fontColor($r('sys.color.font_tertiary'))
                  .margin({ right: 4 })
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_tertiary')])
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => {
                console.info('点击：特别鸣谢');
              })
            }
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
          }
          .padding({ left: 16, right: 16, bottom: 16 })

          // ====================== 联系与支持 ==========================
          Column() {
            Column() {
              // 官方主页
              Row() {
                SymbolGlyph($r('sys.symbol.house'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('官方主页')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_tertiary')])
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => {
                console.info('点击：官方主页');
                router.pushUrl({
                  url: 'https://calcx.startyi.com/privacy',
                });
              })

              this.ItemDivider()

              // 开源地址
              Row() {
                SymbolGlyph($r('sys.symbol.share'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('开源地址')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_tertiary')])
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => {
                console.info('点击：开源地址');
              })

              this.ItemDivider()

              // 联系开发者
              Row() {
                SymbolGlyph($r('sys.symbol.envelope'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_secondary')])
                  .margin({ right: 12 })
                Text('联系开发者')
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                Blank()
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(20)
                  .fontColor([$r('sys.color.icon_tertiary')])
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => {
                console.info('点击：联系开发者');
              })
            }
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius(16)
          }
          .padding({ left: 16, right: 16, bottom: 32 })

          // ====================== 底部版权信息 ==========================
          Column() {
            Text('© 2026 Yi Rui (易睿). All Rights Reserved.')
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
              .margin({ bottom: 4 })
            Text('www.startyi.com')
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ bottom: 48 + this.navBarHeight })

        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .mode(NavigationMode.Stack)
    .titleBar({
      content: {
        title: { mainTitle: '关于此应用' },
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
      },
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false
    })
    .bindToScrollable([this.scrollerForScroll])
    .hideBackButton(false)
    .titleMode(HdsNavigationTitleMode.MINI) // 采用 FREE 模式，允许大标题向下滚动时缩小
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
  }
}