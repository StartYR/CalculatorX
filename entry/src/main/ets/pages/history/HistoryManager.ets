/**
 * Copyright (c) 2026 易睿 (Yi Rui). All rights reserved.
 * * @file HistoryManager.ets
 * @description 全局全屏历史检索页，用于处理跨模块的海量计算记录检索
* * @author 易睿 (Yi Rui)
 * @date 2026
 */

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

// 引擎
import { UniversalHistoryList } from '../../components/UniversalHistoryList';
// 数据库操作库，用于一键清空
import { HistoryRepository } from '../../database/HistoryRepository';

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

  // 全局刷新信号！当发生清空操作时，通知所有 Tab 重新加载数据
  @State refreshSignal: number = 0;

  private getTabItems(): TabItemConfig[] {
    return [
      {
        label: '全部',
        icon: new SymbolGlyphModifier($r('sys.symbol.list_bullet_square_fill')).fontSize(24).fontColor([$r('sys.color.icon_primary')]),
        selectedIcon: new SymbolGlyphModifier($r('sys.symbol.list_bullet_square_fill')).fontSize(24).fontColor([$r('sys.color.icon_emphasize')])
      },
      {
        label: '计算',
        icon: new SymbolGlyphModifier($r('sys.symbol.calculator_fill')).fontSize(24).fontColor([$r('sys.color.icon_primary')]),
        selectedIcon: new SymbolGlyphModifier($r('sys.symbol.calculator_fill')).fontSize(24).fontColor([$r('sys.color.icon_emphasize')])
      },
      {
        label: '方程',
        icon: new SymbolGlyphModifier($r('sys.symbol.exponentiation')).fontSize(24).fontColor([$r('sys.color.icon_primary')]),
        selectedIcon: new SymbolGlyphModifier($r('sys.symbol.exponentiation')).fontSize(24).fontColor([$r('sys.color.icon_emphasize')])
      },
      {
        label: '函数图像',
        icon: new SymbolGlyphModifier($r('sys.symbol.exponentiation')).fontSize(24).fontColor([$r('sys.color.icon_primary')]),
        selectedIcon: new SymbolGlyphModifier($r('sys.symbol.exponentiation')).fontSize(24).fontColor([$r('sys.color.icon_emphasize')])
      },
      {
        label: '矩阵向量',
        icon: new SymbolGlyphModifier($r('sys.symbol.exponentiation')).fontSize(24).fontColor([$r('sys.color.icon_primary')]),
        selectedIcon: new SymbolGlyphModifier($r('sys.symbol.exponentiation')).fontSize(24).fontColor([$r('sys.color.icon_emphasize')])
      },
      {
        label: '统计分析',
        icon: new SymbolGlyphModifier($r('sys.symbol.exponentiation')).fontSize(24).fontColor([$r('sys.color.icon_primary')]),
        selectedIcon: new SymbolGlyphModifier($r('sys.symbol.exponentiation')).fontSize(24).fontColor([$r('sys.color.icon_emphasize')])
      }
    ];
  }

  @Builder
  TopRightMenu() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.trash'))
        .fontSize(24)
        .fontColor([$r('sys.color.icon_primary')])
    }
    .width(40)
    .height(40)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      // 警告弹窗
      AlertDialog.show({
        title: '清空全局记录',
        message: '确定要清空所有计算模式的历史记录吗？此操作无法撤销。',
        alignment: DialogAlignment.Bottom,
        offset: { dx: 0, dy: -280 },
        primaryButton: {
          value: '取消',
          action: () => {}
        },
        secondaryButton: {
          value: '全部清空',
          fontColor: '#FF3B30', // 红
          action: async () => {
            await HistoryRepository.clearHistory();
            // 触发列表刷新
            this.refreshSignal++;
          }
        }
      })
    })
  }

  @Builder
  buildTabs(tabsConfig: TabItemConfig[]) {
    HdsTabs({ controller: this.controller }) {
      ForEach(tabsConfig, (tab: TabItemConfig, index: number) => {
        TabContent() {
          // 把 refreshCounter 绑定进引擎，让引擎能听到主控制台的刷新指令
          if (index === 0) {
            UniversalHistoryList({ moduleType: 'all', isGlobalPage: true, refreshCounter: this.refreshSignal })
          } else if (index === 1) {
            UniversalHistoryList({ moduleType: 'basic,scientific', isGlobalPage: true, refreshCounter: this.refreshSignal })
          } else {
            UniversalHistoryList({ moduleType: 'equation', isGlobalPage: true, refreshCounter: this.refreshSignal })
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
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    })
    .height('100%')
    .width('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {

      HdsNavigation() {
        this.buildTabs(this.getTabItems())
      }
      .mode(NavigationMode.Stack)
      .titleBar({
        content: { title: { mainTitle: '全局历史记录' } },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR
          },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        },
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: false
      })
      .hideBackButton(false)
      .titleMode(HdsNavigationTitleMode.MINI)
      // HdsNavigation 忽略了顶部安全区（钻到了状态栏下面）
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      // .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
      .backgroundColor($r('sys.color.background_secondary'))

      // 悬浮的垃圾桶菜单
      Row() {
        this.TopRightMenu()
      }
      .height(133)
      .padding({ right: 16 })
    }
    .width('100%')
    .height('100%')
  }}