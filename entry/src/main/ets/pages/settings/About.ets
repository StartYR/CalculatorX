// entry/src/main/ets/pages/settings/About.ets
import router from '@ohos.router';
import common from '@ohos.app.ability.common'; // 新增：用于获取上下文以启动外部应用
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';

// 定义鸣谢数据结构
interface CreditItem {
  name: string;
  desc: string;
}

const creditsList: CreditItem[] = [
  { name: 'Giac/Xcas', desc: '核心微积分与高级符号运算引擎' },
  { name: 'SymEngine', desc: '基础计算机代数系统 (CAS)' },
  { name: 'MathLive', desc: '前端 LaTeX 公式渲染与 MathJSON 引擎' },
  { name: 'nlohmann/json', desc: 'C++ 高效 JSON 解析库' },
  { name: 'Boost & GMP', desc: '高精度底层大数运算支持' }
];

// 定义极其优雅的半屏弹窗
@CustomDialog
struct CreditsDialog {
  controller: CustomDialogController;

  build() {
    Column() {
      Text('特别鸣谢')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .margin({ top: 24, bottom: 16 })

      List({ space: 16 }) {
        ForEach(creditsList, (item: CreditItem) => {
          ListItem() {
            Column({ space: 4 }) {
              Text(item.name)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
              Text(item.desc)
                .fontSize(14)
                .fontColor($r('sys.color.font_tertiary'))
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }
        })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
      .layoutWeight(1) // 占满剩余空间
      .scrollBar(BarState.Off)

      // 底部关闭按钮
      Button('关闭')
        .type(ButtonType.Capsule)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .fontColor($r('sys.color.font_primary'))
        .width('80%')
        .margin({ top: 16, bottom: 24 })
        .onClick(() => {
          this.controller.close();
        })
    }
    .width('100%')
    .height('55%') // 占据屏幕一半高度
    .backgroundColor($r('sys.color.background_secondary'))
    .borderRadius({ topLeft: 24, topRight: 24 }) // 顶部大圆角
  }
}


@Entry
@Component
struct About {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  private scrollerForScroll: Scroller = new Scroller();

  // 获取当前 UIAbility 的上下文，用于拉起外部应用
  private context = getContext(this) as common.UIAbilityContext;

  // 初始化弹窗控制器
  private creditsDialogController: CustomDialogController = new CustomDialogController({
    builder: CreditsDialog(),
    alignment: DialogAlignment.Bottom, // 从底部弹出
    customStyle: true, // 使用自定义圆角和背景
    offset: { dx: 0, dy: 0 }
  });

  @Builder ItemDivider() {
    Divider()
      .strokeWidth(1)
      .color($r('sys.color.comp_divider'))
      .margin({ left: 48, right: 16 })
  }

  // 统一封装拉起外部浏览器的函数
  private openUrlInBrowser(url: string) {
    this.context.startAbility({
      action: "ohos.want.action.viewData",
      entities: ["entity.system.browsable"],
      uri: url
    }).catch((err: Error) => {
      console.error(`拉起浏览器失败: ${err.message}`);
    });
  }

  // 统一封装拉起邮件客户端的函数
  private sendEmail(email: string) {
    this.context.startAbility({
      action: "ohos.want.action.sendData",
      uri: `mailto:${email}`
    }).catch((err: Error) => {
      console.error(`拉起邮件客户端失败: ${err.message}`);
    });
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
              .borderRadius(18)
              .shadow({ radius: 16, color: 'rgba(0, 0, 0, 0.08)', offsetY: 6 })

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
                // this.creditsDialogController.open();
                router.pushUrl({
                  url: 'pages/settings/Credits',
                });
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
                this.openUrlInBrowser('https://calcx.startyi.com');
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
                this.openUrlInBrowser('https://github.com/StarHeartY/CalculatorX');
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
                this.sendEmail('support@startyi.com');
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
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
  }
}