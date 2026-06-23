// entry/src/main/ets/pages/history/HistoryManager.ets
import router from '@ohos.router';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  hdsMaterial,
  ScrollEffectType,
  HdsTabs,
  HdsTabsController,
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
// 引入我们的终极引擎
import { UniversalHistoryList } from '../../components/UniversalHistoryList';

interface TabItemConfig {
  label: string;
  icon: SymbolGlyphModifier;
  selectedIcon: SymbolGlyphModifier;
}

@Entry
@Component
export struct HistoryManager {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  private controller: HdsTabsController = new HdsTabsController();

  private getTabItems(): TabItemConfig[] {
    return [
      {
        label: '全部',
        icon: new SymbolGlyphModifier($r('sys.symbol.list_bullet_square_fill')).fontSize(24).fontColor([$r('sys.color.icon_primary')]),
        selectedIcon: new SymbolGlyphModifier($r('sys.symbol.list_bullet_square_fill')).fontSize(24).fontColor([$r('sys.color.icon_emphasize')])
      },
      {
        label: '科学计算',
        icon: new SymbolGlyphModifier($r('sys.symbol.calculator_fill')).fontSize(24).fontColor([$r('sys.color.icon_primary')]),
        selectedIcon: new SymbolGlyphModifier($r('sys.symbol.calculator_fill')).fontSize(24).fontColor([$r('sys.color.icon_emphasize')])
      },
      {
        label: '方程求解',
        icon: new SymbolGlyphModifier($r('sys.symbol.exponentiation')).fontSize(24).fontColor([$r('sys.color.icon_primary')]),
        selectedIcon: new SymbolGlyphModifier($r('sys.symbol.exponentiation')).fontSize(24).fontColor([$r('sys.color.icon_emphasize')])
      }
    ];
  }

  @Builder
  buildTabs(tabsConfig: TabItemConfig[]) {
    HdsTabs({ controller: this.controller }) {
      ForEach(tabsConfig, (tab: TabItemConfig, index: number) => {
        TabContent() {
          // 召唤引擎！这里不需要 onItemClick，纯展示。并且设置 isGlobalPage 为 true 开启下上占位
          if (index === 0) {
            UniversalHistoryList({ moduleType: 'all', isGlobalPage: true })
          } else if (index === 1) {
            UniversalHistoryList({ moduleType: 'scientific', isGlobalPage: true })
          } else {
            // TODO: 未来新增单位换算等页签，在此继续增加 else if 分支即可
            UniversalHistoryList({ moduleType: 'equation', isGlobalPage: true })
          }
        }
        .tabBar(new BottomTabBarStyle({ normal: tab.icon, selected: tab.selectedIcon }, tab.label))
      })
    }
    .barOverlap(true)
    .vertical(false)
    .barPosition(BarPosition.End)
    .barFloatingStyle({
      barBottomMargin: 24,
      systemMaterialEffect: { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE }
    })
    .height('100%')
    .width('100%')
  }

  build() {
    HdsNavigation() {
      this.buildTabs(this.getTabItems())
    }
    .mode(NavigationMode.Stack)
    .titleBar({
      content: { title: { mainTitle: '全局历史记录' } },
      style: {
        scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.ADAPTIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE }
      },
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false
    })
    .hideBackButton(false)
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
  }
}