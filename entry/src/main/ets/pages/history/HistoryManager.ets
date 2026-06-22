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

          // 【核心占位】：高度 = 小横条(navBarHeight) + 悬浮胶囊高度(64) + 悬浮底边距(24) + 留白(16)
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
  @State currentIndex: number = 0;
  private tabsController: TabsController = new TabsController();

  // 自定义悬浮胶囊内的按钮样式 (带图标与弹性动效)
  @Builder PillTabItem(title: string, icon: Resource, targetIndex: number) {
    Column() {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([this.currentIndex === targetIndex ? $r('sys.color.font_emphasize') : $r('sys.color.icon_primary')])
        .fontWeight(this.currentIndex === targetIndex ? FontWeight.Bold : FontWeight.Normal)
        .margin({ bottom: 4 })
      Text(title)
        .fontColor(this.currentIndex === targetIndex ? $r('sys.color.font_emphasize') : $r('sys.color.font_primary'))
        .fontSize(12)
        .fontWeight(this.currentIndex === targetIndex ? FontWeight.Medium : FontWeight.Normal)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      // 点击时触发原生弹性动画，并切换页面
      animateTo({ duration: 350, curve: Curve.Friction }, () => {
        this.currentIndex = targetIndex;
      });
      this.tabsController.changeIndex(targetIndex);
    })
  }

  build() {
    HdsNavigation() {
      // 【核心架构重构】：使用 Stack 实现真正的悬浮叠底
      Stack({ alignContent: Alignment.Bottom }) {

        // ================= 1. 底层内容区 =================
        Column() {
          // 顶部标题占位，防止与 HdsNavigation 标题栏重叠
          Row().width('100%').height(96)

          Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
            TabContent() { HistoryListTab({ moduleType: 'all' }) }
            TabContent() { HistoryListTab({ moduleType: 'scientific' }) }
            TabContent() { HistoryListTab({ moduleType: 'equation' }) }
          }
          .vertical(false)
          .barHeight(0) // 核心：彻底干掉系统原生 TabBar，完全由我们接管 UI
          .animationDuration(350)
          .onChange((index: number) => {
            animateTo({ duration: 350, curve: Curve.Friction }, () => {
              this.currentIndex = index;
            });
          })
          .width('100%')
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')

        // ================= 2. 顶层悬浮胶囊 =================
        Row() {
          this.PillTabItem('全部', $r('sys.symbol.list_bullet'), 0)
          this.PillTabItem('科学计算', $r('sys.symbol.calculator'), 1)
          this.PillTabItem('方程求解', $r('sys.symbol.exponentiation'), 2)
        }
        .width('85%') // 胶囊宽度，两边留出空隙
        .height(64)
        .backgroundColor('#54ffffff') // 半透明白底，配合深浅模式
        .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK) // 开启终极厚材质毛玻璃
        .borderRadius(32) // 极致圆角形成胶囊
        .border({ width: 0.5, color: $r('sys.color.comp_divider') }) // 细微的边缘高光线
        .shadow({
          radius: 32,
          color: '#15000000',
          offsetX: 0,
          offsetY: 8
        })
        .margin({ bottom: this.navBarHeight + 24 }) // 精准悬浮在小横条上方 24vp
      }
      .width('100%')
      .height('100%')
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