// entry/src/main/ets/pages/history/HistoryManager.ets
import router from '@ohos.router';
import { HistoryRepository, HistoryRecord } from '../../database/HistoryRepository';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  hdsMaterial,
  ScrollEffectType,
  HdsTabs,
  HdsTabsController,
  // BottomTabBarStyle
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';

// ==================== 页签项数据结构 ====================
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
  @State isDarkMode: boolean = false;

  aboutToAppear() {
    let context = getContext(this) as common.UIAbilityContext;
    let currentMode = context.config.colorMode;
    this.isDarkMode = (currentMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    this.loadData();
  }

  async loadData() {
    this.historyList = await HistoryRepository.queryRecords(this.moduleType, 100);
  }

  build() {
    Column() {
      if (this.historyList.length === 0) {
        // 空状态
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
        // 数据列表
        List({ space: 12 }) {
          // 【关键修复】顶部占位，让内容从标题栏下方开始，保留沉浸光感
          ListItem() {
            Row().width('100%').height(96) // 与 HdsNavigation 标题栏高度匹配
          }

          ForEach(this.historyList, (item: HistoryRecord) => {
            ListItem() {
              Column() {
                // 上半部分：优先显示输入表达式的图片，没有则显示文本
                if (item.inputBase64 && item.inputBase64.length > 0) {
                  Row() {
                    Image(item.inputBase64)
                      .height(32) // 高度可根据截图实际清晰度微调
                      // 如果当前系统是深色模式，套用反色矩阵
                      .colorFilter(this.isDarkMode ? [
                        -1,  0,  0, 0, 255,
                        0, -1,  0, 0, 255,
                        0,  0, -1, 0, 255,
                        0,  0,  0, 1,   0
                      ] : undefined)
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Start) // [新增] Row 强制把内部紧凑的图片推到最左边
                } else {
                  Text(item.inputContent)
                    .fontSize(16)
                    .fontColor($r('sys.color.font_primary'))
                    .width('100%')
                    .textAlign(TextAlign.Start)
                    .maxLines(3)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }

                // 下半部分：优先显示计算结果的图片，没有则显示文本
                if (item.outputBase64 && item.outputBase64.length > 0) {
                  Row() {
                    Text('=  ')
                      .fontSize(20)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('sys.color.font_primary'))

                    Image(item.outputBase64)
                      .height(40) // 结果字号稍微大一点
                      .objectFit(ImageFit.Contain)
                      .colorFilter(this.isDarkMode ? [
                        -1,  0,  0, 0, 255,
                        0, -1,  0, 0, 255,
                        0,  0, -1, 0, 255,
                        0,  0,  0, 1,   0
                      ] : undefined)
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.End) // 结果整体靠右对齐
                  .margin({ top: 8 })
                } else {
                  Text(`=  ${item.outputContent}`)
                    .fontSize(20)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.font_primary'))
                    .width('100%')
                    .textAlign(TextAlign.End)
                    .margin({ top: 8 })
                }
              }
              .padding(16)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(16)
            }
          }, (item: HistoryRecord) => item.id?.toString())

          // 底部占位：小横条 + 悬浮胶囊高度 + 边距
          ListItem() {
            Row().width('100%').height(this.navBarHeight + 104)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 0, bottom: 0 }) // 顶部内边距归零，由占位控制
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

  // 构建页签配置数组
  private getTabItems(): TabItemConfig[] {
    const allTab: TabItemConfig = {
      label: '全部',
      icon: new SymbolGlyphModifier($r('sys.symbol.list_bullet_square_fill'))
        .fontSize(24)
        .fontColor([$r('sys.color.icon_primary')]),
      selectedIcon: new SymbolGlyphModifier($r('sys.symbol.list_bullet_square_fill'))
        .fontSize(24)
        .fontColor([$r('sys.color.icon_emphasize')])
    };

    const scientificTab: TabItemConfig = {
      label: '科学计算',
      icon: new SymbolGlyphModifier($r('sys.symbol.calculator_fill'))
        .fontSize(24)
        .fontColor([$r('sys.color.icon_primary')]),
      selectedIcon: new SymbolGlyphModifier($r('sys.symbol.calculator_fill'))
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

    return [allTab, scientificTab, equationTab];
  }

  @Builder
  buildTabs(tabsConfig: TabItemConfig[]) {
    HdsTabs({ controller: this.controller }) {
      ForEach(tabsConfig, (tab: TabItemConfig, index: number) => {
        TabContent() {
          if (index === 0) {
            HistoryListTab({ moduleType: 'all' })
          } else if (index === 1) {
            HistoryListTab({ moduleType: 'scientific' })
          } else {
            HistoryListTab({ moduleType: 'equation' })
          }
        }
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
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor($r('sys.color.background_secondary'))
  }
}