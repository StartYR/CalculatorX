// entry/src/main/ets/pages/settings/About.ets
import router from '@ohos.router';
import common from '@ohos.app.ability.common'; // 用于获取上下文以启动外部应用
import { GroupHeader, ItemDivider, MenuButton, MenuGroup } from '../../components/MenuComponents';
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

  // 统一封装拉起外部浏览器的函数
  private openUrlInBrowser(url: string): void {
    this.context.startAbility({
      action: "ohos.want.action.viewData",
      entities: ["entity.system.browsable"],
      uri: url
    }).catch((err: Error) => {
      console.error(`拉起浏览器失败: ${err.message}`);
    });
  }

  // 统一封装拉起邮件客户端的函数
  private sendEmail(email: string): void {
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
              .width(108)
              .height(108)
              .borderRadius(18)
              .shadow({ radius: 64, color: 'rgba(0, 0, 0, 0.28)', offsetX: 12, offsetY: 24 })

            Row() {
              Text('Calculator')
                .fontSize(36)
                .fontWeight(FontWeight.Bolder)
                .fontColor($r('sys.color.font_primary'))
              Text('X')
                .fontSize(36)
                .fontWeight(FontWeight.Bolder)
                .fontColor($r('sys.color.font_emphasize'))
            }
            .padding({top: 32})

            Text('Version 1.1.0 Beta (HarmonyOS)')
              .fontSize(14)
              .fontColor($r('sys.color.font_tertiary'))
              .margin({ top: 6, bottom: 40 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // ====================== 特别鸣谢 ==========================
          Column() {
            MenuGroup() {
              MenuButton({
                icon: $r('sys.symbol.gift'),
                title: '特别鸣谢',
                onClickAction: (): void => {
                  console.info('点击：特别鸣谢');
                  // this.creditsDialogController.open();
                  router.pushUrl({
                    url: 'pages/settings/Credits',
                  });
                }
              })
            }
          }
          .padding({ left: 16, right: 16, bottom: 16 })

          // ====================== 联系与支持 ==========================
          Column() {
            MenuGroup() {
              // 官方主页
              MenuButton({
                icon: $r('sys.symbol.house'),
                title: '官方主页',
                onClickAction: (): void => {
                  console.info('点击：官方主页');
                  this.openUrlInBrowser('https://calcx.startyi.com');
                }
              })

              ItemDivider()

              // 开源地址
              MenuButton({
                icon: $r('sys.symbol.share'),
                title: '开源地址',
                onClickAction: (): void => {
                  console.info('点击：开源地址');
                  this.openUrlInBrowser('https://github.com/StarHeartY/CalculatorX');
                }
              })

              ItemDivider()

              // 联系开发者
              MenuButton({
                icon: $r('sys.symbol.envelope'),
                title: '联系开发者',
                onClickAction: (): void => {
                  console.info('点击：联系开发者');
                  this.sendEmail('support@startyi.com');
                }
              })
            }
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