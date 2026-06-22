// entry/src/main/ets/pages/history/HistoryManager.ets
import router from '@ohos.router';
import { HistoryRepository, HistoryRecord } from '../../database/HistoryRepository';
import { HdsNavigation, HdsNavigationTitleMode, hdsMaterial, ScrollEffectType } from '@kit.UIDesignKit';

// ==================== 内部子组件：用于渲染不同模块的列表 ====================
@Component
struct HistoryListTab {
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @Prop moduleType: string = 'all';
  @State historyList: HistoryRecord[] = [];

  aboutToAppear() {
    this.loadData();
  }

  // 每次切换 Tab 时，从 SQLite 重新拉取对应分类的数据
  async loadData() {
    this.historyList = await HistoryRepository.queryRecords(this.moduleType, 100); // 全局页面可以多展示一些，上限设为 100
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
            Row().width('100%').height(this.navBarHeight + 16)
          }
        }

        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 0})
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
  @State currentIndex: number = 0;
  private tabsController: TabsController = new TabsController();

  // 自定义 Tab 样式，选中时变大加粗
  @Builder TabBuilder(title: string, targetIndex: number) {
    Column() {
      Text(title)
        .fontColor(this.currentIndex === targetIndex ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
        .fontSize(this.currentIndex === targetIndex ? 16 : 14)
        .fontWeight(this.currentIndex === targetIndex ? FontWeight.Bold : FontWeight.Normal)
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .onClick(() => {
      this.currentIndex = targetIndex;
      this.tabsController.changeIndex(targetIndex);
    })
  }

  build() {
    HdsNavigation() {
      Column() {
        Row().width('100%').height(96)

        Tabs({ barPosition: BarPosition.Start, controller: this.tabsController }) {
          // Tab 1: 全部记录
          TabContent() {
            HistoryListTab({ moduleType: 'all' })
          }
          .tabBar(this.TabBuilder('全部', 0))

          // Tab 2: 科学计算
          TabContent() {
            HistoryListTab({ moduleType: 'scientific' })
          }
          .tabBar(this.TabBuilder('科学计算', 1))

          // Tab 3: 方程求解 (未来的功能占位)
          TabContent() {
            HistoryListTab({ moduleType: 'equation' })
          }
          .tabBar(this.TabBuilder('方程求解', 2))
        }
        .vertical(false)
        .barMode(BarMode.Scrollable) // 如果未来分类很多，允许顶部 Tab 左右滑动
        .barHeight(52)
        .animationDuration(300)
        .onChange((index: number) => {
          this.currentIndex = index;
        })
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      // .padding({ bottom: this.navBarHeight })
    }
    .mode(NavigationMode.Stack)
    .titleBar({
      content: {
        title: { mainTitle: '全局历史记录' }
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
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