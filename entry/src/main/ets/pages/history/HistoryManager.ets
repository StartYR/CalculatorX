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
import { SymbolGlyphModifier, promptAction } from '@kit.ArkUI';

import pasteboard from '@ohos.pasteboard'; // 剪贴板

// 引擎
import { UniversalHistoryList } from '../../components/common/UniversalHistoryList';
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

  // ==================== 核心状态 ====================
  @State currentIndex: number = 0;             // 记住用户当前滑到了哪个 Tab
  @State currentTabHasData: boolean = false;   // 当前 Tab 是否有数据（控制垃圾桶显隐）
  @State refreshSignal: number = 0;            // 列表刷新信号

  aboutToAppear() {
    // 页面加载时，静默探测第 0 个 Tab ("全部") 的数据状态
    this.checkTabHasData(0);
  }

  // ==================== 页面路由字典 ====================
  // 通过 index 翻译出数据库需要的 moduleType
  private getModuleTypeByIndex(index: number): string {
    switch (index) {
      case 0: return 'all';
      case 1: return 'basic,scientific';
      case 2: return 'equation';
      case 3: return 'graph';
      case 4: return 'matrix';
      case 5: return 'conversion';
      case 6: return 'pro';
      default: return 'all';
    }
  }

  // ==================== 轻量级静默探针 ====================
  private async checkTabHasData(index: number) {
    const targetModule = this.getModuleTypeByIndex(index);
    // limit 设为 1，只要查到 1 条数据，就说明不为空
    const res = await HistoryRepository.queryRecords(targetModule, 1);
    this.currentTabHasData = res.length > 0;
  }

  // TabItem 制造机
  private createTabItem(label: string, symbolRes: Resource): TabItemConfig {
    return {
      label: label,
      icon: new SymbolGlyphModifier(symbolRes)
        .fontSize(24)
        .fontColor([$r('sys.color.icon_primary')]),
      selectedIcon: new SymbolGlyphModifier(symbolRes)
        .fontSize(24)
        .fontColor([$r('sys.color.icon_emphasize')])
    };
  }

  private getTabItems(): TabItemConfig[] {
    return [
      this.createTabItem('全部', $r('sys.symbol.list_bullet_square_fill_1')),
      this.createTabItem('计算', $r('sys.symbol.calculator_fill')),
      this.createTabItem('方程', $r('sys.symbol.exponentiation')),
      this.createTabItem('绘图', $r('sys.symbol.foldline_screen_fill')),
      this.createTabItem('矩阵', $r('sys.symbol.square_fill_grid_2x2')),
      this.createTabItem('转换', $r('sys.symbol.arrow_left_arrow_right')),
      this.createTabItem('更多', $r('sys.symbol.more_fill'))
    ];
  }

  // ==================== 上下文感知垃圾桶 ====================
  @Builder
  TopRightMenu() {
    // 显隐逻辑绑定到当前 Tab 的专属状态上
    if (this.currentTabHasData) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(24)
          .fontColor([$r('sys.color.icon_primary')])
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        // 提取当前 Tab 的名字和模块标识符
        const currentTitle = this.getTabItems()[this.currentIndex].label;
        const targetModule = this.getModuleTypeByIndex(this.currentIndex);

        // 智能动态警告弹窗
        AlertDialog.show({
          title: `清空【${currentTitle}】历史记录`,
          message: targetModule === 'all'
            ? '确定要清空所有模式的历史记录吗？\n此操作无法撤销。'
            : `确定要清空【${currentTitle}】历史记录吗？\n此操作无法撤销。`,
          alignment: DialogAlignment.Bottom,
          offset: { dx: 0, dy: -280 },
          primaryButton: {
            value: '取消',
            action: () => {}
          },
          secondaryButton: {
            value: '清空',
            fontColor: '#FF3B30',
            action: async () => {
              await HistoryRepository.clearHistory(targetModule);// 只清空当前 moduleType 的数据
              this.currentTabHasData = false; // 状态断言：清空完毕后，垃圾桶原地消失
              this.refreshSignal++; // 动画刷新：触发底层 UniversalHistoryList 的清空动画
            }
          }
        })
      })
    }
  }

  // 引擎装配流水线
  @Builder
  buildHistoryList(targetModule: string) {
    UniversalHistoryList({
      moduleType: targetModule,
      isGlobalPage: true,
      refreshCounter: this.refreshSignal,
      onItemClick: (record, insertType) => {
        const textToCopy = insertType === 'input' ? record.inputContent : record.outputContent;
        if (textToCopy) {
          const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, textToCopy);
          pasteboard.getSystemPasteboard().setData(pasteData).then(() => {
            promptAction.showToast({
              message: insertType === 'input' ? '已复制表达式' : '已复制结果',
              duration: 2000,
              bottom: 80
            });
          }).catch((err: Error) => {
            console.error(`复制失败: ${err.message}`);
          });
        }
      }
    })
  }

  @Builder
  buildTabs(tabsConfig: TabItemConfig[]) {
    HdsTabs({ controller: this.controller }) {
      ForEach(tabsConfig, (tab: TabItemConfig, index: number) => {
        TabContent() {
          // 【代码瘦身魔法】：用字典瞬间干掉几十行的 if-else 屎山！
          this.buildHistoryList(this.getModuleTypeByIndex(index))
        }
        .tabBar(new BottomTabBarStyle({ normal: tab.icon, selected: tab.selectedIcon }, tab.label))
      })
    }
    .onChange((index: number) => {
      this.currentIndex = index;           // 更新当前所在 Tab 的指针
      this.checkTabHasData(index);         // 瞬间去查数据库，判断垃圾桶该不该出来！
    })
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

      Row() {
        this.TopRightMenu()
      }
      .height(133)
      .padding({ right: 16 })
    }
    .width('100%')
    .height('100%')
  }
}