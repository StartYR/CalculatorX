// entry/src/main/ets/components/UniversalHistoryList.ets
import { HistoryRepository, HistoryRecord } from '../database/HistoryRepository';
import { mediaquery } from '@kit.ArkUI';

@Component
export struct UniversalHistoryList {
  @StorageProp('navBarHeight') navBarHeight: number = 0;

  // 核心参数：决定去数据库捞哪个模块的数据
  @Prop moduleType: string = 'scientific';
  // 核心参数：决定是否需要为了沉浸式导航栏在首尾留出空白占位
  @Prop isGlobalPage: boolean = false;
  // 核心参数：用于接收外部传来的刷新信号
  @Prop @Watch('loadData') refreshCounter: number = 0;

  @State historyList: HistoryRecord[] = [];
  @State isDarkMode: boolean = false;
  private darkModeListener: mediaquery.MediaQueryListener = mediaquery.matchMediaSync('(dark-mode: true)');

  // 暴露点击事件给外部容器处理
  onItemClick?: (record: HistoryRecord) => void;

  aboutToAppear() {
    this.darkModeListener.on('change', (mediaQueryResult: mediaquery.MediaQueryResult) => {
      this.isDarkMode = mediaQueryResult.matches;
    });
    this.isDarkMode = this.darkModeListener.matches;
    this.loadData();
  }

  aboutToDisappear() {
    this.darkModeListener.off('change');
  }

  async loadData() {
    // 引擎不管外壳是谁，只管根据传进来的 moduleType 去查数据库
    let limit = this.isGlobalPage ? 100 : 50;
    this.historyList = await HistoryRepository.queryRecords(this.moduleType, limit);
  }

  build() {
    Column() {
      if (this.historyList.length === 0) {
        // 空状态展现
        Column() {
          SymbolGlyph(this.isGlobalPage ? $r('sys.symbol.clock') : $r('sys.symbol.arrow_counterclockwise_clock'))
            .fontSize(48)
            .fontColor([$r('sys.color.icon_tertiary')])
            .margin({ bottom: 12 })
          Text(this.isGlobalPage ? '暂无记录' : '暂无计算记录')
            .fontSize(14)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        // 核心渲染列表
        List({ space: 12 }) {
          // 如果是全局页面，顶部增加占位以避开沉浸式标题栏
          if (this.isGlobalPage) {
            ListItem() { Row().width('100%').height(96) }
          }

          ForEach(this.historyList, (item: HistoryRecord) => {
            ListItem() {
              Column() {
                // 【输入区】
                if (item.inputBase64 && item.inputBase64.length > 0) {
                  Row() {
                    Image(item.inputBase64)
                      .height(32)
                      .objectFit(ImageFit.Contain)
                      .colorFilter(this.isDarkMode ? [ -1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0 ] : undefined)
                  }.width('100%').justifyContent(FlexAlign.Start)
                } else {
                  Text(item.inputContent).fontSize(16).fontColor($r('sys.color.font_primary'))
                    .width('100%').textAlign(TextAlign.Start).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                }

                // 【输出区】
                if (item.outputBase64 && item.outputBase64.length > 0) {
                  Row() {
                    Text('=  ').fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
                    Image(item.outputBase64)
                      .height(40)
                      .objectFit(ImageFit.Contain)
                      .colorFilter(this.isDarkMode ? [ -1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0 ] : undefined)
                  }.width('100%').justifyContent(FlexAlign.End).margin({ top: 8 })
                } else {
                  Text(`=  ${item.outputContent}`).fontSize(20).fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.font_primary')).width('100%').textAlign(TextAlign.End).margin({ top: 8 })
                }
              }
              .padding(16)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius(16)
              .onClick(() => {
                // 将点击事件抛给外部处理
                if (this.onItemClick) {
                  this.onItemClick(item);
                }
              })
            }
          }, (item: HistoryRecord) => item.id?.toString())

          // 如果是全局页面，底部增加占位以避开 Tab 栏
          if (this.isGlobalPage) {
            ListItem() { Row().width('100%').height(this.navBarHeight + 104) }
          }
        }
        .layoutWeight(1)
        .width('100%')
        // 根据是否为全局页面调整内边距
        .padding(this.isGlobalPage ? { left: 16, right: 16, top: 0, bottom: 0 } : { left: 16, right: 16, bottom: 16 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
  }
}