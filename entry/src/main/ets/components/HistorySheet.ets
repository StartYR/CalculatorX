// entry/src/main/ets/components/HistorySheet.ets
import { HistoryRepository, HistoryRecord } from '../database/HistoryRepository';

@Component
export struct HistorySheet {
  @Prop moduleType: string = 'scientific'; // 默认科学计算
  @State historyList: HistoryRecord[] = [];

  // 回调：点击某条记录进行回填
  onItemClick?: (record: HistoryRecord) => void;
  // 回调：触发关闭面板
  onClose?: () => void;

  aboutToAppear() {
    this.loadHistory();
  }

  // 异步加载数据库中的记录
  async loadHistory() {
    this.historyList = await HistoryRepository.queryRecords(this.moduleType, 50);

    if (this.historyList.length > 0) {
      console.info(`【探针3】UI列表第1条的 inputBase64 类型: ${typeof this.historyList[0].inputBase64}, 长度: ${this.historyList[0].inputBase64?.length}`);
    }

  }

  build() {
    Column() {
      // 1. 顶部标题和清空按钮
      Row() {
        Text('历史记录')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))

        Blank() // 弹性占位

        if (this.historyList.length > 0) {
          Text('清空')
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
            .padding(8)
            .stateStyles({
              pressed: { .backgroundColor($r('sys.color.comp_background_secondary')) },
              normal: { .backgroundColor(Color.Transparent) }
            })
            .borderRadius(8)
            .onClick(async () => {
              // 执行清空并重新拉取数据刷新 UI
              await HistoryRepository.clearHistory(this.moduleType);
              this.loadHistory();
            })
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 12 })

      // 2. 列表区域
      if (this.historyList.length === 0) {
        // 空状态展示
        Column() {
          SymbolGlyph($r('sys.symbol.arrow_counterclockwise_clock'))
            .fontSize(48)
            .fontColor([$r('sys.color.icon_tertiary')])
            .margin({ bottom: 12 })
          Text('暂无计算记录')
            .fontSize(14)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        // 数据列表展示
        List({ space: 12 }) {
          ForEach(this.historyList, (item: HistoryRecord) => {
            ListItem() {
              Column() {
                // 上半部分：优先显示输入表达式的图片，没有则显示文本
                if (item.inputBase64 && item.inputBase64.length > 0) {
                  Row() {
                    Image(item.inputBase64)
                      .height(32) // 高度可根据截图实际清晰度微调
                      .objectFit(ImageFit.Contain)
                    // 深色模式反色滤镜预留位
                    // .colorFilter(this.isDarkMode ? [ -1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0 ] : undefined)
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
                    // .colorFilter(...) 同上，深色模式可套用反色矩阵
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
              .onClick(() => {
                // 触发回填回调，并附带关闭面板的回调
                if (this.onItemClick) {
                  this.onItemClick(item);
                }
                if (this.onClose) {
                  this.onClose();
                }
              })
            }
          }, (item: HistoryRecord) => item.id?.toString())
        }
        .layoutWeight(1) // 占据剩余全部高度
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    // 限制一个最大高度，防止数据过多时顶满全屏，保持半模态的优雅
    .constraintSize({ maxHeight: '75%' })
    .backgroundColor($r('sys.color.background_secondary'))
  }
}