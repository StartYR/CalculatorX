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

  // 构建函数
  @Builder
  buildHistoryList(targetModule: string) {
    UniversalHistoryList({
      moduleType: targetModule,
      isGlobalPage: true,
      refreshCounter: this.refreshSignal,
      onItemClick: (record, insertType) => {

        // 1. 智能判断需要复制的内容
        const textToCopy = insertType === 'input' ? record.inputContent : record.outputContent;

        // 2. 只有当内容不为空时才执行复制
        if (textToCopy) {
          // 创建纯文本的剪贴板数据对象
          const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, textToCopy);
          // 获取系统剪贴板
          const systemPasteboard = pasteboard.getSystemPasteboard();

          // 写入数据
          systemPasteboard.setData(pasteData).then(() => {
            // 3. 写入成功后，给用户一个极度舒适的反馈
            promptAction.showToast({
              // 根据点击的区域，动态提示文案
              message: insertType === 'input' ? '已复制表达式' : '已复制结果',
              duration: 2000,
              bottom: 80 // 稍微抬高一点，避免被底部 Tab 栏挡住
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
          // 把 refreshCounter 绑定进引擎，让引擎能听到主控制台的刷新指令
          if (index === 0) {
            this.buildHistoryList('all')
          } else if (index === 1) {
            this.buildHistoryList('basic,scientific')
          } else if (index === 2) {
            this.buildHistoryList('equation')
          } else if (index === 3) {
            // TODO
          } else if (index === 4) {
            // TODO
          } else {
            // TODO
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