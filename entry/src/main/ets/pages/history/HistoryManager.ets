// entry/src/main/ets/pages/history/HistoryManager.ets
import router from '@ohos.router';
import { HistoryRepository, HistoryRecord } from '../../database/HistoryRepository';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  hdsMaterial,
  ScrollEffectType,
  HdsTabs,
  HdsTabsController
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';

// ==================== 定义页签项的数据结构 ====================
// 声明一个接口来描述页签项的完整类型
interface TabItemConfig {
  label: string;
  icon: SymbolGlyphModifier;
  selectedIcon: SymbolGlyphModifier;
}

// ==================== 内部子组件：用于渲染不同模块的列表 ====================
@Component
struct HistoryListTab {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @Prop moduleType: string = 'all';
  @State historyList: HistoryRecord[] = [];

  aboutToAppear() {
    this.loadData();
  }

  async loadData() {
    this.historyList = await HistoryRepository.queryRecords(this.moduleType, 100);
  }

  build() {
    Column() {
      if (this.historyList.length === 0) {
        Column() {
          SymbolGlyph($r('sys.symbol.clock'))
            .fontSize(48)
            .fontColor([$r('sys.color.icon_tertiary')])
            .margin({ bottom: 12 })
          Text('暂无记录')
            .fontSize(14)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        List({ space: 12 }) {
          ForEach(this.historyList, (item: HistoryRecord) => {
            ListItem() {
              Column() {
                Text(item.inputContent)
                  .fontSize(16)
                  .fontColor($r('sys.color.font_primary'))
                  .width('100%')
                  .textAlign(TextAlign.Start)
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(`=  ${item.outputContent}`)
                  .fontSize(20)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                  .width('100%')
                  .textAlign(TextAlign.End)
                  .margin({ top: 8 })
              }
              .padding(16)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(16)
            }
          }, (item: HistoryRecord) => item.id?.toString())

          ListItem() {
            Row().width('100%').height(this.navBarHeight + 104)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 0 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
  }
}

// ==================== 全局历史页面主入口 ====================
@Entry
@Component
export struct HistoryManager {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  private controller: HdsTabsController = new HdsTabsController();

  // 【修复2】明确指定返回类型为 TabItemConfig[]，并正确构建对象
  private getTabItems(): TabItemConfig[] {
    // 使用显式的对象创建，每个属性都符合 TabItemConfig 接口
    const allTab: TabItemConfig = {
      label: '全部',
      icon: new SymbolGlyphModifier($r('sys.symbol.list_bullet'))
        .fontSize(24)
        .fontColor([$r('sys.color.icon_primary')]),
      selectedIcon: new SymbolGlyphModifier($r('sys.symbol.list_bullet'))
        .fontSize(24)
        .fontColor([$r('sys.color.icon_emphasize')])
    };

    const scientificTab: TabItemConfig = {
      label: '科学计算',
      icon: new SymbolGlyphModifier($r('sys.symbol.calculator'))
        .fontSize(24)
        .fontColor([$r('sys.color.icon_primary')]),
      selectedIcon: new SymbolGlyphModifier($r('sys.symbol.calculator'))
        .fontSize(24)
        .fontColor([$r('sys.color.icon_emphasize')])
    };

    const equationTab: TabItemConfig = {
      label: '方程求解',
      icon: new SymbolGlyphModifier($r('sys.symbol.exponentiation'))
        .fontSize(24)
        .fontColor([$r('sys.color.icon_primary')]),
      selectedIcon: new SymbolGlyphModifier($r('sys.symbol.exponentiation'))
        .fontSize(24)
        .fontColor([$r('sys.color.icon_emphasize')])
    };

    // 返回显式类型的数组
    return [allTab, scientificTab, equationTab];
  }

  // 构建页签UI的方法，接收 TabItemConfig 数组
  @Builder
  buildTabs(tabsConfig: TabItemConfig[]) {
    HdsTabs({ controller: this.controller }) {
      ForEach(tabsConfig, (tab: TabItemConfig, index: number) => {
        TabContent() {
          // 根据索引或tab.label决定显示哪个列表
          if (index === 0) {
            HistoryListTab({ moduleType: 'all' })
          } else if (index === 1) {
            HistoryListTab({ moduleType: 'scientific' })
          } else {
            HistoryListTab({ moduleType: 'equation' })
          }
        }
        // 使用 HdsTabs 的页签样式，注意这里传入的是 Modifier 对象
        .tabBar(new BottomTabBarStyle({
          normal: tab.icon,
          selected: tab.selectedIcon
        }, tab.label))
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
    HdsNavigation() {
      // 调用构建方法，传入页签配置
      this.buildTabs(this.getTabItems())
    }
    .mode(NavigationMode.Stack)
    .titleBar({
      content: { title: { mainTitle: '全局历史记录' } },
      style: {
        scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
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
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
  }
}