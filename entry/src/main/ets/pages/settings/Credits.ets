/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file Credits.ets
 * @description 鸣谢页面，展示项目所依赖的开源组件与第三方库及其主页链接
* * @author 易睿 (Yi Rui)
 * @date 2026
 */

import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { MenuGroup, MenuButton, ItemDivider } from '../../components/common/MenuComponents';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';
import Logger from '../../utils/Logger'

interface CreditItem {
  name: string;
  desc: string;
  url: string;
}

const creditsList: CreditItem[] = [
  { name: 'Giac/Xcas', desc: '核心微积分与高级符号运算引擎', url: 'https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac.html' },
  { name: 'SymEngine', desc: '基础计算机代数系统 (CAS)', url: 'https://github.com/symengine/symengine' },
  { name: 'MathLive', desc: '前端 LaTeX 公式渲染与 MathJSON 引擎', url: 'https://cortexjs.io/mathlive/' },
  { name: 'nlohmann/json', desc: 'C++ 高效 JSON 解析库', url: 'https://github.com/nlohmann/json' },
  { name: 'Boost', desc: '高性能泛型 C++ 基础库', url: 'https://www.boost.org/' },
  { name: 'GMP', desc: 'GNU 多精度算术库，提供极速大数支持', url: 'https://gmplib.org/' }
];

@Entry
@Component
struct Credits {
  private scrollerForScroll: Scroller = new Scroller();
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

  build() {
    HdsNavigation() {
      Scroll(this.scrollerForScroll) {
        Column() {
          Row().width('100%').height(24) // 顶部留白

          // ====================== 鸣谢列表 ==========================
          Column() {
            MenuGroup() {
              ForEach(creditsList, (item: CreditItem, index: number) => {
                MenuButton({
                  title: item.name,
                  subTitle: item.desc,
                  onClickAction: (): void => {
                    this.openUrlInBrowser(item.url);
                  }
                })

                // 除了最后一项，都加上分割线
                if (index < creditsList.length - 1) {
                  ItemDivider({ marginLeft: 12 })
                }
              })
            }
          }
          .padding({ left: 16, right: 16, bottom: 32 })

          Text('我们站在巨人的肩膀上。')
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
            .margin({ bottom: 48 })
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
        title: { mainTitle: '特别鸣谢' },
      },
      style: {
        scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE }
      },
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false
    })
    .bindToScrollable([this.scrollerForScroll])
    .hideBackButton(false) // 允许返回上一页 (About)
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
  }
}