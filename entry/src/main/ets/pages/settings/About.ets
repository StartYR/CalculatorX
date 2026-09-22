/**
 * Copyright (c) 2026 StartYi. All rights reserved.
 * @file About.ets
 * @description 关于此应用页面，展示版本信息、官方链接与开源许可声明
 * @author StartYi
 * @date 2026
 */

import common from '@ohos.app.ability.common'; // 用于获取上下文以启动外部应用
import { GroupHeader, ItemDivider, MenuButton, MenuGroup } from '../../components/common/MenuComponents';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';
import Logger from '../../utils/Logger'
import bundleManager from '@ohos.bundle.bundleManager';
import { createDialogMaterial } from '../../utils/ImmersiveMaterialUtils';

// 定义鸣谢数据结构
interface CreditItem {
  name: string;
  desc: string;
  url: string;
}

const creditsList: CreditItem[] = [
  {
    name: 'Giac/Xcas',
    desc: '核心微积分与高级符号运算引擎',
    url: 'https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac.html'
  },
  { name: 'SymEngine', desc: '基础计算机代数系统 (CAS)', url: 'https://github.com/symengine/symengine' },
  { name: 'MathLive', desc: '前端 LaTeX 公式渲染与 MathJSON 引擎', url: 'https://cortexjs.io/mathlive/' },
  { name: 'nlohmann/json', desc: 'C++ 高效 JSON 解析库', url: 'https://github.com/nlohmann/json' },
  { name: 'Boost', desc: '高性能泛型 C++ 基础库', url: 'https://www.boost.org/' },
  { name: 'GMP', desc: 'GNU 多精度算术库，提供极速大数支持', url: 'https://gmplib.org/' }
];


@Entry
@Component
struct About {
  @StorageProp('navBarHeight') navBarHeight: number = 0;

  // 定义版本号状态变量
  @State appVersion: string = 'v0.0.0';

  private scrollerForScroll: Scroller = new Scroller();

  // 获取当前 UIAbility 的上下文，用于拉起外部应用
  private context = getContext(this) as common.UIAbilityContext;

  // 统一封装拉起外部浏览器的函数
  private openUrlInBrowser(url: string): void {
    this.context.startAbility({
      action: "ohos.want.action.viewData",
      entities: ["entity.system.browsable"],
      uri: url
    }).catch((err: Error) => {
      Logger.error(`拉起浏览器失败: ${err.message}`);
    });
  }

  private showCreditsDialog(): void {
    let sheets: SheetInfo[] = creditsList.map((item: CreditItem): SheetInfo => {
      return {
        title: `${item.name} · ${item.desc}`,
        action: () => this.openUrlInBrowser(item.url)
      };
    });

    this.getUIContext().showActionSheet({
      title: '特别鸣谢',
      message: '我们站在巨人的肩膀上。点击项目名称可访问其主页。',
      systemMaterial: createDialogMaterial(),
      sheets: sheets,
      confirm: { value: '关闭', action: () => {} }
    });
  }

  // 统一封装拉起邮件客户端的函数
  private sendEmail(email: string): void {
    this.context.startAbility({
      action: "ohos.want.action.sendData",
      uri: `mailto:${email}`
    }).catch((err: Error) => {
      Logger.error(`拉起邮件客户端失败: ${err.message}`);
    });
  }

  // 在页面即将挂载时，动态获取当前应用的版本号
  aboutToAppear() {
    bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      .then((bundleInfo) => {
        // 成功获取后，将其赋值给状态变量，UI 会自动刷新
        this.appVersion = bundleInfo.versionName;
      })
      .catch((err: Error) => {
        Logger.error(`获取版本号失败: ${err.message}`);
        this.appVersion = '未知版本'; // 容错处理
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

            Text(`Version ${this.appVersion} (HarmonyOS)`)
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
                  Logger.info('点击：特别鸣谢');
                  this.showCreditsDialog();
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
                  Logger.info('点击：官方主页');
                  this.openUrlInBrowser('https://calcx.startyi.com');
                }
              })

              ItemDivider()

              // 开源地址
              MenuButton({
                icon: $r('sys.symbol.share'),
                title: '开源地址',
                onClickAction: (): void => {
                  Logger.info('点击：开源地址');
                  this.openUrlInBrowser('https://github.com/StartYR/CalculatorX');
                }
              })

              ItemDivider()

              // 联系开发者
              MenuButton({
                icon: $r('sys.symbol.envelope'),
                title: '联系我们',
                onClickAction: (): void => {
                  Logger.info('点击：联系我们');
                  this.sendEmail('support@startyi.com');
                }
              })
            }
          }
          .padding({ left: 16, right: 16, bottom: 32 })

          // ====================== 底部版权信息 ==========================
          Column() {
            Text('版权所有 © 2026 StartYi')
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
              .margin({ top: 4, bottom: 4 })
            Text('赣ICP备2026021841号-2A')
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
              .margin({ top: 4, bottom: 4 })
              .onClick(() => {
                this.openUrlInBrowser('https://beian.miit.gov.cn');
              })
            Text('startyi.com')
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
              .margin({ top: 4, bottom: 4 })
              .onClick(() => {
                this.openUrlInBrowser('https://startyi.com');
              })
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
