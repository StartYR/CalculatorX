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
                // 上半部分：输入的表达式 (LaTeX 源码)
                if (item.inputBase64 && item.inputBase64.length > 0) {
                  Image(item.inputBase64)
                    .height(32) // 高度可根据你导出的图片清晰度自行微调
                    .width('100%')
                    .objectFit(ImageFit.Contain)
                    .align(Alignment.Start)
                  // TODO: 适配深色模式时，可取消下方注释，应用反色矩阵
                  // .colorFilter(this.isDarkMode ? [ -1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0 ] : undefined)
                } else {
                  Text(item.inputContent)
                    .fontSize(16)
                    .fontColor($r('sys.color.font_primary'))
                    .width('100%')
                    .textAlign(TextAlign.Start)
                    .maxLines(3)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }

                // 下半部分：计算结果
                if (item.outputBase64 && item.outputBase64.length > 0) {
                  Row() {
                    Text('=  ')
                      .fontSize(20)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('sys.color.font_primary'))

                    Image(item.outputBase64)
                      .height(40)
                      .objectFit(ImageFit.Contain)
                    // .colorFilter(...) 同样可以加上深色反转滤镜
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.End) // 结果靠右对齐
                  .margin({ top: 8 })
                } else {
                  Text(`=  ${item.outputContent}`)
                    .fontSize(20)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.font_primary')) // 品牌色，比如 $r('sys.color.brand') 可以替换
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